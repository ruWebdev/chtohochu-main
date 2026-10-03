import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/sync/outbox_store.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../domain/auth_session.dart';
import '../domain/user.dart';

/// Абстракция репозитория авторизации.
///
/// Feature-код зависит только от этого интерфейса. Реализация —
/// [ApiAuthRepository] поверх реального Laravel API.
abstract interface class AuthRepository {
  /// Регистрация по email/password.
  Future<AuthSession> register({
    required String email,
    required String password,
    String? name,
  });

  /// Вход по email/password.
  Future<AuthSession> login({required String email, required String password});

  /// OAuth-вход через VK.
  Future<AuthSession> loginWithVk();

  /// OAuth-вход через Yandex.
  Future<AuthSession> loginWithYandex();

  /// Текущая сессия из хранилища или `null`, если пользователь не авторизован.
  ///
  /// Работает offline: access token (secure storage) + persisted
  /// user id (prefs) + профиль (Drift) = сессия без сети.
  Future<AuthSession?> currentSession();

  /// Выход — отзыв токена на сервере (best-effort) + очистка credentials.
  Future<void> logout();

  /// Локальная очистка credentials без обращения к API.
  ///
  /// Используется при 401 от сервера: токен уже невалиден, удалённый
  /// logout делать бессмысленно. Account-scoped данные в Drift НЕ
  /// удаляются — после повторного входа того же пользователя они
  /// доступны снова.
  Future<void> clearCredentials();
}

/// Ошибка авторизации.
///
/// [message] — технический код/пояснение для логов и отладки,
/// НЕ пользовательский текст. Пользовательский текст выбирает
/// presentation-слой через `authErrorMessage` (lib/l10n).
sealed class AuthError implements Exception {
  const AuthError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Неверные учётные данные.
class InvalidCredentialsError extends AuthError {
  const InvalidCredentialsError() : super('invalid_credentials');
}

/// Аккаунт с таким email уже существует.
class DuplicateAccountError extends AuthError {
  const DuplicateAccountError() : super('duplicate_account');
}

/// Ошибка сети.
class AuthNetworkError extends AuthError {
  const AuthNetworkError() : super('network');
}

/// Ошибка валидации, текст пришёл с backend (уже локализован на сервере).
class AuthValidationError extends AuthError {
  const AuthValidationError([this.serverMessage]) : super('validation');

  /// Пользовательский текст от backend. `null` — показать общий текст.
  final String? serverMessage;
}

/// OAuth-провайдер ещё не подключён на backend.
class OAuthUnavailableError extends AuthError {
  const OAuthUnavailableError(this.provider) : super('oauth_unavailable');

  /// Код провайдера: `vk` | `yandex`.
  final String provider;
}

/// Непредвиденный сбой OAuth-входа.
class OAuthFailedError extends AuthError {
  const OAuthFailedError(this.provider) : super('oauth_failed');

  /// Код провайдера: `vk` | `yandex`.
  final String provider;
}

/// Непредвиденная ошибка авторизации.
class UnknownAuthError extends AuthError {
  const UnknownAuthError() : super('unknown');
}

/// Провайдер `AuthRepository` — реальный API-клиент.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(
    ref.read(apiClientProvider),
    ref.read(secureStorageServiceProvider),
    ref.read(preferencesServiceProvider),
    ref.read(appDatabaseProvider),
  );
});

/// `AuthRepository` поверх Laravel API.
///
/// Токен хранится в secure storage; persisted identity —
/// `current_user_id` в prefs + строка `profiles` в Drift. Этого
/// достаточно для cold start offline без обращения к `/me`.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio, this._secureStorage, this._prefs, this._db);

  final Dio _dio;
  final SecureStorageService _secureStorage;
  final PreferencesService _prefs;
  final AppDatabase _db;

  Future<AuthSession> _persist(String token, Map<String, dynamic> user) async {
    await _secureStorage.saveAccessToken(token);
    await _prefs.setCurrentUserId(user['id'] as String);
    await _db.upsertProfile(
      ProfilesCompanion(
        id: Value(user['id'] as String),
        email: Value(user['email'] as String),
        name: Value(user['name'] as String?),
        username: Value(user['username'] as String?),
        avatarUrl: Value(user['avatar_url'] as String?),
        updatedAt: Value(
          user['updated_at'] != null
              ? DateTime.parse(user['updated_at'] as String)
              : null,
        ),
      ),
    );
    return AuthSession(token: token, user: _userFromJson(user));
  }

  static User _userFromJson(Map<String, dynamic> m) => User(
    id: m['id'] as String,
    email: m['email'] as String,
    name: m['name'] as String?,
    username: m['username'] as String?,
    avatarUrl: m['avatar_url'] as String?,
  );

  Map<String, dynamic> _data(Response<dynamic> res) =>
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'password_confirmation': password,
          'name': name,
        },
      );
      final data = _data(res);
      return await _persist(
        data['token'] as String,
        data['user'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapError(e, duplicateEmail: const DuplicateAccountError());
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = _data(res);
      return await _persist(
        data['token'] as String,
        data['user'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapError(e, unauthorized: const InvalidCredentialsError());
    }
  }

  @override
  Future<AuthSession?> currentSession() async {
    final token = await _secureStorage.readAccessToken();
    if (token == null) return null;

    final userId = _prefs.currentUserId();
    final profile = userId == null ? null : await _db.profileById(userId);

    if (profile != null) {
      final user = await _applyLegacyProfileCache(
        User(
          id: profile.id,
          email: profile.email,
          name: profile.name,
          username: profile.username,
          avatarUrl: profile.avatarUrl,
        ),
      );
      return AuthSession(token: token, user: user);
    }

    // Профиля нет локально (апгрейд со старой версии) — пробуем /me.
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me');
      final data = _data(res);
      await _persist(token, data);
      return AuthSession(
        token: token,
        user: await _applyLegacyProfileCache(_userFromJson(data)),
      );
    } on DioException {
      // Offline и нет persisted identity — сессию восстановить нельзя.
      return null;
    }
  }

  /// One-time перенос legacy `user_profile_cache` (SharedPreferences)
  /// в `profiles` — имя/username, отредактированные до миграции на
  /// Drift, не должны потеряться. После переноса кэш очищается.
  ///
  /// Если legacy-значения отличаются от текущих — это несинхронизированная
  /// локальная правка: upsert + outbox `update` ставятся одной
  /// транзакцией, иначе ближайший `GET /me` reconcile вернёт строку
  /// к серверному состоянию и правка потеряется.
  Future<User> _applyLegacyProfileCache(User user) async {
    final json = _prefs.readUserProfileCache();
    if (json == null) return user;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      final merged = user.copyWith(
        name: (m['name'] as String?) ?? user.name,
        username: (m['username'] as String?) ?? user.username,
        avatarUrl: (m['avatarUrl'] as String?) ?? user.avatarUrl,
      );
      final changed =
          merged.name != user.name ||
          merged.username != user.username ||
          merged.avatarUrl != user.avatarUrl;
      await _db.transaction(() async {
        await _db.upsertProfile(
          ProfilesCompanion(
            id: Value(merged.id),
            email: Value(merged.email),
            name: Value(merged.name),
            username: Value(merged.username),
            avatarUrl: Value(merged.avatarUrl),
            updatedAt: Value(DateTime.now()),
          ),
        );
        if (changed) {
          await OutboxStore(_db).enqueue(
            ownerId: merged.id,
            entityType: 'profile',
            entityId: merged.id,
            operation: OutboxOp.update,
            payload: {
              'name': merged.name,
              'username': merged.username,
              'avatar_url': merged.avatarUrl,
            },
          );
        }
      });
      await _prefs.clearUserProfileCache();
      return merged;
    } catch (_) {
      return user;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // Offline/401 — локальный logout всё равно обязан завершиться.
    }
    await clearCredentials();
  }

  @override
  Future<void> clearCredentials() async {
    await _secureStorage.clearTokens();
    await _prefs.clearCurrentUserId();
  }

  @override
  Future<AuthSession> loginWithVk() => throw const OAuthUnavailableError('vk');

  @override
  Future<AuthSession> loginWithYandex() =>
      throw const OAuthUnavailableError('yandex');

  AuthError _mapError(
    DioException e, {
    AuthError? unauthorized,
    AuthError? duplicateEmail,
  }) {
    final code = e.response?.statusCode;
    if (code == 401) return unauthorized ?? const InvalidCredentialsError();
    if (code == 422) {
      final errors = (e.response?.data as Map?)?['errors'] as Map?;
      if (errors != null && errors.containsKey('email')) {
        return duplicateEmail ?? const DuplicateAccountError();
      }
      final first = errors?.values.first;
      final msg = first is List && first.isNotEmpty
          ? first.first.toString()
          : null;
      return AuthValidationError(msg);
    }
    return const AuthNetworkError();
  }
}
