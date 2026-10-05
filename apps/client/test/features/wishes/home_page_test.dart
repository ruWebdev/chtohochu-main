import 'package:chtohochu/core/sync/sync_engine.dart';
import 'package:chtohochu/features/notifications/presentation/pages/notifications_page.dart';
import 'package:chtohochu/features/shopping/presentation/pages/shopping_list_form_page.dart';
import 'package:chtohochu/features/friends/presentation/pages/friend_search_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/home_page.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/add_wish_sheet.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_details_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_form_page.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/wish_card.dart';
import 'package:chtohochu/shared/ui/navigation/app_bottom_bar.dart';
import 'package:chtohochu/shared/ui/scaffolding/app_shell_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

Map<String, Object> _authPrefs([String wishesCache = '[]']) => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
  'wishes_cache': wishesCache,
};

const _wishBook =
    '{"id":"11111111-1111-1111-1111-111111111111","title":"Книга",'
    '"price":890,"createdAt":"2025-01-01T00:00:00.000"}';
const _wishLaptop =
    '{"id":"22222222-2222-2222-2222-222222222222","title":"Ноутбук",'
    '"price":120000,"createdAt":"2025-01-02T00:00:00.000"}';
const _wishNoPrice =
    '{"id":"33333333-3333-3333-3333-333333333333","title":"Поездка на море",'
    '"createdAt":"2025-01-03T00:00:00.000"}';

void main() {
  testWidgets('Empty state: title, question, CTA; no count, no AddRow', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    // «Что хочу» — и заголовок, и метка активной вкладки bottom bar.
    expect(find.text('Что хочу'), findsWidgets);
    expect(find.text('Что ты хочешь?'), findsOneWidget);
    expect(find.text('Добавить первое желание'), findsOneWidget);
    // Count subtitle и AddRow отсутствуют при пустом списке.
    expect(find.byType(AddWishRow), findsNothing);
    expect(find.text('Добавить желание'), findsNothing);
    // Никакого поиска на Home.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Empty CTA navigates to new wish', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить первое желание'));
    await tester.pumpAndSettle();

    expect(find.byType(WishFormPage), findsOneWidget);
  });

  testWidgets('Count subtitle shown only with wishes; cards + AddRow', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook,$_wishLaptop]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('2 желания'), findsOneWidget);
    expect(find.byType(WishCard), findsNWidgets(2));
    expect(find.byType(AddWishRow), findsOneWidget);
    expect(find.text('Добавить желание'), findsOneWidget);
  });

  testWidgets('AppBar shows bell (not plus); bell navigates to notifications', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // В AppBar — только колокольчик; «+» живёт в центре bottom bar.
    expect(
      find.descendant(
        of: find.byType(AppShellBar),
        matching: find.byTooltip('Добавить желание'),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Оповещения'), findsOneWidget);

    await tester.tap(find.byTooltip('Оповещения'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.text('Оповещения'), findsOneWidget);
    expect(find.text('Пока нет оповещений'), findsOneWidget);
  });

  testWidgets('Center add button on home opens quick-add sheet', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final centerAdd = find.descendant(
      of: find.byType(AppBottomBar),
      matching: find.byTooltip('Добавить желание'),
    );
    expect(centerAdd, findsOneWidget);

    await tester.tap(centerAdd);
    await tester.pumpAndSettle();

    expect(find.byType(AddWishSheet), findsOneWidget);
  });

  testWidgets('Center add button is contextual: shopping → new list', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Покупки'));
    await tester.pumpAndSettle();

    // Тултип есть и у AppBar-action экрана — берём именно кнопку бара.
    final centerAdd = find.descendant(
      of: find.byType(AppBottomBar),
      matching: find.byTooltip('Создать список покупок'),
    );
    expect(centerAdd, findsOneWidget);

    await tester.tap(centerAdd);
    await tester.pumpAndSettle();

    expect(find.byType(ShoppingListFormPage), findsOneWidget);
  });

  testWidgets('Center add button is contextual: friends → add friend', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Друзья'));
    await tester.pumpAndSettle();

    final centerAdd = find.descendant(
      of: find.byType(AppBottomBar),
      matching: find.byTooltip('Добавить друга'),
    );
    expect(centerAdd, findsOneWidget);

    await tester.tap(centerAdd);
    await tester.pumpAndSettle();

    expect(find.byType(FriendSearchPage), findsOneWidget);
  });

  testWidgets('AddRow navigates to new wish', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AddWishRow));
    await tester.pumpAndSettle();

    expect(find.byType(WishFormPage), findsOneWidget);
  });

  testWidgets('Wish card opens details; price rendered', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishLaptop]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Ноутбук'), findsOneWidget);
    expect(find.text('120 000 ₽'), findsOneWidget);

    await tester.tap(find.byType(WishCard));
    await tester.pumpAndSettle();

    expect(find.byType(WishDetailsPage), findsOneWidget);
  });

  testWidgets('Wish without price: card renders, same list geometry', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishNoPrice]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Поездка на море'), findsOneWidget);
    expect(find.byType(WishCard), findsOneWidget);
    final cardSize = tester.getSize(find.byType(WishCard));
    // Высота карточки = 64 thumb + 2×12 padding = 88.
    expect(cardSize.height, 88);
  });

  testWidgets('Syncing: micro spinner in subtitle', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    container.read(syncStatusProvider.notifier).set(SyncStatus.syncing);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('1 желание'), findsOneWidget);

    container.read(syncStatusProvider.notifier).set(SyncStatus.idle);
    await tester.pump();
  });

  testWidgets('Offline + pending outbox: «не синхронизировано» in subtitle', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
      overrides: [
        pendingOutboxCountProvider.overrideWith((ref) => Stream.value(2)),
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    container.read(syncStatusProvider.notifier).set(SyncStatus.offline);
    await tester.pump();

    expect(find.text('1 желание · не синхронизировано'), findsOneWidget);

    container.read(syncStatusProvider.notifier).set(SyncStatus.idle);
    await tester.pump();
  });

  testWidgets('Offline + empty outbox: no sync fragment', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    container.read(syncStatusProvider.notifier).set(SyncStatus.offline);
    await tester.pump();

    // Outbox пуст (миграция уже синхронизирована fake API) — чистый count.
    expect(find.text('1 желание'), findsOneWidget);
    expect(find.textContaining('не синхронизировано'), findsNothing);

    container.read(syncStatusProvider.notifier).set(SyncStatus.idle);
    await tester.pump();
  });

  testWidgets('Wide layout (≥600): centered max-width + 2-column grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook,$_wishLaptop,$_wishNoPrice]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // 800 logical px → wide layout: SliverGrid вместо ListView.separated.
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(WishCard), findsNWidgets(3));
    expect(find.byType(AddWishRow), findsOneWidget);
  });

  testWidgets('Narrow layout (<600): single-column list', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook,$_wishLaptop]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // 360 logical px → узкий layout.
    expect(find.byType(SliverGrid), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(WishCard), findsNWidgets(2));
  });
}
