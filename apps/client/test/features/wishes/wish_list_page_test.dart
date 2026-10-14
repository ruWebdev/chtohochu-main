import 'package:chtohochu/core/database/database_provider.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:chtohochu/features/wishes/domain/wish.dart';
import 'package:chtohochu/features/wishes/domain/wish_image.dart';
import 'package:chtohochu/features/wishes/domain/wish_list.dart';
import 'package:chtohochu/features/wishes/presentation/pages/home_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_details_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/wish_list_page.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/wish_card.dart';
import 'package:chtohochu/features/wishes/presentation/widgets/wish_list_card.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:chtohochu/shared/ui/lists/app_list_item.dart';
import 'package:chtohochu/shared/ui/scaffolding/app_screen_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

Map<String, Object> _authPrefs([String wishesCache = '[]']) => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
  'wishes_cache': wishesCache,
};

const _uid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

Map<String, dynamic> _serverWish(String id, String title, {String? listId}) => {
  'id': id,
  'title': title,
  'description': null,
  'price': null,
  'link': null,
  'image_url': null,
  'list_id': listId,
  'created_at': '2025-01-01T00:00:00.000Z',
  'updated_at': '2025-01-01T00:00:00.000Z',
};

void main() {
  /// Приложение с boot-pull: список и желания приходят «с сервера» —
  /// Drift заполняется обычным reconcile, без ручного сидирования.
  Future<(Widget, FakeApiAdapter)> appWithList({
    List<Map<String, dynamic>> wishes = const [],
    List<String> extraListTitles = const [],
    String listTitle = 'Техника',
  }) async {
    final api = FakeApiAdapter(autoUserId: _uid);
    api.seedWishList(_uid, 'list-1', listTitle);
    for (var i = 0; i < extraListTitles.length; i++) {
      api.seedWishList(_uid, 'list-x$i', extraListTitles[i]);
    }
    for (final w in wishes) {
      api.seedWish(_uid, w);
    }
    final widget = await createTestApp(
      preferences: _authPrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    return (widget, api);
  }

  /// Home → тап по карточке списка → WishListPage.
  Future<void> openListPage(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(WishListCard, 'Техника'));
    await tester.pumpAndSettle();
    expect(find.byType(WishListPage), findsOneWidget);
  }

  testWidgets('Желания любого приоритета — единый список без групп '
      'и маркеров', (tester) async {
    final (widget, _) = await appWithList(
      wishes: [
        {
          ..._serverWish('w1', 'Отложенное', listId: 'list-1'),
          'priority': 'later',
        },
        {..._serverWish('w2', 'Срочное', listId: 'list-1'), 'priority': 'high'},
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await openListPage(tester);

    // Оба желания — в единой сетке; группировка «Не сейчас»
    // и high-маркер — прерогатива только Home.
    expect(find.byType(WishGridCard), findsNWidgets(2));
    expect(find.text('Отложенное'), findsOneWidget);
    expect(find.text('Срочное'), findsOneWidget);
    expect(find.text('Не сейчас · 1'), findsNothing);
    expect(find.byIcon(PhosphorIconsFill.heart), findsNothing);
  });

  testWidgets('Tap on WishListCard opens WishListPage with title and '
      'count subtitle', (tester) async {
    final (widget, _) = await appWithList(
      wishes: [_serverWish('w1', 'Наушники', listId: 'list-1')],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);

    await openListPage(tester);

    // Заголовок AppScreenTitle + счётчик вторичным текстом.
    final header = tester.widget<AppScreenTitle>(find.byType(AppScreenTitle));
    expect(header.title, 'Техника');
    expect(header.subtitle, '1 желание');
  });

  testWidgets('List wishes render as WishGridCard; wishes outside the '
      'list are not shown', (tester) async {
    final (widget, _) = await appWithList(
      wishes: [
        _serverWish('w1', 'Наушники', listId: 'list-1'),
        _serverWish('w2', 'Клавиатура', listId: 'list-1'),
        _serverWish('w3', 'Поездка'), // вне списка
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await openListPage(tester);

    expect(find.byType(WishGridCard), findsNWidgets(2));
    expect(find.text('Наушники'), findsOneWidget);
    expect(find.text('Клавиатура'), findsOneWidget);
    expect(find.text('Поездка'), findsNothing);
    // Та же двухколоночная сетка, что на Home.
    expect(find.byType(SliverGrid), findsOneWidget);
  });

  testWidgets('Empty list shows AppEmptyState', (tester) async {
    final (widget, _) = await appWithList();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await openListPage(tester);

    expect(find.text('Техника'), findsOneWidget);
    expect(find.text('Список пуст'), findsOneWidget);
    expect(
      find.text('Добавь желание в этот список — и оно появится здесь.'),
      findsOneWidget,
    );
    expect(find.byType(WishGridCard), findsNothing);
  });

  testWidgets('Reactive membership: assign/unassign updates the page '
      'without refresh', (tester) async {
    final (widget, _) = await appWithList(
      wishes: [
        _serverWish('w1', 'Наушники', listId: 'list-1'),
        _serverWish('w2', 'Свитер'),
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await openListPage(tester);
    expect(find.byType(WishGridCard), findsNWidgets(1));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WishListPage)),
    );
    final repo = container.read(wishRepositoryProvider);

    // Внешнее желание входит в список → появляется на экране.
    await repo.assignWishToList('w2', 'list-1');
    await tester.pumpAndSettle();
    expect(find.byType(WishGridCard), findsNWidgets(2));
    expect(find.text('Свитер'), findsOneWidget);

    // Желание убирается из списка → исчезает, счётчик обновляется.
    await repo.assignWishToList('w1', null);
    await tester.pumpAndSettle();
    expect(find.byType(WishGridCard), findsNWidgets(1));
    expect(find.text('Наушники'), findsNothing);
    final header = tester.widget<AppScreenTitle>(find.byType(AppScreenTitle));
    expect(header.subtitle, '1 желание');
  });

  testWidgets('Back returns to Home with updated wishCount on the '
      'list card', (tester) async {
    final (widget, _) = await appWithList(
      wishes: [_serverWish('w1', 'Наушники', listId: 'list-1')],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await openListPage(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WishListPage)),
    );
    // Membership изменился «заглазно» — возврат покажет актуальный count.
    await container.read(wishRepositoryProvider).assignWishToList('w1', null);
    await tester.pumpAndSettle();
    expect(find.text('Список пуст'), findsOneWidget);

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('0 желаний'), findsOneWidget);
    expect(find.byType(WishListCard), findsOneWidget);
  });

  group('«Добавить желание» — picker несгруппированных', () {
    testWidgets('picker показывает только желания без списка; выбор '
        'добавляет желание и обновляет счётчик', (tester) async {
      final (widget, api) = await appWithList(
        extraListTitles: ['Дом'],
        wishes: [
          _serverWish('w1', 'Наушники', listId: 'list-1'),
          _serverWish('w2', 'Свитер'), // без списка
          _serverWish('w3', 'Лампа', listId: 'list-x0'), // в «Дом»
        ],
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);
      expect(find.byType(WishGridCard), findsNWidgets(1));

      // Действие в app bar открывает picker.
      await tester.tap(find.byTooltip('Добавить желание'));
      await tester.pumpAndSettle();

      // Только несгруппированные: «Свитер» виден, «Наушники»
      // (этот список) и «Лампа» (другой список) — нет. Поиск
      // внутри sheet — карточки страницы остаются под ним.
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Свитер')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Наушники')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Лампа')),
        findsNothing,
      );

      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Свитер')),
      );
      await tester.pumpAndSettle();

      // Sheet закрыт, желание на странице, счётчик вырос.
      expect(find.byType(WishGridCard), findsNWidgets(2));
      expect(find.text('Свитер'), findsOneWidget);
      final header = tester.widget<AppScreenTitle>(find.byType(AppScreenTitle));
      expect(header.subtitle, '2 желания');
      // Сервер получил membership (offline-first → PATCH доехал).
      expect(
        api.wishesOf(_uid).firstWhere((w) => w['id'] == 'w2')['list_id'],
        'list-1',
      );
    });

    testWidgets('все желания разложены → empty state в picker', (tester) async {
      final (widget, _) = await appWithList(
        wishes: [
          _serverWish('w1', 'Наушники', listId: 'list-1'),
          _serverWish('w3', 'Лампа', listId: 'list-x0'),
        ],
        extraListTitles: ['Дом'],
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      await tester.tap(find.byTooltip('Добавить желание'));
      await tester.pumpAndSettle();

      expect(find.text('Нет желаний без списка'), findsOneWidget);
      expect(
        find.text('Все желания уже разложены по спискам.'),
        findsOneWidget,
      );
    });
  });

  group('Управление списком — меню «Ещё»', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Ещё'));
      await tester.pumpAndSettle();
    }

    testWidgets('бар: «Добавить желание», «Поделиться» и «Ещё» — '
        'прямые кнопки', (tester) async {
      final (widget, _) = await appWithList();
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      expect(find.byTooltip('Назад'), findsOneWidget);
      expect(find.byTooltip('Добавить желание'), findsOneWidget);
      expect(find.byTooltip('Поделиться'), findsOneWidget);
      expect(find.byTooltip('Ещё'), findsOneWidget);
      // Переименование/удаление не вынесены на бар — живут в шите.
      expect(find.byTooltip('Переименовать'), findsNothing);
      expect(find.byTooltip('Удалить список'), findsNothing);
    });

    testWidgets('меню-шит: заголовок = название списка, разделитель и '
        'красное «Удалить список»', (tester) async {
      final (widget, _) = await appWithList();
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      await openMenu(tester);

      // Flat bottom sheet: заголовок = название списка.
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Техника')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.widgetWithText(AppListItem, 'Переименовать'),
        ),
        findsOneWidget,
      );
      // Разделитель перед destructive-действием.
      expect(
        find.descendant(of: sheet, matching: find.byType(AppListDivider)),
        findsOneWidget,
      );
      final deleteItem = tester.widget<AppListItem>(
        find.widgetWithText(AppListItem, 'Удалить список'),
      );
      expect(deleteItem.destructive, isTrue);
    });

    testWidgets('меню содержит «Переименовать» и «Удалить список»; '
        'переименование обновляет заголовок, сервер и Home', (tester) async {
      final (widget, api) = await appWithList(
        wishes: [_serverWish('w1', 'Наушники', listId: 'list-1')],
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      await openMenu(tester);
      expect(find.widgetWithText(AppListItem, 'Переименовать'), findsOneWidget);
      expect(
        find.widgetWithText(AppListItem, 'Удалить список'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(AppListItem, 'Переименовать'));
      await tester.pumpAndSettle();

      // Sheet в режиме переименования: заголовок + текущее
      // название предзаполнено, «Сохранить» выключена пока
      // название не изменилось.
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Переименовать список')),
        findsOneWidget,
      );
      final field = find.descendant(
        of: sheet,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).controller!.text, 'Техника');
      final saveButton = find.widgetWithText(AppButton, 'Сохранить');
      expect(tester.widget<AppButton>(saveButton).enabled, isFalse);

      // Пустое/пробельное название не сохраняется.
      await tester.enterText(field, '   ');
      await tester.pump();
      expect(tester.widget<AppButton>(saveButton).enabled, isFalse);

      await tester.enterText(field, 'Гаджеты');
      await tester.pump();
      expect(tester.widget<AppButton>(saveButton).enabled, isTrue);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Заголовок страницы обновлён реактивно; PATCH доехал до
      // сервера через существующий outbox-путь.
      var header = tester.widget<AppScreenTitle>(find.byType(AppScreenTitle));
      expect(header.title, 'Гаджеты');
      expect(
        api.wishListsOf(_uid).firstWhere((l) => l['id'] == 'list-1')['title'],
        'Гаджеты',
      );

      // Home показывает карточку с новым названием.
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.widgetWithText(WishListCard, 'Гаджеты'), findsOneWidget);
    });

    testWidgets('удаление: подтверждение объясняет, что желания '
        'остаются; список удаляется, желания разгруппированы, '
        'возврат на Home', (tester) async {
      final (widget, api) = await appWithList(
        wishes: [
          _serverWish('w1', 'Наушники', listId: 'list-1'),
          _serverWish('w2', 'Свитер', listId: 'list-1'),
        ],
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      await openMenu(tester);
      await tester.tap(find.widgetWithText(AppListItem, 'Удалить список'));
      await tester.pumpAndSettle();

      // Подтверждение: список удаляется, желания — нет.
      expect(find.text('Удалить список?'), findsOneWidget);
      expect(find.textContaining('Желания из него останутся'), findsOneWidget);

      // Отмена не меняет ничего.
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.byType(WishListPage), findsOneWidget);
      expect(api.wishListsOf(_uid), hasLength(1));
      expect(find.byType(WishGridCard), findsNWidgets(2));

      // Подтверждаем удаление.
      await openMenu(tester);
      await tester.tap(find.widgetWithText(AppListItem, 'Удалить список'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Удалить'));
      await tester.pumpAndSettle();

      // Автоматический возврат на Home; карточка списка исчезла,
      // желания остались в общем разделе.
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(WishListCard), findsNothing);
      expect(find.text('Наушники'), findsOneWidget);
      expect(find.text('Свитер'), findsOneWidget);

      // Сервер: список удалён, желания разгруппированы, а не
      // удалены.
      expect(api.wishListsOf(_uid), isEmpty);
      final wishes = api.wishesOf(_uid);
      expect(wishes, hasLength(2));
      expect(wishes.every((w) => w['list_id'] == null), isTrue);
    });

    testWidgets('«Поделиться» запрашивает share-ссылку и открывает '
        'системный Share с URL', (tester) async {
      final shareCalls = <MethodCall>[];
      mockShareChannel(tester, shareCalls);
      final (widget, api) = await appWithList();
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      await tester.tap(find.byTooltip('Поделиться'));
      await tester.pumpAndSettle();

      expect(
        api.requests.where((r) => r == 'POST /wish-lists/list-1/share'),
        hasLength(1),
      );
      expect(shareCalls, hasLength(1));
      expect(
        shareCalls.single.arguments['text'] as String,
        startsWith('https://app.chtohochu.ru/s/'),
      );
    });

    testWidgets('ошибка API при share — snackbar, Share sheet не '
        'открывается', (tester) async {
      final shareCalls = <MethodCall>[];
      mockShareChannel(tester, shareCalls);
      final (widget, api) = await appWithList();
      api.failures['POST /wish-lists/list-1/share'] = 500;
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      await tester.tap(find.byTooltip('Поделиться'));
      await tester.pumpAndSettle();

      expect(
        find.text('Произошла ошибка. Попробуй ещё раз.'),
        findsOneWidget,
      );
      expect(shareCalls, isEmpty);
    });

    testWidgets('повторное «Поделиться» во время запроса не создаёт '
        'второй POST', (tester) async {
      mockShareChannel(tester, <MethodCall>[]);
      final (widget, api) = await appWithList();
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);
      // Задержка только на share-запросе, после boot-pull. Большая —
      // чтобы повторный тап гарантированно пришёлся на полёт запроса.
      api.latency = const Duration(seconds: 60);

      await tester.tap(find.byTooltip('Поделиться'));
      await tester.pump(); // запрос ещё в полёте (latency)
      await tester.tap(find.byTooltip('Поделиться'));
      await tester.pumpAndSettle();

      // Добиваем таймер задержки — первый запрос завершается.
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();

      expect(
        api.requests.where((r) => r == 'POST /wish-lists/list-1/share'),
        hasLength(1),
      );
    });
  });

  group('«Убрать из списка» — long-press по карточке', () {
    testWidgets('выбор действия сбрасывает membership: карточка '
        'исчезает, счётчик уменьшается, желание живо и видно '
        'на Home', (tester) async {
      final (widget, api) = await appWithList(
        wishes: [
          _serverWish('w1', 'Наушники', listId: 'list-1'),
          _serverWish('w2', 'Свитер', listId: 'list-1'),
        ],
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);
      expect(find.byType(WishGridCard), findsNWidgets(2));

      // Long-press открывает sheet действий с названием желания.
      await tester.longPress(find.widgetWithText(WishGridCard, 'Свитер'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Свитер')),
        findsOneWidget,
      );
      final action = find.descendant(
        of: sheet,
        matching: find.text('Убрать из списка'),
      );
      expect(action, findsOneWidget);

      await tester.tap(action);
      await tester.pumpAndSettle();

      // Желание исчезло из списка, счётчик и feedback обновились.
      expect(find.byType(WishGridCard), findsNWidgets(1));
      expect(find.text('Свитер'), findsNothing);
      final header = tester.widget<AppScreenTitle>(find.byType(AppScreenTitle));
      expect(header.subtitle, '1 желание');
      expect(find.text('Желание убрано из списка'), findsOneWidget);

      // Сервер получил list_id = null; само желание не удалено.
      expect(
        api.wishesOf(_uid).firstWhere((w) => w['id'] == 'w2')['list_id'],
        isNull,
      );
      expect(api.wishesOf(_uid), hasLength(2));

      // Возврат на Home: желание в общем разделе, список с count 1.
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Свитер'), findsOneWidget);
      expect(find.widgetWithText(WishListCard, '1 желание'), findsOneWidget);
    });

    testWidgets('обычный tap по карточке по-прежнему открывает '
        'WishDetailsPage', (tester) async {
      final (widget, _) = await appWithList(
        wishes: [_serverWish('w1', 'Наушники', listId: 'list-1')],
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      await tester.tap(find.widgetWithText(WishGridCard, 'Наушники'));
      await tester.pumpAndSettle();

      expect(find.byType(WishDetailsPage), findsOneWidget);
      expect(find.text('Наушники'), findsOneWidget);
    });

    testWidgets('ошибка assign → карточка остаётся и показывается '
        'error feedback', (tester) async {
      final api = FakeApiAdapter(autoUserId: _uid);
      api.seedWishList(_uid, 'list-1', 'Техника');
      api.seedWish(_uid, _serverWish('w1', 'Наушники', listId: 'list-1'));
      final widget = await createTestApp(
        preferences: _authPrefs(),
        secureStorage: {'access_token': 'mock_token'},
        api: api,
        overrides: [
          // Реальный Drift-репозиторий, но assignWishToList падает.
          wishRepositoryProvider.overrideWith(
            (ref) => _FailAssignRepo(
              DriftWishRepository(
                ref.read(appDatabaseProvider),
                ref.read(preferencesServiceProvider),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await openListPage(tester);

      await tester.longPress(find.widgetWithText(WishGridCard, 'Наушники'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Убрать из списка'));
      await tester.pumpAndSettle();

      // Карточка не исчезла, показан error feedback, membership
      // на сервере не изменился.
      expect(find.byType(WishListPage), findsOneWidget);
      expect(find.byType(WishGridCard), findsOneWidget);
      expect(find.text('Наушники'), findsOneWidget);
      expect(
        find.text('Произошла ошибка. Попробуй ещё раз.'),
        findsOneWidget,
      );
      expect(
        api.wishesOf(_uid).firstWhere((w) => w['id'] == 'w1')['list_id'],
        'list-1',
      );
    });
  });
}

/// Мокает method-channel `share_plus` и складывает вызовы системного
/// Share sheet в [calls] для проверки в тестах.
void mockShareChannel(WidgetTester tester, List<MethodCall> calls) {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    calls.add(call);
    return '';
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

/// Обёртка над настоящим репозиторием: все вызовы делегируются,
/// но `assignWishToList` падает — для проверки error feedback
/// при сбое membership-операции.
class _FailAssignRepo implements WishRepository {
  _FailAssignRepo(this._inner);

  final WishRepository _inner;

  @override
  Future<Wish> assignWishToList(String wishId, String? listId) =>
      throw const UnknownWishError();

  @override
  Stream<List<Wish>> watchWishes() => _inner.watchWishes();
  @override
  Future<List<Wish>> getWishes() => _inner.getWishes();
  @override
  Future<Wish?> getWishById(String id) => _inner.getWishById(id);
  @override
  Future<bool> hasWishes() => _inner.hasWishes();
  @override
  Stream<List<WishList>> watchWishLists() => _inner.watchWishLists();
  @override
  Stream<List<Wish>> watchWishesInList(String listId) =>
      _inner.watchWishesInList(listId);
  @override
  Future<WishList> createWishList({required String title}) =>
      _inner.createWishList(title: title);
  @override
  Future<WishList> updateWishList(WishList list) => _inner.updateWishList(list);
  @override
  Future<void> deleteWishList(String id) => _inner.deleteWishList(id);
  @override
  Stream<List<WishImage>> watchWishImages(String wishId) =>
      _inner.watchWishImages(wishId);
  @override
  Future<List<WishImage>> getWishImages(String wishId) =>
      _inner.getWishImages(wishId);
  @override
  Future<Wish> createWish({
    required String title,
    String? description,
    int? price,
    String? link,
    String? imageUrl,
    WishPriority priority = WishPriority.normal,
    List<String> additionalImagePaths = const [],
  }) => _inner.createWish(
    title: title,
    description: description,
    price: price,
    link: link,
    imageUrl: imageUrl,
    priority: priority,
    additionalImagePaths: additionalImagePaths,
  );
  @override
  Future<Wish> updateWish(Wish wish, {List<WishImageInput>? images}) =>
      _inner.updateWish(wish, images: images);
  @override
  Future<void> deleteWish(String id) => _inner.deleteWish(id);
}
