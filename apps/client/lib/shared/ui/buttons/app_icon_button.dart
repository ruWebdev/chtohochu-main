import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_sizes.dart';
import '../../../app/theme/app_theme.dart';

/// Квадратная кнопка-иконка с умеренным скруглением углов.
///
/// Используется в AppBar actions и как самостоятельная action-кнопка.
/// Компактная, с мягким фоном и hover/pressed state.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = AppSizes.iconButtonSize,
    this.iconSize = AppSizes.appBarIconSize,
    this.variant = AppIconButtonVariant.subtle,
    this.tooltip,
    this.semanticLabel,
  });

  /// Иконка.
  final Widget icon;

  /// Callback. Если `null` — кнопка disabled.
  final VoidCallback? onPressed;

  /// Внешний размер кнопки.
  final double size;

  /// Размер иконки.
  final double iconSize;

  /// Вариант оформления.
  final AppIconButtonVariant variant;

  /// Тултип при долгом нажатии.
  final String? tooltip;

  /// Семантическая метка для accessibility.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isDisabled = onPressed == null;
    final (bg, fg) = _resolveAppearance(colors, isDisabled);

    // Тень только для filled-вариантов в активном состоянии.
    // Ghost/outline (прозрачный фон) и disabled — без тени.
    final hasShadow =
        !isDisabled &&
        (variant == AppIconButtonVariant.subtle ||
            variant == AppIconButtonVariant.primary);
    final shadow = hasShadow ? context.shadowFloating : const <BoxShadow>[];

    // Тонкая обводка для subtle и outline вариантов.
    // primary (сплошная заливка) и ghost (прозрачный) — без обводки.
    final hasBorder =
        variant == AppIconButtonVariant.subtle ||
        variant == AppIconButtonVariant.outline;

    final radius = BorderRadius.circular(AppRadii.lg);

    final inner = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: hasBorder ? Border.all(color: colors.border) : null,
      ),
      alignment: Alignment.center,
      child: IconTheme.merge(
        data: IconThemeData(color: fg, size: iconSize),
        child: icon,
      ),
    );

    // Тень рисуется внешним контейнером, чтобы Material clip
    // (borderRadius + antiAlias) её не обрезал.
    final interactive = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onPressed, borderRadius: radius, child: inner),
      ),
    );

    final labeled = semanticLabel != null
        ? Semantics(button: true, label: semanticLabel, child: interactive)
        : interactive;

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: labeled);
    }
    return labeled;
  }

  (Color, Color) _resolveAppearance(AppThemeColors colors, bool isDisabled) {
    if (isDisabled) {
      return (Colors.transparent, colors.textMuted);
    }
    return switch (variant) {
      AppIconButtonVariant.subtle => (
        colors.surfaceMuted,
        colors.textSecondary,
      ),
      AppIconButtonVariant.ghost => (Colors.transparent, colors.textSecondary),
      AppIconButtonVariant.primary => (
        colors.primary,
        colors.primaryForeground,
      ),
      AppIconButtonVariant.outline => (Colors.transparent, colors.textPrimary),
    };
  }
}

/// Вариант кнопки-иконки.
enum AppIconButtonVariant {
  /// Мягкий фон (surfaceMuted) + тонкая обводка.
  subtle,

  /// Без фона.
  ghost,

  /// Брендовый акцент.
  primary,

  /// С границей.
  outline,
}
