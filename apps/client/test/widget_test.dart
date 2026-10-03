import 'package:chtohochu/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('New user sees onboarding on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final widget = await createTestApp();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('Пропустить'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });

  testWidgets('Onboarding can be completed and navigates to auth', (
    tester,
  ) async {
    final widget = await createTestApp();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Пропустить onboarding → должен появиться экран авторизации.
    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(find.text('ЧтоХочу'), findsWidgets);
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets('User who completed onboarding sees auth on next launch', (
    tester,
  ) async {
    // Onboarding уже пройден.
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Должен сразу попасть на авторизацию (без onboarding).
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets('Onboarding "Далее" advances PageView to the last slide', (
    tester,
  ) async {
    final widget = await createTestApp();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final pageController =
        tester.widget<PageView>(find.byType(PageView)).controller
            as PageController;
    expect(pageController.page, 0);

    // «Далее» реально листает PageView — до fix менялся только индекс.
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(pageController.page, 1);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(pageController.page, 2);
    expect(find.text('Начать'), findsOneWidget);

    // Последний слайд завершает onboarding → auth.
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(find.text('Войти'), findsOneWidget);
  });
}
