import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/ui/ui.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/wish.dart';

/// Карточка желания в списке.
///
/// Компактная: миниатюра (изображение или иконка), название,
/// цена (если задана), chevron — показывает, что карточка интерактивна.
/// Удаление и редактирование живут на экране деталей.
class WishCard extends StatelessWidget {
  const WishCard({super.key, required this.wish, this.onTap});

  final Wish wish;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          _WishThumb(imageUrl: wish.imageUrl),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  wish.title,
                  style: t.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (wish.price != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatPrice(wish.price!),
                    style: t.secondary.copyWith(color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

/// Миниатюра желания: изображение по ссылке или нейтральная иконка.
class _WishThumb extends StatelessWidget {
  const _WishThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const size = AppSizes.wishThumbSize;
    final radius = BorderRadius.circular(AppRadii.md);

    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.secondary, borderRadius: radius),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsRegular.gift,
        color: colors.secondaryForeground,
        size: AppSizes.iconSize,
      ),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) return placeholder;

    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return ClipRRect(
      borderRadius: radius,
      child: AppImage(
        src: url,
        width: size,
        height: size,
        cacheWidth: cacheWidth,
        errorWidget: placeholder,
        loadingWidget: placeholder,
      ),
    );
  }
}
