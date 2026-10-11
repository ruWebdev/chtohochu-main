import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/sync/sync_engine.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_app.dart';

/// Offline-first WishList: push/pull синхронизация списков
/// желаний через общий outbox + SyncEngine. Проверяет
/// create/update/delete lifecycle, tombstone, разгруппировку
/// wishes при удалении списка, snapshot reconcile, изоляцию
/// аккаунтов и идемпотентность retry (без дублей).
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
  late DriftWishRepository repo;
  late PreferencesService prefs;

  Future<List<OutboxEntry>> outboxOf(String ownerId) {
    return (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(ownerId))).get();
  }

  Future<WishListRow?> listRowOf(String id) => (db.select(
    db.wishLists,
  )..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<WishRow?> wishRowOf(String id) =>
      (db.select(db.wishes)..where((w) => w.id.equals(id))).getSingleOrNull();

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
    repo = DriftWishRepository(db, prefs);
    api = FakeApiAdapter(autoUserId: ownerA);
    dio = createTestApiClient(api);
    engine = SyncEngine(
      db: db,
      dio: dio,
      onUnauthorized: () {},
      onStatus: (_) {},
    );
    engine.attach(ownerA);
    await sync(); // стартовый pull на пустом сервере
  });

  tearDown(() async {
    engine.detach();
    await db.close();
  });

  group('push: базовые операции', () {
    test('create list → POST /wish-lists с клиентским UUID → '
        'outbox снят', () async {
      final list = await repo.createWishList(title: 'Подарки');
      await sync();

      expect(await outboxOf(ownerA), isEmpty);
      final server = api.wishListsOf(ownerA).single;
      expect(server['id'], list.id); // identity не перемаплена
      expect(server['title'], 'Подарки');
      expect(mutatingRequests(), ['POST /wish-lists']);
    });

    test('update list → PATCH /wish-lists/{id}', () async {
      final list = await repo.createWishList(title: 'Старое');
      await sync();
      api.requests.clear();

      await repo.updateWishList(list.copyWith(title: 'Новое'));
      await sync();

      expect(mutatingRequests(), ['PATCH /wish-lists/${list.id}']);
      expect(api.wishListsOf(ownerA).single['title'], 'Новое');
      expect((await listRowOf(list.id))!.title, 'Новое');
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('delete synced list → tombstone → DELETE → физическое '
        'удаление', () async {
      final list = await repo.createWishList(title: 'L');
      await sync();

      await repo.deleteWishList(list.id);
      // До sync — tombstone: UI уже не видит список, строка жива.
      expect((await listRowOf(list.id))!.deletedAt, isNotNull);
      expect(await repo.watchWishLists().first, isEmpty);

      await sync();
      expect(mutatingRequests().last, 'DELETE /wish-lists/${list.id}');
      expect(await listRowOf(list.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('delete несинхронизированного списка — физическое удаление '
        'без HTTP', () async {
      late String listId;
      await offline(() async {
        final list = await repo.createWishList(title: 'L');
        listId = list.id;
        await repo.deleteWishList(list.id);
      });
      api.requests.clear();
      await sync();

      expect(await listRowOf(listId), isNull);
      expect(await outboxOf(ownerA), isEmpty);
      expect(mutatingRequests(), isEmpty);
    });
  });

  group('wish↔list связь', () {
    test('удаление списка не удаляет желания — listId → null '
        'локально и на сервере', () async {
      final list = await repo.createWishList(title: 'Подарки');
      final wish = await repo.createWish(title: 'Носки');
      await repo.assignWishToList(wish.id, list.id);
      await sync();
      expect(api.wishesOf(ownerA).single['list_id'], list.id);

      await repo.deleteWishList(list.id);
      final row = await wishRowOf(wish.id);
      expect(row, isNotNull);
      expect(row!.listId, isNull);

      await sync();
      // После sync желание осталось разгруппированным и живым
      // (backend DELETE списка делает SET NULL + pull reconcile).
      expect((await wishRowOf(wish.id))!.listId, isNull);
      expect(api.wishesOf(ownerA).single['list_id'], isNull);
    });

    test(
      'remote delete списка → желания разгруппированы, не удалены',
      () async {
        api.seedWishList(ownerA, 'remote-list', 'Remote');
        await sync();
        expect((await listRowOf('remote-list'))!.title, 'Remote');

        final wish = await repo.createWish(title: 'W');
        await repo.assignWishToList(wish.id, 'remote-list');
        await sync();
        expect(api.wishesOf(ownerA).single['list_id'], 'remote-list');

        api.deleteServerWishList(ownerA, 'remote-list');
        await sync();

        expect(await listRowOf('remote-list'), isNull);
        final row = await wishRowOf(wish.id);
        expect(row, isNotNull);
        expect(row!.listId, isNull);
      },
    );

    test('удаление желания не удаляет список', () async {
      final list = await repo.createWishList(title: 'L');
      final wish = await repo.createWish(title: 'W');
      await repo.assignWishToList(wish.id, list.id);
      await sync();

      await repo.deleteWish(wish.id);
      await sync();

      expect(await listRowOf(list.id), isNotNull);
      expect(api.wishListsOf(ownerA), hasLength(1));
    });
  });

  group('offline / retry', () {
    test('offline create: список локально + outbox, после reconnect '
        'уходит на сервер', () async {
      late String listId;
      await offline(() async {
        final list = await repo.createWishList(title: 'Offline');
        listId = list.id;
      });

      expect((await listRowOf(listId))!.title, 'Offline');
      final ops = await outboxOf(ownerA);
      expect(ops.single.entityType, 'wish_list');
      expect(ops.single.operation, 'create');

      await sync(); // attach уже переподключил — push доставил
      expect(api.wishListsOf(ownerA).single['id'], listId);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('server error 5xx → список сохранён, outbox pending retry, '
        'повтор без дублей', () async {
      api.failures['POST /wish-lists'] = 503;
      final list = await repo.createWishList(title: 'L');
      await sync();

      // Ошибка не удаляет локальные данные.
      expect(await listRowOf(list.id), isNotNull);
      expect(await outboxOf(ownerA), hasLength(1));
      expect(api.wishListsOf(ownerA), isEmpty);

      api.failures.clear();
      // Backoff истёк (retry-окно наступило).
      await (db.update(db.outboxEntries)
            ..where((o) => o.ownerId.equals(ownerA)))
          .write(const OutboxEntriesCompanion(nextRetryAt: Value(null)));
      await sync();
      expect(api.wishListsOf(ownerA), hasLength(1));
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('lost response: 409 → reconcile через GET, outbox снят', () async {
      // Сервер «уже знает» список (ответ на первый POST потерян).
      final list = await repo.createWishList(title: 'Подарки');
      api.seedWishList(ownerA, list.id, 'Подарки');
      api.requests.clear();

      await sync();

      expect(await outboxOf(ownerA), isEmpty);
      expect(api.wishListsOf(ownerA), hasLength(1));
      // POST получил 409 → reconcile читал сущность.
      expect(
        api.requests.any((r) => r == 'GET /wish-lists/${list.id}'),
        isTrue,
      );
      expect((await listRowOf(list.id))!.title, 'Подарки');
    });

    test('failed delete (5xx) → tombstone и retryable op сохранены, '
        'после retry удаление завершается', () async {
      final list = await repo.createWishList(title: 'L');
      await sync();

      api.failures['DELETE /wish-lists/${list.id}'] = 503;
      await repo.deleteWishList(list.id);
      await sync();

      // Tombstone не снят, операция жива и ретраится.
      expect((await listRowOf(list.id))!.deletedAt, isNotNull);
      expect(await outboxOf(ownerA), hasLength(1));

      api.failures.clear();
      await (db.update(db.outboxEntries)
            ..where((o) => o.ownerId.equals(ownerA)))
          .write(const OutboxEntriesCompanion(nextRetryAt: Value(null)));
      await sync();
      expect(await listRowOf(list.id), isNull);
      expect(api.wishListsOf(ownerA), isEmpty);
    });
  });

  group('membership wish ↔ list (server contract)', () {
    test('create wish с listId → POST несёт list_id → сервер '
        'сохраняет membership', () async {
      final list = await repo.createWishList(title: 'Подарки');
      await sync();

      final wish = await repo.createWish(title: 'W', listId: list.id);
      await sync();

      expect(api.wishesOf(ownerA).single['list_id'], list.id);
      expect(api.requests, contains('POST /wishes'));
      expect((await wishRowOf(wish.id))!.listId, list.id);
    });

    test('assign: null → list → другой list → null — все переходы '
        'уходят PATCH и применяются сервером', () async {
      final a = await repo.createWishList(title: 'A');
      final b = await repo.createWishList(title: 'B');
      final wish = await repo.createWish(title: 'W');
      await sync();

      await repo.assignWishToList(wish.id, a.id);
      await sync();
      expect(api.wishesOf(ownerA).single['list_id'], a.id);

      await repo.assignWishToList(wish.id, b.id);
      await sync();
      expect(api.wishesOf(ownerA).single['list_id'], b.id);

      await repo.assignWishToList(wish.id, null);
      await sync();
      expect(api.wishesOf(ownerA).single['list_id'], isNull);
      expect((await wishRowOf(wish.id))!.listId, isNull);
    });

    test('операция желания с listId откладывается, пока список не '
        'создан на сервере', () async {
      // Оффлайн: create списка + желание сразу в него.
      late String listId;
      late String wishId;
      await offline(() async {
        listId = (await repo.createWishList(title: 'L')).id;
        wishId = (await repo.createWish(title: 'W', listId: listId)).id;
      });
      api.requests.clear();
      await sync();

      final mutating = mutatingRequests();
      // FIFO + defer: POST списка раньше POST желания.
      expect(
        mutating.indexOf('POST /wish-lists'),
        lessThan(mutating.indexOf('POST /wishes')),
      );
      expect(api.wishListsOf(ownerA).single['id'], listId);
      expect(api.wishesOf(ownerA).single['list_id'], listId);
      expect((await wishRowOf(wishId))!.listId, listId);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('pull применяет remote membership', () async {
      api.seedWishList(ownerA, 'rl', 'Remote');
      api.seedWish(ownerA, {
        'id': 'rw',
        'title': 'RemoteW',
        'list_id': 'rl',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await sync();

      expect((await wishRowOf('rw'))!.listId, 'rl');
    });

    test('pending local membership не затирается pull', () async {
      api.seedWishList(ownerA, 'rl', 'Remote');
      final wish = await repo.createWish(title: 'W');
      await sync();
      expect(api.wishesOf(ownerA).single['list_id'], isNull);

      await offline(() => repo.assignWishToList(wish.id, 'rl'));

      // PATCH не доходит → op остаётся pending; pull видит remote
      // list_id=null, но не затирает локальный pending membership.
      api.failures['PATCH /wishes/${wish.id}'] = 503;
      await sync();
      expect((await wishRowOf(wish.id))!.listId, 'rl');
      expect(api.wishesOf(ownerA).single['list_id'], isNull);

      // После retry membership доезжает до сервера.
      api.failures.remove('PATCH /wishes/${wish.id}');
      await (db.update(db.outboxEntries)
            ..where((o) => o.ownerId.equals(ownerA)))
          .write(const OutboxEntriesCompanion(nextRetryAt: Value(null)));
      await sync();
      expect(api.wishesOf(ownerA).single['list_id'], 'rl');
      expect((await wishRowOf(wish.id))!.listId, 'rl');
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('удаление списка переписывает pending payload желания '
        '(list_id → null, без 422)', () async {
      // Синхронизированный список; желание создано оффлайн и
      // привязано к списку — create-op несёт list_id.
      final list = await repo.createWishList(title: 'L');
      await sync();

      late String wishId;
      await offline(() async {
        final wish = await repo.createWish(title: 'W', listId: list.id);
        wishId = wish.id;
        // Пока create желания в полёте не было — удаляем список.
        await repo.deleteWishList(list.id);
      });
      api.requests.clear();
      await sync();

      // Wish create ушёл с list_id=null — сервер принял.
      expect(api.wishesOf(ownerA).single['list_id'], isNull);
      expect((await wishRowOf(wishId))!.listId, isNull);
      expect(await outboxOf(ownerA), isEmpty);
      expect(api.wishListsOf(ownerA), isEmpty);
    });
  });

  group('pull / reconcile', () {
    test('remote create другого устройства появляется локально', () async {
      api.seedWishList(ownerA, 'r1', 'Серверный');
      await sync();

      final row = await listRowOf('r1');
      expect(row, isNotNull);
      expect(row!.ownerId, ownerA);
      expect(row.title, 'Серверный');
      expect(row.deletedAt, isNull);
    });

    test('pending create не уничтожается pull snapshot без этой '
        'сущности', () async {
      late String listId;
      await offline(() async {
        listId = (await repo.createWishList(title: 'Local')).id;
      });
      api.requests.clear();
      // Pull внутри sync — списка нет на сервере; pending-операция
      // защищает строку от remote-delete.
      await sync();

      expect((await listRowOf(listId))!.title, 'Local');
      expect(api.wishListsOf(ownerA).single['id'], listId);
    });

    test('remote update перезаписывает чистую локальную строку', () async {
      api.seedWishList(ownerA, 'r1', 'V1');
      await sync();
      api.seedWishList(ownerA, 'r1', 'V2');

      await sync();
      expect((await listRowOf('r1'))!.title, 'V2');
    });

    test('списки другого аккаунта не появляются и не затираются', () async {
      api.seedWishList(ownerB, 'b1', 'Чужой');
      await sync();

      expect(await listRowOf('b1'), isNull);
      expect(await repo.watchWishLists().first, isEmpty);

      // Локальная строка чужого owner'а не трогается reconcile.
      final now = DateTime.now();
      await db
          .into(db.wishLists)
          .insert(
            WishListsCompanion(
              id: const Value('local-b'),
              ownerId: const Value(ownerB),
              title: const Value('B local'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await sync();
      expect((await listRowOf('local-b'))!.title, 'B local');
    });
  });
}
