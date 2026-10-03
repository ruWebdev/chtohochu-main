import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_session.dart';

/// Режим экрана авторизации.
enum AuthMode { login, register }

/// Состояние формы авторизации.
sealed class AuthFormState {
  const AuthFormState();
}

/// Форма готова к вводу.
class AuthFormIdle extends AuthFormState {
  const AuthFormIdle({this.error});

  /// Типизированная ошибка авторизации — текст выбирает UI через
  /// `authErrorMessage` (ошибки не локализуются в контроллере).
  final AuthError? error;
}

/// Выполняется запрос авторизации.
class AuthFormLoading extends AuthFormState {
  const AuthFormLoading();
}

/// Авторизация успешна.
class AuthFormSuccess extends AuthFormState {
  const AuthFormSuccess(this.session);
  final AuthSession session;
}

/// Контроллер формы авторизации.
///
/// Управляет режимом (login/register), выполнением запросов и
/// преобразованием ошибок репозитория в пользовательские сообщения.
class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormIdle();

  /// Текущий режим формы. Хранится отдельно, т.к. [state] — это статус запроса.
  AuthMode mode = AuthMode.login;

  /// Переключить режим login ↔ register.
  void toggleMode() {
    mode = mode == AuthMode.login ? AuthMode.register : AuthMode.login;
    state = const AuthFormIdle();
  }

  /// Установить конкретный режим.
  void setMode(AuthMode newMode) {
    if (newMode == mode) return;
    mode = newMode;
    state = const AuthFormIdle();
  }

  /// Сбросить ошибку.
  void clearError() {
    if (state is AuthFormIdle) {
      state = const AuthFormIdle();
    }
  }

  /// Выполнить вход/регистрацию.
  ///
  /// Повторный вызов во время выполнения запроса игнорируется —
  /// защита от double submit (кнопка, keyboard submit, hardware Enter).
  Future<void> submit({
    required String email,
    required String password,
    String? name,
  }) async {
    if (state is AuthFormLoading) return;
    state = const AuthFormLoading();
    final repo = ref.read(authRepositoryProvider);
    try {
      final session = mode == AuthMode.login
          ? await repo.login(email: email, password: password)
          : await repo.register(email: email, password: password, name: name);
      state = AuthFormSuccess(session);
    } on AuthError catch (e) {
      state = AuthFormIdle(error: e);
    } catch (_) {
      state = const AuthFormIdle(error: UnknownAuthError());
    }
  }

  /// OAuth-вход через VK.
  Future<void> loginWithVk() async {
    if (state is AuthFormLoading) return;
    state = const AuthFormLoading();
    try {
      final session = await ref.read(authRepositoryProvider).loginWithVk();
      state = AuthFormSuccess(session);
    } on AuthError catch (e) {
      state = AuthFormIdle(error: e);
    } catch (_) {
      state = const AuthFormIdle(error: OAuthFailedError('vk'));
    }
  }

  /// OAuth-вход через Yandex.
  Future<void> loginWithYandex() async {
    if (state is AuthFormLoading) return;
    state = const AuthFormLoading();
    try {
      final session = await ref.read(authRepositoryProvider).loginWithYandex();
      state = AuthFormSuccess(session);
    } on AuthError catch (e) {
      state = AuthFormIdle(error: e);
    } catch (_) {
      state = const AuthFormIdle(error: OAuthFailedError('yandex'));
    }
  }
}

/// Провайдер контроллера формы авторизации.
///
/// `autoDispose`: единственный подписчик — `AuthPage`. При уходе с `/auth`
/// (успешный вход, logout-flow) состояние и режим сбрасываются — повторное
/// открытие экрана всегда начинается с чистого `AuthFormIdle` в режиме login.
final authControllerProvider =
    NotifierProvider.autoDispose<AuthController, AuthFormState>(
      AuthController.new,
    );
