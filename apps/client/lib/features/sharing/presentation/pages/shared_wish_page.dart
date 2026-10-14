import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
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
          // Primary + доп.изображения — та же карусель, что
          // в приватных деталях (tap → fullscreen, точки при >1).
          AppImageCarousel(
            sources: [
              if (wish.imageUrl != null && wish.imageUrl!.isNotEmpty)
                wish.imageUrl!,
              ...wish.images,
            ],
            semanticLabel: wish.title,
          ),
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

