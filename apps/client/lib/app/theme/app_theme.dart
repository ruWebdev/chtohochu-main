import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_shadows.dart';
import 'app_sizes.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Сборка тем приложения.
///
/// Material 3 используется как техническая основа, но визуальный стиль
/// настраивается явно через component themes и [AppThemeColors].
class AppTheme {
  const AppTheme._();

  /// Светлая тема.
  static ThemeData get light => _build(Brightness.light);

  /// Тёмная тема.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = brightness == Brightness.light
        ? AppColors.lightScheme
        : AppColors.darkScheme;
    final themeColors = brightness == Brightness.light
        ? AppColors.lightThemeColors
        : AppColors.darkThemeColors;
    final textTheme = AppTypography.textTheme(brightness);
    final shadowScrim = brightness == Brightness.light
        ? AppShadows.lightScrim
        : AppShadows.darkScrim;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: themeColors.background,
      canvasColor: themeColors.background,
      textTheme: textTheme,
      extensions: [themeColors],
      appBarTheme: AppBarTheme(
        backgroundColor: themeColors.background,
        foregroundColor: themeColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.screenPaddingHorizontal,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: themeColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: themeColors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: themeColors.divider,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: themeColors.primary,
          foregroundColor: themeColors.primaryForeground,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColors.surface,
          foregroundColor: themeColors.textPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: BorderSide(color: themeColors.border),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: themeColors.textPrimary,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          side: BorderSide(color: themeColors.border),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: themeColors.primary,
          minimumSize: const Size(0, AppSizes.buttonHeightSm),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: themeColors.textSecondary,
          backgroundColor: Colors.transparent,
          minimumSize: const Size.square(AppSpacing.minTouchTarget),
          shape: const CircleBorder(),
          iconSize: AppSizes.iconSize,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: themeColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: themeColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: themeColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: themeColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: themeColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: themeColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: themeColors.divider),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: themeColors.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: themeColors.textSecondary,
        ),
        errorStyle: textTheme.labelSmall?.copyWith(color: themeColors.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: themeColors.surfaceMuted,
        selectedColor: themeColors.secondary,
        checkmarkColor: themeColors.secondaryForeground,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: themeColors.textSecondary,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: themeColors.secondaryForeground,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: themeColors.surfaceElevated,
        elevation: AppShadows.floatingElevation,
        shadowColor: shadowScrim,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: themeColors.surfaceElevated,
        elevation: AppShadows.floatingElevation,
        shadowColor: shadowScrim,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: themeColors.divider,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: themeColors.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: themeColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        titleTextStyle: textTheme.bodyMedium,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: themeColors.textSecondary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: themeColors.primary,
        linearTrackColor: themeColors.divider,
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );
  }
}

/// Утилита для доступа к теням с учётом темы.
extension AppShadowsContext on BuildContext {
  /// Едва заметная тень для лёгкого приподнятия.
  List<BoxShadow> get shadowSubtle =>
      AppShadows.subtle(Theme.brightnessOf(this));

  /// Тень основных карточек.
  List<BoxShadow> get shadowCard => AppShadows.card(Theme.brightnessOf(this));

  /// Тень floating-элементов (круглые action-кнопки и т.п.).
  List<BoxShadow> get shadowFloating =>
      AppShadows.floating(Theme.brightnessOf(this));
}
