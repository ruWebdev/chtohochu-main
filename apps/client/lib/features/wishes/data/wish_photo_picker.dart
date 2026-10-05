import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_image_processor.dart';
import '../../../core/media/media_paths.dart';

/// Источник фото для быстрого добавления желания.
///
/// Абстракция над `image_picker`: presentation-слой не зависит от
/// платформенного плагина, а тесты подменяют реализацию через
/// [wishPhotoPickerProvider].
abstract interface class WishPhotoPicker {
  /// Открыть камеру и вернуть путь к сохранённому файлу,
  /// либо `null`, если пользователь отменил съёмку.
  Future<String?> capture();

  /// Открыть системный выбор фото и вернуть пути к сохранённым
  /// файлам. Пустой список — пользователь отменил выбор.
  Future<List<String>> pickFromGallery();
}

/// Реализация поверх `image_picker`: камера и системная галерея.
///
/// Выбранный файл проходит [MediaImageProcessor] (ориентация,
/// ресайз, JPEG/PNG/WebP по политике ADR-015) и сохраняется в
/// `Documents/media/wishes/` — persistent storage, переживающий
/// очистку cache и ожидание upload.
class ImagePickerWishPhotoPicker implements WishPhotoPicker {
  ImagePickerWishPhotoPicker(this._processor);

  final MediaImageProcessor _processor;

  @override
  Future<String?> capture() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return null;
    return persist(picked.path);
  }

  @override
  Future<List<String>> pickFromGallery() async {
    final picked = await ImagePicker().pickMultiImage();
    return [for (final file in picked) await persist(file.path)];
  }

  /// Обработать и сохранить файл в постоянное media-хранилище.
  Future<String> persist(String sourcePath) async {
    final dir = await MediaPaths.wishesDir();
    return (await _processor.process(sourcePath, dir)).path;
  }
}

/// Провайдер источника фото — реальная камера/галерея на устройстве,
/// в тестах подменяется фейком через `overrides`.
final wishPhotoPickerProvider = Provider<WishPhotoPicker>(
  (ref) => ImagePickerWishPhotoPicker(ref.read(mediaImageProcessorProvider)),
);

/// Удалить локальные файлы фотографий (best-effort).
///
/// Вызывается при физическом удалении желания/аккаунта, чтобы
/// в `Documents/media/` не копились orphan-файлы.
/// Ошибки игнорируются: файл может быть уже удалён или
/// недоступен — это не должно ломать основную операцию.
Future<void> deleteWishPhotoFiles(Iterable<String> paths) async {
  for (final path in paths) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      continue;
    }
    try {
      // Sync IO: вызывается и из widget-тестов (FakeAsync-зона,
      // async dart:io не завершается).
      File(path).deleteSync();
    } catch (_) {
      // best-effort cleanup.
    }
  }
}
