/// Пользователь приложения.
///
/// Минимальная модель для первого vertical slice.
/// В будущем будет расширена и, вероятно, сгенерирована через Freezed.
class User {
  const User({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.avatarUrl,
  });

  /// Идентификатор пользователя.
  final String id;

  /// Email пользователя.
  final String email;

  /// Отображаемое имя (опционально).
  final String? name;

  /// Уникальный handle (`@username`) — используется для поиска друзей.
  final String? username;

  /// Ссылка на аватар (опционально).
  final String? avatarUrl;

  /// Имя для приветствия: name или часть email до `@`.
  String get displayName =>
      name?.isNotEmpty == true ? name! : email.split('@').first;

  /// Инициалы для аватара (до двух букв, из имени или email).
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Создаёт копию с изменёнными полями.
  ///
  /// Для очистки [avatarUrl] передайте `avatarUrl: null` явно —
  /// используется sentinel, чтобы отличить «не менять» от «очистить».
  User copyWith({
    String? name,
    Object? username = _sentinel,
    Object? avatarUrl = _sentinel,
  }) {
    return User(
      id: id,
      email: email,
      name: name ?? this.name,
      username: username == _sentinel ? this.username : username as String?,
      avatarUrl: avatarUrl == _sentinel ? this.avatarUrl : avatarUrl as String?,
    );
  }

  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          email == other.email &&
          name == other.name &&
          username == other.username &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode => Object.hash(id, email, name, username, avatarUrl);

  @override
  String toString() => 'User(id: $id, email: $email, name: $name)';
}
