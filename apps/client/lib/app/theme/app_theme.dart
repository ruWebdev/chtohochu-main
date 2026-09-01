import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Сборка тем приложения.
class AppTheme {
  const AppTheme._();

  /// Светлая тема Material 3.
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: AppColors.lightScheme,
    textTheme: AppTypography.light,
  );

  /// Тёмная тема Material 3.
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: AppColors.darkScheme,
    textTheme: AppTypography.dark,
  );
}
