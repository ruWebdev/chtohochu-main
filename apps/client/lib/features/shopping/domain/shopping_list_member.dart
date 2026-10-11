/// Участник совместного списка покупок.
///
/// Публичная проекция пользователя (как `PublicUserResource`)
/// + роль в списке. `owner` — владелец, у него расширенные
/// права (переименование, удаление списка, управление составом).
class ShoppingListMember {
  const ShoppingListMember({
    required this.id,
    required this.role,
    this.name,
    this.username,
    this.avatarUrl,
  });

  /// UUID пользователя.
  final String id;

  /// 'owner' | 'member'.
  final String role;

  final String? name;
  final String? username;
  final String? avatarUrl;

  bool get isOwner => role == 'owner';

  /// Отображаемое имя: name → username → '?'.
  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final u = username?.trim();
    if (u != null && u.isNotEmpty) return '@$u';
    return '?';
  }

  /// Инициалы для аватара (до двух букв).
  String get initials {
    final parts = displayName
        .replaceFirst('@', '')
        .trim()
        .split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  ShoppingListMember copyWith({
    String? id,
    String? role,
    String? name,
    String? username,
    String? avatarUrl,
  }) {
    return ShoppingListMember(
      id: id ?? this.id,
      role: role ?? this.role,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingListMember &&
          id == other.id &&
          role == other.role &&
          name == other.name &&
          username == other.username &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode => Object.hash(id, role, name, username, avatarUrl);

  @override
  String toString() => 'ShoppingListMember(id: $id, role: $role)';
}
