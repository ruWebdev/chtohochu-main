import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/preferences_service.dart';
import '../sync/outbox_store.dart';
import 'app_database.dart';
import 'database_provider.dart';

/// One-time миграция legacy SharedPreferences-кэша в Drift.
///
/// Старые `wish_<millis>` id — не UUID и не годятся как server
/// identity → при импорте каждой записи выдаётся новый UUID и
/// ставится outbox-операция create (сервер получит её при sync).
///
/// Идемпотентна: выполняется один раз (флаг `wishes_migrated`);
/// при повторном запуске — no-op. При сбое транзакции флаг не
/// ставится и старый кэш не удаляется → повтор при следующем старте.
class LegacyWishesMigration {
  LegacyWishesMigration(this._db, this._prefs);

  final AppDatabase _db;
  final PreferencesService _prefs;

  static const _uuid = Uuid();
  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Импортировать legacy желания для [ownerId]. Вызывать после
  /// того, как установлена сессия (нужен владелец данных).
  Future<void> migrate(String ownerId) async {
    if (_prefs.isWishesMigrated()) return;

    final json = _prefs.readLegacyWishesCache();
    if (json != null) {
      List<dynamic> items;
      try {
        items = jsonDecode(json) as List<dynamic>;
      } catch (_) {
        items = const [];
      }

      await _db.transaction(() async {
        for (final item in items) {
          final m = item as Map<String, dynamic>;
          final oldId = m['id'] as String;
          // Старый id сохраняем только если это валидный UUID;
          // иначе — новый (server identity всегда UUID).
          final id = _uuidRe.hasMatch(oldId) ? oldId : _uuid.v4();
          final createdAt =
              DateTime.tryParse(m['createdAt'] as String? ?? '') ??
              DateTime.now();

          final exists =
              await (_db.select(
                _db.wishes,
              )..where((w) => w.id.equals(id))).getSingleOrNull() !=
              null;
          if (exists) continue;

          await _db
              .into(_db.wishes)
              .insert(
                WishesCompanion(
                  id: Value(id),
                  ownerId: Value(ownerId),
                  title: Value(m['title'] as String),
                  description: Value(m['description'] as String?),
                  price: Value(m['price'] as int?),
                  link: Value(m['link'] as String?),
                  imageUrl: Value(m['imageUrl'] as String?),
                  createdAt: Value(createdAt),
                  updatedAt: Value(createdAt),
                ),
              );
          await OutboxStore(_db).enqueue(
            ownerId: ownerId,
            entityType: 'wish',
            entityId: id,
            operation: OutboxOp.create,
            payload: {
              'id': id,
              'title': m['title'],
              'description': m['description'],
              'price': m['price'],
              'link': m['link'],
              'image_url': m['imageUrl'],
            },
          );
        }
      });
    }

    await _prefs.clearLegacyWishesCache();
    await _prefs.setWishesMigrated();
  }
}

final legacyWishesMigrationProvider = Provider<LegacyWishesMigration>((ref) {
  return LegacyWishesMigration(
    ref.read(appDatabaseProvider),
    ref.read(preferencesServiceProvider),
  );
});

/// One-time миграция legacy `shopping_lists_cache` в Drift.
///
/// Старые `list_<millis>`/`item_<millis>` id → новые UUID
/// (server identity всегда UUID). Для каждого импортированного
/// списка и позиции ставится outbox create — они доедут при
/// первом sync. Идемпотентна (флаг `shopping_lists_migrated`).
class LegacyShoppingListsMigration {
  LegacyShoppingListsMigration(this._db, this._prefs);

  final AppDatabase _db;
  final PreferencesService _prefs;

  static const _uuid = Uuid();
  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Импортировать legacy списки покупок для [ownerId].
  Future<void> migrate(String ownerId) async {
    if (_prefs.isShoppingListsMigrated()) return;

    final json = _prefs.readShoppingListsCache();
    if (json != null) {
      List<dynamic> lists;
      try {
        lists = jsonDecode(json) as List<dynamic>;
      } catch (_) {
        lists = const [];
      }

      await _db.transaction(() async {
        final outbox = OutboxStore(_db);
        for (final rawList in lists) {
          final m = rawList as Map<String, dynamic>;
          final listId = _idOrNew(m['id'] as String?);
          final createdAt =
              DateTime.tryParse(m['createdAt'] as String? ?? '') ??
              DateTime.now();

          final exists =
              await (_db.select(
                _db.shoppingLists,
              )..where((l) => l.id.equals(listId))).getSingleOrNull() !=
              null;
          if (exists) continue;

          await _db
              .into(_db.shoppingLists)
              .insert(
                ShoppingListsCompanion(
                  id: Value(listId),
                  ownerId: Value(ownerId),
                  title: Value(m['title'] as String),
                  createdAt: Value(createdAt),
                  updatedAt: Value(createdAt),
                ),
              );
          await outbox.enqueue(
            ownerId: ownerId,
            entityType: 'shopping_list',
            entityId: listId,
            operation: OutboxOp.create,
            payload: {'id': listId, 'title': m['title']},
          );

          final items = m['items'];
          if (items is! List) continue;
          for (final rawItem in items) {
            final im = rawItem as Map<String, dynamic>;
            final itemId = _idOrNew(im['id'] as String?);
            final quantity = im['quantity'] as int? ?? 1;
            final isChecked = im['isChecked'] as bool? ?? false;
            await _db
                .into(_db.shoppingItems)
                .insert(
                  ShoppingItemsCompanion(
                    id: Value(itemId),
                    ownerId: Value(ownerId),
                    listId: Value(listId),
                    title: Value(im['title'] as String),
                    quantity: Value(quantity),
                    isChecked: Value(isChecked),
                    createdAt: Value(createdAt),
                    updatedAt: Value(createdAt),
                  ),
                );
            await outbox.enqueue(
              ownerId: ownerId,
              entityType: 'shopping_item',
              entityId: itemId,
              operation: OutboxOp.create,
              payload: {
                'id': itemId,
                'list_id': listId,
                'title': im['title'],
                'quantity': quantity,
                'is_checked': isChecked,
              },
            );
          }
        }
      });
    }

    await _prefs.clearShoppingListsCache();
    await _prefs.setShoppingListsMigrated();
  }

  /// Валидный UUID сохраняется как identity; legacy id → новый UUID.
  String _idOrNew(String? raw) =>
      raw != null && _uuidRe.hasMatch(raw) ? raw : _uuid.v4();
}

final legacyShoppingListsMigrationProvider =
    Provider<LegacyShoppingListsMigration>((ref) {
      return LegacyShoppingListsMigration(
        ref.read(appDatabaseProvider),
        ref.read(preferencesServiceProvider),
      );
    });
