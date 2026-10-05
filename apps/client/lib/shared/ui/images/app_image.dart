import 'dart:io';

import 'package:flutter/material.dart';

/// Изображение по строковому источнику: сетевой URL или локальный файл.
///
/// Желание может хранить как `https://…`-ссылку, так и путь к фото,
/// снятому камерой (`/data/…/wish_photos/xx.jpg`). Виджет выбирает
/// источник по схеме: `http(s)` — network, иначе — file.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.semanticLabel,
    this.errorWidget,
    this.loadingWidget,
  });

  /// URL изображения или путь к локальному файлу.
  final String src;

  final double? width;
  final double? height;
  final BoxFit fit;

  /// Подсказка размеру декодирования (только для network).
  final int? cacheWidth;

  /// Accessibility-лейбл изображения.
  final String? semanticLabel;

  /// Виджет при ошибке загрузки/отсутствии файла.
  final Widget? errorWidget;

  /// Виджет на время загрузки (только для network).
  final Widget? loadingWidget;

  /// Источник — сетевой URL?
  static bool isRemote(String src) =>
      src.startsWith('http://') || src.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ?? const SizedBox.shrink();

    if (!isRemote(src)) {
      return Image.file(
        File(src),
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return Image.network(
      src,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: loadingWidget == null
          ? null
          : (context, child, progress) {
              if (progress == null) return child;
              return loadingWidget!;
            },
    );
  }
}
