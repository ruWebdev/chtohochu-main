import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/wish.dart';

/// Тело деталей желания: изображение, название, цена, ссылка,
/// заметка, дата добавления.
///
/// Используется и на собственном экране деталей, и для read-only
/// просмотра желаний друзей — виджет не содержит действий владельца.
class WishDetailsBody extends StatelessWidget {
  const WishDetailsBody({super.key, required this.wish});

  final Wish wish;

  static Future<void> _copyLink(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.linkCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WishImage(imageUrl: wish.imageUrl, title: wish.title),
          const SizedBox(height: AppSpacing.lg),

          Text(wish.title, style: t.title),
          if (wish.price != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatPrice(wish.price!),
              style: t.title.copyWith(color: colors.primary),
            ),
          ],
          if (wish.link != null && wish.link!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _LinkRow(link: wish.link!, onCopyLink: _copyLink),
          ],
          if (wish.description != null && wish.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.noteSection,
              style: t.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(wish.description!, style: t.body),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.wishAddedOn(formatDate(wish.createdAt, l10n.localeName)),
            style: t.captionSmall.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Изображение желания с заглушкой.
///
/// Если `imageUrl` пустой или картинка не загрузилась — нейтральный
/// блок с иконкой подарка вместо «битого» изображения.
class _WishImage extends StatelessWidget {
  const _WishImage({required this.imageUrl, required this.title});

  final String? imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const height = 200.0;
    final radius = BorderRadius.circular(AppRadii.xl);

    final placeholder = Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsRegular.gift,
        size: AppSizes.iconSizeLg * 2,
        color: colors.textMuted,
      ),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: title,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder;
        },
      ),
    );
  }
}

/// Строка со ссылкой: тап копирует в буфер обмена.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.onCopyLink});

  final String link;
  final Future<void> Function(BuildContext, String) onCopyLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: () => onCopyLink(context, link),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.link,
            size: AppSizes.iconSize,
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              link,
              style: t.secondary.copyWith(color: colors.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            PhosphorIconsRegular.copy,
            size: AppSizes.iconSizeSm,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}
