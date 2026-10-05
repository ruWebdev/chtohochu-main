import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Локальная структура media-хранилища (ADR-015):
///
/// ```
/// Documents/media/
///   wishes/    — фотографии желаний (primary + additional)
///   avatars/   — аватары (заложено, UI позже)
///   shopping/  — изображения списков покупок (заложено, UI позже)
/// ```
///
/// Persistent Documents — не cache: файлы переживают очистку кэша ОС
/// и нужны до момента успешного upload в S3.
abstract final class MediaPaths {
  static Future<Directory> wishesDir() => _dir('wishes');

  static Future<Directory> avatarsDir() => _dir('avatars');

  static Future<Directory> shoppingDir() => _dir('shopping');

  /// Путь каталога без создания — для call-sites с собственным
  /// FS-доступом (например, one-time миграция с sync IO).
  static Future<String> wishesDirPath() => _path('wishes');

  static Future<Directory> _dir(String name) async {
    final dir = Directory(await _path(name));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<String> _path(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/media/$name';
  }

  /// Content-Type по расширению файла — совпадает с backend-whitelist
  /// `media.allowed_content_types`. null → тип неизвестен/не разрешён.
  static String? contentTypeForPath(String path) {
    switch (path.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }
}
