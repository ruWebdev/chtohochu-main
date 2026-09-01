import 'package:flutter/material.dart';

/// Типографика приложения.
class AppTypography {
  const AppTypography._();

  /// Текстовые темы для светлой темы.
  static TextTheme get light => Typography.material2021().black;

  /// Текстовые темы для тёмной темы.
  static TextTheme get dark => Typography.material2021().white;
}
