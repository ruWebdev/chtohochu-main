import 'package:flutter/material.dart';

/// Тени приложения.
///
/// Дизайн — flat: декоративные тени и приподнятость убраны из
/// компонентов, карточек, кнопок, диалогов и шитов. Единственное
/// исключение — стеклянный Bottom Navigation Bar: его мягкая тень
/// нужна, чтобы floating-панель читалась поверх контента.
///
/// Иерархия на остальных поверхностях строится через типографику,
/// отступы, различия фоновых поверхностей и тонкие границы.
class AppShadows {
  const AppShadows._();

  /// Тень floating-элементов нижней навигации:
  /// Y 2, blur 6, opacity ~8% (light) / ~3% (dark).
  static List<BoxShadow> floating(Brightness brightness) {
    final color = brightness == Brightness.light
        ? const Color(0x14000000)
        : const Color(0x08000000);
    return [BoxShadow(color: color, blurRadius: 6, offset: const Offset(0, 2))];
  }
}
