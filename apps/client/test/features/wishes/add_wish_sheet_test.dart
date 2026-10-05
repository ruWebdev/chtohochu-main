import 'dart:io';

import 'package:chtohochu/features/wishes/data/wish_photo_picker.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/add_wish_sheet.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:chtohochu/shared/ui/navigation/app_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Map<String, Object> _authPrefs() => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
};

/// Фейковый источник фото: камера и галерея возвращают пути
/// к реальным временным файлам (валидный PNG 1×1).
class _FakePhotoPicker implements WishPhotoPicker {
  _FakePhotoPicker({
    this.cancelCamera = false,
    this.galleryCount = 0,
    this.cancelGallery = false,
  });

  /// Отмена камеры → `capture()` вернёт `null`.
  final bool cancelCamera;

  /// Сколько файлов «выбрала» галерея.
  final int galleryCount;

  /// Отмена галереи → `pickFromGallery()` вернёт `[]`.
  final bool cancelGallery;

  int cameraCalls = 0;
  int galleryCalls = 0;
  int _count = 0;

  /// Минимальный валидный PNG (1×1, прозрачный).
  static const _png = <int>[
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

  String _nextPath() {
    _count++;
    final file = File('${Directory.systemTemp.path}/fake_photo_$_count.png');
    // Синхронная запись: в widget-тесте FakeAsync-зона
    // не дожидается реального async IO внутри pumpAndSettle.
    file.writeAsBytesSync(_png);
    return file.path;
  }

  @override
  Future<String?> capture() {
    cameraCalls++;
    return Future.value(cancelCamera ? null : _nextPath());
  }

  @override
  Future<List<String>> pickFromGallery() {
    galleryCalls++;
    if (cancelGallery) return Future.value(const []);
    return Future.value([for (var i = 0; i < galleryCount; i++) _nextPath()]);
  }
}

Future<void> _openSheet(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  final widget = await createTestApp(
    preferences: _authPrefs(),
    secureStorage: {'access_token': 'mock_token'},
    overrides: overrides,
  );
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomBar),
      matching: find.byTooltip('Добавить желание'),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _addButton => find.widgetWithText(AppButton, 'Добавить');
Finder get _photoTiles => find.byTooltip('Удалить фото');

void main() {
  testWidgets('Sheet opens: title, close, field, URL/Камера/Галерея', (
    tester,
  ) async {
    await _openSheet(tester);

    expect(find.byType(AddWishSheet), findsOneWidget);
    expect(find.text('Добавить желание'), findsOneWidget);
    expect(find.byTooltip('Закрыть'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('URL'), findsOneWidget);
    expect(find.text('Камера'), findsOneWidget);
    expect(find.text('Галерея'), findsOneWidget);
    expect(tester.widget<AppButton>(_addButton).enabled, isFalse);
  });

  testWidgets('Text only → add enabled → wish appears in list', (tester) async {
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'Новые наушники Sony');
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(_addButton).enabled, isTrue);

    await tester.tap(_addButton);
    await tester.pumpAndSettle();

    // Sheet закрылся, желание видно через reactive local flow.
    expect(find.byType(AddWishSheet), findsNothing);
    expect(find.text('Новые наушники Sony'), findsOneWidget);
  });

  testWidgets('+URL reveals link field; URL alone creates wish', (
    tester,
  ) async {
    await _openSheet(tester);

    await tester.tap(find.text('URL'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(
      find.byType(TextField).at(1),
      'market.yandex.ru/product--naushniki-sony',
    );
    await tester.pumpAndSettle();

    await tester.tap(_addButton);
    await tester.pumpAndSettle();

    expect(find.byType(AddWishSheet), findsNothing);
    // Без названия — заголовок желания = хост ссылки.
    expect(find.text('market.yandex.ru'), findsOneWidget);
  });

  testWidgets('Invalid URL → error, wish not created', (tester) async {
    await _openSheet(tester);

    await tester.tap(find.text('URL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'просто текст');
    await tester.pumpAndSettle();

    await tester.tap(_addButton);
    await tester.pumpAndSettle();

    expect(find.text('Некорректная ссылка'), findsOneWidget);
    expect(find.byType(AddWishSheet), findsOneWidget);
  });

  testWidgets('Camera: photo tile appears, second photo, remove, add', (
    tester,
  ) async {
    final picker = _FakePhotoPicker();
    await _openSheet(
      tester,
      overrides: [wishPhotoPickerProvider.overrideWithValue(picker)],
    );

    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();

    expect(picker.cameraCalls, 1);
    expect(picker.galleryCalls, 0);
    expect(_photoTiles, findsOneWidget);
    // Текст не обязателен — фото само по себе контент.
    expect(tester.widget<AppButton>(_addButton).enabled, isTrue);

    // Повторная съёмка добавляет вторую плитку, первая не исчезает.
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    expect(_photoTiles, findsNWidgets(2));

    // Удалить первое → остаётся одно.
    await tester.tap(_photoTiles.first);
    await tester.pumpAndSettle();
    expect(_photoTiles, findsOneWidget);

    await tester.tap(_addButton);
    await tester.pumpAndSettle();

    expect(find.byType(AddWishSheet), findsNothing);
    // Фото без текста → «Фотография».
    expect(find.text('Фотография'), findsOneWidget);
  });

  testWidgets('Gallery: multi-select adds tiles, camera not called', (
    tester,
  ) async {
    final picker = _FakePhotoPicker(galleryCount: 2);
    await _openSheet(
      tester,
      overrides: [wishPhotoPickerProvider.overrideWithValue(picker)],
    );

    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();

    expect(picker.galleryCalls, 1);
    expect(picker.cameraCalls, 0);
    expect(_photoTiles, findsNWidgets(2));
    expect(tester.widget<AppButton>(_addButton).enabled, isTrue);
  });

  testWidgets('Camera cancel changes nothing', (tester) async {
    final picker = _FakePhotoPicker(cancelCamera: true);
    await _openSheet(
      tester,
      overrides: [wishPhotoPickerProvider.overrideWithValue(picker)],
    );

    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();

    expect(picker.cameraCalls, 1);
    expect(_photoTiles, findsNothing);
    expect(find.byType(AddWishSheet), findsOneWidget);
    expect(tester.widget<AppButton>(_addButton).enabled, isFalse);
  });

  testWidgets('Gallery cancel changes nothing', (tester) async {
    final picker = _FakePhotoPicker(cancelGallery: true);
    await _openSheet(
      tester,
      overrides: [wishPhotoPickerProvider.overrideWithValue(picker)],
    );

    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();

    expect(picker.galleryCalls, 1);
    expect(_photoTiles, findsNothing);
    expect(find.byType(AddWishSheet), findsOneWidget);
    expect(tester.widget<AppButton>(_addButton).enabled, isFalse);
  });

  testWidgets('Multiple photos: first → primary, rest persist in wish_images', (
    tester,
  ) async {
    const ownerId = 'user-a';
    final db = createTestDatabase();
    addTearDown(db.close);
    final picker = _FakePhotoPicker(galleryCount: 2);
    final widget = await createTestApp(
      preferences: _authPrefs(),
      secureStorage: {'access_token': 'mock_token'},
      database: db,
      api: FakeApiAdapter(autoUserId: ownerId),
      overrides: [wishPhotoPickerProvider.overrideWithValue(picker)],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.byTooltip('Добавить желание'),
      ),
    );
    await tester.pumpAndSettle();

    // Три фото: камера + два из галереи за раз.
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();

    await tester.tap(_addButton);
    await tester.pumpAndSettle();
    expect(find.byType(AddWishSheet), findsNothing);

    final wish = (await (db.select(
      db.wishes,
    )..where((w) => w.ownerId.equals(ownerId))).get()).single;
    // Первый путь — primary image_url, остальные — wish_images
    // в порядке добавления. Все три — реальные пути fake-файлов.
    expect(wish.imageUrl, isNotNull);
    final images = await db.wishImagesOf(ownerId, wish.id);
    expect(images, hasLength(2));
    expect(images.map((i) => i.sortOrder), [1, 2]);
  });

  testWidgets('Text and URL survive picker round-trip', (tester) async {
    final picker = _FakePhotoPicker();
    await _openSheet(
      tester,
      overrides: [wishPhotoPickerProvider.overrideWithValue(picker)],
    );

    await tester.enterText(find.byType(TextField), 'кофемолка');
    await tester.tap(find.text('URL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'ozon.ru/item');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();

    // Состояние sheet не потеряно после возврата из picker.
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'кофемолка',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'ozon.ru/item',
    );
    expect(_photoTiles, findsOneWidget);
  });

  testWidgets('Dirty close asks confirmation; cancel keeps sheet', (
    tester,
  ) async {
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'что-то');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();

    // Подтверждение вместо бездумного закрытия.
    expect(find.text('Закрыть без сохранения?'), findsOneWidget);
    expect(find.byType(AddWishSheet), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(AddWishSheet), findsOneWidget);

    // Повторное закрытие → подтвердить.
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byType(AddWishSheet), findsNothing);
  });

  testWidgets('Three secondary actions fit at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openSheet(tester);

    expect(find.byType(AddWishSheet), findsOneWidget);
    expect(find.text('URL'), findsOneWidget);
    expect(find.text('Камера'), findsOneWidget);
    expect(find.text('Галерея'), findsOneWidget);
  });

  testWidgets('Clean sheet closes without confirmation', (tester) async {
    await _openSheet(tester);

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();

    expect(find.byType(AddWishSheet), findsNothing);
  });
}
