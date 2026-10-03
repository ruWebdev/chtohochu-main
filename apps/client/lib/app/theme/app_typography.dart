import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Типографика приложения.
///
/// Шрифт — Open Sans (через `google_fonts`). Все размеры централизованы здесь;
/// feature-код обращается к semantic-токенам через `AppTypography.of(context)`
/// или `Theme.of(context).textTheme`.
class AppTypography {
  const AppTypography._();

  /// Имя семейства шрифта.
  static const String fontFamily = 'Open Sans';

  /// Базовый `TextTheme` для заданной яркости.
  ///
  /// Все стили используют Open Sans; цвета берутся из [AppThemeColors],
  /// чтобы светлая/тёмная тема получали корректные цвета текста.
  static TextTheme textTheme(Brightness brightness) {
    final colors = brightness == Brightness.light
        ? AppColors.lightThemeColors
        : AppColors.darkThemeColors;
    return _base(colors);
  }

  /// Возвращает semantic-стиль по имени для текущей темы.
  ///
  /// Используется в виджетах: `AppTypography.of(context).body`.
  static AppTypographyStyles of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppThemeColors>()!;
    return AppTypographyStyles._(_base(colors));
  }

  static TextTheme _base(AppThemeColors colors) {
    final base = GoogleFonts.getTextTheme(fontFamily, _raw);
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        height: 30 / 22,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12,
        height: 18 / 12,
        fontWeight: FontWeight.w400,
        color: colors.textMuted,
      ),
    );
  }

  /// Сырой `TextTheme` из google_fonts (без переопределения размеров).
  static const TextTheme _raw = TextTheme();
}

/// Semantic-обёртка над `TextTheme` для удобного доступа по именам.
class AppTypographyStyles {
  AppTypographyStyles._(this._theme);
  final TextTheme _theme;

  /// Display — крупный заголовок (28/36/600).
  TextStyle get display => _theme.displayLarge!;

  /// Screen title — заголовок экрана (24/32/600).
  TextStyle get screenTitle => _theme.displayMedium!;

  /// Section title — заголовок секции (22/30/600).
  TextStyle get sectionTitle => _theme.headlineMedium!;

  /// Подзаголовок карточки/блока (18/24/600).
  TextStyle get title => _theme.titleLarge!;

  /// Body large — основной крупный текст (16/24/400).
  TextStyle get bodyLarge => _theme.bodyLarge!;

  /// Body — основной текст (15/22/400).
  TextStyle get body => _theme.bodyMedium!;

  /// Body medium — основной текст полужирный (15/22/500).
  TextStyle get bodyMedium => _theme.labelLarge!;

  /// Secondary — вторичный текст (14/20/400).
  TextStyle get secondary => _theme.bodySmall!;

  /// Caption — приглушённый текст (13/18/500).
  TextStyle get caption => _theme.labelMedium!;

  /// Caption small — самый мелкий текст (12/18/400).
  TextStyle get captionSmall => _theme.labelSmall!;
}
