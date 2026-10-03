import 'user.dart';

/// Авторизованная сессия пользователя.
///
/// Содержит access-токен и данные пользователя.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  /// Sanctum access-токен.
  final String token;

  /// Данные пользователя.
  final User user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession && token == other.token && user == other.user;

  @override
  int get hashCode => Object.hash(token, user);

  @override
  String toString() => 'AuthSession(token: ***, user: $user)';
}
