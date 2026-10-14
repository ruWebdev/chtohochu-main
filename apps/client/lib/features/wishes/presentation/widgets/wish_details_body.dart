import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/wish.dart';
import '../../domain/wish_image.dart';

/// Тело деталей желания: изображение, название, цена, ссылка,
/// заметка, дата добавления.
///
/// Используется и на собственном экране деталей, и для read-only
/// просмотра желаний друзей — виджет не содержит действий владельца.
class WishDetailsBody extends StatelessWidget {
  const WishDetailsBody({
    super.key,
    required this.wish,
    this.additionalImages = const [],
    this.listTitle,
    this.inList = false,
    this.onListTap,
  });

  final Wish wish;

  /// Дополнительные изображения желания (primary — `wish.imageUrl`).
  /// Для чужих желаний не передаётся — лента не рисуется.
  final List<WishImage> additionalImages;

  /// Название списка желания для блока membership (или уже
  /// локализованное «Без списка»). `null` — блок не рисуется
  /// (просмотр чужих желаний, список ещё не загружен).
  final String? listTitle;

  /// Желание состоит в списке — влияет на иконку/стиль строки.
  final bool inList;

  /// Тап по блоку списка — открывает выбор списка.
  /// `null` — строка не интерактивна (просмотр чужих желаний).
  final VoidCallback? onListTap;

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

    // Все изображения желания: primary + additional по sortOrder.
    // Карусель со свайпом и точками (индикатор — только при >1);
    // одно фото остаётся статичным блоком, пусто — заглушка.
    final sources = [
      if (wish.imageDisplaySource != null) wish.imageDisplaySource!,
      for (final img in additionalImages)
        if (img.displaySource != null) img.displaySource!,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppImageCarousel(sources: sources, semanticLabel: wish.title),
          const SizedBox(height: AppSpacing.lg),

          Text(wish.title, style: t.title),
          if (wish.price != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatPrice(wish.price!),
              style: t.title.copyWith(color: colors.primary),
            ),
          ],
          if (listTitle != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.wishListSection,
              style: t.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xxs),
            _ListRow(title: listTitle!, inList: inList, onTap: onListTap),
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

/// Строка принадлежности списку: название списка (тап → переход
/// в него) или «Без списка» (не интерактивна).
class _ListRow extends StatelessWidget {
  const _ListRow({required this.title, required this.inList, this.onTap});

  final String title;
  final bool inList;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            inList
                ? PhosphorIconsRegular.listBullets
                : PhosphorIconsRegular.listDashes,
            size: AppSizes.iconSize,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: t.secondary.copyWith(
                color: inList ? colors.textPrimary : colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: AppSizes.iconSizeSm,
              color: colors.textMuted,
            ),
          ],
        ],
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
            color: colors.textSecondary,
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
