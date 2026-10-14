import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/services/secure_storage_service.dart';
import 'package:chtohochu/features/auth/data/auth_repository.dart';
import 'package:chtohochu/features/auth/domain/auth_session.dart';
import 'package:chtohochu/features/auth/domain/oauth_provider.dart';
import 'package:chtohochu/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/test_app.dart';

/// OAuth-флоу на уровне репозитория и контроллера.
///
/// WebView-часть (OAuthPage) платформенная и в widget-тестах не
/// проверяется — здесь покрыт контракт обмена: success, отказ
/// провайдера (422), конфликт email (409 oauth_link_required),
/// подтверждённая привязка и состояния контроллера.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter api;
  late ApiAuthRepository repo;
  late SecureStorageService secureStorage;
  late PreferencesService prefs;

  setUp(() async {
    setupTestStorage();
    final sharedPrefs = await SharedPreferences.getInstance();
    secureStorage = SecureStorageService(const FlutterSecureStorage());
    prefs = PreferencesService(sharedPrefs);
    api = FakeApiAdapter();
    repo = ApiAuthRepository(
      createTestApiClient(api),
      secureStorage,
      prefs,
      createTestDatabase(),
    );
  });

  group('loginWithVk', () {
    test('обменивает provider-токен на сессию и персистит её', () async {
      final session = await repo.loginWithVk(
        credentials: const OAuthCredentials(accessToken: 'vk-abc'),
      );

      expect(session.token, isNotEmpty);
      // Синтетический email по provider id — как на backend.
      expect(session.user.email, 'vk_vk-abc@vk.local');
      expect(await secureStorage.readAccessToken(), session.token);
      expect(prefs.currentUserId(), session.user.id);
    });

    test('email из фрагмента передаётся на backend', () async {
      final session = await repo.loginWithVk(
        credentials: const OAuthCredentials(
          accessToken: 'vk-abc',
          email: 'ivan@mail.ru',
        ),
      );
      expect(session.user.email, 'ivan@mail.ru');
    });

    test('совпадение email → OAuthLinkRequiredError (409)', () async {
      // Существующий аккаунт с той же почтой — регистрацией через fake.
      final dio = createTestApiClient(api);
      await dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': 'ivan@mail.ru',
          'password': 'password123',
          'password_confirmation': 'password123',
        },
      );

      expect(
        () => repo.loginWithVk(
          credentials: const OAuthCredentials(
            accessToken: 'vk-abc',
            email: 'ivan@mail.ru',
          ),
        ),
        throwsA(isA<OAuthLinkRequiredError>()),
      );
    });

    test('отказ провайдера (422) → OAuthFailedError', () {
      expect(
        () => repo.loginWithVk(
          credentials: const OAuthCredentials(accessToken: 'bad-token'),
        ),
        throwsA(isA<OAuthFailedError>()),
      );
    });
  });

  group('loginWithYandex', () {
    test('создаёт сессию, email приходит от провайдера', () async {
      final session = await repo.loginWithYandex(
        credentials: const OAuthCredentials(accessToken: 'ya-abc'),
      );

      expect(session.token, isNotEmpty);
      expect(session.user.email, 'ya_ya-abc@yandex.ru');
    });
  });

  group('link', () {
    test('link проставляет provider id на сервере', () async {
      final session = await repo.loginWithVk(
        credentials: const OAuthCredentials(accessToken: 'vk-abc'),
      );

      await repo.linkWithYandex(
        credentials: const OAuthCredentials(accessToken: 'ya-abc'),
      );

      expect(
        api.serverUser(session.user.id)?['yandex_id'],
        'pid_ya-abc',
      );
    });

    test('конфликт привязки (409) → OAuthLinkFailedError', () async {
      // Один пользователь привязал ya-токен, второй пытается тот же.
      await repo.loginWithYandex(
        credentials: const OAuthCredentials(accessToken: 'ya-abc'),
      );
      await repo.clearCredentials();

      await repo.loginWithVk(
        credentials: const OAuthCredentials(accessToken: 'vk-other'),
      );

      expect(
        () => repo.linkWithYandex(
          credentials: const OAuthCredentials(accessToken: 'ya-abc'),
        ),
        throwsA(isA<OAuthLinkFailedError>()),
      );
    });
  });

  group('AuthController', () {
    ProviderContainer containerWith(AuthRepository authRepo) {
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepo)],
      );
      addTearDown(container.dispose);
      // Держим autoDispose-провайдер живым на время теста.
      container.listen(authControllerProvider, (_, _) {});
      return container;
    }

    test('успешный вход → AuthFormSuccess', () async {
      final container = containerWith(
        FakeAuthRepository(secureStorage, prefs),
      );
      await container
          .read(authControllerProvider.notifier)
          .loginWithVk(const OAuthCredentials(accessToken: 'vk-abc'));

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthFormSuccess>());
      expect((state as AuthFormSuccess).session.user.id, isNotEmpty);
    });

    test('ошибка обмена → AuthFormIdle с типизированной ошибкой', () async {
      final container = containerWith(
        _OAuthFailingRepository(secureStorage, prefs),
      );
      await container
          .read(authControllerProvider.notifier)
          .loginWithVk(const OAuthCredentials(accessToken: 'vk-abc'));

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthFormIdle>());
      expect((state as AuthFormIdle).error, isA<OAuthFailedError>());
    });

    test('notifyOAuthUnavailable → info-ошибка без запроса', () {
      final container = containerWith(
        FakeAuthRepository(secureStorage, prefs),
      );
      container
          .read(authControllerProvider.notifier)
          .notifyOAuthUnavailable('vk');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthFormIdle>());
      expect(
        (state as AuthFormIdle).error,
        isA<OAuthUnavailableError>(),
      );
    });
  });
}

class _OAuthFailingRepository extends FakeAuthRepository {
  _OAuthFailingRepository(super.secureStorage, super.prefs);

  @override
  Future<AuthSession> loginWithVk({required OAuthCredentials credentials}) =>
      throw const OAuthFailedError('vk');
}
