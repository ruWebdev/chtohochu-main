import 'package:chtohochu/features/auth/domain/user.dart';
import 'package:chtohochu/features/auth/presentation/pages/auth_page.dart';
import 'package:chtohochu/features/profile/data/profile_repository.dart';
import 'package:chtohochu/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:chtohochu/features/profile/presentation/pages/profile_page.dart';
import 'package:chtohochu/shared/ui/avatars/app_avatar.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/test_app.dart';

Map<String, Object> _basePrefs() => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
};

// Mock-пользователь из currentSession(): user@chtohochu.ru →
// displayName 'user', username 'user'.
Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.text('Профиль'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Profile renders header and sections', (tester) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);

    expect(find.byType(ProfilePage), findsOneWidget);
    // Header: имя из email, username, кнопка редактирования.
    expect(find.text('user'), findsOneWidget);
    expect(find.text('@user'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Редактировать профиль'),
      findsOneWidget,
    );
    // Секции.
    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Внешний вид'), findsOneWidget);
    expect(find.text('Аккаунт'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
    expect(find.text('О приложении'), findsOneWidget);
    expect(find.text('ЧтоХочу'), findsOneWidget);
    expect(find.text('Версия 2.0.0'), findsOneWidget);
  });

  testWidgets('Edit profile saves name and username', (tester) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Редактировать профиль'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Николай');
    await tester.enterText(find.byType(TextField).last, 'nikolay.k');
    await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Вернулись на профиль — изменения видны.
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Николай'), findsOneWidget);
    expect(find.text('@nikolay.k'), findsOneWidget);
  });

  testWidgets('Invalid username shows error and stays on edit', (tester) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Редактировать профиль'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '!!');
    await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileEditPage), findsOneWidget);
    expect(
      find.text('Латиница, цифры, «_» и «.», минимум 3 символа'),
      findsOneWidget,
    );
  });

  testWidgets('Avatar placeholder → pick mock avatar → image shown', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Редактировать профиль'));
    await tester.pumpAndSettle();

    // Без аватара — инициалы, нет Image.
    expect(
      find.descendant(of: find.byType(AppAvatar), matching: find.byType(Image)),
      findsNothing,
    );

    await tester.tap(find.text('Изменить фото'));
    await tester.pumpAndSettle();
    expect(find.text('Аватар 1'), findsOneWidget);
    await tester.tap(find.text('Аватар 1'));
    await tester.pumpAndSettle();

    // Выбранный аватар — Image в главном аватаре (не в шитах).
    expect(
      find.descendant(of: find.byType(AppAvatar), matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('Theme picker switches to dark and system', (tester) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);

    // Текущее значение — светлая.
    expect(find.text('Светлая'), findsOneWidget);

    await tester.tap(find.text('Внешний вид'));
    await tester.pumpAndSettle();
    expect(find.text('Системная'), findsOneWidget);
    expect(find.text('Тёмная'), findsOneWidget);

    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    // System тоже поддерживается.
    await tester.tap(find.text('Внешний вид'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Системная'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });

  testWidgets('Logout asks confirmation; cancel keeps session', (tester) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('Logout confirm navigates to auth', (tester) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Выйти'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('Back from edit returns to profile without saving', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Редактировать профиль'));
    await tester.pumpAndSettle();

    // Изменили имя, но ушли назад без сохранения.
    await tester.enterText(find.byType(TextField).first, 'Черновик');
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Черновик'), findsNothing);
    expect(find.text('user'), findsOneWidget);
  });

  testWidgets('Save profile failure shows error and does not get stuck', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      overrides: [
        profileRepositoryProvider.overrideWith(
          (ref) => _FailingProfileRepository(),
        ),
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openProfile(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Редактировать профиль'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Николай');
    await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Ошибка показана, остались на форме, кнопка не в loading.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(ProfileEditPage), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Сохранить'), findsOneWidget);
  });
}

/// Profile-репозиторий, который падает при сохранении —
/// для проверки error-path `_save` в UI.
class _FailingProfileRepository implements ProfileRepository {
  @override
  Stream<User?> watchProfile() => Stream.value(FakeAuthRepository.testUser);

  @override
  Future<User?> getProfile() async => FakeAuthRepository.testUser;

  @override
  Future<User> updateProfile({
    required String name,
    String? username,
    String? avatarUrl,
  }) {
    return Future.error(const ProfileStorageError());
  }
}
