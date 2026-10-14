import 'dart:async';
import 'dart:io';

import 'package:chtohochu/core/link_preview/link_preview.dart';
import 'package:chtohochu/core/media/media_image_processor.dart';
import 'package:chtohochu/core/media/remote_image.dart';
import 'package:chtohochu/features/wishes/domain/wish_draft.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/add_wish_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Map<String, Object> _authPrefs() => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
};

class _FakeExtractor extends LinkPreviewExtractor {
  _FakeExtractor({this.preview, this.completer});

  final LinkPreview? preview;
  final Completer<LinkPreview?>? completer;
  int calls = 0;

  @override
  Future<LinkPreview?> extract(
    String url, {
    Duration maxWait = const Duration(seconds: 60),
    int stablePolls = 2,
  }) {
    calls++;
    if (completer != null) return completer!.future;
    return Future.value(preview);
  }

  @override
  Future<void> cancel() async {}
}

class _NoopProcessor implements MediaImageProcessor {
  @override
  Future<File> process(String sourcePath, Directory targetDir) =>
      throw UnimplementedError();
}

class _FakeFetcher extends RemoteImageFetcher {
  _FakeFetcher(this.result) : super(_NoopProcessor());

  final String? result;

  @override
  Future<String?> fetchForWish(String url) async => result;
}

const _productUrl = 'https://www.wildberries.ru/catalog/1260579203/detail.aspx';

/// Открыть AddWishSheet в режиме импорта — как это делает AppShell
/// по событию importRequestProvider.
Future<void> _openImportSheet(
  WidgetTester tester, {
  LinkPreview? preview,
  Completer<LinkPreview?>? completer,
  String? fetchedImage = '/tmp/og_image.jpg',
}) async {
  final widget = await createTestApp(
    preferences: _authPrefs(),
    secureStorage: {'access_token': 'mock_token'},
    api: FakeApiAdapter(autoUserId: 'user-a'),
    overrides: [
      linkPreviewExtractorProvider.overrideWithValue(
        _FakeExtractor(preview: preview, completer: completer),
      ),
      remoteImageFetcherProvider.overrideWithValue(_FakeFetcher(fetchedImage)),
    ],
  );
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();

  unawaited(
    showAddWishSheet(
      tester.element(find.byType(Scaffold).first),
      draft: const WishDraft(link: _productUrl),
    ),
  );
  // Не pumpAndSettle: пока импорт идёт, спиннер крутится бесконечно.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('импорт: превью — цена, хост, название в поле', (tester) async {
    await _openImportSheet(
      tester,
      preview: const LinkPreview(
        title: 'Кофемашина AURIXO',
        description: 'Портативная',
        price: 3217,
        imageUrl: 'https://cdn.example/1.webp',
      ),
    );

    expect(find.text('Импорт товара'), findsOneWidget);
    expect(find.text('3 217 ₽'), findsOneWidget);
    expect(find.text('www.wildberries.ru'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Кофемашина AURIXO',
    );
    expect(find.text('Добавить желание'), findsOneWidget);
    expect(find.text('Редактировать'), findsOneWidget);
  });

  testWidgets('во время загрузки форма не показывается', (tester) async {
    final completer = Completer<LinkPreview?>();
    await _openImportSheet(tester, completer: completer);

    expect(find.text('Загружаем данные по ссылке…'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Отмена'), findsOneWidget);
  });

  testWidgets('импорт не затирает название, введённое пользователем', (
    tester,
  ) async {
    final completer = Completer<LinkPreview?>();
    await _openImportSheet(tester, completer: completer);

    // Отменяем индикатор → ручной ввод до ответа экстрактора.
    await tester.tap(find.text('Отмена'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.enterText(find.byType(TextField).at(0), 'моё название');
    await tester.pump();

    completer.complete(const LinkPreview(title: 'Кофемашина AURIXO'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      'моё название',
    );
  });

  testWidgets('экстракция вернула null → ошибка + ручной ввод, ссылка цела', (
    tester,
  ) async {
    await _openImportSheet(tester, preview: null, fetchedImage: null);

    expect(
      find.text('Не удалось загрузить данные по ссылке — заполните вручную.'),
      findsOneWidget,
    );
    // Поля: название + ссылка.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      _productUrl,
    );
    expect(find.text('Добавить'), findsOneWidget);
  });

  testWidgets('сохранение из превью создаёт желание и закрывает sheet', (
    tester,
  ) async {
    await _openImportSheet(
      tester,
      preview: const LinkPreview(title: 'Кофемашина AURIXO', price: 3217),
      fetchedImage: null,
    );

    await tester.tap(find.text('Добавить желание'));
    await tester.pumpAndSettle();

    expect(find.text('Импорт товара'), findsNothing);
    expect(find.text('Кофемашина AURIXO'), findsOneWidget);
  });
}
