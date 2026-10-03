import 'package:chtohochu/features/wishes/presentation/pages/wish_form_page.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

/// Данные «пользователя A»: желание, список покупок, друг, профиль.
Map<String, Object> _userAPrefs() => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
  'wishes_cache':
      '[{"id":"w1","title":"Наушники Sony","description":null,"price":12990,'
      '"link":null,"imageUrl":null,"createdAt":"2025-01-01T00:00:00.000"}]',
  'shopping_lists_cache':
      '[{"id":"l1","title":"Продукты","createdAt":"2025-01-01T00:00:00.000",'
      '"items":[{"id":"i1","title":"Молоко","quantity":1,"isChecked":false}]}]',
  'friends_cache': '["u1"]',
  'user_profile_cache':
      '{"name":"Мария","username":"maria.k","avatarUrl":null}',
};

void main() {
  testWidgets(
    'Logout clears user data — next user sees nothing from previous account',
    (tester) async {
      final widget = await createTestApp(
        preferences: _userAPrefs(),
        secureStorage: {'access_token': 'mock_token'},
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Пользователь A видит своё желание и свой профиль.
      expect(find.text('Наушники Sony'), findsOneWidget);
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();
      expect(find.text('Мария'), findsOneWidget);

      // Logout → диалог → auth.
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Выйти'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Войти'), findsOneWidget);

      // Вход «другого пользователя» — данные A недоступны.
      await tester.enterText(find.byType(TextField).at(0), 'boris@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Желания очищены и флаг first-wish flow сброшен →
      // новый пользователь без желаний видит flow первого желания.
      expect(find.byType(WishFormPage), findsOneWidget);
      await tester.tap(find.text('Пропустить'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Желаний пользователя A нет.
      expect(find.text('Пока нет желаний'), findsOneWidget);
      expect(find.text('Наушники Sony'), findsNothing);

      // Списков покупок A нет.
      await tester.tap(find.text('Покупки'));
      await tester.pumpAndSettle();
      expect(find.text('Пока нет списков'), findsOneWidget);
      expect(find.text('Продукты'), findsNothing);

      // Друзей A нет.
      await tester.tap(find.text('Друзья'));
      await tester.pumpAndSettle();
      expect(find.text('Пока нет друзей'), findsOneWidget);
      expect(find.text('Анна Соколова'), findsNothing);

      // Профиль A не подтянулся — дефолтный пользователь.
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();
      expect(find.text('Мария'), findsNothing);
      expect(find.text('@maria.k'), findsNothing);
    },
  );

  testWidgets(
    'Logout with pending outbox requires explicit destructive confirm',
    (tester) async {
      final api = FakeApiAdapter(autoUserId: 'u1');
      final widget = await createTestApp(
        preferences: {
          'onboarding_complete': true,
          'first_wish_flow_shown': true,
        },
        secureStorage: {'access_token': 'mock_token'},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Создать желание при отсутствии сети — операция в outbox.
      api.failures['POST /wishes'] = 'network';
      await tester.tap(find.byTooltip('Добавить желание'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Оффлайн желание');
      await tester.tap(find.text('Сохранить желание'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Желание видно из Drift, но не синхронизировано.
      expect(find.text('Оффлайн желание'), findsOneWidget);

      // Logout → строгое предупреждение вместо обычного диалога.
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();

      expect(find.text('Несохранённые изменения'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Удалить и выйти'), findsOneWidget);

      // Отмена — сессия и данные на месте.
      await tester.tap(find.widgetWithText(AppButton, 'Отмена'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Что хочу'));
      await tester.pumpAndSettle();
      expect(find.text('Оффлайн желание'), findsOneWidget);

      // Destructive confirm → auth, данные аккаунта удалены.
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Удалить и выйти'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Войти'), findsOneWidget);
      // И сервер так и не узнал о желании (network failure сохранён).
      expect(api.wishesOf('u1'), isEmpty);
    },
  );
}
