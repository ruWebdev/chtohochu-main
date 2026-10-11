import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/wish_list.dart';
import '../utils/formatters.dart';

/// Карточка списка желаний на Home — сетка «Мои списки».
///
/// Визуально отличается от карточки желания: elevated-поверхность
/// и иконка-значок вместо миниатюры изображения. Показывает только
/// название и число желаний — меню/обложек/sharing пока нет.
class WishListCard extends StatelessWidget {
  const WishListCard({super.key, required this.list, this.onTap});

  final WishList list;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              PhosphorIconsRegular.listBullets,
              color: colors.secondaryForeground,
              size: AppSizes.iconSizeSm,
            ),
          ),
          const Spacer(),
          Text(
            list.title,
            style: t.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            wishesCountLabel(context.l10n, list.wishCount),
            style: t.caption.copyWith(color: colors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
