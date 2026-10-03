import 'package:chtohochu/features/auth/presentation/pages/auth_page.dart';
import 'package:chtohochu/app/theme/app_sizes.dart';
import 'package:chtohochu/app/theme/app_spacing.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('Auth page shows login form by default', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // email + password
  });

  testWidgets('Toggling to register shows name field', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.text('Создать аккаунт'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3)); // name + email + password
  });

  testWidgets('Email validation shows error on invalid input', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Введите корректный email'), findsOneWidget);
  });

  testWidgets('Password validation shows error on short input', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), '1234567');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Пароль не короче 8 символов'), findsOneWidget);
  });

  testWidgets('Successful login navigates to first wish flow', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Войти'));
    // Mock auth (800ms) + hasWishes (500ms) + router refresh.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // После успешного входа → first wish flow.
    expect(find.byType(WishFormPage), findsOneWidget);
    expect(find.text('Создай своё первое желание'), findsOneWidget);
  });

  // --- Новый UI: стабильность геометрии, состояния, accessibility ---

  /// Нижний блок (CTA, разделитель, OAuth) не должен двигаться при
  /// появлении серверной ошибки: она занимает свободное место над формой.
  testWidgets('Server error does not move CTA/divider/OAuth', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = FakeApiAdapter();
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final cta = find.widgetWithText(AppButton, 'Войти');
    final divider = find.text('или');
    final vk = find.widgetWithText(AppButton, 'Войти через VK');
    final ctaBefore = tester.getRect(cta);
    final dividerBefore = tester.getRect(divider);
    final vkBefore = tester.getRect(vk);

    // 401 → InvalidCredentialsError → AppFeedback над карточкой.
    api.failures['POST /auth/login'] = 401;
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(cta);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Компактный feedback: текст в одну строку.
    final errorText = find.text('Неверный email или пароль');
    expect(errorText, findsOneWidget);
    expect(tester.widget<Text>(errorText).maxLines, 1);
    expect(tester.getRect(cta), ctaBefore);
    expect(tester.getRect(divider), dividerBefore);
    expect(tester.getRect(vk), vkBefore);

    // Через 5 секунд сообщение скрывается автоматически,
    // нижний блок остаётся на месте.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(errorText, findsNothing);
    expect(tester.getRect(cta), ctaBefore);
  });

  /// Переключение в регистрацию добавляет поле «Имя» — рост карточки
  /// идёт вверх, нижние элементы (CTA, OAuth) не сдвигаются.
  testWidgets('Toggle to register grows card upward, bottom stays', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final vk = find.widgetWithText(AppButton, 'Войти через VK');
    final vkBefore = tester.getRect(vk);

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    expect(tester.getRect(vk), vkBefore);
  });

  /// Повторный submit через клавиатуру во время запроса игнорируется —
  /// на сервер уходит ровно один запрос логина.
  testWidgets('Keyboard submit during loading does not double-send', (
    tester,
  ) async {
    final api = FakeApiAdapter();
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.byType(TextField).at(1));
    // Два submit подряд без pump — второй видит AuthFormLoading и выходит.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final logins = api.requests.where((r) => r == 'POST /auth/login').length;
    expect(logins, 1);
  });

  /// OAuth-провайдеры ещё не подключены — tap показывает info feedback,
  /// а не ошибку пользователя.
  testWidgets('OAuth tap shows informational feedback', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Войти через VK'));
    await tester.pumpAndSettle();

    expect(
      find.text('Вход через соцсети скоро будет доступен'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    // Info-блок скрывается автоматически через 5 секунд.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Вход через соцсети скоро будет доступен'), findsNothing);
  });

  /// После logout /auth открывается с чистым состоянием: режим login,
  /// без унаследованной ошибки или register-режима (provider autoDispose).
  testWidgets('Auth page resets to login mode after logout', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Регистрация (режим register) → первое желание → пропуск → профиль.
    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'anna@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Выйти'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Чистое состояние: login-режим, без register-CTA и без ошибок.
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('Создать аккаунт'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Войти'), findsOneWidget);
  });

  /// Semantics: у полей есть accessibility-метки (AppTextField
  /// semanticsLabel теперь реально применяется).
  testWidgets('Fields expose semantics labels', (tester) async {
    final handle = tester.ensureSemantics();

    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Адрес электронной почты',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Пароль',
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  /// Тёмная тема: экран рендерится без исключений с dark-токенами.
  testWidgets('Dark theme renders without overflow', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true, 'theme_mode': 'dark'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('Войти через VK'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF15130F));
  });

  /// Малый viewport + режим регистрации: контент скроллится, без overflow.
  testWidgets('Small viewport register mode scrolls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    // overflow сам роняет тест
  });

  /// Brand tagline — статичная однострочная строка, не зависит от режима
  /// и не ломается на узком экране (360px).
  testWidgets('Tagline stays single-line on narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final tagline = find.text('Твоё пространство желаний');
    expect(tagline, findsOneWidget);
    // Одна строка secondary (14/20) — высота ~20, переноса нет.
    expect(tester.getSize(tagline).height, lessThan(24));

    // В register tagline тот же — header статичен.
    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();
    expect(tagline, findsOneWidget);
    expect(tester.getSize(tagline).height, lessThan(24));
  });

  /// Mode toggle: визуальный pill компактнее 48px touch-зоны —
  /// селектор не перетягивает внимание, но нажатие остаётся доступным.
  testWidgets('Mode toggle visual pill is compact, tap still works', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Pill — AnimatedContainer вокруг текста вкладки: 32px < 48px touch.
    final pill = find.ancestor(
      of: find.text('Вход'),
      matching: find.byType(AnimatedContainer),
    );
    expect(pill, findsOneWidget);
    final pillSize = tester.getSize(pill);
    expect(pillSize.height, AppSizes.buttonHeightSm);
    expect(pillSize.height, lessThan(AppSpacing.minTouchTarget));

    // Нажатие по вкладке по-прежнему переключает режим.
    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();
    expect(find.text('Создать аккаунт'), findsOneWidget);
  });
}
