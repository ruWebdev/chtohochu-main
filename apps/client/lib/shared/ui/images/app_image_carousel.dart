import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_sizes.dart';
import '../../../app/theme/app_spacing.dart';
import 'app_image.dart';
import 'fullscreen_image_viewer.dart';

/// Горизонтальный слайдер изображений со свайпом и точечным
/// индикатором под изображением (только когда sources > 1).
///
/// Одно изображение — статичный блок без индикатора; пустой
/// список — нейтральная заглушка. Тап по странице открывает
/// [showAppImageViewer]. Изображения вписываются без обрезания
/// (`BoxFit.contain`) на muted-подложке — пропорции сохраняются
/// при любом aspect-ratio.
class AppImageCarousel extends StatefulWidget {
  const AppImageCarousel({
    super.key,
    required this.sources,
    this.height = 200,
    this.semanticLabel,
    this.placeholderIcon = PhosphorIconsRegular.gift,
  });

  /// Источники изображений (local path или URL) в порядке показа.
  final List<String> sources;

  /// Высота слайдера.
  final double height;

  /// Accessibility-лейбл изображений.
  final String? semanticLabel;

  /// Иконка заглушки при пустом наборе / ошибке загрузки.
  final IconData placeholderIcon;

  @override
  State<AppImageCarousel> createState() => _AppImageCarouselState();
}

class _AppImageCarouselState extends State<AppImageCarousel> {
  late final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.circular(AppRadii.xl);
    final sources = widget.sources;

    final placeholder = Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(
        widget.placeholderIcon,
        size: AppSizes.iconSizeLg * 2,
        color: colors.textMuted,
      ),
    );

    if (sources.isEmpty) return placeholder;

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: radius,
            child: Container(
              color: colors.surfaceMuted,
              child: PageView.builder(
                controller: _controller,
                itemCount: sources.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final src = sources[index];
                  return GestureDetector(
                    // Тап открывает полноэкранный просмотр с зумом.
                    onTap: () => showAppImageViewer(
                      context,
                      src: src,
                      semanticLabel: widget.semanticLabel,
                    ),
                    child: AppImage(
                      src: src,
                      height: widget.height,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      semanticLabel: widget.semanticLabel,
                      errorWidget: placeholder,
                      loadingWidget: placeholder,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Индикатор — только при нескольких изображениях.
        if (sources.length > 1) ...[
          const SizedBox(height: AppSpacing.xs),
          _DotsIndicator(count: sources.length, current: _page),
        ],
      ],
    );
  }
}

/// Точечный индикатор страниц карусели — нейтральные цвета темы.
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? colors.textSecondary : colors.border,
            ),
          ),
      ],
    );
  }
}
