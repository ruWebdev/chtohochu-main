import 'shopping_item.dart';

/// Список покупок.
///
/// У пользователя может быть несколько списков. Позиции хранятся
/// внутри списка — для MVP это достаточно; при появлении backend
/// модель можно разделить на `ShoppingList` + отдельные items.
class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.title,
    required this.createdAt,
    this.items = const [],
  });

  /// Идентификатор списка.
  final String id;

  /// Название списка.
  final String title;

  /// Позиции списка.
  final List<ShoppingItem> items;

  /// Дата создания.
  final DateTime createdAt;

  /// Количество отмеченных (купленных) позиций.
  int get checkedCount => items.where((i) => i.isChecked).length;

  /// Создаёт копию с изменёнными полями.
  ShoppingList copyWith({
    String? id,
    String? title,
    List<ShoppingItem>? items,
    DateTime? createdAt,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      title: title ?? this.title,
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
          createdAt == other.createdAt &&
          _listEquals(items, other.items);

  @override
  int get hashCode => Object.hash(id, title, createdAt, Object.hashAll(items));

  static bool _listEquals(List<ShoppingItem> a, List<ShoppingItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'ShoppingList(id: $id, title: $title)';
}
