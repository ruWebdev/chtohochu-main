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

/// Публичный read-only просмотр shared-желания.
///
/// Не `WishDetailsPage`: нет редактирования, удаления, membership
/// и приватных полей — только public-проекция [SharedWish].
class SharedWishPage extends StatelessWidget {
  const SharedWishPage({super.key, required this.wish});

  final SharedWish wish;

  Future<void> _openLink(BuildContext context) async {
    final link = wish.link;
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    // Внешние ссылки — только http(s), без custom-scheme.
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    }
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
          _SharedImage(imageUrl: wish.imageUrl, title: wish.title),
          const SizedBox(height: AppSpacing.lg),
          if (wish.ownerName != null)
            Text(
              l10n.sharedOwnerWishes(wish.ownerName!),
              style: t.caption.copyWith(color: colors.textMuted),
            ),
          if (wish.ownerName != null) const SizedBox(height: AppSpacing.xxs),
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
            AppButton(
              label: l10n.sharedOpenProduct,
              expand: true,
              leading: const Icon(PhosphorIconsRegular.arrowSquareOut),
              onPressed: () => _openLink(context),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Изображение shared-желания через `AppImage` (network URL) с
/// gift-заглушкой — тот же паттерн, что в приватных деталях.
class _SharedImage extends StatelessWidget {
  const _SharedImage({required this.imageUrl, required this.title});

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
      child: AppImage(
        src: url,
        height: height,
        width: double.infinity,
        semanticLabel: title,
        errorWidget: placeholder,
        loadingWidget: placeholder,
      ),
    );
  }
}
