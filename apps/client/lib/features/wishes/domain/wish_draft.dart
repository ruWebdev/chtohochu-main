import 'wish.dart';

/// Черновик желания — типизированный `extra` для роута `/wishes/new`
/// и параметр `AddWishSheet` в режиме импорта.
///
/// Создаётся входящим шерингом (`ACTION_SEND` из маркетплейса/браузера).
/// `link` — извлечённый из share-текста URL. Опциональные поля превью
/// заполняются уже выполненной OG-экстракцией — тогда форма не
/// запускает её повторно (`previewDone`).
class WishDraft {
  const WishDraft({
    required this.link,
    this.title,
    this.description,
    this.price,
    this.imagePath,
    this.priority,
    this.previewDone = false,
  });

  /// URL товара/источника из входящего share.
  final String link;

  /// Извлечённые метаданные (если экстракция уже отработала).
  final String? title;
  final String? description;
  final int? price;

  /// Локальный путь уже скачанного `og:image` — файл прошёл
  /// `MediaImageProcessor` и лежит в media-хранилище желаний.
  final String? imagePath;

  /// Приоритет, выбранный в quick-sheet до перехода в полную
  /// форму (`null` — дефолт формы `normal`).
  final WishPriority? priority;

  /// `true` — экстракция по ссылке уже выполнялась; получатель
  /// черновика не должен грузить страницу заново.
  final bool previewDone;
}
