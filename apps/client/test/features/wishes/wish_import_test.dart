import 'dart:async';
import 'dart:io';

import 'package:chtohochu/app/router/routes.dart';
import 'package:chtohochu/core/link_preview/link_preview.dart';
import 'package:chtohochu/core/media/media_image_processor.dart';
import 'package:chtohochu/core/media/remote_image.dart';
import 'package:chtohochu/features/wishes/domain/wish_draft.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  String? lastUrl;

  @override
  Future<LinkPreview?> extract(
    String url, {
    Duration maxWait = const Duration(seconds: 60),
    int stablePolls = 2,
  }) {
    calls++;
    lastUrl = url;
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
  int calls = 0;

  @override
  Future<String?> fetchForWish(String url) async {
    calls++;
    return result;
  }
}

const _productUrl = 'https://www.wildberries.ru/catalog/1260579203/detail.aspx';

/// Открыть `/wishes/new` с draft — как это делает IncomingShareHandler.
Future<void> _openImportForm(
  WidgetTester tester, {
  LinkPreview? preview,
  Completer<LinkPreview?>? completer,
  String? fetchedImage = '/tmp/og_image.jpg',
  _FakeExtractor? extractor,
  WishDraft? draft,
}) async {
  final fake =
      extractor ?? _FakeExtractor(preview: preview, completer: completer);
  final widget = await createTestApp(
    preferences: _authPrefs(),
    secureStorage: {'access_token': 'mock_token'},
    api: FakeApiAdapter(autoUserId: 'user-a'),
    overrides: [
      linkPreviewExtractorProvider.overrideWithValue(fake),
      remoteImageFetcherProvider.overrideWithValue(_FakeFetcher(fetchedImage)),
    ],
  );
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();

  tester
      .element(find.byType(Scaffold).first)
      .go(
        AppRoutes.newWish,
        extra: draft ?? const WishDraft(link: _productUrl),
      );
  // Не pumpAndSettle: пока импорт идёт, спиннер крутится бесконечно.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

TextField _fieldAt(WidgetTester tester, int i) =>
    tester.widget<TextField>(find.byType(TextField).at(i));

void main() {
  testWidgets('draft: ссылка в поле, OG заполняет title/price/desc/image', (
    tester,
  ) async {
    const localPath = '/tmp/og_image.jpg';
    await _openImportForm(
      tester,
      preview: const LinkPreview(
        title: 'Кофемашина AURIXO',
        description: 'Портативная, с аккумулятором',
        price: 3217,
        imageUrl: 'https://cdn.example/1.webp',
      ),
      fetchedImage: localPath,
    );

    expect(find.byType(WishFormPage), findsOneWidget);
    expect(_fieldAt(tester, 2).controller!.text, _productUrl);
    expect(_fieldAt(tester, 0).controller!.text, 'Кофемашина AURIXO');
    expect(_fieldAt(tester, 1).controller!.text, '3217');
    expect(_fieldAt(tester, 3).controller!.text, localPath);
    expect(
      _fieldAt(tester, 4).controller!.text,
      'Портативная, с аккумулятором',
    );
  });

  testWidgets('импорт не затирает поле, которое уже правил пользователь', (
    tester,
  ) async {
    final completer = Completer<LinkPreview?>();
    await _openImportForm(tester, completer: completer, preview: null);

    // Пользователь успел ввести своё название до ответа экстрактора.
    await tester.enterText(find.byType(TextField).at(0), 'моё название');
    await tester.pump();

    completer.complete(
      const LinkPreview(title: 'Кофемашина AURIXO', price: 3217),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(_fieldAt(tester, 0).controller!.text, 'моё название');
    expect(_fieldAt(tester, 1).controller!.text, '3217');
  });

  testWidgets('экстракция вернула null → ошибка показана, форма работает', (
    tester,
  ) async {
    await _openImportForm(tester, preview: null, fetchedImage: null);

    expect(
      find.text('Не удалось загрузить данные по ссылке — заполни вручную.'),
      findsOneWidget,
    );
    expect(_fieldAt(tester, 2).controller!.text, _productUrl);

    // Ручное заполнение и сохранение — импорт не блокирует.
    await tester.enterText(find.byType(TextField).at(0), 'Кофемашина');
    await tester.pump();
    await tester.ensureVisible(find.text('Сохранить желание'));
    await tester.tap(find.text('Сохранить желание'));
    await tester.pumpAndSettle();

    expect(find.byType(WishFormPage), findsNothing);
    expect(find.text('Кофемашина'), findsOneWidget);
  });

  testWidgets('og:title >100 символов обрезается до лимита backend', (
    tester,
  ) async {
    final long = 'А' * 150;
    await _openImportForm(
      tester,
      preview: LinkPreview(title: long),
      fetchedImage: null,
    );

    expect(_fieldAt(tester, 0).controller!.text.length, 100);
  });

  testWidgets('previewDone-draft: поля предзаполнены, экстракция не бежит', (
    tester,
  ) async {
    final fake = _FakeExtractor(preview: null);
    await _openImportForm(
      tester,
      extractor: fake,
      fetchedImage: null,
      draft: const WishDraft(
        link: _productUrl,
        title: 'Кофемашина из шита',
        description: 'Описание',
        price: 999,
        imagePath: '/tmp/og_image.jpg',
        previewDone: true,
      ),
    );

    expect(fake.calls, 0);
    expect(_fieldAt(tester, 0).controller!.text, 'Кофемашина из шита');
    expect(_fieldAt(tester, 1).controller!.text, '999');
    expect(_fieldAt(tester, 2).controller!.text, _productUrl);
    expect(_fieldAt(tester, 3).controller!.text, '/tmp/og_image.jpg');
    expect(_fieldAt(tester, 4).controller!.text, 'Описание');
  });
}
