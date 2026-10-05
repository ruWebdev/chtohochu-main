import 'package:chtohochu/app/router/routes.dart';
import 'package:chtohochu/core/database/database_provider.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:chtohochu/features/wishes/presentation/pages/home_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_details_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_form_page.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';

/// JSON желания с ценой, ссылкой и заметкой.
const _wishJson =
    '[{"id":"w1","title":"Наушники Sony","description":"Чёрные, беспроводные","price":12990,"link":"https://example.com/sony","imageUrl":null,"createdAt":"2025-01-01T00:00:00.000"}]';

Map<String, Object> _prefs(String wishesJson) => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
  'wishes_cache': wishesJson,
};

void main() {
  testWidgets('Tapping wish card opens details with price and note', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _prefs(_wishJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Тап по карточке → детали.
    await tester.tap(find.text('Наушники Sony'));
    await tester.pumpAndSettle();

    expect(find.byType(WishDetailsPage), findsOneWidget);
    expect(find.text('Наушники Sony'), findsOneWidget);
    expect(find.text('12 990 ₽'), findsOneWidget);
    expect(find.text('Чёрные, беспроводные'), findsOneWidget);
    expect(find.text('https://example.com/sony'), findsOneWidget);
  });

  testWidgets('Back button on details returns to home', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_wishJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Наушники Sony'));
    await tester.pumpAndSettle();
    expect(find.byType(WishDetailsPage), findsOneWidget);

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Наушники Sony'), findsOneWidget);
  });

  testWidgets('Edit wish from details updates it and returns to details', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _prefs(_wishJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Детали → редактирование.
    await tester.tap(find.text('Наушники Sony'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Редактировать'));
    await tester.pumpAndSettle();

    expect(find.byType(WishFormPage), findsOneWidget);
    expect(find.text('Редактировать желание'), findsOneWidget);
    // Поле предзаполнено текущим названием.
    expect(find.text('Наушники Sony'), findsWidgets);

    // Изменить название и сохранить.
    await tester.enterText(
      find.byType(TextField).first,
      'Наушники Sony WH-1000XM6',
    );
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Вернулись на детали с новым названием.
    expect(find.byType(WishDetailsPage), findsOneWidget);
    expect(find.text('Наушники Sony WH-1000XM6'), findsOneWidget);
  });

  testWidgets('Delete wish asks confirmation and removes from list', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _prefs(_wishJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Детали → удалить → диалог подтверждения.
    await tester.tap(find.text('Наушники Sony'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить желание?'), findsOneWidget);

    // Подтвердить → возврат на список без желания.
    await tester.tap(find.widgetWithText(AppButton, 'Удалить'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Наушники Sony'), findsNothing);
    expect(find.text('Что ты хочешь?'), findsOneWidget);
  });

  testWidgets('List with several wishes shows all cards and count', (
    tester,
  ) async {
    const threeWishes =
        '[{"id":"w1","title":"Книга","description":null,"price":null,"link":null,"imageUrl":null,"createdAt":"2025-01-01T00:00:00.000"},'
        '{"id":"w2","title":"Наушники","description":null,"price":12990,"link":null,"imageUrl":null,"createdAt":"2025-01-02T00:00:00.000"},'
        '{"id":"w3","title":"Плед","description":"Шерстяной","price":null,"link":null,"imageUrl":null,"createdAt":"2025-01-03T00:00:00.000"}]';
    final widget = await createTestApp(
      preferences: _prefs(threeWishes),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Книга'), findsOneWidget);
    expect(find.text('Наушники'), findsOneWidget);
    expect(find.text('12 990 ₽'), findsOneWidget);
    expect(find.text('Плед'), findsOneWidget);
    // Счётчик в AppBar.
    expect(find.text('3 желания'), findsOneWidget);
  });

  testWidgets('Single wish renders as a normal list', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_wishJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Наушники Sony'), findsOneWidget);
    expect(find.text('1 желание'), findsOneWidget);
    expect(find.text('Что ты хочешь?'), findsNothing);
  });

  testWidgets('System back on details returns to home', (tester) async {
    final widget = await createTestApp(
      preferences: _prefs(_wishJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Наушники Sony'));
    await tester.pumpAndSettle();
    expect(find.byType(WishDetailsPage), findsOneWidget);

    // Системный Back без PopScope закрыл бы приложение.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Наушники Sony'), findsOneWidget);
  });

  testWidgets('System back on unknown wish edit returns to home', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _prefs(_wishJson),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Прямая навигация на resolver для несуществующего желания.
    GoRouter.of(
      tester.element(find.byType(HomePage)),
    ).go(AppRoutes.wishEdit('unknown-id'));
    await tester.pumpAndSettle();

    expect(find.text('Желание не найдено'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('Delete wish failure shows error and stays on details', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _prefs(_wishJson),
      secureStorage: {'access_token': 'mock_token'},
      overrides: [
        wishRepositoryProvider.overrideWith(
          (ref) => _FailingWishRepository(
            ref.read(appDatabaseProvider),
            ref.read(preferencesServiceProvider),
          ),
        ),
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Наушники Sony'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Удалить'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Ошибка показана, экран остался на деталях.
    expect(find.text('Не удалось удалить желание.'), findsOneWidget);
    expect(find.byType(WishDetailsPage), findsOneWidget);
    expect(find.text('Наушники Sony'), findsOneWidget);
  });
}

/// Репозиторий, который падает при удалении — для проверки
/// error-path мутаций в UI.
class _FailingWishRepository extends DriftWishRepository {
  _FailingWishRepository(super.db, super.prefs);

  @override
  Future<void> deleteWish(String id) {
    return Future.error(const WishNetworkError());
  }
}
