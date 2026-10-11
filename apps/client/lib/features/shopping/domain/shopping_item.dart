/// Позиция в списке покупок.
///
/// Минимальная модель для MVP: название, опциональное количество,
/// одно локальное фото и состояние «куплено». Не путать с `Wish` —
/// это отдельный пользовательский сценарий.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.title,
    this.quantity = 1,
    this.isChecked = false,
    this.imageLocalPath,
  });

  /// Идентификатор позиции.
  final String id;

  /// Название позиции.
  final String title;

  /// Количество (минимум 1; в UI показывается как «× N» при N > 1).
  final int quantity;

  /// Отмечена ли позиция как купленная.
  final bool isChecked;

  /// Локальный файл фото позиции (`media/shopping/`).
  /// Только локально — backend позиций изображения не хранит.
  final String? imageLocalPath;

  /// Создаёт копию с изменёнными полями.
  ShoppingItem copyWith({
    String? id,
    String? title,
    int? quantity,
    bool? isChecked,
    String? imageLocalPath,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingItem &&
          id == other.id &&
          title == other.title &&
          quantity == other.quantity &&
          isChecked == other.isChecked &&
          imageLocalPath == other.imageLocalPath;

  @override
  int get hashCode =>
      Object.hash(id, title, quantity, isChecked, imageLocalPath);

  @override
  String toString() => 'ShoppingItem(id: $id, title: $title)';
}
