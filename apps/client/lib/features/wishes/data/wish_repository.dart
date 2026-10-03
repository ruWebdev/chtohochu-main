import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/sync/outbox_store.dart';
import '../domain/wish.dart';

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

  /// Создать желание локально (UUID генерируется на клиенте).
  Future<Wish> createWish({
    required String title,
    String? description,
    int? price,
    String? link,
    String? imageUrl,
  });

  /// Обновить существующее желание (замена по [Wish.id]).
  Future<Wish> updateWish(Wish wish);

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
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  /// Snapshot полей для outbox payload (snake_case = API body).
  static Map<String, dynamic> _payload(Wish w, {String? id}) => {
    'id': ?id,
    'title': w.title,
    'description': w.description,
    'price': w.price,
    'link': w.link,
    'image_url': w.imageUrl,
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
  Future<Wish> createWish({
    required String title,
    String? description,
    int? price,
    String? link,
    String? imageUrl,
  }) async {
    final now = DateTime.now();
    final wish = Wish(
      id: _uuid.v4(),
      title: title,
      description: description,
      price: price,
      link: link,
      imageUrl: imageUrl,
      createdAt: now,
      updatedAt: now,
    );

    await _db.transaction(() async {
      await _db
          .into(_db.wishes)
          .insert(
            WishesCompanion(
              id: Value(wish.id),
              ownerId: Value(_ownerId),
              title: Value(wish.title),
              description: Value(wish.description),
              price: Value(wish.price),
              link: Value(wish.link),
              imageUrl: Value(wish.imageUrl),
              createdAt: Value(wish.createdAt),
              updatedAt: Value(wish.updatedAt!),
            ),
          );
      await OutboxStore(_db).enqueue(
        ownerId: _ownerId,
        entityType: 'wish',
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
          updatedAt: Value(updated.updatedAt!),
        ),
      );
      await OutboxStore(_db).enqueue(
        ownerId: ownerId,
        entityType: 'wish',
        entityId: updated.id,
        operation: OutboxOp.update,
        payload: _payload(updated),
      );
    });

    return updated;
  }

  @override
  Future<void> deleteWish(String id) async {
    final ownerId = _ownerId;
    await _db.transaction(() async {
      final outbox = OutboxStore(_db);
      if (await outbox.hasUnsyncedCreate(ownerId, id)) {
        // create + delete до первого успешного push: сервер никогда
        // не принимал сущность — удаляем физически, HTTP не нужен.
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
        entityType: 'wish',
        entityId: id,
        operation: OutboxOp.delete,
      );
    });
  }
}
