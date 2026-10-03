import 'package:flutter/material.dart';

/// Доступ к [AppThemeColors] текущей темы через `context.appColors`.
extension AppThemeColorsContext on BuildContext {
  /// Семантические цвета текущей темы.
  AppThemeColors get appColors => Theme.of(this).extension<AppThemeColors>()!;
}

/// Цветовая система приложения.
///
/// Брендовый primary — `#6C63FF`, используется как акцент, а не как основная
/// заливка интерфейса. Поверхности — светлые, тёплые (мягкий peach/cream).
class AppColors {
  const AppColors._();

  /// Брендовый primary-цвет проекта.
  static const Color brand = Color(0xFF6C63FF);

  /// Seed-цвет для Material 3 `ColorScheme` (светлая тема).
  static const Color lightSeed = brand;

  /// Seed-цвет для Material 3 `ColorScheme` (тёмная тема).
  static const Color darkSeed = Color(0xFF8B83FF);

  /// Светлая `ColorScheme` Material 3.
  static ColorScheme get lightScheme =>
      ColorScheme.fromSeed(seedColor: lightSeed, brightness: Brightness.light);

  /// Тёмная `ColorScheme` Material 3.
  static ColorScheme get darkScheme =>
      ColorScheme.fromSeed(seedColor: darkSeed, brightness: Brightness.dark);

  /// Светлая тема — семантические токены.
  static AppThemeColors get lightThemeColors => const AppThemeColors(
    background: Color(0xFFFBF8F4),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3EEE7),
    textPrimary: Color(0xFF1F1B16),
    textSecondary: Color(0xFF5C544B),
    textMuted: Color(0xFF8A8278),
    primary: brand,
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFFE8E6FF),
    secondaryForeground: Color(0xFF3A33A8),
    border: Color(0xFFE7E1D8),
    divider: Color(0xFFEFEAE2),
    success: Color(0xFF1F8A4C),
    successSurface: Color(0xFFE8F5EC),
    warning: Color(0xFFB26A00),
    warningSurface: Color(0xFFFFF3E0),
    error: Color(0xFFC62828),
    errorSurface: Color(0xFFFDECEA),
    info: Color(0xFF2A6DBE),
    infoSurface: Color(0xFFE7F0FB),
    scrim: Color(0x66000000),
  );

  /// Тёмная тема — семантические токены.
  static AppThemeColors get darkThemeColors => const AppThemeColors(
    background: Color(0xFF15130F),
    surface: Color(0xFF1F1C17),
    surfaceElevated: Color(0xFF272320),
    surfaceMuted: Color(0xFF2C2823),
    textPrimary: Color(0xFFF5F1EA),
    textSecondary: Color(0xFFC3BBAF),
    textMuted: Color(0xFF8E8678),
    primary: Color(0xFF8B83FF),
    primaryForeground: Color(0xFF14121F),
    secondary: Color(0xFF2A2659),
    secondaryForeground: Color(0xFFD6D2FF),
    border: Color(0xFF3A352E),
    divider: Color(0xFF2F2A24),
    success: Color(0xFF7ED99B),
    successSurface: Color(0xFF1E3326),
    warning: Color(0xFFFFB95E),
    warningSurface: Color(0xFF3A2E18),
    error: Color(0xFFFF8A80),
    errorSurface: Color(0xFF3A1E1C),
    info: Color(0xFF8AB8F0),
    infoSurface: Color(0xFF1E2A3A),
    scrim: Color(0x99000000),
  );
}

/// Семантические цвета приложения, выходящие за рамки `ColorScheme`.
///
/// Доступ через `Theme.of(context).extension<AppThemeColors>()`.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.border,
    required this.divider,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.error,
    required this.errorSurface,
    required this.info,
    required this.infoSurface,
    required this.scrim,
  });

  /// Основной фон приложения.
  final Color background;

  /// Базовая поверхность карточек/листов.
  final Color surface;

  /// Приподнятая поверхность (диалоги, sheets).
  final Color surfaceElevated;

  /// Приглушённая поверхность (поля, chips фон).
  final Color surfaceMuted;

  /// Основной текст.
  final Color textPrimary;

  /// Вторичный текст.
  final Color textSecondary;

  /// Приглушённый текст (caption, placeholder).
  final Color textMuted;

  /// Брендовый акцент.
  final Color primary;

  /// Текст/иконки на брендовом акценте.
  final Color primaryForeground;

  /// Вторичный акцент (мягкий фон выбранного).
  final Color secondary;

  /// Текст/иконки на вторичном акценте.
  final Color secondaryForeground;

  /// Границы карточек, полей, разделители секций.
  final Color border;

  /// Тонкий разделитель внутри списков.
  final Color divider;

  /// Успех.
  final Color success;

  /// Фон блока успеха.
  final Color successSurface;

  /// Предупреждение.
  final Color warning;

  /// Фон блока предупреждения.
  final Color warningSurface;

  /// Ошибка.
  final Color error;

  /// Фон блока ошибки.
  final Color errorSurface;

  /// Информация.
  final Color info;

  /// Фон блока информации.
  final Color infoSurface;

  /// Затемнение scrim.
  final Color scrim;

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? border,
    Color? divider,
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? error,
    Color? errorSurface,
    Color? info,
    Color? infoSurface,
    Color? scrim,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      error: error ?? this.error,
      errorSurface: errorSurface ?? this.errorSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
