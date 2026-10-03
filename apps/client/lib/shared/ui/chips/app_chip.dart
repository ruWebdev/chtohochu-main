import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_sizes.dart';

/// Chip приложения.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.leading,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppThemeColors>()!;

    final bg = selected ? colors.secondary : colors.surfaceMuted;
    final fg = selected ? colors.secondaryForeground : colors.textSecondary;
    final style = theme.textTheme.labelMedium!.copyWith(color: fg);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSizes.chipHeight / 2),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSizes.chipHeight / 2),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.chipHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                IconTheme.merge(
                  data: IconThemeData(color: fg, size: AppSizes.iconSizeSm),
                  child: leading!,
                ),
                const SizedBox(width: 6),
              ],
              Text(label, style: style),
              if (onDeleted != null) ...[
                const SizedBox(width: 6),
                IconTheme.merge(
                  data: IconThemeData(color: fg, size: AppSizes.iconSizeSm),
                  child: GestureDetector(
                    onTap: onDeleted,
                    child: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
