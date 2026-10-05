import 'package:chtohochu/features/wishes/presentation/pages/wish_form_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('First wish page shows title and form', (tester) async {
    // Onboarding пройден, авторизован, first wish flow не показан.
    final widget = await createTestApp(
      preferences: {
        'onboarding_complete': true,
        'first_wish_flow_shown': false,
      },
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(WishFormPage), findsOneWidget);
    expect(find.text('Создай своё первое желание'), findsOneWidget);
    expect(find.text('Что вы хотите?'), findsOneWidget);
    expect(find.text('Сохранить желание'), findsOneWidget);
    expect(find.text('Пропустить'), findsOneWidget);
  });

  testWidgets('Title validation shows error on empty input', (tester) async {
    final widget = await createTestApp(
      preferences: {
        'onboarding_complete': true,
        'first_wish_flow_shown': false,
      },
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить желание'));
    await tester.pumpAndSettle();

    expect(find.text('Введите название желания'), findsOneWidget);
  });

  testWidgets('Successful wish creation navigates to home', (tester) async {
    final widget = await createTestApp(
      preferences: {
        'onboarding_complete': true,
        'first_wish_flow_shown': false,
      },
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Ввести название и сохранить.
    await tester.enterText(find.byType(TextField).first, 'Наушники Sony');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить желание'));
    // Mock wish repo (500ms) + router refresh.
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Должен попасть на home с созданным желанием.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Наушники Sony'), findsOneWidget);
  });

  testWidgets('Skip first wish goes to home with empty state', (tester) async {
    final widget = await createTestApp(
      preferences: {
        'onboarding_complete': true,
        'first_wish_flow_shown': false,
      },
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Что ты хочешь?'), findsOneWidget);
  });

  testWidgets('Authenticated user with wishes goes directly to home', (
    tester,
  ) async {
    // Onboarding пройден, авторизован, first wish flow показан,
    // есть сохранённое желание.
    final widget = await createTestApp(
      preferences: {
        'onboarding_complete': true,
        'first_wish_flow_shown': true,
        'wishes_cache':
            '[{"id":"w1","title":"Книга","description":null,"createdAt":"2025-01-01T00:00:00.000"}]',
      },
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Книга'), findsOneWidget);
  });

  testWidgets('Close button on add-wish page returns to home', (tester) async {
    // /wishes/new открывается через context.go() — в стеке ничего нет,
    // поэтому закрытие должно делать fallback на go('/home').
    final widget = await createTestApp(
      preferences: {
        'onboarding_complete': true,
        'first_wish_flow_shown': true,
        'wishes_cache':
            '[{"id":"w1","title":"Книга","description":null,"createdAt":"2025-01-01T00:00:00.000"}]',
      },
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Открыть экран создания желания через + в AppBar.
    await tester.tap(find.byType(AddWishRow));
    await tester.pumpAndSettle();

    expect(find.byType(WishFormPage), findsOneWidget);
    expect(find.text('Новое желание'), findsOneWidget);

    // Закрыть через X — должен вернуться на home.
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Книга'), findsOneWidget);
  });

  testWidgets('System back on add-wish page returns to home', (tester) async {
    final widget = await createTestApp(
      preferences: {
        'onboarding_complete': true,
        'first_wish_flow_shown': true,
        'wishes_cache':
            '[{"id":"w1","title":"Книга","description":null,"createdAt":"2025-01-01T00:00:00.000"}]',
      },
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AddWishRow));
    await tester.pumpAndSettle();
    expect(find.byType(WishFormPage), findsOneWidget);

    // Системный Back без PopScope закрыл бы приложение —
    // теперь должен вернуть на home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Книга'), findsOneWidget);
  });
}
