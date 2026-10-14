import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/shopping_item.dart';

/// Строка позиции в списке покупок — flat-карточка.
///
/// Компоновка: [фото/placeholder] — [название] — [checkbox «куплено»].
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
          color: colors.error,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: const Icon(
          PhosphorIconsRegular.trash,
          color: Colors.white,
          size: AppSizes.iconSize,
        ),
      ),
      child: AppCard(
        variant: AppCardVariant.elevated,
        radius: AppRadii.lg,
        onTap: onToggle,
        onLongPress: onLongPress,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _ItemThumbnail(imagePath: item.imageLocalPath),
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
            const SizedBox(width: AppSpacing.sm),
            _CheckBox(checked: item.isChecked),
          ],
        ),
      ),
    );
  }
}

/// Превью фото позиции или ненавязчивый placeholder на его месте —
/// одинаковая геометрия для всех строк.
class _ItemThumbnail extends StatelessWidget {
  const _ItemThumbnail({required this.imagePath});

  static const _size = 40.0;

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final placeholder = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: colors.accentShopping.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsRegular.basket,
        color: colors.accentShopping,
        size: AppSizes.iconSize,
      ),
    );

    if (imagePath == null) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: _size,
        height: _size,
        child: AppImage(
          src: imagePath!,
          fit: BoxFit.cover,
          errorWidget: placeholder,
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
        color: checked ? colors.accentShopping : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.xs),
        border: Border.all(
          color: checked ? colors.accentShopping : colors.border,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: checked
          ? const Icon(
              PhosphorIconsRegular.check,
              size: AppSizes.iconSizeSm,
              color: Colors.white,
            )
          : null,
    );
  }
}
