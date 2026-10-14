import 'dart:io';

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
      variant: AppCardVariant.elevated,
      onTap: onTap,
      radius: AppRadii.xl,
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

/// Masonry-карточка желания для главного экрана.
///
/// Отличие от [WishGridCard] (пользовательские списки): высота
/// естественная — обложка держит исходные пропорции изображения
/// (зажаты в [coverMinHeight]…[coverMaxHeight]), под ней —
/// название до 3 строк, цена и мета-строка (бэдж «Личное»/
/// «Поделился» + название списка). Одинаковая высота карточек
/// не резервируется — сетка выравнивает колонки сама.
class WishMasonryCard extends StatelessWidget {
  const WishMasonryCard({
    super.key,
    required this.wish,
    this.onTap,
    this.highMarker = false,
    this.listTitle,
  });

  /// Нижняя/верхняя граница высоты области изображения —
  /// слишком вытянутые фото не ломают композицию.
  static const double coverMinHeight = 120;
  static const double coverMaxHeight = 280;

  /// Высота области изображения до резолва аспекта и в
  /// состояниях «нет изображения»/ошибка.
  static const double coverPlaceholderHeight = 140;

  final Wish wish;
  final VoidCallback? onTap;

  /// Ненавязчивый маркер «Очень хочу» (сердечко в углу
  /// обложки) — группировка по приоритету живёт на главном.
  final bool highMarker;

  /// Название списка, в котором лежит желание (`wish.listId`);
  /// `null` — желание личное либо список не загружен.
  final String? listTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final inList = wish.listId != null;

    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: onTap,
      radius: AppRadii.xl,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _MasonryCover(imageUrl: wish.imageDisplaySource),
              if (highMarker && wish.priority == WishPriority.high)
                const Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: _HighPriorityBadge(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            wish.title,
            style: t.title.copyWith(fontSize: 16),
            maxLines: 3,
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
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _MasonryBadge(
                label: inList ? l10n.wishBadgeShared : l10n.wishBadgePersonal,
              ),
              if (inList && listTitle != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    listTitle!,
                    style: t.caption.copyWith(color: colors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Маленький плоский бэдж («Личное»/«Поделился») в мета-строке
/// masonry-карточки.
class _MasonryBadge extends StatelessWidget {
  const _MasonryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        style: t.caption.copyWith(color: colors.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Обложка masonry-карточки: исходные пропорции изображения.
///
/// Аспект (width/height) резолвится через [ImageProvider] и
/// кэшируется в [_aspectCache] по src: после первого показа
/// повторные сборки, прокрутка и перерисовка групп получают
/// высоту сразу — карточки не прыгают. Высота области —
/// `width / aspect`, зажатая в min/max; изображение заполняет
/// область (`BoxFit.cover`) без полос, поэтому все обложки
/// начинаются у верхнего края карточки. Кроп происходит только
/// у пропорций, выходящих за допустимый диапазон высоты.
class _MasonryCover extends StatefulWidget {
  const _MasonryCover({required this.imageUrl});

  final String? imageUrl;

  /// Разрешённые аспекты по src; `0` — ошибка резолва (показываем
  /// placeholder без повторных попыток до смены src).
  static final Map<String, double> _aspectCache = {};

  @override
  State<_MasonryCover> createState() => _MasonryCoverState();
}

class _MasonryCoverState extends State<_MasonryCover> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_MasonryCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _unsubscribe();
      _aspect = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    final src = widget.imageUrl;
    if (src == null || src.isEmpty) return;
    final cached = _MasonryCover._aspectCache[src];
    if (cached != null) {
      _aspect = cached;
      return;
    }
    final ImageProvider provider = AppImage.isRemote(src)
        ? NetworkImage(src)
        : FileImage(File(src));
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final image = info.image;
      _complete(src, image.width / image.height);
    }, onError: (_, _) => _complete(src, 0));
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _complete(String src, double aspect) {
    if (_MasonryCover._aspectCache.length > 500) {
      _MasonryCover._aspectCache.clear();
    }
    _MasonryCover._aspectCache[src] = aspect;
    if (!mounted || widget.imageUrl != src) return;
    setState(() => _aspect = aspect);
  }

  /// Плоская заглушка обложки. С [height] — самостоятельный
  /// блок фиксированной высоты (нет изображения / резолв
  /// аспекта / ошибка резолва); без — заполняет родителя
  /// (error/loading состояния внутри уже размеченной области).
  Widget _placeholder({double? height}) {
    final colors = context.appColors;
    return Container(
      height: height,
      width: double.infinity,
      decoration: height != null
          ? BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            )
          : BoxDecoration(color: colors.secondary),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsRegular.gift,
        color: colors.secondaryForeground,
        size: AppSizes.iconSizeLg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg);

    final src = widget.imageUrl;
    final aspect = _aspect;
    if (src == null || src.isEmpty || aspect != null && aspect <= 0) {
      return _placeholder(height: WishMasonryCard.coverPlaceholderHeight);
    }

    if (aspect == null) {
      // Аспект ещё резолвится — держим нейтральную высоту, чтобы
      // карточка не схлопывалась и прыгнула один раз.
      return ClipRRect(
        borderRadius: radius,
        child: _placeholder(height: WishMasonryCard.coverPlaceholderHeight),
      );
    }

    final cacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) /
                2)
            .round();

    return ClipRRect(
      borderRadius: radius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Высота бокса = высота изображения при его пропорциях,
          // зажатая в min/max. Бокс всегда совпадает с размером
          // изображения по ширине — без letterbox-полос сверху и
          // снизу, фото начинается ровно у верхнего края карточки.
          // Кроп (cover) возможен только у пропорций, выходящих за
          // допустимый диапазон высоты.
          final height = (width / aspect).clamp(
            WishMasonryCard.coverMinHeight,
            WishMasonryCard.coverMaxHeight,
          );
          return SizedBox(
            width: width,
            height: height,
            child: AppImage(
              src: src,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorWidget: _placeholder(),
              loadingWidget: _placeholder(),
            ),
          );
        },
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
