import '../../wishes/domain/wish.dart';

/// Друг пользователя.
///
/// Минимальная модель для MVP: имя, username для поиска и список
/// видимых желаний. Желания переиспользуют [Wish] — отдельная модель
/// «чужого желания» пока не нужна.
class Friend {
  const Friend({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.wishes = const [],
  });

  /// Идентификатор пользователя.
  final String id;

  /// Отображаемое имя.
  final String name;

  /// Уникальный handle для поиска (`@username`).
  final String username;

  /// Ссылка на аватар (опционально).
  final String? avatarUrl;

  /// Желания, видимые текущему пользователю.
  ///
  /// Не все желания друга обязаны быть здесь — набор определяется
  /// будущей моделью privacy. Для mock — весь список.
  final List<Wish> wishes;

  /// Инициалы для аватара (до двух букв).
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Создаёт копию с изменёнными полями.
  Friend copyWith({
    String? id,
    String? name,
    String? username,
    String? avatarUrl,
    List<Wish>? wishes,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      wishes: wishes ?? this.wishes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friend &&
          id == other.id &&
          name == other.name &&
          username == other.username;

  @override
  int get hashCode => Object.hash(id, name, username);

  @override
  String toString() => 'Friend(id: $id, username: $username)';
}
