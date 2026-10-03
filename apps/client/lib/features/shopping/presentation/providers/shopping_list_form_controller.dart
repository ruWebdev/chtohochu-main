import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shopping_repository.dart';
import '../../domain/shopping_list.dart';

/// Состояние формы списка покупок (создание / переименование).
sealed class ShoppingListFormState {
  const ShoppingListFormState();
}

/// Форма готова к вводу.
class ShoppingListFormIdle extends ShoppingListFormState {
  const ShoppingListFormIdle({this.error});

  /// Типизированная ошибка — текст выбирает UI через `shoppingErrorMessage`.
  final ShoppingError? error;
}

/// Выполняется сохранение.
class ShoppingListFormLoading extends ShoppingListFormState {
  const ShoppingListFormLoading();
}

/// Список успешно сохранён.
class ShoppingListFormSuccess extends ShoppingListFormState {
  const ShoppingListFormSuccess(this.list);
  final ShoppingList list;
}

/// Контроллер формы списка покупок.
///
/// Один контроллер и для создания, и для редактирования названия —
/// различие только в наличии [existing]. Защищает от двойного сабмита.
class ShoppingListFormController extends Notifier<ShoppingListFormState> {
  @override
  ShoppingListFormState build() => const ShoppingListFormIdle();

  /// Сохранить список.
  ///
  /// Если [existing] задан — переименовывает, иначе создаёт новый.
  /// Возвращает сохранённый [ShoppingList] при успехе, `null` при ошибке.
  Future<ShoppingList?> save({
    required String title,
    ShoppingList? existing,
  }) async {
    if (state is ShoppingListFormLoading) return null;
    state = const ShoppingListFormLoading();
    try {
      final repo = ref.read(shoppingRepositoryProvider);
      // Стрим контроллера обновит UI из Drift сам — ручной
      // apply* в state не нужен.
      final list = existing == null
          ? await repo.createList(title: title)
          : await repo.updateList(existing.copyWith(title: title));
      state = ShoppingListFormSuccess(list);
      return list;
    } on ShoppingError catch (e) {
      state = ShoppingListFormIdle(error: e);
      return null;
    } catch (_) {
      state = const ShoppingListFormIdle(error: UnknownShoppingError());
      return null;
    }
  }
}

/// Провайдер контроллера формы списка покупок.
final shoppingListFormControllerProvider =
    NotifierProvider<ShoppingListFormController, ShoppingListFormState>(
      ShoppingListFormController.new,
    );
