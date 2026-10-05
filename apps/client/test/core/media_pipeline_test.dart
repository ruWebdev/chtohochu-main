import 'dart:io';

import 'package:chtohochu/core/media/media_image_processor.dart';
import 'package:chtohochu/core/media/media_paths.dart';
import 'package:chtohochu/features/wishes/data/wish_photo_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Media pipeline (ADR-015): форматная политика и persist-этап —
/// что файл проходит processor и ложится в `Documents/media/wishes/`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('docs_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  group('format policy', () {
    test('обычные фото → jpeg; png/webp сохраняют формат', () {
      expect(resolveTargetExtension('/x/photo.jpg'), 'jpg');
      expect(resolveTargetExtension('/x/photo.jpeg'), 'jpg');
      expect(resolveTargetExtension('/x/photo.heic'), 'jpg');
      expect(resolveTargetExtension('/x/screenshot.png'), 'png');
      expect(resolveTargetExtension('/x/sticker.webp'), 'webp');
    });

    test('content type по расширению, неразрешённый → null', () {
      expect(MediaPaths.contentTypeForPath('/x/a.jpg'), 'image/jpeg');
      expect(MediaPaths.contentTypeForPath('/x/a.png'), 'image/png');
      expect(MediaPaths.contentTypeForPath('/x/a.webp'), 'image/webp');
      expect(MediaPaths.contentTypeForPath('/x/a.gif'), isNull);
      expect(MediaPaths.contentTypeForPath('/x/a.bin'), isNull);
    });
  });

  group('persist в media/wishes', () {
    test('picker прогоняет файл через processor и кладёт в '
        'Documents/media/wishes/', () async {
      final source = File('${docs.path}/source.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final processor = _RecordingProcessor();
      final picker = ImagePickerWishPhotoPicker(processor);

      final path = await picker.persist(source.path);

      // Processor вызван ровно один раз, результат — в media/wishes.
      expect(processor.sources, [source.path]);
      expect(path, contains('/media/wishes/'));
      expect(File(path).existsSync(), isTrue);
      // Исходный каталог legacy — не используется.
      expect(path, isNot(contains('wish_photos')));
    });
  });
}

class _RecordingProcessor implements MediaImageProcessor {
  final sources = <String>[];

  @override
  Future<File> process(String sourcePath, Directory targetDir) async {
    sources.add(sourcePath);
    final out = File('${targetDir.path}/processed.jpg');
    await out.writeAsBytes(await File(sourcePath).readAsBytes());
    return out;
  }
}
