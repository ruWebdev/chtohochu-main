import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_sizes.dart';
import '../../../app/theme/app_spacing.dart';

/// Вариант кнопки.
enum AppButtonVariant {
  /// Основная кнопка (брендовый акцент).
  primary,

  /// Вторичная кнопка (приглушённая поверхность).
  secondary,

  /// Кнопка с границей.
  outline,

  /// Текстовая кнопка.
  ghost,

  /// Деструктивная кнопка (ошибка).
  destructive,
}

/// Размер кнопки.
enum AppButtonSize {
  /// Маленькая (32px).
  sm,

  /// Средняя (40px) — по умолчанию.
  md,

  /// Большая (48px).
  lg,
}

/// Кнопка приложения.
///
/// Построена поверх Material 3, но с собственными вариантами, согласованными
/// с дизайн-системой. Не содержит бизнес-логики.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.leading,
    this.trailing,
    this.expand = false,
    this.isLoading = false,
  });

  /// Текст кнопки.
  final String label;

  /// Callback. Вызывается при нажатии. Если `null` — нажатие игнорируется,
  /// но кнопка остаётся визуально активной (если [enabled] = `true`).
  final VoidCallback? onPressed;

  /// Визуальное состояние кнопки. `false` = disabled (приглушённый вид).
  /// По умолчанию `true` — позволяет показывать кнопки в showcase без callback.
  final bool enabled;

  /// Вариант оформления.
  final AppButtonVariant variant;

  /// Размер.
  final AppButtonSize size;

  /// Иконка перед текстом.
  final Widget? leading;

  /// Иконка после текста.
  final Widget? trailing;

  /// Растянуть на всю ширину.
  final bool expand;

  /// Показать индикатор загрузки (замещает leading/trailing).
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppThemeColors>()!;
    final typography = theme.textTheme;
    final isDisabled = !enabled;
    final effectiveOnPressed = (isLoading || !enabled) ? null : onPressed;

    final (bg, fg, borderColor) = _resolveAppearance(colors, isDisabled);
    final height = _resolveHeight();
    final pad = _resolvePadding();
    final style =
        (size == AppButtonSize.sm
                ? typography.labelMedium
                : typography.labelLarge)!
            .copyWith(color: fg);

    Widget content = Row(
      // Кнопка на всю ширину центрирует контент, компактная — нет.
      mainAxisAlignment: expand
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: AppSizes.iconSizeSm,
            height: AppSizes.iconSizeSm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else ...[
          if (leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(color: fg, size: AppSizes.iconSize),
              child: leading!,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: style,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            IconTheme.merge(
              data: IconThemeData(color: fg, size: AppSizes.iconSize),
              child: trailing!,
            ),
          ],
        ],
      ],
    );

    final radius = BorderRadius.circular(AppRadii.lg);

    // Контейнер с визуальным фоном (цвет + граница).
    final container = Container(
      constraints: BoxConstraints(minHeight: height),
      padding: pad,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: content,
    );

    // Material + InkWell — только для ripple-эффекта.
    final button = Material(
      type: MaterialType.transparency,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: effectiveOnPressed,
        borderRadius: radius,
        child: container,
      ),
    );

    if (expand) return SizedBox(width: double.infinity, child: button);
    return button;
  }

  double _resolveHeight() {
    return switch (size) {
      AppButtonSize.sm => AppSizes.buttonHeightSm,
      AppButtonSize.md => AppSizes.buttonHeight,
      AppButtonSize.lg => AppSizes.buttonHeightLg,
    };
  }

  EdgeInsets _resolvePadding() {
    return switch (size) {
      AppButtonSize.sm => const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      AppButtonSize.md => const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      AppButtonSize.lg => const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    };
  }

  (Color, Color, Color?) _resolveAppearance(
    AppThemeColors colors,
    bool isDisabled,
  ) {
    final base = switch (variant) {
      AppButtonVariant.primary => (
        colors.primary,
        colors.primaryForeground,
        null,
      ),
      AppButtonVariant.secondary => (
        colors.surfaceMuted,
        colors.textPrimary,
        null,
      ),
      AppButtonVariant.outline => (
        colors.surface,
        colors.textPrimary,
        colors.border,
      ),
      AppButtonVariant.ghost => (Colors.transparent, colors.primary, null),
      AppButtonVariant.destructive => (colors.error, Colors.white, null),
    };
    if (isDisabled) {
      return (colors.surfaceMuted, colors.textMuted, null);
    }
    return base;
  }
}
