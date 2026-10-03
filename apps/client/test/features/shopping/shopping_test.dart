import 'package:chtohochu/core/database/database_provider.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/features/shopping/domain/shopping_item.dart';
import 'package:chtohochu/features/shopping/data/shopping_repository.dart';
import 'package:chtohochu/features/shopping/presentation/pages/shopping_list_page.dart';
import 'package:chtohochu/features/shopping/presentation/pages/shopping_page.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../helpers/test_app.dart';

/// Два независимых списка с позициями.
const _twoListsJson =
    '[{"id":"l1","title":"Продукты","createdAt":"2025-01-01T00:00:00.000",'
    '"items":[{"id":"i1","title":"Молоко","quantity":1,"isChecked":false},'
    '{"id":"i2","title":"Хлеб","quantity":2,"isChecked":true}]},'
    '{"id":"l2","title":"Для дома","createdAt":"2025-01-02T00:00:00.000",'
    '"items":[{"id":"i3","title":"Лампочка","quantity":1,"isChecked":false}]}]';

Map<String, Object> _prefs(String json) => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
  'shopping_lists_cache': json,
};

Map<String, Object> _basePrefs() => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
};

Future<void> _openShopping(WidgetTester tester) async {
  await tester.tap(find.text('Покупки'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Empty shopping section shows empty state with CTA', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await _openShopping(tester);

    expect(find.byType(ShoppingPage), findsOneWidget);
    expect(find.text('Пока нет списков'), findsOneWidget);
    expect(find.text('Создать список'), findsOneWidget);
  });

  testWidgets('Several lists render with progress', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);

    expect(find.textContaining('Продукты'), findsOneWidget);
    expect(find.text('1 из 2 куплено'), findsOneWidget);
    expect(find.textContaining('Для дома'), findsOneWidget);
    expect(find.text('0 из 1 куплено'), findsOneWidget);
    expect(find.text('2 списка'), findsOneWidget);
  });

  testWidgets('Create list flow adds list to the root screen', (tester) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);

    // + в AppBar → форма создания.
    await tester.tap(find.byTooltip('Создать список покупок'));
    await tester.pumpAndSettle();
    expect(find.text('Новый список'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'В поездку');
    await tester.tap(find.text('Создать список'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Вернулись на список списков, новый список виден.
    expect(find.byType(ShoppingPage), findsOneWidget);
    expect(find.textContaining('В поездку'), findsOneWidget);
    expect(find.text('Пока пусто'), findsOneWidget);
  });

  testWidgets('Opening a list shows its items with checked state', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);

    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    expect(find.byType(ShoppingListPage), findsOneWidget);
    expect(find.textContaining('Молоко'), findsOneWidget);
    expect(find.textContaining('Хлеб'), findsOneWidget);
    expect(find.text('1 из 2 куплено'), findsOneWidget);
    // Купленная позиция — check-иконка видна.
    expect(find.byIcon(PhosphorIconsRegular.check), findsWidgets);
  });

  testWidgets('Quick-add adds an item to the list', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    // Развернуть поле добавления и ввести позицию.
    await tester.tap(find.text('Добавить товар'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Кофе');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('Кофе'), findsOneWidget);
    expect(find.text('1 из 3 куплено'), findsOneWidget);
  });

  testWidgets('Tapping item toggles checked and back', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    // Отметить «Молоко» как купленное.
    await tester.tap(find.textContaining('Молоко'));
    await tester.pumpAndSettle();
    expect(find.text('Всё куплено'), findsOneWidget);

    // Снять отметку — позиция возвращается в список.
    await tester.tap(find.textContaining('Молоко'));
    await tester.pumpAndSettle();
    expect(find.text('1 из 2 куплено'), findsOneWidget);
  });

  testWidgets('Swipe deletes an item from the list', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    await tester.drag(find.textContaining('Молоко'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('Молоко'), findsNothing);
    // Остался только купленный «Хлеб» — список полностью выкуплен.
    expect(find.text('Всё куплено'), findsOneWidget);

    // Даём синку дожать вылетевший DELETE, чтобы не осталось pending-таймеров.
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Long-press opens item edit sheet with quantity', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('Молоко'));
    await tester.pumpAndSettle();

    expect(find.text('Позиция'), findsOneWidget);
    expect(find.text('Количество'), findsOneWidget);

    // Изменить название и количество.
    await tester.enterText(find.byType(TextField).first, 'Молоко 3.2%');
    await tester.enterText(find.byType(TextField).last, '3');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Молоко 3.2%'), findsOneWidget);
    expect(find.textContaining('× 3'), findsOneWidget);
  });

  testWidgets('Rename list returns to the list screen', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Переименовать'));
    await tester.pumpAndSettle();
    expect(find.text('Переименовать список'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Продукты на неделю');
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(ShoppingListPage), findsOneWidget);
    expect(find.textContaining('Продукты на неделю'), findsOneWidget);
    expect(find.textContaining('Молоко'), findsOneWidget);
  });

  testWidgets('Delete list asks confirmation and removes it', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Удалить список'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить список?'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Удалить'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(ShoppingPage), findsOneWidget);
    expect(find.textContaining('Продукты'), findsNothing);
    expect(find.textContaining('Для дома'), findsOneWidget);
    expect(find.text('1 список'), findsOneWidget);
  });

  testWidgets('Two lists keep their items independent', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);

    // Первый список — только его позиции.
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Молоко'), findsOneWidget);
    expect(find.textContaining('Хлеб'), findsOneWidget);
    expect(find.textContaining('Лампочка'), findsNothing);

    // Назад → второй список — только его позиции.
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Для дома'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Лампочка'), findsOneWidget);
    expect(find.textContaining('Молоко'), findsNothing);
  });

  testWidgets('Back from list page returns to shopping root', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    expect(find.byType(ShoppingPage), findsOneWidget);
    expect(find.textContaining('Продукты'), findsOneWidget);
  });

  testWidgets('System back on list page returns to shopping root', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    // Системный Back без PopScope закрыл бы приложение.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ShoppingPage), findsOneWidget);
    expect(find.textContaining('Продукты'), findsOneWidget);
  });

  testWidgets('Toggle item failure shows error and keeps item unchecked', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _prefs(_twoListsJson),
      secureStorage: {'access_token': 'mock_token'},
      overrides: [
        shoppingRepositoryProvider.overrideWith(
          (ref) => _FailingShoppingRepository(
            ref.read(appDatabaseProvider),
            ref.read(preferencesServiceProvider),
          ),
        ),
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openShopping(tester);
    await tester.tap(find.textContaining('Продукты'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Молоко'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Ошибка показана, состояние не изменилось — «Молоко» не куплено.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('1 из 2 куплено'), findsOneWidget);
  });
}

/// Репозиторий, который падает при мутации позиции — для проверки
/// error-path мутаций (toggle/add/edit/delete позиций).
class _FailingShoppingRepository extends DriftShoppingRepository {
  _FailingShoppingRepository(super.db, super.prefs);

  @override
  Future<ShoppingItem> updateItem(ShoppingItem item, {required String listId}) {
    return Future.error(const ShoppingStorageError());
  }
}
