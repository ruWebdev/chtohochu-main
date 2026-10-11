import 'dart:io';

import 'package:chtohochu/shared/ui/images/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Минимальный валидный PNG (1×1).
final _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

Widget _wrap(String src) => MaterialApp(
  home: Scaffold(body: AppImage(src: src, width: 10, height: 10)),
);

FileImage? _fileProvider(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return image.image is FileImage ? image.image as FileImage : null;
}

void main() {
  late File localFile;

  setUp(() {
    localFile = File(
      '${Directory.systemTemp.path}/app_image_test_${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(_png);
  });

  tearDown(() {
    if (localFile.existsSync()) localFile.deleteSync();
  });

  testWidgets('local path renders FileImage', (tester) async {
    await tester.pumpWidget(_wrap(localFile.path));
    expect(_fileProvider(tester)!.file.path, localFile.path);
  });

  testWidgets('remote-only src uses NetworkImage directly', (tester) async {
    await tester.pumpWidget(_wrap('https://cdn.test/a.png'));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
  });

  testWidgets('remote → local switch renders the new local file', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap('https://cdn.test/a.png'));
    await tester.pumpWidget(_wrap(localFile.path));
    expect(_fileProvider(tester)!.file.path, localFile.path);
  });
}
