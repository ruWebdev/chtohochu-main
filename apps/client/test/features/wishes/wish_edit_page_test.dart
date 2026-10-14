import 'dart:convert';
import 'dart:io';

import 'package:chtohochu/app/router/routes.dart';
import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/features/wishes/data/wish_photo_picker.dart';
import 'package:chtohochu/features/wishes/presentation/pages/home_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_form_page.dart';

import 'package:chtohochu/features/wishes/presentation/widgets/wish_photo_tile.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

/// Сид желания с изображениями: primary — `wishes.image_url`,
/// доп. — строки `wish_images`. ownerId фиксирован через
/// `FakeApiAdapter(autoUserId:)` — иначе он генерируется.
const _owner = 'u-test';
const _wishId = 'aaaaaaaa-1111-1111-1111-111111111111';

Map<String, Object> _prefs({String? imageUrl}) => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
  'wishes_cache': jsonEncode([
    {
      'id': _wishId,
      'title': 'Наушники Sony',
      'description': null,
      'price': null,
      'link': null,
      'imageUrl': imageUrl,
      'createdAt': '2025-01-01T00:00:00.000',
    },
  ]),
};

WishImagesCompanion _img(
  String id, {
  String? remoteUrl,
  String? localPath,
  required int sortOrder,
  String status = 'uploaded',
}) => WishImagesCompanion(
  id: Value(id),
  uploadId: Value(id),
  ownerId: const Value(_owner),
  wishId: const Value(_wishId),
  remoteUrl: Value(remoteUrl),
  localPath: Value(localPath),
  uploadStatus: Value(status),
  sortOrder: Value(sortOrder),
  createdAt: Value(DateTime.now()),
);

class _FakePicker implements WishPhotoPicker {
  _FakePicker(this.galleryPaths);

  final List<String> galleryPaths;

  @override
  Future<String?> capture() async =>
      galleryPaths.isEmpty ? null : galleryPaths.first;

  @override
  Future<List<String>> pickFromGallery() async => galleryPaths;
}

/// Поднять приложение с желанием в БД и открыть форму редактирования.
Future<({AppDatabase db, FakeApiAdapter api})> _openEditForm(
  WidgetTester tester, {
  String? imageUrl,
  List<WishImagesCompanion> images = const [],
  WishPhotoPicker? picker,
}) async {
  final db = createTestDatabase();
  final api = FakeApiAdapter(autoUserId: _owner);
  final widget = await createTestApp(
    preferences: _prefs(imageUrl: imageUrl),
    secureStorage: {'access_token': 'mock_token'},
    api: api,
    database: db,
    overrides: [
      if (picker != null) wishPhotoPickerProvider.overrideWithValue(picker),
    ],
  );
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();

  for (final img in images) {
    await db.insertWishImage(img);
  }

  tester.element(find.byType(HomePage)).go(AppRoutes.wishEdit(_wishId));
  await tester.pumpAndSettle();
  return (db: db, api: api);
}

/// Тап по «Сохранить изменения» + ожидание возврата на детали.
Future<void> _save(WidgetTester tester) async {
  // Кнопка внизу скролла — прокручиваем до неё.
  await tester.ensureVisible(find.text('Сохранить изменения'));
  await tester.tap(find.text('Сохранить изменения'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('секция фото: тайлы вместо поля URL, кнопки камера/галерея', (
    tester,
  ) async {
    await _openEditForm(
      tester,
      imageUrl: '/tmp/primary.jpg',
      images: [
        _img('img-1', remoteUrl: 'https://cdn.test/a.jpg', sortOrder: 1),
        _img('img-2', remoteUrl: 'https://cdn.test/b.jpg', sortOrder: 2),
      ],
    );

    expect(find.byType(WishFormPage), findsOneWidget);
    expect(find.text('Редактировать желание'), findsOneWidget);
    expect(find.text('Фотографии'), findsOneWidget);
    // primary + 2 additional.
    expect(find.byType(WishPhotoTile), findsNWidgets(3));
    expect(find.text('Камера'), findsOneWidget);
    expect(find.text('Галерея'), findsOneWidget);
    // Текстового поля «Ссылка на изображение» в режиме
    // редактирования больше нет.
    expect(find.text('Ссылка на изображение (необязательно)'), findsNothing);
  });

  testWidgets('желание без фото: секция показывает только кнопки', (
    tester,
  ) async {
    await _openEditForm(tester);

    expect(find.text('Фотографии'), findsOneWidget);
    expect(find.byType(WishPhotoTile), findsNothing);
    expect(find.text('Камера'), findsOneWidget);
    expect(find.text('Галерея'), findsOneWidget);
  });

  testWidgets('удаление доп.фото: тайл исчезает, после сохранения строка '
      'удалена локально и на сервере', (tester) async {
    final (:db, :api) = await _openEditForm(
      tester,
      imageUrl: '/tmp/primary.jpg',
      images: [
        _img('img-1', remoteUrl: 'https://cdn.test/a.jpg', sortOrder: 1),
        _img('img-2', remoteUrl: 'https://cdn.test/b.jpg', sortOrder: 2),
      ],
    );
    expect(find.byType(WishPhotoTile), findsNWidgets(3));

    // Удаляем последний тайл (img-2).
    await tester.ensureVisible(find.byTooltip('Удалить фото').last);
    await tester.tap(find.byTooltip('Удалить фото').last);
    await tester.pumpAndSettle();
    expect(find.byType(WishPhotoTile), findsNWidgets(2));

    await _save(tester);

    final rows = await db.wishImagesOf(_owner, _wishId);
    expect(rows.map((r) => r.id), ['img-1']);
    // Серверный набор заменён: img-2 удалён.
    final server = api.wishesOf(_owner).single;
    expect((server['images'] as List).map((i) => i['id']), ['img-1']);
  });

  testWidgets('удаление первого фото: следующее становится обложкой', (
    tester,
  ) async {
    final (:db, :api) = await _openEditForm(
      tester,
      imageUrl: '/tmp/primary.jpg',
      images: [
        _img('img-1', remoteUrl: 'https://cdn.test/a.jpg', sortOrder: 1),
        _img('img-2', remoteUrl: 'https://cdn.test/b.jpg', sortOrder: 2),
      ],
    );

    // Удаляем первый тайл — img-1 продвигается в primary.
    await tester.ensureVisible(find.byTooltip('Удалить фото').first);
    await tester.tap(find.byTooltip('Удалить фото').first);
    await tester.pumpAndSettle();
    expect(find.byType(WishPhotoTile), findsNWidgets(2));

    await _save(tester);

    final wish = (await db.wishById(_owner, _wishId))!;
    expect(wish.imageUrl, 'https://cdn.test/a.jpg');
    // img-1 ушёл из additional — он теперь primary.
    expect(await db.wishImagesOf(_owner, _wishId), hasLength(1));
    final server = api.wishesOf(_owner).single;
    expect(server['image_url'], 'https://cdn.test/a.jpg');
    expect((server['images'] as List).map((i) => i['id']), ['img-2']);
  });

  testWidgets('добавление из галереи: новая строка wish_images', (
    tester,
  ) async {
    // Media-upload проверяет существование файла на диске.
    File('/tmp/gallery-1.jpg').writeAsBytesSync([1, 2, 3]);
    final (:db, :api) = await _openEditForm(
      tester,
      imageUrl: '/tmp/primary.jpg',
      picker: _FakePicker(['/tmp/gallery-1.jpg']),
    );

    await tester.ensureVisible(find.text('Галерея'));
    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();
    expect(find.byType(WishPhotoTile), findsNWidgets(2));

    await _save(tester);

    final rows = await db.wishImagesOf(_owner, _wishId);
    expect(rows, hasLength(1));
    expect(rows.single.localPath, '/tmp/gallery-1.jpg');
    // Новый файл сначала pending → media-upload поднимает его и
    // штатным PATCH доносит remote_url до сервера (фейк-PUT
    // мгновенный — к моменту assert строка уже uploaded и сервер
    // знает изображение под id строки).
    expect(rows.single.uploadStatus, 'uploaded');
    final server = api.wishesOf(_owner).single;
    expect((server['images'] as List).map((i) => i['id']), [rows.single.id]);
  });

  testWidgets('сохранение без правок: remote-набор не теряется', (
    tester,
  ) async {
    final (:db, :api) = await _openEditForm(
      tester,
      imageUrl: 'https://cdn.test/primary.jpg',
      images: [
        _img('img-1', remoteUrl: 'https://cdn.test/a.jpg', sortOrder: 1),
        _img('img-2', remoteUrl: 'https://cdn.test/b.jpg', sortOrder: 2),
      ],
    );

    await _save(tester);

    // Локально строки на месте, сервер получил те же id —
    // порядок sort_order следует позиции в форме.
    final rows = await db.wishImagesOf(_owner, _wishId);
    expect(rows.map((r) => r.id), ['img-1', 'img-2']);
    final server = api.wishesOf(_owner).single;
    expect(server['image_url'], 'https://cdn.test/primary.jpg');
    expect((server['images'] as List).map((i) => i['id']), ['img-1', 'img-2']);
  });

  testWidgets('реордер: перетаскивание доп.фото в начало делает его '
      'обложкой', (tester) async {
    final (:db, :api) = await _openEditForm(
      tester,
      imageUrl: 'https://cdn.test/primary.jpg',
      images: [
        _img('img-1', remoteUrl: 'https://cdn.test/a.jpg', sortOrder: 1),
        _img('img-2', remoteUrl: 'https://cdn.test/b.jpg', sortOrder: 2),
      ],
    );

    // Long-press по третьему тайлу (img-2) и перенос в начало.
    final third = tester.getCenter(find.byType(WishPhotoTile).at(2));
    final first = tester.getCenter(find.byType(WishPhotoTile).at(0));
    final gesture = await tester.startGesture(third);
    await tester.pump(const Duration(milliseconds: 600));
    // Перетаскивание влево маленькими шагами — как палец.
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(Offset(-(third.dx - first.dx) / 10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    await _save(tester);

    final wish = (await db.wishById(_owner, _wishId))!;
    // img-2 продвинут в обложку — его строка ушла из wish_images.
    expect(wish.imageUrl, 'https://cdn.test/b.jpg');
    final rows = await db.wishImagesOf(_owner, _wishId);
    expect(rows.any((r) => r.id == 'img-2'), isFalse);
    // Бывший remote-primary остался в наборе новой uploaded-строкой
    // (не уходит в повторный upload), img-1 сохранил id.
    expect(
      rows.map((r) => r.remoteUrl),
      contains('https://cdn.test/primary.jpg'),
    );
    expect(rows.map((r) => r.id), contains('img-1'));
    expect(rows.every((r) => r.uploadStatus == 'uploaded'), isTrue);

    final server = api.wishesOf(_owner).single;
    expect(server['image_url'], 'https://cdn.test/b.jpg');
    expect((server['images'] as List).map((i) => i['url']), [
      'https://cdn.test/primary.jpg',
      'https://cdn.test/a.jpg',
    ]);
  });

  testWidgets('удаление всех фото: image_url и набор очищаются', (
    tester,
  ) async {
    final (:db, :api) = await _openEditForm(
      tester,
      imageUrl: '/tmp/primary.jpg',
      images: [
        _img('img-1', remoteUrl: 'https://cdn.test/a.jpg', sortOrder: 1),
      ],
    );
    expect(find.byType(WishPhotoTile), findsNWidgets(2));

    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byTooltip('Удалить фото').first);
      await tester.tap(find.byTooltip('Удалить фото').first);
      await tester.pumpAndSettle();
    }
    expect(find.byType(WishPhotoTile), findsNothing);

    await _save(tester);

    final wish = (await db.wishById(_owner, _wishId))!;
    expect(wish.imageUrl, isNull);
    expect(await db.wishImagesOf(_owner, _wishId), isEmpty);
    final server = api.wishesOf(_owner).single;
    expect(server['image_url'], isNull);
    expect(server['images'], isEmpty);
  });
}
