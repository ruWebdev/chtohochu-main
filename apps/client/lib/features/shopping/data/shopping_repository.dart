import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/sync/outbox_store.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';

/// Абстракция репозитория списков покупок.
///
/// Feature-код зависит только от этого интерфейса.
/// Реализация — [DriftShoppingRepository]: локальная БД является
/// единственным источником данных для UI; HTTP живёт в SyncEngine.
abstract interface class ShoppingRepository {
  /// Реактивный поток списков с позициями (source of truth для UI).
  Stream<List<ShoppingList>> watchLists();

  /// Все списки покупок текущего пользователя.
  Future<List<ShoppingList>> getLists();

  /// Список по id, или `null` если не найден.
  Future<ShoppingList?> getListById(String id);

  /// Создать список локально (UUID генерируется на клиенте).
  Future<ShoppingList> createList({required String title});

  /// Обновить список (название + дифф позиций — каждая изменённая
  /// часть идёт своей outbox-операцией в одной транзакции).
  Future<ShoppingList> updateList(ShoppingList list);

  /// Удалить список по id вместе с позициями.
  Future<void> deleteList(String id);

  /// Добавить позицию в список.
  Future<ShoppingItem> addItem({
    required String listId,
    required String title,
    int quantity = 1,
  });

  /// Обновить позицию (название, количество, отметка «куплено»).
  Future<ShoppingItem> updateItem(ShoppingItem item, {required String listId});

  /// Удалить позицию.
  Future<void> deleteItem(String itemId, {required String listId});
}

/// Ошибка репозитория покупок.
///
/// [message] — технический код для логов/отладки, НЕ пользовательский
/// текст. Текст выбирает presentation через `shoppingErrorMessage`.
sealed class ShoppingError implements Exception {
  const ShoppingError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Ошибка хранилища/состояния при работе со списками покупок.
class ShoppingStorageError extends ShoppingError {
  const ShoppingStorageError() : super('storage');
}

/// Действие требует авторизованного пользователя.
class ShoppingNotAuthenticatedError extends ShoppingError {
  const ShoppingNotAuthenticatedError() : super('not_authenticated');
}

/// Список покупок не найден.
class ShoppingListNotFoundError extends ShoppingError {
  const ShoppingListNotFoundError() : super('list_not_found');
}

/// Позиция списка не найдена.
class ShoppingItemNotFoundError extends ShoppingError {
  const ShoppingItemNotFoundError() : super('item_not_found');
}

/// Непредвиденная ошибка при сохранении списка.
class UnknownShoppingError extends ShoppingError {
  const UnknownShoppingError() : super('unknown');
}

/// Провайдер `ShoppingRepository` — Drift-backed реализация.
final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return DriftShoppingRepository(
    ref.read(appDatabaseProvider),
    ref.read(preferencesServiceProvider),
  );
});

/// Типы сущностей в общем outbox.
abstract final class ShoppingEntityTypes {
  static const String list = 'shopping_list';
  static const String item = 'shopping_item';
}

/// Репозиторий покупок поверх Drift.
///
/// Каждая мутация — одна транзакция: запись сущности + outbox-
/// операция атомарно. Сети здесь нет — доставкой занимается
/// SyncEngine. UUID выдаётся до локальной записи и служит
/// серверной identity без remap'а.
class DriftShoppingRepository implements ShoppingRepository {
  DriftShoppingRepository(this._db, this._prefs);

  final AppDatabase _db;
  final PreferencesService _prefs;

  static const _uuid = Uuid();
  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  String get _ownerId {
    final id = _prefs.currentUserId();
    if (id == null) {
      throw const ShoppingNotAuthenticatedError();
    }
    return id;
  }

  static ShoppingItem _itemToDomain(ShoppingItemRow r) => ShoppingItem(
    id: r.id,
    title: r.title,
    quantity: r.quantity,
    isChecked: r.isChecked,
  );

  @override
  Stream<List<ShoppingList>> watchLists() {
    return _db.watchShoppingListsWithItems(_ownerId).map((rows) {
      // Группировка join-строк `list + item?` в доменную модель.
      final byId = <String, ShoppingList>{};
      final itemsByList = <String, List<ShoppingItem>>{};
      final order = <String>[];
      for (final row in rows) {
        final l = row.readTable(_db.shoppingLists);
        final item = row.readTableOrNull(_db.shoppingItems);
        if (!byId.containsKey(l.id)) {
          byId[l.id] = ShoppingList(
            id: l.id,
            title: l.title,
            createdAt: l.createdAt,
          );
          order.add(l.id);
        }
        if (item != null) {
          itemsByList.putIfAbsent(l.id, () => []).add(_itemToDomain(item));
        }
      }
      return [
        for (final id in order)
          byId[id]!.copyWith(items: itemsByList[id] ?? const []),
      ];
    });
  }

  @override
  Future<List<ShoppingList>> getLists() => watchLists().first;

  @override
  Future<ShoppingList?> getListById(String id) async {
    final row = await _db.shoppingListById(_ownerId, id);
    if (row == null) return null;
    final items = await _db.shoppingItemsOf(_ownerId, id);
    return ShoppingList(
      id: row.id,
      title: row.title,
      createdAt: row.createdAt,
      items: [for (final i in items) _itemToDomain(i)],
    );
  }

  @override
  Future<ShoppingList> createList({required String title}) async {
    final ownerId = _ownerId;
    final now = DateTime.now();
    final list = ShoppingList(id: _uuid.v4(), title: title, createdAt: now);

    await _db.transaction(() async {
      await _db
          .into(_db.shoppingLists)
          .insert(
            ShoppingListsCompanion(
              id: Value(list.id),
              ownerId: Value(ownerId),
              title: Value(list.title),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await OutboxStore(_db).enqueue(
        ownerId: ownerId,
        entityType: ShoppingEntityTypes.list,
        entityId: list.id,
        operation: OutboxOp.create,
        payload: {'id': list.id, 'title': title},
      );
    });

    return list;
  }

  @override
  Future<ShoppingList> updateList(ShoppingList list) async {
    final ownerId = _ownerId;
    final existing = await _db.shoppingListById(ownerId, list.id);
    if (existing == null) {
      throw const ShoppingListNotFoundError();
    }
    final now = DateTime.now();
    final localItems = await _db.shoppingItemsOf(ownerId, list.id);
    final localById = {for (final i in localItems) i.id: i};

    await _db.transaction(() async {
      final outbox = OutboxStore(_db);

      // Название изменилось — update-операция списка.
      if (existing.title != list.title) {
        await (_db.update(_db.shoppingLists)
              ..where((l) => l.id.equals(list.id) & l.ownerId.equals(ownerId)))
            .write(
              ShoppingListsCompanion(
                title: Value(list.title),
                updatedAt: Value(now),
              ),
            );
        await outbox.enqueue(
          ownerId: ownerId,
          entityType: ShoppingEntityTypes.list,
          entityId: list.id,
          operation: OutboxOp.update,
          payload: {'title': list.title},
        );
      }

      // Дифф позиций: новые → create, изменённые → update.
      final incomingIds = <String>{};
      for (final item in list.items) {
        final local = localById[item.id];
        if (local == null) {
          // Позиция без валидного UUID — выдаём серверную identity.
          final itemId = _uuidRe.hasMatch(item.id) ? item.id : _uuid.v4();
          await _insertItem(
            outbox,
            ownerId: ownerId,
            listId: list.id,
            item: item.copyWith(id: itemId),
            now: now,
          );
        } else if (local.title != item.title ||
            local.quantity != item.quantity ||
            local.isChecked != item.isChecked) {
          await _writeItem(
            outbox,
            ownerId: ownerId,
            listId: list.id,
            item: item,
            now: now,
          );
        }
        incomingIds.add(local?.id ?? item.id);
      }

      // Убранные из списка позиции — delete по обычному пути.
      for (final local in localItems) {
        if (incomingIds.contains(local.id)) continue;
        await _deleteItemRow(outbox, ownerId: ownerId, itemId: local.id);
      }
    });

    return list;
  }

  @override
  Future<void> deleteList(String id) async {
    final ownerId = _ownerId;
    await _db.transaction(() async {
      final outbox = OutboxStore(_db);

      // Позиции умирают вместе со списком: серверный
      // DELETE /shopping-lists/{id} каскадно удалит их — отдельные
      // item-операции не нужны, свои ops снимаем целиком.
      final items = await _db.shoppingItemsOf(ownerId, id);
      for (final item in items) {
        await (_db.delete(
          _db.shoppingItems,
        )..where((i) => i.id.equals(item.id) & i.ownerId.equals(ownerId))).go();
        await outbox.dropEntityOps(ownerId, item.id);
      }

      if (await outbox.hasUnsyncedCreate(ownerId, id)) {
        // Список никогда не доезжал до сервера — физическое
        // удаление, HTTP не нужен.
        await (_db.delete(
          _db.shoppingLists,
        )..where((l) => l.id.equals(id) & l.ownerId.equals(ownerId))).go();
      } else {
        await (_db.update(_db.shoppingLists)
              ..where((l) => l.id.equals(id) & l.ownerId.equals(ownerId)))
            .write(ShoppingListsCompanion(deletedAt: Value(DateTime.now())));
      }
      await outbox.enqueue(
        ownerId: ownerId,
        entityType: ShoppingEntityTypes.list,
        entityId: id,
        operation: OutboxOp.delete,
      );
    });
  }

  @override
  Future<ShoppingItem> addItem({
    required String listId,
    required String title,
    int quantity = 1,
  }) async {
    final ownerId = _ownerId;
    final list = await _db.shoppingListById(ownerId, listId);
    if (list == null) {
      throw const ShoppingListNotFoundError();
    }
    final item = ShoppingItem(id: _uuid.v4(), title: title, quantity: quantity);
    await _db.transaction(() async {
      await _insertItem(
        OutboxStore(_db),
        ownerId: ownerId,
        listId: listId,
        item: item,
        now: DateTime.now(),
      );
    });
    return item;
  }

  @override
  Future<ShoppingItem> updateItem(
    ShoppingItem item, {
    required String listId,
  }) async {
    final ownerId = _ownerId;
    final existing = await _db.shoppingItemByIdAny(ownerId, item.id);
    if (existing == null ||
        existing.listId != listId ||
        existing.deletedAt != null) {
      throw const ShoppingItemNotFoundError();
    }
    await _db.transaction(() async {
      await _writeItem(
        OutboxStore(_db),
        ownerId: ownerId,
        listId: listId,
        item: item,
        now: DateTime.now(),
      );
    });
    return item;
  }

  @override
  Future<void> deleteItem(String itemId, {required String listId}) async {
    final ownerId = _ownerId;
    await _db.transaction(() async {
      final existing = await _db.shoppingItemByIdAny(ownerId, itemId);
      if (existing == null || existing.listId != listId) return;
      await _deleteItemRow(OutboxStore(_db), ownerId: ownerId, itemId: itemId);
    });
  }

  /// INSERT позиции + outbox create (внутри транзакции вызывающего).
  Future<void> _insertItem(
    OutboxStore outbox, {
    required String ownerId,
    required String listId,
    required ShoppingItem item,
    required DateTime now,
  }) async {
    await _db
        .into(_db.shoppingItems)
        .insert(
          ShoppingItemsCompanion(
            id: Value(item.id),
            ownerId: Value(ownerId),
            listId: Value(listId),
            title: Value(item.title),
            quantity: Value(item.quantity),
            isChecked: Value(item.isChecked),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await outbox.enqueue(
      ownerId: ownerId,
      entityType: ShoppingEntityTypes.item,
      entityId: item.id,
      operation: OutboxOp.create,
      payload: {
        'id': item.id,
        'list_id': listId,
        'title': item.title,
        'quantity': item.quantity,
        'is_checked': item.isChecked,
      },
    );
  }

  /// UPDATE позиции + outbox update (внутри транзакции вызывающего).
  Future<void> _writeItem(
    OutboxStore outbox, {
    required String ownerId,
    required String listId,
    required ShoppingItem item,
    required DateTime now,
  }) async {
    await (_db.update(_db.shoppingItems)..where(
          (i) =>
              i.id.equals(item.id) &
              i.ownerId.equals(ownerId) &
              i.listId.equals(listId),
        ))
        .write(
          ShoppingItemsCompanion(
            title: Value(item.title),
            quantity: Value(item.quantity),
            isChecked: Value(item.isChecked),
            updatedAt: Value(now),
          ),
        );
    await outbox.enqueue(
      ownerId: ownerId,
      entityType: ShoppingEntityTypes.item,
      entityId: item.id,
      operation: OutboxOp.update,
      payload: {
        'title': item.title,
        'quantity': item.quantity,
        'is_checked': item.isChecked,
      },
    );
  }

  /// DELETE позиции: unsynced-create → физически, иначе tombstone
  /// + outbox delete (внутри транзакции вызывающего).
  Future<void> _deleteItemRow(
    OutboxStore outbox, {
    required String ownerId,
    required String itemId,
  }) async {
    if (await outbox.hasUnsyncedCreate(ownerId, itemId)) {
      await (_db.delete(
        _db.shoppingItems,
      )..where((i) => i.id.equals(itemId) & i.ownerId.equals(ownerId))).go();
    } else {
      await (_db.update(_db.shoppingItems)
            ..where((i) => i.id.equals(itemId) & i.ownerId.equals(ownerId)))
          .write(ShoppingItemsCompanion(deletedAt: Value(DateTime.now())));
    }
    await outbox.enqueue(
      ownerId: ownerId,
      entityType: ShoppingEntityTypes.item,
      entityId: itemId,
      operation: OutboxOp.delete,
    );
  }
}
