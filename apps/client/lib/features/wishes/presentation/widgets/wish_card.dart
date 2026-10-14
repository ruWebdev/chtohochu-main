import 'package:flutter/material.dart';
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
          _WishThumb(imageUrl: wish.imageDisplaySource),
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

/// Вертикальная карточка желания для двухколоночной сетки Home.
///
/// Flat-карточка без границы: белая поверхность, радиус 16,
/// внутренние отступы со всех сторон. Обложка занимает всю
/// внутреннюю ширину с аспектом 1:1 и радиусом 12, под ней —
/// название и цена. Действия не меняются — тап открывает
/// детали, long-press — контекстные действия.
class WishGridCard extends StatelessWidget {
  const WishGridCard({
    super.key,
    required this.wish,
    this.onTap,
    this.onLongPress,
    this.highMarker = false,
  });

  /// Аспект обложки (ширина : высота) — всегда квадрат.
  static const double coverAspectRatio = 1;

  final Wish wish;
  final VoidCallback? onTap;

  /// Long-press — контекстные действия над карточкой (например,
  /// «Убрать из списка» на странице списка). `null` — без жеста.
  final VoidCallback? onLongPress;

  /// Ненавязчивый маркер «Очень хочу» (сердечко в углу обложки)
  /// — включается на главном экране, где живёт группировка
  /// по приоритету. В списках выключен по умолчанию.
  final bool highMarker;

  /// Высота карточки для заданной ширины колонки сетки:
  /// вертикальные отступы + обложка по [coverAspectRatio] +
  /// инфо-блок (gap 12 + строка заголовка/рейтинга 16/24 → 24 +
  /// gap 4 + подзаголовок 13/18 → 18 + gap 16 + строка
  /// цены/кнопки → 36). Обложка зависит от ширины, поэтому
  /// extent вычисляется, а не задаётся константой.
  static double extentForColumnWidth(double columnWidth) {
    final cover = (columnWidth - AppSpacing.sm * 2) / coverAspectRatio;
    const text =
        AppSpacing.sm + 24.0 + AppSpacing.xxs + 18.0 + AppSpacing.md + 36.0;
    return AppSpacing.sm * 2 + cover + text;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: onTap,
      onLongPress: onLongPress,
      radius: AppRadii.xl,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _WishCover(imageUrl: wish.imageDisplaySource),
              if (highMarker && wish.priority == WishPriority.high)
                const Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: _HighPriorityBadge(),
                ),
            ],
          ),
          // Инфо-блок: заголовок + mock-рейтинг, подзаголовок.
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  wish.title,
                  style: t.title.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Mock-рейтинг: данных в модели пока нет.
              Icon(
                PhosphorIconsFill.star,
                size: AppSizes.iconSizeSm,
                color: colors.warning,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                '4.8',
                style: t.secondary.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Mock-подзаголовок (источник/категория).
          Text(
            l10n.wishCardSubtitle,
            style: t.caption.copyWith(color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Цена + mock-кнопка действия.
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (wish.price != null)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          formatPrice(wish.price!),
                          style: t.title.copyWith(fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Mock старой цены: поля в модели нет.
                      Flexible(
                        child: Text(
                          formatPrice((wish.price! * 1.25).round()),
                          style: t.secondary.copyWith(
                            color: colors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: AppSpacing.xs),
              Material(
                color: colors.primary,
                borderRadius: BorderRadius.circular(AppRadii.full),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      l10n.wishCardAction,
                      style: t.secondary.copyWith(
                        color: colors.primaryForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Маркер «Очень хочу» — маленькое сердечко на контрастном
/// кружке в углу обложки. Flat: без тени, только fill-поверхность.
class _HighPriorityBadge extends StatelessWidget {
  const _HighPriorityBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsFill.heart,
        size: 13,
        color: colors.accentFriends,
      ),
    );
  }
}

/// Обложка grid-карточки: изображение по ссылке во всю внутреннюю
/// ширину карточки (аспект 1:1, радиус 12, crop) или нейтральная
/// иконка.
class _WishCover extends StatelessWidget {
  const _WishCover({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.circular(AppRadii.lg);

    final placeholder = Container(
      decoration: BoxDecoration(color: colors.secondary, borderRadius: radius),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsRegular.gift,
        color: colors.secondaryForeground,
        size: AppSizes.iconSizeLg,
      ),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return AspectRatio(
        aspectRatio: WishGridCard.coverAspectRatio,
        child: placeholder,
      );
    }

    final cacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) /
                2)
            .round();

    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: WishGridCard.coverAspectRatio,
        child: AppImage(
          src: url,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: cacheWidth,
          errorWidget: placeholder,
          loadingWidget: placeholder,
        ),
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
