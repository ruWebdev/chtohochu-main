/// Желание пользователя.
///
/// Модель для MVP vertical slice: название, опциональные описание,
/// цена, ссылка на товар и ссылка на изображение. В будущем будет
/// расширена (списки, статус, резервирование) и, вероятно,
/// сгенерирована через Freezed + json_serializable.
class Wish {
  const Wish({
    required this.id,
    required this.title,
    required this.createdAt,
    this.description,
    this.price,
    this.link,
    this.imageUrl,
    this.updatedAt,
  });

  /// Идентификатор желания.
  final String id;

  /// Название желания.
  final String title;

  /// Заметка/описание (опционально).
  final String? description;

  /// Примерная цена в рублях (опционально).
  final int? price;

  /// Ссылка на товар/источник (опционально).
  final String? link;

  /// Ссылка на изображение (опционально).
  final String? imageUrl;

  /// Дата создания.
  final DateTime createdAt;

  /// Дата последнего изменения (server `updated_at` после sync).
  final DateTime? updatedAt;

  /// Создаёт копию с изменёнными полями.
  ///
  /// Nullable-поля нельзя сбросить через `copyWith` (нет способа отличить
  /// «не менять» от «очистить»). Для редактирования создавайте новый
  /// [Wish] с явными значениями.
  Wish copyWith({
    String? id,
    String? title,
    String? description,
    int? price,
    String? link,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wish(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      link: link ?? this.link,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wish &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          price == other.price &&
          link == other.link &&
          imageUrl == other.imageUrl &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(id, title, description, price, link, imageUrl, createdAt);

  @override
  String toString() => 'Wish(id: $id, title: $title)';
}
