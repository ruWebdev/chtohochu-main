/// Позиция в списке покупок.
///
/// Минимальная модель для MVP: название, опциональное количество
/// и состояние «куплено». Не путать с `Wish` — это отдельный
/// пользовательский сценарий.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.title,
    this.quantity = 1,
    this.isChecked = false,
  });

  /// Идентификатор позиции.
  final String id;

  /// Название позиции.
  final String title;

  /// Количество (минимум 1; в UI показывается как «× N» при N > 1).
  final int quantity;

  /// Отмечена ли позиция как купленная.
  final bool isChecked;

  /// Создаёт копию с изменёнными полями.
  ShoppingItem copyWith({
    String? id,
    String? title,
    int? quantity,
    bool? isChecked,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingItem &&
          id == other.id &&
          title == other.title &&
          quantity == other.quantity &&
          isChecked == other.isChecked;

  @override
  int get hashCode => Object.hash(id, title, quantity, isChecked);

  @override
  String toString() => 'ShoppingItem(id: $id, title: $title)';
}
