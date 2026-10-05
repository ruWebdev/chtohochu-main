/// Дополнительное изображение желания.
///
/// Primary-изображение — `Wish.imageUrl` (сохраняет прежнюю
/// семантику: remote URL или локальный путь). Эта сущность —
/// только additional-изображения из `wish_images`.
///
/// Источники разделены: [localPath] — файл на устройстве
/// (`Documents/wish_photos/`), [remoteUrl] — URL после будущего
/// upload. `remoteUrl == null` — изображение ещё не загружено
/// (задел под S3-этап).
class WishImage {
  const WishImage({
    required this.id,
    required this.sortOrder,
    this.localPath,
    this.remoteUrl,
  });

  /// UUID изображения (клиентский).
  final String id;

  /// Порядок отображения: 1, 2, … (primary — `Wish.imageUrl`).
  final int sortOrder;

  /// Путь к локальному файлу, если источник — устройство.
  final String? localPath;

  /// URL после загрузки на сервер/CDN.
  final String? remoteUrl;

  /// Источник для отображения через `AppImage`:
  /// локальный файл приоритетнее — он уже на устройстве.
  String? get displaySource => localPath ?? remoteUrl;

  @override
  String toString() =>
      'WishImage(id: $id, sortOrder: $sortOrder, '
      'local: ${localPath != null}, remote: ${remoteUrl != null})';
}
