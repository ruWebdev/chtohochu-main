import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/shopping_item.dart';

/// Строка позиции в списке покупок.
///
/// * тап по строке — переключает «куплено»;
/// * свайп влево — удаление ([Dismissible]);
/// * долгое нажатие — редактирование (bottom sheet снаружи).
///
/// Купленная позиция: зачёркнутый приглушённый текст + filled check.
class ShoppingItemRow extends StatelessWidget {
  const ShoppingItemRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
    this.onLongPress,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return Dismissible(
      key: ValueKey('shopping_item_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.errorSurface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Icon(
          PhosphorIconsRegular.trash,
          color: colors.error,
          size: AppSizes.iconSize,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _CheckBox(checked: item.isChecked),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: item.title,
                          style: t.body.copyWith(
                            color: item.isChecked
                                ? colors.textMuted
                                : colors.textPrimary,
                            decoration: item.isChecked
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: colors.textMuted,
                          ),
                        ),
                        if (item.quantity > 1)
                          TextSpan(
                            text: '  × ${item.quantity}',
                            style: t.secondary.copyWith(
                              color: colors.textMuted,
                              decoration: TextDecoration.none,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
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

/// Кастомный checkbox в стиле дизайн-системы.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.xs),
        border: Border.all(
          color: checked ? colors.primary : colors.textMuted,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: checked
          ? Icon(
              PhosphorIconsRegular.check,
              size: AppSizes.iconSizeSm,
              color: colors.primaryForeground,
            )
          : null,
    );
  }
}
