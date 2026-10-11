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
    this.imageLocalPath,
    this.listId,
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
  ///
  /// Sync-facing поле: локальный путь до upload, remote URL после.
  /// Для отображения используйте [imageDisplaySource].
  final String? imageUrl;

  /// Путь к локальному файлу primary-изображения — иммутабельный.
  /// Не перезаписывается remote URL: источник отображения не
  /// переключается вживую (бесшовный local→remote после upload).
  final String? imageLocalPath;

  /// Источник изображения для отображения: локальный файл
  /// приоритетнее — он уже на устройстве и не мигает.
  String? get imageDisplaySource => imageLocalPath ?? imageUrl;

  /// `true`, если [ref] — удалённый URL (или отсутствует);
  /// `false` — локальный путь файла, который нельзя слать в API.
  static bool isRemoteImageRef(String? ref) =>
      ref == null || ref.startsWith('http://') || ref.startsWith('https://');

  /// Список желаний, в котором лежит желание (`WishList.id`);
  /// `null` — вне списков. Local-only: сервер связь пока не знает.
  final String? listId;

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
    String? imageLocalPath,
    String? listId,
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
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
      listId: listId ?? this.listId,
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
          imageLocalPath == other.imageLocalPath &&
          listId == other.listId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    price,
    link,
    imageUrl,
    imageLocalPath,
    listId,
    createdAt,
  );

  @override
  String toString() => 'Wish(id: $id, title: $title)';
}
