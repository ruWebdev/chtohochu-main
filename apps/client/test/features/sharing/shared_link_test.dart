import 'package:chtohochu/app/app.dart';
import 'package:chtohochu/app/router/app_router.dart';
import 'package:chtohochu/app/router/share_deep_links.dart';
import 'package:chtohochu/features/auth/presentation/pages/auth_page.dart';
import 'package:chtohochu/features/sharing/presentation/pages/shared_link_page.dart';
import 'package:chtohochu/features/sharing/presentation/pages/shared_wish_list_page.dart';
import 'package:chtohochu/features/sharing/presentation/pages/shared_wish_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/home_page.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:chtohochu/shared/ui/navigation/app_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

const _uid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

Map<String, Object> _prefs() => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
  'wishes_cache': '[]',
};

Map<String, dynamic> _wish({
  String? listId,
  String? description,
  String? link,
  String? imageUrl,
}) => {
  'id': 'w1',
  'title': 'Наушники Sony',
  'description': description,
  'price': 12990,
  'link': link,
  'image_url': imageUrl,
  'list_id': listId,
  'created_at': '2025-01-01T00:00:00.000Z',
  'updated_at': '2025-01-01T00:00:00.000Z',
};

/// Эмулирует входящий deep link через реальный обработчик —
/// `ShareDeepLinkHandler.handleUri` вызывается без плагина.
ShareDeepLinkHandler _handlerOf(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ChtoHochuApp)),
  );
  return container.read(shareDeepLinkHandlerProvider);
}

Future<void> _openShareLink(
  WidgetTester tester,
  String token, {
  String host = 'chtohochu.ru',
}) async {
  _handlerOf(tester).handleUri(Uri.parse('https://$host/s/$token'));
  await tester.pumpAndSettle();
}

void main() {
  group('публичный viewer /s/{token}', () {
    testWidgets('без auth: share link открывает SharedWishPage, '
        'а не /auth', (tester) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      api.seedWish(
        _uid,
        _wish(
          description: 'приватная заметка',
          link: 'https://example.com/sony',
        ),
      );
      final token = api.seedShare(_uid, 'wish:w1');
      // Без access_token — сессия NeedsAuth.
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);

      await _openShareLink(tester, token);

      expect(find.byType(SharedLinkPage), findsOneWidget);
      expect(find.byType(SharedWishPage), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
      expect(find.text('Наушники Sony'), findsOneWidget);
      expect(find.text('Наташа хочет'), findsNothing); // owner из users
      expect(find.text('12 990 ₽'), findsOneWidget);
      expect(find.text('Открыть товар'), findsOneWidget);
      // Приватная заметка не попадает в public viewer.
      expect(find.text('приватная заметка'), findsNothing);
      // BottomBar и приватные actions отсутствуют.
      expect(find.byType(AppBottomBar), findsNothing);
      expect(find.byTooltip('Удалить'), findsNothing);
      expect(find.byTooltip('Редактировать'), findsNothing);
    });

    testWidgets('public wish показывает имя владельца', (tester) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      api.seedUser(_uid, name: 'Наташа');
      api.seedWish(_uid, _wish());
      final token = api.seedShare(_uid, 'wish:w1');
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await _openShareLink(tester, token);

      expect(find.text('Наташа хочет'), findsOneWidget);
      // Gift-placeholder вместо изображения (image_url == null).
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('public wish_list → SharedWishListPage с карточками', (
      tester,
    ) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      api.seedUser(_uid, name: 'Наташа');
      api.seedWishList(_uid, 'l1', 'Техника');
      api.seedWish(_uid, _wish(listId: 'l1', link: 'https://example.com/sony'));
      api.seedWish(_uid, {
        ..._wish(),
        'id': 'w2',
        'title': 'MacBook Air',
        'price': 99990,
        'link': null,
        'image_url': null,
        'list_id': 'l1',
      });
      final token = api.seedShare(_uid, 'list:l1');
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await _openShareLink(tester, token);

      expect(find.byType(SharedWishListPage), findsOneWidget);
      expect(find.text('Наташа'), findsOneWidget);
      expect(find.text('Техника'), findsOneWidget);
      expect(find.text('Наушники Sony'), findsOneWidget);
      expect(find.text('MacBook Air'), findsOneWidget);
      expect(find.text('12 990 ₽'), findsOneWidget);
      expect(find.text('99 990 ₽'), findsOneWidget);
      expect(find.text('Открыть товар'), findsOneWidget);
    });

    testWidgets('404 → единое «Ссылка недействительна»', (tester) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await _openShareLink(tester, 'nonexistent');

      expect(find.text('Ссылка недействительна'), findsOneWidget);
      expect(
        find.text(
          'Возможно, желание было удалено или ссылка больше не доступна.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('server error → «Не удалось загрузить» + «Повторить» '
        'перезапрашивает API', (tester) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      api.seedUser(_uid, name: 'Наташа');
      api.seedWish(_uid, _wish());
      final token = api.seedShare(_uid, 'wish:w1');
      api.failures['GET /share/$token'] = 500;
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await _openShareLink(tester, token);
      expect(find.text('Не удалось загрузить'), findsOneWidget);
      expect(
        find.text('Проверь подключение к интернету и попробуй ещё раз.'),
        findsOneWidget,
      );

      api.failures.remove('GET /share/$token');
      await tester.tap(find.widgetWithText(AppButton, 'Повторить'));
      await tester.pumpAndSettle();

      expect(find.byType(SharedWishPage), findsOneWidget);
      expect(find.text('Наушники Sony'), findsOneWidget);
      // Retry повторил запрос.
      expect(api.requests.where((r) => r == 'GET /share/$token'), hasLength(2));
    });

    testWidgets('один и тот же URI дважды — без дубля навигации/запроса', (
      tester,
    ) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      api.seedUser(_uid, name: 'Наташа');
      api.seedWish(_uid, _wish());
      final token = api.seedShare(_uid, 'wish:w1');
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Cold start доставляет initial + stream-дубль того же URI.
      final handler = _handlerOf(tester);
      final uri = Uri.parse('https://chtohochu.ru/s/$token');
      handler.handleUri(uri);
      handler.handleUri(uri);
      await tester.pumpAndSettle();

      expect(find.byType(SharedWishPage), findsOneWidget);
      expect(api.requests.where((r) => r == 'GET /share/$token'), hasLength(1));
    });

    testWidgets('postоронние URI и «чужие» hosts игнорируются', (tester) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);

      final handler = _handlerOf(tester);
      handler.handleUri(Uri.parse('https://evil.example.com/s/abc'));
      handler.handleUri(Uri.parse('https://chtohochu.ru/other/abc'));
      handler.handleUri(Uri.parse('https://chtohochu.ru/s/'));
      await tester.pumpAndSettle();

      // Ничего не открылось — остались на auth, запросов к API нет.
      expect(find.byType(SharedLinkPage), findsNothing);
      expect(find.byType(AuthPage), findsOneWidget);
      expect(api.requests.where((r) => r.startsWith('GET /share/')), isEmpty);
    });

    testWidgets('viewer не пишет в API — только публичный GET', (tester) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      api.seedUser(_uid, name: 'Наташа');
      api.seedWish(_uid, _wish());
      final token = api.seedShare(_uid, 'wish:w1');
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await _openShareLink(tester, token);
      expect(find.byType(SharedWishPage), findsOneWidget);

      // Ни одной мутации — viewer read-only.
      expect(api.requests.where((r) => !r.startsWith('GET')), isEmpty);
    });

    testWidgets('приватный route по-прежнему редиректит unauth на /auth', (
      tester,
    ) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: const {},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChtoHochuApp)),
      );
      container.read(goRouterProvider).go('/home');
      await tester.pumpAndSettle();

      // Приватный раздел недоступен без сессии.
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(AuthPage), findsOneWidget);
    });

    testWidgets('авторизованный пользователь: Back → Home', (tester) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      api.seedUser(_uid, name: 'Наташа');
      api.seedWish(_uid, _wish());
      final token = api.seedShare(_uid, 'wish:w1');
      final widget = await createTestApp(
        preferences: _prefs(),
        secureStorage: {'access_token': 'mock_token'},
        api: api,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);

      await _openShareLink(tester, token);
      expect(find.byType(SharedWishPage), findsOneWidget);

      // Стек пуст (go из deep link) → Back ведёт на Home.
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });
  });
}
