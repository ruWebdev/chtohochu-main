import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Расширение результата обработки.
///
/// Обычные фотографии нормализуются в JPEG (камера может отдать
/// HEIC — на backend он не уходит как есть). PNG/WebP сохраняют
/// формат: возможная прозрачность не портится конвертацией в JPEG.
String resolveTargetExtension(String sourcePath) {
  switch (sourcePath.split('.').last.toLowerCase()) {
    case 'png':
      return 'png';
    case 'webp':
      return 'webp';
    default:
      return 'jpg';
  }
}

/// Единый image-processing pipeline перед попаданием файла в
/// persistent storage и upload (ADR-015):
///
/// ```
/// original → decode → EXIF-ориентация → resize ≤2048 → encode
///          → JPEG quality 82 (или исходный png/webp)
/// ```
///
/// Платформенный код изолирован за интерфейсом — тесты подменяют
/// реализацию через [mediaImageProcessorProvider].
abstract interface class MediaImageProcessor {
  /// Обработать [sourcePath] и записать результат в [targetDir]
  /// под новым uuid-именем. Возвращает готовый файл.
  Future<File> process(String sourcePath, Directory targetDir);
}

/// Реализация на `flutter_image_compress`: EXIF-rotation применяется
/// автоматически (`autoCorrectionAngle`), ресайз — уменьшение до
/// bounding box 2048×2048 без upscale.
class FlutterCompressMediaImageProcessor implements MediaImageProcessor {
  static const _uuid = Uuid();

  /// Production-политика обычных фотографий.
  static const maxDimension = 2048;
  static const jpegQuality = 82;

  @override
  Future<File> process(String sourcePath, Directory targetDir) async {
    final ext = resolveTargetExtension(sourcePath);
    final format = switch (ext) {
      'png' => CompressFormat.png,
      'webp' => CompressFormat.webp,
      _ => CompressFormat.jpeg,
    };

    final bytes = await FlutterImageCompress.compressWithFile(
      sourcePath,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: jpegQuality,
      format: format,
      autoCorrectionAngle: true,
      keepExif: false,
    );
    if (bytes == null) {
      // Неподдерживаемый формат — сохраняем как есть, upload
      // дальше решает backend (Content-Type валидируется).
      return File(sourcePath).copy('${targetDir.path}/${_uuid.v4()}.$ext');
    }

    final file = File('${targetDir.path}/${_uuid.v4()}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

final mediaImageProcessorProvider = Provider<MediaImageProcessor>(
  (ref) => FlutterCompressMediaImageProcessor(),
);
