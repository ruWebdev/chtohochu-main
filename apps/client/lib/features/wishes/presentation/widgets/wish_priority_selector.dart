import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/wish.dart';

/// Единый селектор приоритета желания: «Не сейчас | Хочу | Очень хочу».
///
/// Используется в AddWishSheet и WishFormPage — три равных flat-
/// сегмента в цветах AppChip (secondary при выборе, muted иначе),
/// без теней. Только состояние формы — сетевых побочек нет.
class WishPrioritySelector extends StatelessWidget {
  const WishPrioritySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// Текущий приоритет ([WishPriority.normal] по умолчанию на форме).
  final WishPriority value;

  /// Выбор сегмента пользователем.
  final ValueChanged<WishPriority> onChanged;

  /// `false` во время сохранения формы.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final options = <(WishPriority, String)>[
      (WishPriority.later, l10n.wishPriorityLater),
      (WishPriority.normal, l10n.wishPriorityNormal),
      (WishPriority.high, l10n.wishPriorityHigh),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.wishPriorityLabel,
          style: t.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _Segment(
                  label: options[i].$2,
                  selected: value == options[i].$1,
                  enabled: enabled,
                  onTap: () => onChanged(options[i].$1),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Один сегмент селектора — pill в цветах [AppChip]: выбранный —
/// secondary/secondaryForeground, остальные — muted/textSecondary.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    final bg = selected ? colors.secondary : colors.surfaceMuted;
    final fg = selected ? colors.secondaryForeground : colors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadii.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(
                    PhosphorIconsBold.check,
                    size: AppSizes.iconSizeSm,
                    color: fg,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: t.caption.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
