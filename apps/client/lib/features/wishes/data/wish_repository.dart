import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/sync/outbox_store.dart';
import '../domain/wish.dart';
import '../domain/wish_image.dart';
import '../domain/wish_list.dart';
import 'wish_photo_picker.dart';

/// Абстракция репозитория желаний.
///
/// Feature-код зависит только от этого интерфейса.
/// Реализация — [DriftWishRepository]: локальная БД является
/// единственным источником данных для UI; HTTP живёт в SyncEngine.
abstract interface class WishRepository {
  /// Реактивный поток желаний текущего пользователя (source of truth).
  Stream<List<Wish>> watchWishes();

  /// Все желания текущего пользователя.
  Future<List<Wish>> getWishes();

  /// Желание по id, или `null` если не найдено.
  Future<Wish?> getWishById(String id);

  /// Есть ли хотя бы одно желание.
  Future<bool> hasWishes();

  /// Реактивный поток списков желаний с числом желаний в каждом.
  Stream<List<WishList>> watchWishLists();

  /// Реактивный поток желаний конкретного списка (owner-scoped,
  /// без tombstone). Реагирует на изменение `Wish.listId` —
  /// экран списка обновляется без ручного refresh.
  Stream<List<Wish>> watchWishesInList(String listId);

  /// Создать список желаний локально (UUID генерируется
  /// на клиенте). Запись + outbox create — одна транзакция;
  /// доставку на сервер выполняет SyncEngine.
  Future<WishList> createWishList({required String title});

  /// Переименовать список (замена по [WishList.id]).
  Future<WishList> updateWishList(WishList list);

  /// Удалить список по id: tombstone/физическое удаление по
  /// outbox-правилам + разгруппировка желаний (`listId` → null;
  /// pending-операции желаний патчатся, чтобы не унести мёртвую
  /// ссылку на сервер).
  Future<void> deleteWishList(String id);

  /// Реактивный поток дополнительных изображений желания
  /// (primary — `Wish.imageUrl`), упорядоченных по `sortOrder`.
  Stream<List<WishImage>> watchWishImages(String wishId);

  /// Создать желание локально (UUID генерируется на клиенте).
  ///
  /// [imageUrl] — primary-изображение (remote URL или локальный
  /// путь). [additionalImagePaths] — локальные пути дополнительных
  /// фото (камера/галерея quick-capture); записываются в
  /// `wish_images` в порядке списка (`sortOrder` 1..N) в той же
  /// транзакции — желание никогда не остаётся без части фото.
  Future<Wish> createWish({
    required String title,
    String? description,
    int? price,
    String? link,
    String? imageUrl,
    List<String> additionalImagePaths = const [],
  });

  /// Обновить существующее желание (замена по [Wish.id]).
  Future<Wish> updateWish(Wish wish);

  /// Изменить принадлежность желания списку: [listId] — целевой
  /// список, `null` — убрать из всех списков. Membership — часть
  /// серверного контракта wish: уходит обычным update-op.
  Future<Wish> assignWishToList(String wishId, String? listId);

  /// Удалить желание по id.
  Future<void> deleteWish(String id);
}

/// Ошибка репозитория желаний.
sealed class WishError implements Exception {
  const WishError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Ошибка хранилища/состояния при работе с желаниями.
class WishNetworkError extends WishError {
  const WishNetworkError() : super('storage');
}

/// Действие требует авторизованного пользователя.
class WishNotAuthenticatedError extends WishError {
  const WishNotAuthenticatedError() : super('not_authenticated');
}

/// Желание не найдено в локальном хранилище.
class WishNotFoundError extends WishError {
  const WishNotFoundError() : super('not_found');
}

/// Непредвиденная ошибка при сохранении желания.
class UnknownWishError extends WishError {
  const UnknownWishError() : super('unknown');
}

/// Типы сущностей outbox/sync для wishes-домена.
abstract final class WishEntityTypes {
  static const String wish = 'wish';
  static const String wishList = 'wish_list';
}

/// Провайдер `WishRepository` — Drift-backed реализация.
final wishRepositoryProvider = Provider<WishRepository>((ref) {
  return DriftWishRepository(
    ref.read(appDatabaseProvider),
    ref.read(preferencesServiceProvider),
  );
});

/// Репозиторий желаний поверх Drift.
///
/// Каждая мутация — одна транзакция: запись сущности + outbox-
/// операция атомарно. Сеть сюда не заглядывает — доставкой
/// занимается SyncEngine.
class DriftWishRepository implements WishRepository {
  DriftWishRepository(this._db, this._prefs);

  final AppDatabase _db;
  final PreferencesService _prefs;

  static const _uuid = Uuid();

  String get _ownerId {
    final id = _prefs.currentUserId();
    if (id == null) {
      throw const WishNotAuthenticatedError();
    }
    return id;
  }

  static Wish _toDomain(WishRow r) => Wish(
    id: r.id,
    title: r.title,
    description: r.description,
    price: r.price,
    link: r.link,
    imageUrl: r.imageUrl,
    imageLocalPath: r.imageLocalPath,
    listId: r.listId,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  static WishImage _imageToDomain(WishImageRow r) => WishImage(
    id: r.id,
    localPath: r.localPath,
    remoteUrl: r.remoteUrl,
    sortOrder: r.sortOrder,
  );

  /// Snapshot полей для outbox payload (snake_case = API body).
  static Map<String, dynamic> _payload(Wish w, {String? id}) => {
    'id': ?id,
    'title': w.title,
    'description': w.description,
    'price': w.price,
    'link': w.link,
    // Локальный путь файла не уходит в API (невалидный URL →
    // 422 → markFailed): фото живёт локально до upload-эндпоинта.
    'image_url': Wish.isRemoteImageRef(w.imageUrl) ? w.imageUrl : null,
    // Membership — серверная часть контракта (null = вне списков).
    'list_id': w.listId,
  };

  @override
  Stream<List<Wish>> watchWishes() {
    return _db
        .watchWishes(_ownerId)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<Wish>> getWishes() => watchWishes().first;

  @override
  Future<Wish?> getWishById(String id) async {
    final row = await _db.wishById(_ownerId, id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<bool> hasWishes() => _db.hasWishes(_ownerId);

  @override
  Stream<List<WishList>> watchWishLists() {
    return _db.watchWishListsWithWishes(_ownerId).map((rows) {
      // Группировка join-строк `list + wish?` — счётчик желаний.
      final byId = <String, WishListRow>{};
      final counts = <String, int>{};
      final order = <String>[];
      for (final row in rows) {
        final l = row.readTable(_db.wishLists);
        if (!byId.containsKey(l.id)) {
          byId[l.id] = l;
          order.add(l.id);
        }
        if (row.readTableOrNull(_db.wishes) != null) {
          counts[l.id] = (counts[l.id] ?? 0) + 1;
        }
      }
      return [
        for (final id in order)
          WishList(
            id: id,
            title: byId[id]!.title,
            createdAt: byId[id]!.createdAt,
            updatedAt: byId[id]!.updatedAt,
            wishCount: counts[id] ?? 0,
          ),
      ];
    });
  }

  @override
  Stream<List<Wish>> watchWishesInList(String listId) {
    return _db
        .watchWishesInList(_ownerId, listId)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<WishList> createWishList({required String title}) async {
    final ownerId = _ownerId;
    final now = DateTime.now();
    final list = WishList(id: _uuid.v4(), title: title, createdAt: now);

    await _db.transaction(() async {
      await _db
          .into(_db.wishLists)
          .insert(
            WishListsCompanion(
              id: Value(list.id),
              ownerId: Value(ownerId),
              title: Value(list.title),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await OutboxStore(_db).enqueue(
        ownerId: ownerId,
        entityType: WishEntityTypes.wishList,
        entityId: list.id,
        operation: OutboxOp.create,
        payload: {'id': list.id, 'title': list.title},
      );
    });

    return list;
  }

  @override
  Future<WishList> updateWishList(WishList list) async {
    final ownerId = _ownerId;
    final updated = list.copyWith(updatedAt: DateTime.now());

    await _db.transaction(() async {
      await (_db.update(
        _db.wishLists,
      )..where((l) => l.id.equals(list.id) & l.ownerId.equals(ownerId))).write(
        WishListsCompanion(
          title: Value(updated.title),
          updatedAt: Value(updated.updatedAt!),
        ),
      );
      await OutboxStore(_db).enqueue(
        ownerId: ownerId,
        entityType: WishEntityTypes.wishList,
        entityId: list.id,
        operation: OutboxOp.update,
        payload: {'title': updated.title},
      );
    });

    return updated;
  }

  @override
  Future<void> deleteWishList(String id) async {
    final ownerId = _ownerId;
    await _db.transaction(() async {
      // Желания списка не удаляются — разгруппировываем.
      // Серверная сторона сама обнулит list_id при DELETE списка,
      // поэтому отдельные wish-операции не ставятся; но уже
      // поставленные pending-операции не должны унести list_id
      // мёртвого списка — вычищаем его из их payload'ов.
      await (_db.update(_db.wishes)
            ..where((w) => w.listId.equals(id) & w.ownerId.equals(ownerId)))
          .write(const WishesCompanion(listId: Value(null)));
      await _db.nullListIdInWishOps(ownerId, id);

      final outbox = OutboxStore(_db);
      if (await outbox.hasUnsyncedCreate(ownerId, id)) {
        // create + delete до первого push: сервер сущность не
        // принимал — удаляем физически, HTTP не нужен.
        await (_db.delete(
          _db.wishLists,
        )..where((l) => l.id.equals(id) & l.ownerId.equals(ownerId))).go();
      } else {
        await (_db.update(_db.wishLists)
              ..where((l) => l.id.equals(id) & l.ownerId.equals(ownerId)))
            .write(WishListsCompanion(deletedAt: Value(DateTime.now())));
      }
      await outbox.enqueue(
        ownerId: ownerId,
        entityType: WishEntityTypes.wishList,
        entityId: id,
        operation: OutboxOp.delete,
      );
    });
  }

  @override
  Stream<List<WishImage>> watchWishImages(String wishId) {
    return _db
        .watchWishImages(_ownerId, wishId)
        .map((rows) => rows.map(_imageToDomain).toList());
  }

  @override
  Future<Wish> createWish({
    required String title,
    String? description,
    int? price,
    String? link,
    String? imageUrl,
    String? listId,
    List<String> additionalImagePaths = const [],
  }) async {
    final now = DateTime.now();
    final ownerId = _ownerId;
    final isLocalImage = imageUrl != null && !Wish.isRemoteImageRef(imageUrl);

    final wish = Wish(
      id: _uuid.v4(),
      title: title,
      description: description,
      price: price,
      link: link,
      imageUrl: imageUrl,
      imageLocalPath: isLocalImage ? imageUrl : null,
      listId: listId,
      createdAt: now,
      updatedAt: now,
    );

    await _db.transaction(() async {
      await _db
          .into(_db.wishes)
          .insert(
            WishesCompanion(
              id: Value(wish.id),
              ownerId: Value(ownerId),
              title: Value(wish.title),
              description: Value(wish.description),
              price: Value(wish.price),
              link: Value(wish.link),
              imageUrl: Value(wish.imageUrl),
              imageLocalPath: Value(wish.imageLocalPath),
              // Локальный файл ждёт upload; remote-ссылка
              // считается уже доставленной (ADR-015).
              imageUploadStatus: Value(
                imageUrl == null
                    ? null
                    : isLocalImage
                    ? 'pending'
                    : 'uploaded',
              ),
              imageUploadId: Value(isLocalImage ? _uuid.v4() : null),
              listId: Value(wish.listId),
              createdAt: Value(wish.createdAt),
              updatedAt: Value(wish.updatedAt!),
            ),
          );
      // Дополнительные изображения — в той же транзакции:
      // желание никогда не остаётся без части фото.
      for (var i = 0; i < additionalImagePaths.length; i++) {
        await _db
            .into(_db.wishImages)
            .insert(
              WishImagesCompanion(
                id: Value(_uuid.v4()),
                uploadId: Value(_uuid.v4()),
                ownerId: Value(ownerId),
                wishId: Value(wish.id),
                localPath: Value(additionalImagePaths[i]),
                sortOrder: Value(i + 1),
                createdAt: Value(now),
              ),
            );
      }
      await OutboxStore(_db).enqueue(
        ownerId: ownerId,
        entityType: WishEntityTypes.wish,
        entityId: wish.id,
        operation: OutboxOp.create,
        payload: _payload(wish, id: wish.id),
      );
    });

    return wish;
  }

  @override
  Future<Wish> updateWish(Wish wish) async {
    final ownerId = _ownerId;
    final existing = await _db.wishById(ownerId, wish.id);
    if (existing == null) {
      throw const WishNotFoundError();
    }
    final updated = wish.copyWith(updatedAt: DateTime.now());
    // Local path следует за image_url: не менялся → сохраняем
    // (remote URL после upload не трогает display-source); новый
    // локальный файл → новый путь; смена на URL/null → сброс.
    final localPath = updated.imageUrl == existing.imageUrl
        ? existing.imageLocalPath
        : Wish.isRemoteImageRef(updated.imageUrl)
        ? null
        : updated.imageUrl;

    await _db.transaction(() async {
      await (_db.update(
        _db.wishes,
      )..where((w) => w.id.equals(wish.id) & w.ownerId.equals(ownerId))).write(
        WishesCompanion(
          title: Value(updated.title),
          description: Value(updated.description),
          price: Value(updated.price),
          link: Value(updated.link),
          imageUrl: Value(updated.imageUrl),
          imageLocalPath: Value(localPath),
          listId: Value(updated.listId),
          updatedAt: Value(updated.updatedAt!),
        ),
      );
      await OutboxStore(_db).enqueue(
        ownerId: ownerId,
        entityType: WishEntityTypes.wish,
        entityId: updated.id,
        operation: OutboxOp.update,
        payload: _payload(updated),
      );
    });

    return updated;
  }

  @override
  Future<Wish> assignWishToList(String wishId, String? listId) async {
    // copyWith не умеет сбрасывать nullable — собираем доменную
    // модель из строки напрямую с явным listId.
    final row = await _db.wishById(_ownerId, wishId);
    if (row == null) {
      throw const WishNotFoundError();
    }
    return updateWish(
      Wish(
        id: row.id,
        title: row.title,
        description: row.description,
        price: row.price,
        link: row.link,
        imageUrl: row.imageUrl,
        imageLocalPath: row.imageLocalPath,
        listId: listId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      ),
    );
  }

  @override
  Future<void> deleteWish(String id) async {
    final ownerId = _ownerId;
    var filePaths = const <String>[];
    await _db.transaction(() async {
      final outbox = OutboxStore(_db);
      if (await outbox.hasUnsyncedCreate(ownerId, id)) {
        // create + delete до первого успешного push: сервер никогда
        // не принимал сущность — удаляем физически, HTTP не нужен.
        // Изображения уходят вместе с желанием; tombstone-путь
        // их сохраняет — при 422 желание вернётся вместе с фото.
        final local = await _db.wishById(ownerId, id);
        filePaths = [
          if (local?.imageLocalPath != null)
            local!.imageLocalPath!
          else if (!Wish.isRemoteImageRef(local?.imageUrl))
            local!.imageUrl!,
          ...await _db.deleteWishImages(ownerId, id),
        ];
        await (_db.delete(
          _db.wishes,
        )..where((w) => w.id.equals(id) & w.ownerId.equals(ownerId))).go();
      } else {
        await (_db.update(_db.wishes)
              ..where((w) => w.id.equals(id) & w.ownerId.equals(ownerId)))
            .write(WishesCompanion(deletedAt: Value(DateTime.now())));
      }
      await outbox.enqueue(
        ownerId: ownerId,
        entityType: WishEntityTypes.wish,
        entityId: id,
        operation: OutboxOp.delete,
      );
    });
    // Файлы — вне транзакции, best-effort.
    if (filePaths.isNotEmpty) await deleteWishPhotoFiles(filePaths);
  }
}
