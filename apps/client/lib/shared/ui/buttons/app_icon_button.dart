import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_sizes.dart';

/// Круглая кнопка-иконка.
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

    // Тонкая обводка только у outline варианта.
    // subtle/primary (заливка) и ghost (прозрачный) — без обводки.
    final hasBorder = variant == AppIconButtonVariant.outline;

    final radius = BorderRadius.circular(AppRadii.full);

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

    final interactive = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onPressed, borderRadius: radius, child: inner),
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
        colors.surfaceElevated,
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
  /// Светлый фон (surfaceElevated) без обводки — flat-кнопка баров.
  subtle,

  /// Без фона.
  ghost,

  /// Брендовый акцент.
  primary,

  /// С границей.
  outline,
}
