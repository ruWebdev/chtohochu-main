/// Масштаб отступов приложения.
///
/// Заменяет «магические» значения padding/margin/gap в виджетах.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Горизонтальный отступ контента экрана.
  static const double screenPaddingHorizontal = md;

  /// Вертикальный отступ секции внутри экрана.
  static const double sectionGap = xl;

  /// Расстояние между карточками в списке.
  static const double betweenCards = sm;

  /// Расстояние между полями формы.
  static const double betweenFields = sm;

  /// Минимальная высота touch-target.
  static const double minTouchTarget = 48;

  // --- Bottom Navigation ---

  /// Горизонтальный внешний отступ floating bottom bar.
  static const double bottomBarMarginHorizontal = sm;

  /// Нижний отступ floating bottom bar (поверх Safe Area).
  static const double bottomBarMarginBottom = xs;

  // --- AppBar ---

  /// Расстояние между action-кнопками в AppBar.
  static const double appBarActionSpacing = xs;

  /// Отступ между leading и title в AppBar.
  static const double appBarLeadingGap = sm;
}
