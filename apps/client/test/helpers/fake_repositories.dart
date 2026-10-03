import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/services/secure_storage_service.dart';
import 'package:chtohochu/features/auth/data/auth_repository.dart';
import 'package:chtohochu/features/auth/domain/auth_session.dart';
import 'package:chtohochu/features/auth/domain/user.dart';

/// In-memory `AuthRepository` для тестов error-path'ов —
/// наследники переопределяют отдельные методы под сценарий.
///
/// Пишет `current_user_id` в prefs, чтобы Drift-репозитории
/// могли определить owner_id без сети.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(
    SecureStorageService secureStorage,
    PreferencesService prefs,
  ) : _secureStorage = secureStorage,
      _prefs = prefs;

  final SecureStorageService _secureStorage;
  final PreferencesService _prefs;

  static const testUser = User(
    id: 'u_test',
    email: 'user@chtohochu.ru',
    name: 'user',
    username: 'user',
  );

  Future<AuthSession> _persist(String token) async {
    await _secureStorage.saveAccessToken(token);
    await _prefs.setCurrentUserId(testUser.id);
    return AuthSession(token: token, user: testUser);
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? name,
  }) => _persist('token_$email');

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) => _persist('token_$email');

  @override
  Future<AuthSession> loginWithVk() => throw const OAuthUnavailableError('vk');

  @override
  Future<AuthSession> loginWithYandex() =>
      throw const OAuthUnavailableError('yandex');

  @override
  Future<AuthSession?> currentSession() async {
    final token = await _secureStorage.readAccessToken();
    if (token == null) return null;
    await _prefs.setCurrentUserId(testUser.id);
    return AuthSession(token: token, user: testUser);
  }

  @override
  Future<void> logout() => clearCredentials();

  @override
  Future<void> clearCredentials() async {
    await _secureStorage.clearTokens();
    await _prefs.clearCurrentUserId();
  }
}
