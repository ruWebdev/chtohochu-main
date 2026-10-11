import 'shopping_item.dart';
import 'shopping_list_member.dart';

/// Список покупок.
///
/// Списки могут быть совместными: `ownerUserId` — серверный
/// владелец, `members` — участники (включая владельца).
/// Позиции хранятся в отдельных строках Drift и собираются
/// репозиторием в `items`.
class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.title,
    required this.createdAt,
    this.ownerUserId,
    this.members = const [],
    this.items = const [],
  });

  /// Идентификатор списка.
  final String id;

  /// Название списка.
  final String title;

  /// Серверный владелец списка (UUID пользователя).
  /// `null` для старых локальных записей — считаются своими.
  final String? ownerUserId;

  /// Участники списка (владелец + members).
  final List<ShoppingListMember> members;

  /// Позиции списка.
  final List<ShoppingItem> items;

  /// Дата создания.
  final DateTime createdAt;

  /// Количество отмеченных (купленных) позиций.
  int get checkedCount => items.where((i) => i.isChecked).length;

  /// Совместный ли список — есть участники помимо владельца.
  bool get isShared => members.where((m) => !m.isOwner).isNotEmpty;

  /// Текущий пользователь — владелец списка.
  bool isOwnedBy(String userId) => ownerUserId == null || ownerUserId == userId;

  /// Создаёт копию с изменёнными полями.
  ShoppingList copyWith({
    String? id,
    String? title,
    String? ownerUserId,
    List<ShoppingListMember>? members,
    List<ShoppingItem>? items,
    DateTime? createdAt,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      title: title ?? this.title,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      members: members ?? this.members,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingList &&
          id == other.id &&
          title == other.title &&
          ownerUserId == other.ownerUserId &&
          createdAt == other.createdAt &&
          _listEquals(members, other.members) &&
          _listEquals(items, other.items);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    ownerUserId,
    createdAt,
    Object.hashAll(members),
    Object.hashAll(items),
  );

  static bool _listEquals(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'ShoppingList(id: $id, title: $title)';
}
