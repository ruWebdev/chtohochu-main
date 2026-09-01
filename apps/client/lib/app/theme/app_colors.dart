import 'package:flutter/material.dart';

/// Цветовая схема приложения на основе Material 3.
class AppColors {
  const AppColors._();

  /// Seed-цвет для светлой темы.
  static const Color lightSeed = Color(0xFF6750A4);

  /// Seed-цвет для тёмной темы.
  static const Color darkSeed = Color(0xFFD0BCFF);

  /// Светлая цветовая схема Material 3.
  static ColorScheme get lightScheme =>
      ColorScheme.fromSeed(seedColor: lightSeed, brightness: Brightness.light);

  /// Тёмная цветовая схема Material 3.
  static ColorScheme get darkScheme =>
      ColorScheme.fromSeed(seedColor: darkSeed, brightness: Brightness.dark);
}
