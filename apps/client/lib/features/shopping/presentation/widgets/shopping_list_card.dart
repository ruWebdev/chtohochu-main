import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/shopping_list.dart';

/// Карточка списка покупок на экране «Покупки».
///
/// Компактная: иконка, название, прогресс «N из M куплено» и chevron —
/// показывает, что карточка интерактивна. Не показывает сами позиции.
class ShoppingListCard extends StatelessWidget {
  const ShoppingListCard({super.key, required this.list, this.onTap});

  final ShoppingList list;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final total = list.items.length;
    final checked = list.checkedCount;

    final l10n = context.l10n;
    final (progressText, progressColor) = switch ((total, checked)) {
      (0, _) => (l10n.listEmptyHint, colors.textMuted),
      (final t0, final c0) when c0 == t0 => (l10n.listAllDone, colors.success),
      (final t0, final c0) => (l10n.listProgress(c0, t0), colors.textSecondary),
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              PhosphorIconsRegular.shoppingCart,
              color: colors.secondaryForeground,
              size: AppSizes.iconSize,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  list.title,
                  style: t.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  progressText,
                  style: t.caption.copyWith(color: progressColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            PhosphorIconsRegular.caretRight,
            size: AppSizes.iconSizeSm,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}
