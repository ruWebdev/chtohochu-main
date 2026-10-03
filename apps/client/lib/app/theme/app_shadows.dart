import 'package:flutter/material.dart';

/// Тени приложения.
///
/// Минимальные, мягкие, почти незаметные. Нужны для визуальной иерархии,
/// а не как декоративный эффект. В большинстве случаев предпочтительнее
/// surface + тонкая граница вместо тени.
///
/// Semantic tokens:
/// * [subtle] — едва заметная тень для лёгкого приподнятия;
/// * [card] — тень основных карточек;
/// * [floating] — тень floating-элементов (круглые action-кнопки,
///   dialog, bottom sheet).
///
/// В тёмной теме тени ещё менее заметны — на тёмном фоне чёрная тень
/// сама по себе почти невидима, поэтому opacity дополнительно снижается.
class AppShadows {
  const AppShadows._();

  /// Мягкий scrim для Material elevation-теней в светлой теме (~8%).
  static const Color lightScrim = Color(0x14000000);

  /// Мягкий scrim для Material elevation-теней в тёмной теме (~3%).
  static const Color darkScrim = Color(0x08000000);

  /// Elevation для dialog/bottom sheet — минимальная, чтобы Material
  /// нарисовал мягкую тень через [lightScrim]/[darkScrim].
  static const double floatingElevation = 2;

  /// Очень лёгкая тень: Y 1, blur 3, opacity ~4% (light) / ~1% (dark).
  static List<BoxShadow> subtle(Brightness brightness) {
    final color = brightness == Brightness.light
        ? const Color(0x0A000000)
        : const Color(0x03000000);
    return [BoxShadow(color: color, blurRadius: 3, offset: const Offset(0, 1))];
  }

  /// Тень основных карточек: Y 2, blur 8, opacity ~6% (light) / ~2% (dark).
  static List<BoxShadow> card(Brightness brightness) {
    final color = brightness == Brightness.light
        ? const Color(0x0F000000)
        : const Color(0x05000000);
    return [BoxShadow(color: color, blurRadius: 8, offset: const Offset(0, 2))];
  }

  /// Тень floating-элементов: Y 2, blur 6, opacity ~8% (light) / ~3% (dark).
  static List<BoxShadow> floating(Brightness brightness) {
    final color = brightness == Brightness.light
        ? const Color(0x14000000)
        : const Color(0x08000000);
    return [BoxShadow(color: color, blurRadius: 6, offset: const Offset(0, 2))];
  }
}
