/// Список желаний — группировка wishes.
///
/// Offline-first сущность: создаётся локально с клиентским
/// UUID, синхронизируется через outbox/SyncEngine. Желание
/// входит максимум в один список (`wish.listId`); удаление
/// списка разгруппировывает желания, не удаляя их.
class WishList {
  const WishList({
    required this.id,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.wishCount = 0,
  });

  /// Идентификатор списка (клиентский UUID = серверный).
  final String id;

  /// Название списка.
  final String title;

  /// Дата создания.
  final DateTime createdAt;

  /// Дата последнего изменения (server-synced).
  final DateTime? updatedAt;

  /// Число живых желаний в списке (вычисляется join'ом,
  /// не хранится).
  final int wishCount;

  WishList copyWith({String? title, DateTime? updatedAt}) {
    return WishList(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      wishCount: wishCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WishList &&
          id == other.id &&
          title == other.title &&
          wishCount == other.wishCount &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, title, wishCount, createdAt);

  @override
  String toString() => 'WishList(id: $id, title: $title)';
}
