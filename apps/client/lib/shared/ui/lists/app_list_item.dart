import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_sizes.dart';
import '../../../app/theme/app_spacing.dart';

/// Элемент списка приложения.
///
/// Построен поверх `ListTile`-подобной компоновки, но с собственным layout,
/// согласованным с дизайн-системой.
class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.destructive = false,
    this.showDivider = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;

  /// Деструктивное действие (например, «Выйти») — красный текст и иконка.
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppThemeColors>()!;
    final typography = theme.textTheme;

    final bg = selected ? colors.secondary : Colors.transparent;
    final titleColor = destructive
        ? colors.error
        : (enabled ? colors.textPrimary : colors.textMuted);
    final subtitleColor = enabled ? colors.textSecondary : colors.textMuted;
    final iconColor = destructive ? colors.error : colors.textSecondary;

    return Material(
      color: bg,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                IconTheme.merge(
                  data: IconThemeData(
                    color: iconColor,
                    size: AppSizes.iconSize,
                  ),
                  child: leading!,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: typography.bodyMedium!.copyWith(color: titleColor),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: typography.bodySmall!.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconTheme.merge(
                  data: IconThemeData(
                    color: colors.textMuted,
                    size: AppSizes.iconSize,
                  ),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Разделитель между элементами списка.
class AppListDivider extends StatelessWidget {
  const AppListDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.divider,
      indent: indent,
      endIndent: 0,
    );
  }
}
