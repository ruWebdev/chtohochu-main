import 'dart:convert';

import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/sync/sync_engine.dart';
import 'package:chtohochu/features/notifications/presentation/pages/notifications_page.dart';
import 'package:chtohochu/features/wishes/domain/wish.dart';
import 'package:chtohochu/features/shopping/presentation/widgets/add_shopping_list_sheet.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/add_wish_list_sheet.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/wish_list_card.dart';
import 'package:chtohochu/features/friends/presentation/widgets/add_friend_sheet.dart';
import 'package:chtohochu/features/wishes/presentation/pages/home_page.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/add_wish_sheet.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_details_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_form_page.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/wish_card.dart';
import 'package:chtohochu/app/theme/app_colors.dart';
import 'package:chtohochu/app/theme/app_spacing.dart';
import 'package:chtohochu/shared/ui/buttons/app_add_action_button.dart';
import 'package:chtohochu/shared/ui/avatars/app_avatar.dart';
import 'package:chtohochu/shared/ui/navigation/app_bottom_bar.dart';
import 'package:chtohochu/shared/ui/scaffolding/app_shell_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chtohochu/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;

import '../../helpers/fake_api.dart';
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
const _wishLongTitle =
    '{"id":"44444444-4444-4444-4444-444444444444",'
    '"title":"Портативная кофемашина автоматическая с нагревом",'
    '"price":3217,"createdAt":"2025-01-04T00:00:00.000"}';

const _uid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

/// Серверное желание для boot-pull сида (FakeApi формат ресурса).
Map<String, dynamic> _serverWish(
  String id,
  String title, {
  String? priority,
  String createdAt = '2025-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'title': title,
  'description': null,
  'price': null,
  'link': null,
  'image_url': null,
  'list_id': null,
  'priority': ?priority,
  'created_at': createdAt,
  'updated_at': createdAt,
};

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

  testWidgets('Empty CTA opens add-wish sheet', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs(),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить первое желание'));
    await tester.pumpAndSettle();

    expect(find.byType(AddWishSheet), findsOneWidget);
    expect(find.byType(WishFormPage), findsNothing);
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
    expect(find.byType(WishGridCard), findsNWidgets(2));
    // Карточки стали выше — слот «добавить» за пределами
    // viewport и ещё не смонтирован: прокручиваем до него.
    await tester.scrollUntilVisible(find.byType(AddWishRow), 100);
    await tester.pumpAndSettle();
    expect(find.byType(AddWishRow), findsOneWidget);
    expect(find.text('Добавить желание'), findsOneWidget);
  });

  testWidgets('Home: «Очень хочу» выше обычных, «Не сейчас» свёрнута '
      'и раскрывается по тапу', (tester) async {
    final api = FakeApiAdapter(autoUserId: _uid);
    // Новейшая — normal: без группировки она стояла бы первой
    // (createdAt DESC). High обязана оказаться выше.
    api.seedWish(
      _uid,
      _serverWish('w1', 'Обычное желание', priority: 'normal'),
    );
    api.seedWish(
      _uid,
      _serverWish(
        'w2',
        'Срочное желание',
        priority: 'high',
        createdAt: '2025-01-02T00:00:00.000Z',
      ),
    );
    api.seedWish(
      _uid,
      _serverWish(
        'w3',
        'Отложенное желание',
        priority: 'later',
        createdAt: '2024-12-01T00:00:00.000Z',
      ),
    );
    final widget = await createTestApp(
      preferences: _authPrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Основная группа: high → normal в порядке монтирования сетки.
    final cards = tester
        .widgetList<WishGridCard>(find.byType(WishGridCard))
        .toList();
    expect(cards.map((c) => c.wish.title), [
      'Срочное желание',
      'Обычное желание',
    ]);
    // High-карточка несёт маркер сердечка.
    expect(
      find.descendant(
        of: find.widgetWithText(WishGridCard, 'Срочное желание'),
        matching: find.byIcon(PhosphorIconsFill.heart),
      ),
      findsOneWidget,
    );

    // «Не сейчас» — заголовок со счётчиком, карточка скрыта.
    // Заголовок ниже основной сетки — докручиваем до него.
    await tester.scrollUntilVisible(find.text('Не сейчас · 1'), 200);
    expect(find.text('Не сейчас · 1'), findsOneWidget);
    expect(find.text('Отложенное желание'), findsNothing);

    await tester.tap(find.text('Не сейчас · 1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Отложенное желание'), 200);
    expect(find.text('Отложенное желание'), findsOneWidget);

    // Повторный тап сворачивает обратно.
    await tester.tap(find.text('Не сейчас · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Отложенное желание'), findsNothing);
  });

  testWidgets('Home: пустая группа «Не сейчас» не рендерится; смена '
      'priority перемещает желание между группами', (tester) async {
    final api = FakeApiAdapter(autoUserId: _uid);
    api.seedWish(_uid, _serverWish('w1', 'Книга', priority: 'normal'));
    final db = createTestDatabase();
    final widget = await createTestApp(
      preferences: _authPrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
      database: db,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Отложенных нет — группы нет.
    expect(find.text('Не сейчас · 1'), findsNothing);
    expect(find.byType(WishGridCard), findsOneWidget);

    // Офлайн-мутация через репозиторий: watch-стрим перестраивает
    // группы автоматически, без переноса записи.
    final prefs = await SharedPreferences.getInstance();
    final repo = DriftWishRepository(db, PreferencesService(prefs));
    final wish = (await repo.getWishById('w1'))!;
    expect(wish.priority, WishPriority.normal);
    await repo.updateWish(wish.copyWith(priority: WishPriority.later));
    await tester.pumpAndSettle();

    expect(find.text('Не сейчас · 1'), findsOneWidget);
    expect(find.text('Книга'), findsNothing); // свёрнута
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

  testWidgets('Header shows avatar + displayName + bell badge', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Шапка: аватар + displayName тестового пользователя («user»),
    // колокольчик с красным бейджем — в одном ряду вверху.
    expect(find.byType(AppAvatar), findsOneWidget);
    expect(find.text('user'), findsOneWidget);
    expect(find.byTooltip('Оповещения'), findsOneWidget);

    // Тап по аватару ведёт в профиль.
    await tester.tap(find.byType(AppAvatar));
    await tester.pumpAndSettle();
    expect(find.text('Редактировать профиль'), findsOneWidget);
  });

  testWidgets('Center «+» expands bar into action chooser', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final bar = find.byType(AppBottomBar);
    Finder pill(String label) =>
        find.descendant(of: bar, matching: find.text(label));

    final centerAdd = find.descendant(
      of: bar,
      matching: find.byTooltip('Добавить желание'),
    );
    expect(centerAdd, findsOneWidget);

    await tester.tap(centerAdd);
    await tester.pumpAndSettle();

    // Пилюли действий по сторонам от центральной «+».
    expect(pill('Желание'), findsOneWidget);
    expect(pill('Список'), findsOneWidget);
    // Обычные пункты навигации временно скрыты: заголовок шапки
    // теперь — displayName пользователя («user» в тестовой сессии).
    expect(pill('Покупки'), findsNothing);
    expect(pill('Друзья'), findsNothing);
    expect(pill('Профиль'), findsNothing);
    expect(find.text('user'), findsOneWidget);
    // Ни один sheet не открыт.
    expect(find.byType(AddWishSheet), findsNothing);
    expect(find.byType(AddShoppingListSheet), findsNothing);
  });

  testWidgets('Chooser «Желание» collapses bar and opens wish sheet', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final bar = find.byType(AppBottomBar);
    await tester.tap(
      find.descendant(of: bar, matching: find.byTooltip('Добавить желание')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: bar, matching: find.text('Желание')));
    await tester.pumpAndSettle();

    expect(find.byType(AddWishSheet), findsOneWidget);
    // Bar вернулся в обычное состояние — навигация видна за sheet.
    expect(find.text('Покупки'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
  });

  testWidgets('Chooser «Список» collapses bar and opens list sheet', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final bar = find.byType(AppBottomBar);
    await tester.tap(
      find.descendant(of: bar, matching: find.byTooltip('Добавить желание')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: bar, matching: find.text('Список')));
    await tester.pumpAndSettle();

    expect(find.byType(AddWishListSheet), findsOneWidget);
    expect(find.text('Покупки'), findsWidgets);
    expect(find.text('Друзья'), findsOneWidget);
  });

  testWidgets('Tap outside expanded bar collapses chooser without sheet', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final bar = find.byType(AppBottomBar);
    await tester.tap(
      find.descendant(of: bar, matching: find.byTooltip('Добавить желание')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: bar, matching: find.text('Желание')),
      findsOneWidget,
    );

    // Тап по контенту вне бара — в центре body.
    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();

    expect(find.text('Покупки'), findsOneWidget);
    expect(find.text('Друзья'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Желание'), findsNothing);
    expect(find.text('Список'), findsNothing);
    expect(find.byType(AddWishSheet), findsNothing);
    expect(find.byType(AddShoppingListSheet), findsNothing);
  });

  testWidgets('Second tap on center «+» collapses chooser', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final bar = find.byType(AppBottomBar);
    final centerAdd = find.descendant(
      of: bar,
      matching: find.byTooltip('Добавить желание'),
    );

    await tester.tap(centerAdd);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: bar, matching: find.text('Желание')),
      findsOneWidget,
    );

    await tester.tap(centerAdd);
    await tester.pumpAndSettle();

    expect(find.text('Покупки'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.byType(AddWishSheet), findsNothing);
    expect(find.byType(AddShoppingListSheet), findsNothing);
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

    expect(find.byType(AddShoppingListSheet), findsOneWidget);
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

    expect(find.byType(AddFriendSheet), findsOneWidget);
  });

  testWidgets('Center add button color follows section; disabled on profile', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final expected = AppColors.lightThemeColors;

    AppAddActionButton centerButton() => tester.widget<AppAddActionButton>(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.byType(AppAddActionButton),
      ),
    );

    // Желания — брендовый primary, действие активно.
    expect(centerButton().color, expected.primary);
    expect(centerButton().onPressed, isNotNull);

    await tester.tap(find.text('Покупки'));
    await tester.pumpAndSettle();
    expect(centerButton().color, expected.accentShopping);
    expect(centerButton().onPressed, isNotNull);

    await tester.tap(find.text('Друзья'));
    await tester.pumpAndSettle();
    expect(centerButton().color, expected.accentFriends);
    expect(centerButton().onPressed, isNotNull);

    // Профиль — действия нет: кнопка визуально и функционально disabled.
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(centerButton().color, expected.surfaceMuted);
    expect(centerButton().onPressed, isNull);

    // Возврат к активному разделу — действие восстанавливается.
    await tester.tap(find.text('Что хочу'));
    await tester.pumpAndSettle();
    expect(centerButton().color, expected.primary);
    expect(centerButton().onPressed, isNotNull);
  });

  testWidgets('AddRow opens add-wish sheet', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Карточки стали выше — слот «добавить» за пределами
    // viewport и ещё не смонтирован: прокручиваем до него.
    await tester.scrollUntilVisible(find.byType(AddWishRow), 100);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AddWishRow));
    await tester.pumpAndSettle();

    expect(find.byType(AddWishSheet), findsOneWidget);
    expect(find.byType(WishFormPage), findsNothing);
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

    await tester.tap(find.byType(WishGridCard));
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
    expect(find.byType(WishGridCard), findsOneWidget);
    final cardSize = tester.getSize(find.byType(WishGridCard));
    // Высота grid-карточки вычисляется от ширины колонки —
    // обложка 4:3 + текстовый блок (WishGridCard.extentForColumnWidth).
    final columnWidth =
        (MediaQuery.sizeOf(tester.element(find.byType(WishGridCard))).width -
            AppSpacing.screenPaddingHorizontal * 2 -
            AppSpacing.betweenCards) /
        2;
    expect(cardSize.height, WishGridCard.extentForColumnWidth(columnWidth));
  });

  testWidgets('Wish with long imported title + price: no overflow', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishLongTitle]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    // Любой overflow бросит FlutterError при layout — тест упадёт сам.
    await tester.pumpAndSettle();

    expect(
      find.text('Портативная кофемашина автоматическая с нагревом'),
      findsOneWidget,
    );
    expect(find.text('3 217 ₽'), findsOneWidget);
    expect(find.byType(WishGridCard), findsOneWidget);
  });

  testWidgets('List extends under glass bar; last row clears it at end', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs(
        '[$_wishBook,$_wishLaptop,$_wishNoPrice,$_wishLongTitle]',
      ),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final scrollable = find.byType(CustomScrollView);
    final barRect = tester.getRect(find.byType(AppBottomBar));
    final viewportRect = tester.getRect(scrollable);

    // extendBody: вьюпорт доходит до нижней кромки экрана —
    // контент визуально продолжается под полупрозрачной планкой.
    expect(viewportRect.bottom, greaterThan(barRect.top));

    // Докрутка до конца: последний элемент выходит из-под
    // стекла — под ним остаётся ровно clearance бара.
    await tester.drag(scrollable, const Offset(0, -2000));
    await tester.pumpAndSettle();

    final rowRect = tester.getRect(find.byType(AddWishRow));
    // У строки собственный отступ md — её край выше кромки бара
    // на этот отступ; clearance за ней — ровно высота бара.
    expect(
      rowRect.bottom,
      moreOrLessEquals(barRect.top - AppSpacing.md, epsilon: 2),
    );
    expect(rowRect.bottom, lessThanOrEqualTo(barRect.top));
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

    // 800 logical px → wide layout: та же сетка в центрированной колонке.
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(WishGridCard), findsNWidgets(3));
    expect(find.byType(AddWishRow), findsOneWidget);
  });

  const listOwnerId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  /// Сидирует списки желаний с их outbox create-операциями —
  /// иначе reconcile при boot снимет строки, которых нет на
  /// сервере (offline-first: без pending-операции строка не
  /// защищена от remote-delete). Возвращает (db, listIds).
  Future<(AppDatabase, List<String>)> dbWithWishLists(
    List<String> titles,
  ) async {
    final db = createTestDatabase();
    final ids = <String>[];
    for (var i = 0; i < titles.length; i++) {
      final listId = 'list-000$i-0000-0000-0000-00000000000$i';
      ids.add(listId);
      final now = DateTime(2025, 1, 10 + i);
      await db
          .into(db.wishLists)
          .insert(
            WishListsCompanion(
              id: Value(listId),
              ownerId: const Value(listOwnerId),
              title: Value(titles[i]),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.outboxEntries)
          .insert(
            OutboxEntriesCompanion(
              ownerId: const Value(listOwnerId),
              entityType: const Value('wish_list'),
              entityId: Value(listId),
              operation: const Value('create'),
              payloadJson: Value(
                jsonEncode({'id': listId, 'title': titles[i]}),
              ),
              createdAt: Value(now),
            ),
          );
    }
    return (db, ids);
  }

  testWidgets('Home shows «Мои списки» grid above wishes', (tester) async {
    final (db, listIds) = await dbWithWishLists(['Подарки']);
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
      database: db,
      api: FakeApiAdapter(autoUserId: listOwnerId),
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Два желания через репозиторий (после стартового sync —
    // иначе reconcile снимет не-outbox'нутые строки), привязка —
    // доменным методом membership.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    final repo = container.read(wishRepositoryProvider);
    for (final title in ['A', 'B']) {
      final wish = await repo.createWish(title: title);
      await repo.assignWishToList(wish.id, listIds.first);
    }
    await tester.pumpAndSettle();

    expect(find.text('Мои списки'), findsOneWidget);
    expect(find.text('Мои желания'), findsOneWidget);
    expect(find.byType(WishListCard), findsOneWidget);
    expect(find.text('Подарки'), findsOneWidget);
    expect(find.text('2 желания'), findsOneWidget);
    // Две двухколоночные сетки: списки + желания.
    expect(find.byType(SliverGrid), findsNWidgets(2));
    // Списки выше желаний.
    final listsY = tester.getTopLeft(find.text('Мои списки')).dy;
    final wishesY = tester.getTopLeft(find.text('Мои желания')).dy;
    expect(listsY, lessThan(wishesY));
  });

  testWidgets('No «Мои списки» section without lists', (tester) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Мои списки'), findsNothing);
    expect(find.text('Мои желания'), findsOneWidget);
    expect(find.byType(SliverGrid), findsOneWidget);
  });

  testWidgets('Two wish lists render as 2-col grid row', (tester) async {
    final (db, _) = await dbWithWishLists(['Подарки', 'Дом']);
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
      database: db,
      api: FakeApiAdapter(autoUserId: listOwnerId),
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(WishListCard), findsNWidgets(2));
    // Одна строка grid — карточки на одной высоте, в одной строке.
    final first = tester.getTopLeft(find.byType(WishListCard).first);
    final second = tester.getTopLeft(find.byType(WishListCard).at(1));
    expect(first.dy, second.dy);
    expect(first.dx, lessThan(second.dx));
  });

  testWidgets('«+» → «+ Список» creates wish list shown on Home', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _authPrefs('[$_wishBook]'),
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(WishListCard), findsNothing);

    final bar = find.byType(AppBottomBar);
    await tester.tap(
      find.descendant(of: bar, matching: find.byTooltip('Добавить желание')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: bar, matching: find.text('Список')));
    await tester.pumpAndSettle();

    expect(find.byType(AddWishListSheet), findsOneWidget);
    expect(find.text('Новый список желаний'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Подарки родителям');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    // Sheet закрылся, список появился на Home.
    expect(find.byType(AddWishListSheet), findsNothing);
    expect(find.text('Подарки родителям'), findsOneWidget);
    expect(find.byType(WishListCard), findsOneWidget);
    expect(find.text('Мои списки'), findsOneWidget);
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

    // 360 logical px → узкий layout: те же двухколоночные сетки.
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(WishGridCard), findsNWidgets(2));
  });
}
