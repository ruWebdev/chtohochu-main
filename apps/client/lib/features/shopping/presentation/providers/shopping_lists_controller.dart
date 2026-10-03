import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/sync_engine.dart';
import '../../data/shopping_repository.dart';
import '../../domain/shopping_item.dart';
import '../../domain/shopping_list.dart';

/// Контроллер списков покупок.
///
/// Подписан на Drift stream репозитория — локальные мутации и
/// результат sync обновляют UI автоматически, без ручного
/// управления списком в памяти.
class ShoppingListsController extends StreamNotifier<List<ShoppingList>> {
  @override
  Stream<List<ShoppingList>> build() {
    return ref.watch(shoppingRepositoryProvider).watchLists();
  }

  /// Pull-to-refresh: запросить синхронизацию (push outbox +
  /// pull snapshot). UI продолжает читать Drift — сетевой сбой
  /// не превращает экран в error state.
  Future<void> refresh() => ref.read(syncEngineProvider).requestSync();

  /// Удалить список вместе с позициями (локально + outbox).
  Future<void> deleteList(String id) =>
      ref.read(shoppingRepositoryProvider).deleteList(id);

  /// Добавить позицию в список. Возвращает обновлённый список.
  Future<ShoppingList?> addItem(
    String listId, {
    required String title,
    int quantity = 1,
  }) async {
    await ref
        .read(shoppingRepositoryProvider)
        .addItem(listId: listId, title: title, quantity: quantity);
    return ref.read(shoppingRepositoryProvider).getListById(listId);
  }

  /// Переключить состояние «куплено» у позиции.
  Future<ShoppingList?> toggleItem(String listId, String itemId) async {
    final item = _findItem(listId, itemId);
    if (item == null) return null;
    return _updateItem(listId, item.copyWith(isChecked: !item.isChecked));
  }

  /// Обновить позицию (название, количество).
  Future<ShoppingList?> updateItem(
    String listId,
    String itemId, {
    required String title,
    required int quantity,
  }) async {
    final item = _findItem(listId, itemId);
    if (item == null) return null;
    return _updateItem(listId, item.copyWith(title: title, quantity: quantity));
  }

  /// Удалить позицию из списка.
  Future<ShoppingList?> deleteItem(String listId, String itemId) async {
    await ref
        .read(shoppingRepositoryProvider)
        .deleteItem(itemId, listId: listId);
    return ref.read(shoppingRepositoryProvider).getListById(listId);
  }

  ShoppingItem? _findItem(String listId, String itemId) {
    for (final l in state.value ?? const <ShoppingList>[]) {
      if (l.id != listId) continue;
      for (final i in l.items) {
        if (i.id == itemId) return i;
      }
    }
    return null;
  }

  Future<ShoppingList?> _updateItem(String listId, ShoppingItem item) async {
    await ref.read(shoppingRepositoryProvider).updateItem(item, listId: listId);
    return ref.read(shoppingRepositoryProvider).getListById(listId);
  }
}

/// Провайдер списков покупок.
final shoppingListsControllerProvider =
    StreamNotifierProvider<ShoppingListsController, List<ShoppingList>>(
      ShoppingListsController.new,
    );

/// Список покупок по id из загруженного состояния.
///
/// Используется экраном конкретного списка — автоматически отражает
/// изменения позиций. `null`, пока список грузится или не найден.
final shoppingListByIdProvider = Provider.family<ShoppingList?, String>((
  ref,
  id,
) {
  final lists = ref.watch(shoppingListsControllerProvider).value;
  if (lists == null) return null;
  for (final l in lists) {
    if (l.id == id) return l;
  }
  return null;
});
