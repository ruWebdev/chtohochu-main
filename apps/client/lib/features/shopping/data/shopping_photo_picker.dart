import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_image_processor.dart';
import '../../../core/media/media_paths.dart';
import '../../wishes/data/wish_photo_picker.dart';

/// Источник фото для позиций списка покупок.
///
/// Реализует общий контракт [WishPhotoPicker]: выбранный файл
/// проходит [MediaImageProcessor] (ориентация, ресайз, JPEG/PNG/WebP
/// по политике ADR-015) и сохраняется в `Documents/media/shopping/` —
/// persistent storage, переживающий очистку cache.
class ImagePickerShoppingPhotoPicker implements WishPhotoPicker {
  ImagePickerShoppingPhotoPicker(this._processor);

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
    final dir = await MediaPaths.shoppingDir();
    return (await _processor.process(sourcePath, dir)).path;
  }
}

/// Провайдер источника фото позиций — реальная камера/галерея
/// на устройстве, в тестах подменяется фейком через `overrides`.
final shoppingPhotoPickerProvider = Provider<WishPhotoPicker>(
  (ref) =>
      ImagePickerShoppingPhotoPicker(ref.read(mediaImageProcessorProvider)),
);
