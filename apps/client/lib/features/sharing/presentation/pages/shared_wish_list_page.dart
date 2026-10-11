import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/shared_content.dart';

/// Публичный read-only просмотр shared-списка желаний.
///
/// Не `WishListPage`: без редактирования/удаления/membership —
/// только public-проекция [SharedWishList]. Количество желаний
/// ограничивает backend (200), клиентский лимит не добавляем.
class SharedWishListPage extends StatelessWidget {
  const SharedWishListPage({super.key, required this.list});

  final SharedWishList list;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingHorizontal,
        vertical: AppSpacing.sm,
      ),
      children: [
        if (list.ownerName != null)
          Text(
            list.ownerName!,
            style: t.caption.copyWith(color: colors.textMuted),
          ),
        if (list.ownerName != null) const SizedBox(height: AppSpacing.xxs),
        Text(list.title, style: t.title),
        const SizedBox(height: AppSpacing.lg),
        if (list.wishes.isEmpty)
          AppEmptyState(
            icon: const Icon(PhosphorIconsRegular.listDashes),
            title: l10n.wishListEmptyTitle,
            description: l10n.sharedListEmptyDescription,
          )
        else
          for (final wish in list.wishes) ...[
            _SharedWishCard(wish: wish),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Карточка желания внутри публичного списка: thumb, title, price,
/// опциональная ссылка «Открыть товар». Read-only, без действий
/// владельца.
class _SharedWishCard extends StatelessWidget {
  const _SharedWishCard({required this.wish});

  final SharedWish wish;

  Future<void> _openLink() async {
    final link = wish.link;
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Открытие ссылки best-effort: если система не смогла —
      // молча остаёмся на viewer'е.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    const thumb = AppSizes.wishThumbSize;
    final radius = BorderRadius.circular(AppRadii.md);

    final placeholder = Container(
      width: thumb,
      height: thumb,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsRegular.gift,
        size: AppSizes.iconSize,
        color: colors.textMuted,
      ),
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: radius,
            child: wish.imageUrl == null || wish.imageUrl!.isEmpty
                ? placeholder
                : AppImage(
                    src: wish.imageUrl!,
                    width: thumb,
                    height: thumb,
                    semanticLabel: wish.title,
                    errorWidget: placeholder,
                    loadingWidget: placeholder,
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wish.title,
                  style: t.secondary.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (wish.price != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatPrice(wish.price!),
                    style: t.caption.copyWith(color: colors.textSecondary),
                  ),
                ],
                if (wish.link != null && wish.link!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  GestureDetector(
                    onTap: _openLink,
                    child: Text(
                      l10n.sharedOpenProduct,
                      style: t.caption.copyWith(color: colors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
