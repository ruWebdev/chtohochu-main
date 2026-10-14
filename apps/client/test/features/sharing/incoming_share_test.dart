import 'package:chtohochu/core/link_preview/link_preview.dart';
import 'package:chtohochu/features/sharing/data/incoming_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedTextParser.extractUrl', () {
    test('чистая ссылка', () {
      expect(
        SharedTextParser.extractUrl(
          'https://www.wildberries.ru/catalog/1260579203/detail.aspx',
        ),
        'https://www.wildberries.ru/catalog/1260579203/detail.aspx',
      );
    });

    test('текст маркетплейса вокруг ссылки', () {
      expect(
        SharedTextParser.extractUrl(
          'Капсулы для стирки FRESH X, 52 шт '
          'https://www.ozon.ru/product/x-3660840746/?at=1kW&sh=pfB '
          'купить на OZON',
        ),
        'https://www.ozon.ru/product/x-3660840746/?at=1kW&sh=pfB',
      );
    });

    test('хвостовая пунктуация обрезается', () {
      expect(
        SharedTextParser.extractUrl('смотри https://example.com/p/1.'),
        'https://example.com/p/1',
      );
    });

    test('без ссылки → null', () {
      expect(SharedTextParser.extractUrl('просто текст'), isNull);
      expect(SharedTextParser.extractUrl(''), isNull);
    });
  });

  group('ShareDeduper', () {
    final d = ShareDeduper();
    final t0 = DateTime(2026, 1, 1, 12);

    test('повтор в окне — дубликат', () {
      const url = 'https://example.com/p/1';
      expect(d.isDuplicate(url, t0), isFalse);
      expect(d.isDuplicate(url, t0.add(const Duration(seconds: 2))), isTrue);
    });

    test('после окна — снова новое событие', () {
      const url = 'https://example.com/p/1';
      expect(d.isDuplicate(url, t0.add(const Duration(seconds: 10))), isFalse);
    });

    test('другой url — не дубликат', () {
      expect(d.isDuplicate('https://example.com/p/2', t0), isFalse);
    });
  });

  group('LinkPreviewExtractor.parsePrice', () {
    test('цена с пробелами и ₽', () {
      expect(LinkPreviewExtractor.parsePrice('3 217 ₽'), 3217);
      expect(LinkPreviewExtractor.parsePrice('401 ₽'), 401);
    });

    test('мусор и отсутствие цены', () {
      expect(LinkPreviewExtractor.parsePrice(null), isNull);
      expect(LinkPreviewExtractor.parsePrice('нет цены'), isNull);
      expect(LinkPreviewExtractor.parsePrice('₽'), isNull);
      expect(LinkPreviewExtractor.parsePrice('1234567890123'), isNull);
    });
  });
}
