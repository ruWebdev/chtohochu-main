import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';

/// Вариант карточки.
enum AppCardVariant {
  /// Поверхность + тонкая граница (по умолчанию).
  outlined,

  /// Поверхность + лёгкая тень.
  elevated,

  /// Приглушённая поверхность (без границы).
  muted,
}

/// Карточка приложения.
///
/// Предпочитает surface + тонкая граница вместо тяжёлых теней.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.outlined,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.radius = AppRadii.lg,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final (bg, border, shadow) = switch (variant) {
      AppCardVariant.outlined => (
        colors.surface,
        colors.border,
        const <BoxShadow>[],
      ),
      AppCardVariant.elevated => (
        colors.surfaceElevated,
        null,
        context.shadowCard,
      ),
      AppCardVariant.muted => (colors.surfaceMuted, null, const <BoxShadow>[]),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: border != null ? Border.all(color: border) : null,
            boxShadow: shadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
