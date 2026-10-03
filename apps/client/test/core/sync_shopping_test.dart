import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/sync/sync_engine.dart';
import 'package:chtohochu/features/shopping/data/shopping_repository.dart';
import 'package:chtohochu/features/shopping/domain/shopping_list.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_app.dart';

/// Offline-first Shopping: push/pull синхронизация списков и позиций
/// через общий outbox + SyncEngine. Проверяет parent→child ordering,
/// compaction, HTTP-семантику, snapshot reconcile, изоляцию аккаунтов.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const ownerA = 'user-a';
  const ownerB = 'user-b';
  const token = 'token-a';

  late AppDatabase db;
  late FakeApiAdapter api;
  late Dio dio;
  late SyncEngine engine;
  late DriftShoppingRepository repo;
  late PreferencesService prefs;
  late List<SyncStatus> statuses;
  late bool unauthorizedCalled;

  Future<List<OutboxEntry>> outboxOf(String ownerId) {
    return (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(ownerId))).get();
  }

  Future<ShoppingListRow?> listRowOf(String id) => (db.select(
    db.shoppingLists,
  )..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<ShoppingItemRow?> itemRowOf(String id) => (db.select(
    db.shoppingItems,
  )..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<void> sync() => engine.requestSync();

  List<String> mutatingRequests() =>
      api.requests.where((r) => !r.startsWith('GET')).toList();

  /// Детерминированный «оффлайн»: detach гасит outbox-listener,
  /// мутации копятся без автосинка; attach = reconnect.
  Future<void> offline(Future<void> Function() mutations) async {
    engine.detach();
    await mutations();
    engine.attach(ownerA);
  }

  setUp(() async {
    setupTestStorage(
      preferences: {'current_user_id': ownerA},
      secureStorage: {'access_token': token},
    );
    prefs = PreferencesService(await SharedPreferences.getInstance());
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = DriftShoppingRepository(db, prefs);
    api = FakeApiAdapter(autoUserId: ownerA);
    dio = createTestApiClient(api);
    statuses = [];
    unauthorizedCalled = false;
    engine = SyncEngine(
      db: db,
      dio: dio,
      onUnauthorized: () => unauthorizedCalled = true,
      onStatus: statuses.add,
    );
    engine.attach(ownerA);
    await sync(); // стартовый pull на пустом сервере
    statuses.clear();
  });

  tearDown(() async {
    engine.detach();
    await db.close();
  });

  group('push: базовые операции', () {
    test('create list → POST с клиентским UUID → outbox снят', () async {
      final list = await repo.createList(title: 'Продукты');
      await sync();

      expect(await outboxOf(ownerA), isEmpty);
      final server = api.shoppingListsOf(ownerA).single;
      expect(server['id'], list.id); // identity не перемаплена
      expect(server['title'], 'Продукты');
    });

    test('add item → POST /shopping-lists/{id}/items с list_id', () async {
      late String listId;
      late String itemId;
      await offline(() async {
        final list = await repo.createList(title: 'Продукты');
        listId = list.id;
        final item = await repo.addItem(
          listId: list.id,
          title: 'Молоко',
          quantity: 2,
        );
        itemId = item.id;
      });
      api.requests.clear();

      await sync();

      expect(mutatingRequests(), [
        'POST /shopping-lists',
        'POST /shopping-lists/$listId/items',
      ]);
      final serverItem = api.shoppingItemOf(ownerA, itemId)!;
      expect(serverItem['title'], 'Молоко');
      expect(serverItem['quantity'], 2);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('rename list → PATCH /shopping-lists/{id}', () async {
      final list = await repo.createList(title: 'v1');
      await sync();

      await offline(() => repo.updateList(list.copyWith(title: 'Новое имя')));
      api.requests.clear();
      await sync();

      expect(mutatingRequests(), ['PATCH /shopping-lists/${list.id}']);
      expect(api.shoppingListsOf(ownerA).single['title'], 'Новое имя');
    });

    test('update item → PATCH /shopping-items/{id} со всеми полями', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      await sync();

      await offline(
        () => repo.updateItem(
          item.copyWith(title: 'Кефир', quantity: 3, isChecked: true),
          listId: list.id,
        ),
      );
      api.requests.clear();
      await sync();

      expect(mutatingRequests(), ['PATCH /shopping-items/${item.id}']);
      final server = api.shoppingItemOf(ownerA, item.id)!;
      expect(server['title'], 'Кефир');
      expect(server['quantity'], 3);
      expect(server['is_checked'], true);
    });

    test(
      'delete list → один DELETE; позиции уходят без своих DELETE',
      () async {
        final list = await repo.createList(title: 'L');
        await repo.addItem(listId: list.id, title: 'A');
        await repo.addItem(listId: list.id, title: 'B');
        await sync();

        await offline(() => repo.deleteList(list.id));
        expect(await repo.getLists(), isEmpty); // сразу скрыто из UI
        api.requests.clear();
        await sync();

        // Сервер каскадно удалит позиции — отдельные item-DELETE
        // не отправляются.
        expect(mutatingRequests(), ['DELETE /shopping-lists/${list.id}']);
        expect(api.shoppingListsOf(ownerA), isEmpty);
        expect(await listRowOf(list.id), isNull);
      },
    );

    test('delete item → DELETE /shopping-items/{id}', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      await sync();

      await offline(() => repo.deleteItem(item.id, listId: list.id));
      expect((await repo.getLists()).single.items, isEmpty);
      api.requests.clear();
      await sync();

      expect(mutatingRequests(), ['DELETE /shopping-items/${item.id}']);
      expect(api.shoppingItemOf(ownerA, item.id), isNull);
      expect(await itemRowOf(item.id), isNull);
    });
  });

  group('compaction', () {
    test('list: create + update → один POST с финальным title', () async {
      await offline(() async {
        final list = await repo.createList(title: 'v1');
        await repo.updateList(list.copyWith(title: 'v2'));
      });
      api.requests.clear();

      await sync();

      expect(mutatingRequests(), ['POST /shopping-lists']);
      expect(api.shoppingListsOf(ownerA).single['title'], 'v2');
    });

    test('list: create + delete → ноль HTTP-операций', () async {
      late String listId;
      await offline(() async {
        final list = await repo.createList(title: 'L');
        listId = list.id;
        await repo.deleteList(list.id);
      });
      api.requests.clear();

      await sync();

      expect(mutatingRequests(), isEmpty);
      expect(api.shoppingListsOf(ownerA), isEmpty);
      expect(await listRowOf(listId), isNull);
    });

    test('list: update + update → один PATCH с последним title', () async {
      final list = await repo.createList(title: 'v1');
      await sync();

      await offline(() async {
        await repo.updateList(list.copyWith(title: 'v2'));
        await repo.updateList(list.copyWith(title: 'v3'));
      });
      api.requests.clear();
      await sync();

      expect(mutatingRequests(), ['PATCH /shopping-lists/${list.id}']);
      expect(api.shoppingListsOf(ownerA).single['title'], 'v3');
    });

    test('list: update + delete → один DELETE', () async {
      final list = await repo.createList(title: 'v1');
      await sync();

      await offline(() async {
        await repo.updateList(list.copyWith(title: 'v2'));
        await repo.deleteList(list.id);
      });
      api.requests.clear();
      await sync();

      expect(mutatingRequests(), ['DELETE /shopping-lists/${list.id}']);
      expect(api.shoppingListsOf(ownerA), isEmpty);
    });

    test('item: create + update → один POST с финальным состоянием', () async {
      late String listId;
      late String itemId;
      await offline(() async {
        final list = await repo.createList(title: 'L');
        listId = list.id;
        final item = await repo.addItem(listId: list.id, title: 'v1');
        itemId = item.id;
        await repo.updateItem(
          item.copyWith(title: 'v2', quantity: 5),
          listId: list.id,
        );
      });
      api.requests.clear();

      await sync();

      // is_checked не расходится → follow-up PATCH не нужен:
      // один POST с финальным title/quantity.
      final posts = api.requests.where(
        (r) => r == 'POST /shopping-lists/$listId/items',
      );
      expect(posts, hasLength(1));
      final server = api.shoppingItemOf(ownerA, itemId)!;
      expect(server['title'], 'v2');
      expect(server['quantity'], 5);
    });

    test('item: create + delete → ноль HTTP для позиции', () async {
      late String itemId;
      await offline(() async {
        final list = await repo.createList(title: 'L');
        final item = await repo.addItem(listId: list.id, title: 'Молоко');
        itemId = item.id;
        await repo.deleteItem(item.id, listId: list.id);
      });
      api.requests.clear();

      await sync();

      // Уходит только create списка; позиция никогда не существовала.
      expect(mutatingRequests(), ['POST /shopping-lists']);
      expect(api.shoppingItemOf(ownerA, itemId), isNull);
      expect(await itemRowOf(itemId), isNull);
    });

    test('item: update + update → один PATCH', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'v1');
      await sync();

      await offline(() async {
        await repo.updateItem(item.copyWith(title: 'v2'), listId: list.id);
        await repo.updateItem(item.copyWith(title: 'v3'), listId: list.id);
      });
      api.requests.clear();
      await sync();

      expect(mutatingRequests(), ['PATCH /shopping-items/${item.id}']);
      expect(api.shoppingItemOf(ownerA, item.id)!['title'], 'v3');
    });

    test('item: update + delete → один DELETE', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'v1');
      await sync();

      await offline(() async {
        await repo.updateItem(item.copyWith(title: 'v2'), listId: list.id);
        await repo.deleteItem(item.id, listId: list.id);
      });
      api.requests.clear();
      await sync();

      expect(mutatingRequests(), ['DELETE /shopping-items/${item.id}']);
      expect(api.shoppingItemOf(ownerA, item.id), isNull);
    });

    test(
      'create list → add item → delete list: ноль HTTP, чистая БД',
      () async {
        late String listId;
        await offline(() async {
          final list = await repo.createList(title: 'L');
          listId = list.id;
          await repo.addItem(listId: list.id, title: 'Молоко');
          await repo.deleteList(list.id);
        });
        api.requests.clear();

        await sync();

        // Родитель удалён до sync — дочерний create недействителен
        // и не должен уйти на сервер.
        expect(mutatingRequests(), isEmpty);
        expect(api.shoppingListsOf(ownerA), isEmpty);
        expect(await listRowOf(listId), isNull);
        expect(
          (db.select(
            db.shoppingItems,
          )..where((i) => i.listId.equals(listId))).get(),
          completion(isEmpty),
        );
        expect(await outboxOf(ownerA), isEmpty);
      },
    );
  });

  group('parent → child ordering', () {
    test(
      'offline create list + item: POST списка строго раньше POST item',
      () async {
        late String listId;
        late String itemId;
        await offline(() async {
          final list = await repo.createList(title: 'L');
          listId = list.id;
          final item = await repo.addItem(listId: list.id, title: 'Молоко');
          itemId = item.id;
        });
        api.requests.clear();

        await sync();

        final mutating = mutatingRequests();
        expect(
          mutating.indexOf('POST /shopping-lists'),
          lessThan(mutating.indexOf('POST /shopping-lists/$listId/items')),
        );
        expect(api.shoppingItemOf(ownerA, itemId), isNotNull);
      },
    );

    test('create списка отложен (500): item-операция не уходит', () async {
      api.failures['POST /shopping-lists'] = 500;
      late String listId;
      late String itemId;
      await offline(() async {
        final list = await repo.createList(title: 'L');
        listId = list.id;
        final item = await repo.addItem(listId: list.id, title: 'Молоко');
        itemId = item.id;
      });
      api.requests.clear();
      await sync();

      // Список не принят (backoff) — child-операция deferred без
      // попытки: сервер не видел ни списка, ни позиции.
      expect(api.shoppingListsOf(ownerA), isEmpty);
      expect(api.requests.where((r) => r.contains('/items')), isEmpty);

      // Backoff списка истёк + сбой устранён: список уходит,
      // следом — позиция.
      api.failures.clear();
      await (db.update(db.outboxEntries)
            ..where((o) => o.ownerId.equals(ownerA)))
          .write(const OutboxEntriesCompanion(nextRetryAt: Value(null)));
      await sync();

      final mutating = mutatingRequests();
      expect(
        mutating.indexOf('POST /shopping-lists'),
        lessThan(mutating.indexOf('POST /shopping-lists/$listId/items')),
      );
      expect(api.shoppingItemOf(ownerA, itemId), isNotNull);
    });

    test(
      'failed create списка: item ждёт; rename реанимирует цепочку',
      () async {
        api.failures['POST /shopping-lists'] = 422;
        late ShoppingList list;
        await offline(() async {
          list = await repo.createList(title: 'Битый');
          await repo.addItem(listId: list.id, title: 'Молоко');
        });
        api.requests.clear();
        await sync();

        expect(api.requests.where((r) => r.contains('/items')), isEmpty);

        // Пользователь исправил название — create списка реанимирован.
        // updateList диффит позиции: передаём актуальный список с item.
        api.failures.clear();
        final fresh = await repo.getListById(list.id);
        await repo.updateList(fresh!.copyWith(title: 'Исправленный'));
        await sync();

        expect(api.shoppingListsOf(ownerA).single['title'], 'Исправленный');
        expect(api.shoppingListsOf(ownerA).single['items'], hasLength(1));
        expect(await outboxOf(ownerA), isEmpty);
      },
    );
  });

  group('is_checked divergence (server не принимает при create)', () {
    test(
      'create+check offline → POST + follow-up PATCH → сервер видит checked',
      () async {
        late String listId;
        late String itemId;
        await offline(() async {
          final list = await repo.createList(title: 'L');
          listId = list.id;
          final item = await repo.addItem(listId: list.id, title: 'Молоко');
          itemId = item.id;
          // Compaction: check схлопнулся в create с is_checked: true,
          // но сервер игнорирует его при POST (default false).
          await repo.updateItem(
            item.copyWith(isChecked: true),
            listId: list.id,
          );
        });
        api.requests.clear();

        await sync();

        expect(mutatingRequests(), [
          'POST /shopping-lists',
          'POST /shopping-lists/$listId/items',
          'PATCH /shopping-items/$itemId', // divergence follow-up
        ]);
        expect(api.shoppingItemOf(ownerA, itemId)!['is_checked'], true);
        // Локально отметка сохранена всё это время.
        expect((await itemRowOf(itemId))!.isChecked, isTrue);
      },
    );

    test(
      'lost response → 409 → эхо наше → is_checked довозится follow-up\'ом',
      () async {
        final list = await repo.createList(title: 'L');
        await sync();

        final item = await repo.addItem(listId: list.id, title: 'Молоко');
        await repo.updateItem(item.copyWith(isChecked: true), listId: list.id);
        // Lost response: POST фактически выполнился (is_checked
        // сервер не сохранил при create — default false), ответ
        // потерян → retry получит 409, reconcile-GET вернёт нашу
        // же сущность без is_checked.
        api.seedShoppingList(
          ownerA,
          list.id,
          'L',
          items: [
            {'id': item.id, 'title': 'Молоко'},
          ],
        );
        await sync();

        // Намерение «отмечено» не потеряно reconcile'ом.
        expect(api.shoppingItemOf(ownerA, item.id)!['is_checked'], true);
        expect((await itemRowOf(item.id))!.isChecked, isTrue);
        expect(await outboxOf(ownerA), isEmpty);
      },
    );

    test('409 на чужую сущность (данные не совпадают с отправленными) → '
        'серверное представление принято без follow-up\'а', () async {
      final list = await repo.createList(title: 'L');
      await sync();

      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      // Identity занята чужой позицией — серверные данные
      // отличаются от отправленных.
      api.seedShoppingList(
        ownerA,
        list.id,
        'L',
        items: [
          {'id': item.id, 'title': 'Чужая позиция', 'quantity': 5},
        ],
      );
      await sync();

      // Локальные поля НЕ перебивают чужую серверную сущность.
      expect(api.shoppingItemOf(ownerA, item.id)!['title'], 'Чужая позиция');
      expect((await itemRowOf(item.id))!.title, 'Чужая позиция');
      expect((await itemRowOf(item.id))!.quantity, 5);
      expect(await outboxOf(ownerA), isEmpty);
    });
  });

  group('HTTP-семантика', () {
    test(
      'list create → 409 → reconcile через GET → серверное принято',
      () async {
        final list = await repo.createList(title: 'Продукты');
        // «Ответ потерян»: тот же UUID уже на сервере.
        api.seedShoppingList(ownerA, list.id, 'Продукты (сервер)');
        await sync();

        expect(api.shoppingListsOf(ownerA), hasLength(1));
        expect(await outboxOf(ownerA), isEmpty);
        expect((await listRowOf(list.id))!.title, 'Продукты (сервер)');
      },
    );

    test('item create → 409 → reconcile через GET списка', () async {
      final list = await repo.createList(title: 'L');
      await sync();
      api.seedShoppingList(
        ownerA,
        list.id,
        'L',
        items: [
          {'id': 'srv-item', 'title': 'На сервере'},
        ],
      );

      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      // Имитируем lost response: позиция уже есть на сервере.
      api.seedShoppingList(
        ownerA,
        list.id,
        'L',
        items: [
          {'id': item.id, 'title': 'Молоко (сервер)', 'quantity': 2},
        ],
      );
      await sync();

      expect(await outboxOf(ownerA), isEmpty);
      expect(api.shoppingItemOf(ownerA, item.id)!['title'], 'Молоко (сервер)');
    });

    test('update list → 404 → локальная строка удалена', () async {
      final list = await repo.createList(title: 'L');
      await sync();
      api.deleteServerShoppingList(ownerA, list.id);

      await repo.updateList(list.copyWith(title: 'v2'));
      await sync();

      expect(await listRowOf(list.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('update item → 404 → позиция удалена локально', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      await sync();
      api.deleteServerShoppingItem(ownerA, item.id);

      await repo.updateItem(item.copyWith(title: 'v2'), listId: list.id);
      await sync();

      expect(await itemRowOf(item.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('delete list → 404 → считается выполненным', () async {
      final list = await repo.createList(title: 'L');
      await sync();
      api.deleteServerShoppingList(ownerA, list.id);

      await repo.deleteList(list.id);
      await sync();

      expect(await listRowOf(list.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('update item → 422 → failed, сущность сохранена', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      await sync();

      api.failures['PATCH /shopping-items'] = 422;
      await repo.updateItem(item.copyWith(title: 'Битое'), listId: list.id);
      await sync();

      expect((await outboxOf(ownerA)).single.status, 'failed');
      expect((await itemRowOf(item.id))!.title, 'Битое');

      // Новое редактирование реанимирует failed-операцию.
      api.failures.clear();
      await repo.updateItem(item.copyWith(title: 'Финал'), listId: list.id);
      await sync();
      expect(api.shoppingItemOf(ownerA, item.id)!['title'], 'Финал');
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('delete item → 422 → tombstone снят, позиция снова видна', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      await sync();

      api.failures['DELETE /shopping-items'] = 422;
      await repo.deleteItem(item.id, listId: list.id);
      await sync();

      // Сервер отказал — позиция возвращается в UI.
      expect((await outboxOf(ownerA)).single.status, 'failed');
      expect((await repo.getLists()).single.items, hasLength(1));

      // Повторное удаление доезжает.
      api.failures.clear();
      await repo.deleteItem(item.id, listId: list.id);
      await sync();
      expect(api.shoppingItemOf(ownerA, item.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('500 → retry с backoff, позиция сохранена', () async {
      api.failures['POST /shopping-lists'] = 500;
      await repo.createList(title: 'L');
      await sync();

      final op = (await outboxOf(ownerA)).single;
      expect(op.status, 'pending');
      expect(op.attempts, 1);
      expect(op.nextRetryAt!.isAfter(DateTime.now()), isTrue);
      expect(await repo.getLists(), hasLength(1));
    });

    test('network failure → retry, статус offline', () async {
      api.failures['POST /shopping-lists'] = 'network';
      api.failures['GET /wishes'] = 'network';
      api.failures['GET /shopping-lists'] = 'network';
      await repo.createList(title: 'L');
      await sync();

      expect((await outboxOf(ownerA)).single.attempts, 1);
      expect(statuses, contains(SyncStatus.offline));
      expect(await repo.getLists(), hasLength(1));
    });

    test(
      '401 → sync остановлен, outbox и локальные данные сохранены',
      () async {
        api.failures['POST /shopping-lists'] = 401;
        await repo.createList(title: 'L');
        await sync();

        expect(unauthorizedCalled, isTrue);
        expect(statuses, contains(SyncStatus.unauthorized));
        expect((await outboxOf(ownerA)).single.status, 'pending');
        expect(await repo.getLists(), hasLength(1));

        api.failures.clear();
        await sync();
        expect(api.shoppingListsOf(ownerA), isEmpty); // до reattach
      },
    );
  });

  group('pull: snapshot reconcile', () {
    test('remote list с позициями появляется локально', () async {
      api.seedShoppingList(
        ownerA,
        'srv-list',
        'Серверный',
        items: [
          {'id': 'srv-item', 'title': 'Позиция', 'is_checked': true},
        ],
      );
      await sync();

      final lists = await repo.getLists();
      expect(lists.single.title, 'Серверный');
      expect(lists.single.items.single.title, 'Позиция');
      expect(lists.single.items.single.isChecked, isTrue);
    });

    test('remote delete списка → каскадно удаляет локальные позиции', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      await sync();

      api.deleteServerShoppingList(ownerA, list.id);
      await sync();

      expect(await listRowOf(list.id), isNull);
      expect(await itemRowOf(item.id), isNull);
      expect(await repo.getLists(), isEmpty);
    });

    test('remote delete позиции → исчезает локально', () async {
      final list = await repo.createList(title: 'L');
      final item = await repo.addItem(listId: list.id, title: 'Молоко');
      await sync();

      api.deleteServerShoppingItem(ownerA, item.id);
      await sync();

      expect(await itemRowOf(item.id), isNull);
      expect((await repo.getLists()).single.items, isEmpty);
    });

    test('pending list отсутствует в snapshot → сохраняется', () async {
      api.failures['POST /shopping-lists'] = 'network';
      final list = await repo.createList(title: 'Оффлайн');
      api.failures.remove('POST /shopping-lists');
      await sync(); // pull: snapshot пуст, но у списка pending create

      expect((await listRowOf(list.id))!.title, 'Оффлайн');
      expect(await repo.getLists(), hasLength(1));
    });

    test('failed list отсутствует в snapshot → сохраняется', () async {
      api.failures['POST /shopping-lists'] = 422;
      final list = await repo.createList(title: 'Не принят');
      await sync();

      expect((await outboxOf(ownerA)).single.status, 'failed');
      expect((await listRowOf(list.id))!.title, 'Не принят');
      expect(await repo.getLists(), hasLength(1));
    });

    test('pending item отсутствует в snapshot → сохраняется', () async {
      final list = await repo.createList(title: 'L');
      await sync();

      api.failures['POST /shopping-lists/${list.id}/items'] = 'network';
      final item = await repo.addItem(listId: list.id, title: 'Оффлайн');
      api.failures.remove('POST /shopping-lists/${list.id}/items');
      await sync(); // pull: серверная позиция отсутствует

      expect((await itemRowOf(item.id))!.title, 'Оффлайн');
      expect((await repo.getLists()).single.items, hasLength(1));
    });

    test('failed item отсутствует в snapshot → сохраняется', () async {
      final list = await repo.createList(title: 'L');
      await sync();

      api.failures['POST /shopping-lists/${list.id}/items'] = 422;
      final item = await repo.addItem(listId: list.id, title: 'Не принята');
      await sync();

      expect((await outboxOf(ownerA)).single.status, 'failed');
      expect((await itemRowOf(item.id))!.title, 'Не принята');
      expect((await repo.getLists()).single.items, hasLength(1));
    });

    test('snapshot не трогает строки другого owner_id', () async {
      await db
          .into(db.shoppingLists)
          .insert(
            ShoppingListsCompanion(
              id: const Value('b-list'),
              ownerId: const Value(ownerB),
              title: const Value('Чужой список'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );
      await db
          .into(db.shoppingItems)
          .insert(
            ShoppingItemsCompanion(
              id: const Value('b-item'),
              ownerId: const Value(ownerB),
              listId: const Value('b-list'),
              title: const Value('Чужая позиция'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      await sync(); // snapshot ownerA пуст — строки B не тронуты.

      expect((await listRowOf('b-list'))!.ownerId, ownerB);
      expect((await itemRowOf('b-item'))!.ownerId, ownerB);
    });
  });

  group('account isolation', () {
    test(
      'outbox аккаунта A не уходит при attach(B); B видит свои данные',
      () async {
        api.failures['POST /shopping-lists'] = 'network';
        final listA = await repo.createList(title: 'Список A');
        await repo.addItem(listId: listA.id, title: 'Позиция A');
        api.failures.clear();
        engine.detach();

        // «Вошёл» аккаунт B: регистрация → свой token + uid.
        final reg = await dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: {'email': 'b@chtohochu.ru', 'password': 'pass1234'},
        );
        final regData = reg.data!['data'] as Map<String, dynamic>;
        final uidB = regData['user']['id'] as String;
        const storage = FlutterSecureStorage();
        await storage.write(
          key: 'access_token',
          value: regData['token'] as String,
        );
        api.seedShoppingList(uidB, 'b-srv', 'Список B');

        engine.attach(uidB);
        await sync();

        // Операции A не отправлены под чужой сессией.
        expect(api.shoppingListsOf(ownerA), isEmpty);
        expect(mutatingRequests().where((r) => r.contains('items')), isEmpty);
        expect(
          (await outboxOf(ownerA)).length,
          2, // create list + create item ждут возврата A
        );
        // Pull B: его серверный список записан с ownerId=B, данные A
        // не тронуты.
        expect((await listRowOf('b-srv'))!.ownerId, uidB);
        expect((await listRowOf(listA.id))!.ownerId, ownerA);
      },
    );
  });
}
