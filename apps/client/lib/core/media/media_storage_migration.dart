import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../services/preferences_service.dart';
import 'media_paths.dart';

/// One-time миграция `Documents/wish_photos/` → `Documents/media/wishes/`
/// (ADR-015, общая media-структура).
///
/// Файлы перемещаются (не копируются — дубликатов нет), затем пути
/// в `wishes.image_url` и `wish_images.local_path` переписываются
/// на новые. Пути переписываются для всех аккаунтов: директория
/// одна на устройство. Идемпотентна — флаг `media_dirs_migrated`;
/// файл, уже лежащий в `media/wishes/`, просто пропускается.
class MediaStorageMigration {
  MediaStorageMigration(this._db, this._prefs);

  final AppDatabase _db;
  final PreferencesService _prefs;

  static const _legacyDirName = 'wish_photos';

  Future<void> migrate() async {
    if (_prefs.isMediaDirsMigrated()) return;

    final docs = await getApplicationDocumentsDirectory();
    final legacy = Directory('${docs.path}/$_legacyDirName');

    // Синхронный FS-доступ осознанно: миграция one-time на десятки
    // файлов при старте, а async-IO невозможен в зоне widget-тестов
    // (FakeAsync захватывает колбэки dart:io → deadlock).
    if (legacy.existsSync()) {
      final target = Directory(await MediaPaths.wishesDirPath())
        ..createSync(recursive: true);
      for (final entity in legacy.listSync()) {
        if (entity is! File) continue;
        final name = entity.path.split('/').last;
        final targetPath = '${target.path}/$name';
        if (!File(targetPath).existsSync()) {
          try {
            entity.renameSync(targetPath);
          } on FileSystemException {
            // rename через файловые системы может не сработать —
            // копируем и удаляем исходник.
            try {
              entity.copySync(targetPath);
              entity.deleteSync();
            } on FileSystemException {
              // Файл недоступен — пропускаем, путь не переписываем.
              continue;
            }
          }
        }
        await _rewritePath(entity.path, targetPath);
      }
      try {
        legacy.deleteSync();
      } on FileSystemException {
        // Каталог не пуст/недоступен — не критично.
      }
    }

    await _prefs.setMediaDirsMigrated();
  }

  /// Переписать один путь во всех image-полях обеих таблиц.
  Future<void> _rewritePath(String from, String to) async {
    await _db.transaction(() async {
      await (_db.update(_db.wishes)..where((w) => w.imageUrl.equals(from)))
          .write(WishesCompanion(imageUrl: Value(to)));
      await (_db.update(_db.wishImages)..where((i) => i.localPath.equals(from)))
          .write(WishImagesCompanion(localPath: Value(to)));
    });
  }
}

final mediaStorageMigrationProvider = Provider<MediaStorageMigration>(
  (ref) => MediaStorageMigration(
    ref.read(appDatabaseProvider),
    ref.read(preferencesServiceProvider),
  ),
);
