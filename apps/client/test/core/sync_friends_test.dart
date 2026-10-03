import 'dart:async';

import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/sync/sync_engine.dart';
import 'package:chtohochu/features/friends/data/friends_remote_service.dart';
import 'package:chtohochu/features/friends/data/friends_repository.dart';
import 'package:chtohochu/features/friends/domain/friend.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_app.dart';

/// Offline-first Friends: дружба через общий outbox + SyncEngine.
///
/// Identity связи на проводе — `friend_id` (POST /friends {user_id},
/// DELETE /friends/{user}): серверный UUID Friendship клиенту не
/// отдаётся, outbox entityId = friendId. Пара уникальна → 409 —
/// reconcile, а не failure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const ownerA = 'user-a';
  const ownerB = 'user-b';

  late AppDatabase db;
  late FakeApiAdapter api;
  late _GatedAdapter gated;
  late SyncEngine engine;
  late DriftFriendsRepository repo;
  late FriendsRemoteService remote;
  late PreferencesService prefs;
  late bool unauthorizedCalled;

  Friend friendOf(String id, {String? name, String? username}) => Friend(
    id: id,
    name: name ?? 'Друг $id',
    username: username ?? 'user_$id',
  );

  Future<List<OutboxEntry>> outboxOf(String ownerId) {
    return (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(ownerId))).get();
  }

  Future<FriendshipRow?> friendshipRow(String ownerId, String friendId) =>
      db.friendshipByIdAny(ownerId, friendId);

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

  void seedUsers() {
    api.seedUser('u1', name: 'Анна Соколова', username: 'anna.s');
    api.seedUser('u2', name: 'Максим Орлов', username: 'max_orlov');
  }

  setUp(() async {
    setupTestStorage(
      preferences: {'current_user_id': ownerA},
      secureStorage: {'access_token': 'token-a'},
    );
    prefs = PreferencesService(await SharedPreferences.getInstance());
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = DriftFriendsRepository(db, prefs);
    api = FakeApiAdapter(autoUserId: ownerA);
    gated = _GatedAdapter(api);
    final dio = createTestApiClient(gated);
    remote = FriendsRemoteService(dio, db, prefs);
    unauthorizedCalled = false;
    engine = SyncEngine(
      db: db,
      dio: dio,
      onUnauthorized: () => unauthorizedCalled = true,
      onStatus: (_) {},
    );
    seedUsers();
    engine.attach(ownerA);
    await sync(); // стартовый pull на пустом сервере
    api.requests.clear();
  });

  tearDown(() async {
    engine.detach();
    await db.close();
  });

  group('push: add friend', () {
    test(
      'addFriend пишет friendship + cached_user + outbox атомарно',
      () async {
        await offline(
          () => repo.addFriend(
            friendOf('u1', name: 'Анна Соколова', username: 'anna.s'),
          ),
        );

        // Локальный UI-state сразу: друг виден, желаний пока нет.
        final friends = await repo.getFriends();
        expect(friends.single.id, 'u1');
        expect(friends.single.name, 'Анна Соколова');

        final row = await friendshipRow(ownerA, 'u1');
        expect(row, isNotNull);
        expect(row!.deletedAt, isNull);

        final user = await db.cachedUserById(ownerA, 'u1');
        expect(user!.username, 'anna.s');

        final ops = await outboxOf(ownerA);
        expect(ops.single.entityType, 'friendship');
        expect(ops.single.entityId, 'u1');
        expect(ops.single.operation, 'create');
        expect(ops.single.payloadJson, contains('"user_id":"u1"'));
      },
    );

    test('sync → POST /friends {user_id} → 201 → пара симметрична', () async {
      await offline(() => repo.addFriend(friendOf('u1')));
      api.requests.clear();

      await sync();

      expect(mutatingRequests(), ['POST /friends']);
      expect(await outboxOf(ownerA), isEmpty);
      expect(api.friendsOf(ownerA), contains('u1'));
      expect(api.friendsOf('u1'), contains(ownerA)); // симметрично
      // Друг по-прежнему виден локально.
      expect((await repo.getFriends()).single.id, 'u1');
    });

    test('add + remove до sync → ноль HTTP (compaction)', () async {
      await offline(() async {
        await repo.addFriend(friendOf('u1'));
        await repo.removeFriend('u1');
      });
      api.requests.clear();

      await sync();

      expect(mutatingRequests(), isEmpty);
      expect(api.friendsOf(ownerA), isEmpty);
      expect(await outboxOf(ownerA), isEmpty);
      expect(await friendshipRow(ownerA, 'u1'), isNull);
    });

    test('повторный addFriend для уже друга — no-op', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.requests.clear();

      await repo.addFriend(friendOf('u1'));

      expect(await outboxOf(ownerA), isEmpty);
      expect(mutatingRequests(), isEmpty);
      expect((await repo.getFriends()), hasLength(1));
    });
  });

  group('push: remove friend', () {
    test('synced friend → remove → ровно один DELETE', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.requests.clear();

      await repo.removeFriend('u1');
      // UI сразу пуст.
      expect(await repo.getFriends(), isEmpty);
      // Повторный remove — no-op, второго DELETE не будет.
      await repo.removeFriend('u1');
      await sync();

      expect(mutatingRequests(), ['DELETE /friends/u1']);
      expect(api.friendsOf(ownerA), isEmpty);
      expect(api.friendsOf('u1'), isEmpty);
      expect(await outboxOf(ownerA), isEmpty);
      // Локальная строка и кэш желаний друга сняты.
      expect(await friendshipRow(ownerA, 'u1'), isNull);
      expect(await db.friendWishesOf(ownerA, 'u1'), isEmpty);
    });

    test('DELETE 404 → уже удалено на сервере → успех', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.deleteServerFriendship(ownerA, 'u1'); // удалил другой девайс
      api.requests.clear();

      await repo.removeFriend('u1');
      await sync();

      expect(mutatingRequests(), ['DELETE /friends/u1']);
      expect(await outboxOf(ownerA), isEmpty);
      expect(await repo.getFriends(), isEmpty);
    });

    test('DELETE 422 → tombstone восстановлен, операция failed', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.requests.clear();
      api.failures['DELETE /friends'] = 422;

      await repo.removeFriend('u1');
      await sync();

      final ops = await outboxOf(ownerA);
      expect(ops.single.operation, 'delete');
      expect(ops.single.status, 'failed');
      // Сервер отказал — друг снова виден локально.
      expect((await repo.getFriends()).single.id, 'u1');

      // Новое намерение не блокируется: повторное удаление revive'ит.
      api.failures.clear();
      api.requests.clear();
      await repo.removeFriend('u1');
      await sync();

      expect(mutatingRequests(), ['DELETE /friends/u1']);
      expect(api.friendsOf(ownerA), isEmpty);
    });
  });

  group('409 duplicate', () {
    test('add при существующей на сервере паре → reconcile', () async {
      api.seedFriendship(ownerA, 'u1'); // связь уже есть (другой девайс)
      await offline(() => repo.addFriend(friendOf('u1')));
      api.requests.clear();

      await sync();

      // POST → 409 → GET /friends/u1 → complete.
      expect(mutatingRequests(), ['POST /friends']);
      expect(await outboxOf(ownerA), isEmpty);
      expect((await repo.getFriends()).single.id, 'u1');
      // Нет дубля friendship-строки.
      expect(
        await (db.select(
          db.friendships,
        )..where((f) => f.friendId.equals('u1'))).get(),
        hasLength(1),
      );
    });
  });

  group('snapshot reconcile', () {
    test('remote friend появляется локально (friendship + user)', () async {
      api.seedFriendship(ownerA, 'u1');

      await sync();

      final friends = await repo.getFriends();
      expect(friends.single.id, 'u1');
      expect(friends.single.name, 'Анна Соколова');
      expect(mutatingRequests(), isEmpty);
    });

    test('remote delete дружбы → локальная строка и кэш удалены', () async {
      api.seedFriendship(ownerA, 'u1');
      await sync();
      expect((await repo.getFriends()), hasLength(1));

      // Кэш желаний друга тоже должен уйти вместе со связью.
      await remote.refreshFriendWishes('u1');
      api.deleteServerFriendship(ownerA, 'u1');
      await sync();

      expect(await repo.getFriends(), isEmpty);
      expect(await friendshipRow(ownerA, 'u1'), isNull);
      expect(await db.friendWishesOf(ownerA, 'u1'), isEmpty);
    });

    test('remote изменение профиля обновляет cached_users', () async {
      api.seedFriendship(ownerA, 'u1');
      await sync();
      expect((await repo.getFriends()).single.name, 'Анна Соколова');

      // Переименование на сервере (другой девайс/админка).
      api.seedUser('u1', name: 'Анна Петрова', username: 'anna.s');
      await sync();

      expect((await repo.getFriends()).single.name, 'Анна Петрова');
    });

    test('pending local add отсутствует в snapshot → не удалён', () async {
      await offline(() => repo.addFriend(friendOf('u1')));

      await sync(); // pull: сервер про u1 не знает

      expect(await friendshipRow(ownerA, 'u1'), isNotNull);
      expect((await repo.getFriends()).single.id, 'u1');
    });

    test('failed local add отсутствует в snapshot → не удалён', () async {
      api.failures['POST /friends'] = 422;
      await offline(() => repo.addFriend(friendOf('u1')));

      await sync(); // push failed + pull — snapshot пуст

      expect(await friendshipRow(ownerA, 'u1'), isNotNull);
      final ops = await outboxOf(ownerA);
      expect(ops.single.status, 'failed');
      // Ошибка чинится новой мутацией: повторный add revive'ит.
      api.failures.clear();
      await repo.addFriend(friendOf('u1'));
      await sync();
      expect(api.friendsOf(ownerA), contains('u1'));
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('pending local delete не воскрешается snapshot', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.requests.clear();
      // DELETE не доходит (network) → op остаётся pending,
      // snapshot всё ещё содержит дружбу.
      api.failures['DELETE /friends'] = 'network';

      await repo.removeFriend('u1');
      await sync();

      // Друг скрыт (tombstone), операция pending, snapshot не воскресил.
      expect(await repo.getFriends(), isEmpty);
      expect((await friendshipRow(ownerA, 'u1'))!.deletedAt, isNotNull);
      expect((await outboxOf(ownerA)).single.operation, 'delete');
    });

    test('данные другого аккаунта reconcile не трогает', () async {
      // Имитация данных ownerB в той же БД (как до смены аккаунта).
      final now = DateTime.now();
      await db
          .into(db.friendships)
          .insert(
            FriendshipsCompanion(
              ownerId: const Value(ownerB),
              friendId: const Value('u2'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.cachedUsers)
          .insert(
            CachedUsersCompanion(
              ownerId: const Value(ownerB),
              userId: const Value('u2'),
              name: const Value('Максим Орлов'),
              username: const Value('max_orlov'),
              cachedAt: Value(now),
            ),
          );
      await db
          .into(db.friendWishes)
          .insert(
            FriendWishesCompanion(
              id: const Value('w-u2'),
              ownerId: const Value(ownerB),
              friendId: const Value('u2'),
              title: const Value('Чужой кэш'),
              createdAt: Value(now),
              updatedAt: Value(now),
              fetchedAt: Value(now),
            ),
          );

      await sync(); // pull под ownerA — сервер пуст для него

      // Строки ownerB не тронуты reconcile под ownerA.
      expect(await friendshipRow(ownerB, 'u2'), isNotNull);
      expect((await db.friendWishesOf(ownerB, 'u2')).single.title, 'Чужой кэш');
      expect(await db.cachedUserById(ownerB, 'u2'), isNotNull);
      // А у ownerA ничего не появилось.
      expect(await repo.getFriends(), isEmpty);
    });
  });

  group('failures / retry / 401', () {
    test('network failure на POST → op pending, retry завершает', () async {
      api.failures['POST /friends'] = 'network';
      await repo.addFriend(friendOf('u1'));
      await sync();

      var ops = await outboxOf(ownerA);
      expect(ops.single.status, 'pending');
      expect(ops.single.attempts, greaterThan(0));
      expect(api.friendsOf(ownerA), isEmpty); // не доехало

      api.failures.clear();
      await sync(); // backoff ещё активен — форсируем
      await (db.update(db.outboxEntries)
            ..where((o) => o.ownerId.equals(ownerA)))
          .write(const OutboxEntriesCompanion(nextRetryAt: Value(null)));
      await sync();

      ops = await outboxOf(ownerA);
      expect(ops, isEmpty);
      expect(api.friendsOf(ownerA), contains('u1'));
    });

    test('5xx на DELETE → retry, tombstone сохранён', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.failures['DELETE /friends'] = 503;
      api.requests.clear();

      await repo.removeFriend('u1');
      await sync();

      expect((await outboxOf(ownerA)).single.status, 'pending');
      expect((await friendshipRow(ownerA, 'u1'))!.deletedAt, isNotNull);
      expect(api.friendsOf(ownerA), contains('u1')); // сервер ещё держит

      api.failures.clear();
      await (db.update(db.outboxEntries)
            ..where((o) => o.ownerId.equals(ownerA)))
          .write(const OutboxEntriesCompanion(nextRetryAt: Value(null)));
      await sync();

      expect(api.friendsOf(ownerA), isEmpty);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('failed delete + re-add → новая мутация замещает failed', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.failures['DELETE /friends'] = 422;
      await repo.removeFriend('u1');
      await sync();
      expect((await outboxOf(ownerA)).single.status, 'failed');

      // Пользователь передумал: добавляет снова — failed не блокирует.
      api.failures.clear();
      await repo.addFriend(friendOf('u1'));
      var ops = await outboxOf(ownerA);
      expect(ops.single.operation, 'create');
      expect(ops.single.status, 'pending');

      await sync(); // сервер помнит связь → POST 409 → reconcile
      ops = await outboxOf(ownerA);
      expect(ops, isEmpty);
      expect((await repo.getFriends()).single.id, 'u1');
    });

    test('401 → auth-expired flow, повторный attach восстанавливает', () async {
      await offline(() => repo.addFriend(friendOf('u1')));
      api.failures['POST /friends'] = 401;

      await sync();

      expect(unauthorizedCalled, isTrue);
      expect(await outboxOf(ownerA), isNotEmpty);

      // Reattach с новым токеном — как повторный логин.
      api.failures.clear();
      engine.attach(ownerA);
      await sync();

      expect(api.friendsOf(ownerA), contains('u1'));
      expect(await outboxOf(ownerA), isEmpty);
    });
  });

  group('mid-flight mutations', () {
    test('DELETE в полёте + re-add → ответ не затирает create', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.requests.clear();

      final gate = gated.hold('DELETE', '/friends/');
      await repo.removeFriend('u1');
      await gate.entered.future; // DELETE летит

      // Пользователь передумал и добавил друга обратно, пока
      // DELETE ещё в полёте.
      await repo.addFriend(friendOf('u1'));
      gate.release();

      await sync();

      // Финальное намерение — «в друзьях»: локально и на сервере.
      expect((await repo.getFriends()).single.id, 'u1');
      expect(api.friendsOf(ownerA), contains('u1'));
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('POST в полёте + remove → delete-намерение доезжает', () async {
      final gate = gated.hold('POST', '/friends');
      await repo.addFriend(friendOf('u1'));
      await gate.entered.future; // POST летит

      // Пока POST в полёте — пользователь удалил друга: сущность
      // снята физически, create+delete compaction ничего не ставит.
      await repo.removeFriend('u1');
      gate.release();

      await sync();

      // Сервер успел создать связь → delete-намерение доехало
      // отдельной операцией: итог — нет дружбы нигде.
      expect(await repo.getFriends(), isEmpty);
      expect(api.friendsOf(ownerA), isEmpty);
      expect(await outboxOf(ownerA), isEmpty);
      expect(mutatingRequests(), contains('DELETE /friends/u1'));
    });
  });

  group('friend_wishes cache', () {
    Map<String, dynamic> wishJson(String id, String title) => {
      'id': id,
      'title': title,
      'description': null,
      'price': null,
      'link': null,
      'image_url': null,
      'created_at': '2025-09-01T00:00:00.000Z',
      'updated_at': '2025-09-01T00:00:00.000Z',
    };

    Future<void> befriend(String id) async {
      await repo.addFriend(friendOf(id));
      await sync();
      api.requests.clear();
    }

    test('refresh создаёт кэш, читается оффлайн-проекцией', () async {
      api.seedWish('u1', wishJson('w1', 'Наушники'));
      await befriend('u1');

      await remote.refreshFriendWishes('u1');

      final friend = (await repo.getFriendById('u1'))!;
      expect(friend.wishes.single.id, 'w1');
      expect(friend.wishes.single.title, 'Наушники');
      expect(await db.friendWishesFetchedAt(ownerA, 'u1'), isNotNull);
    });

    test('online refresh заменяет кэш: remote delete пропадает', () async {
      api.seedWish('u1', wishJson('w1', 'Наушники'));
      api.seedWish('u1', wishJson('w2', 'Книга'));
      await befriend('u1');
      await remote.refreshFriendWishes('u1');
      expect((await db.friendWishesOf(ownerA, 'u1')), hasLength(2));

      // Remote: w2 удалён, w3 добавлен.
      api.deleteServerWish('u1', 'w2');
      api.seedWish('u1', wishJson('w3', 'Термокружка'));
      await remote.refreshFriendWishes('u1');

      final wishes = await db.friendWishesOf(ownerA, 'u1');
      expect(wishes.map((w) => w.id).toSet(), {'w1', 'w3'});
    });

    test('network failure оставляет stale-кэш видимым', () async {
      api.seedWish('u1', wishJson('w1', 'Наушники'));
      await befriend('u1');
      await remote.refreshFriendWishes('u1');

      api.failures['GET /friends'] = 'network';
      await remote.refreshFriendWishes('u1'); // падает молча

      expect((await db.friendWishesOf(ownerA, 'u1')).single.id, 'w1');
    });

    test('404 на wishes → кэш инвалидируется, данные не фабрикуются', () async {
      api.seedWish('u1', wishJson('w1', 'Наушники'));
      await befriend('u1');
      await remote.refreshFriendWishes('u1');
      expect((await db.friendWishesOf(ownerA, 'u1')), hasLength(1));

      api.deleteServerFriendship(ownerA, 'u1'); // больше не друзья
      await remote.refreshFriendWishes('u1');

      expect(await db.friendWishesOf(ownerA, 'u1'), isEmpty);
    });

    test('кэш желаний owner-scoped: ownerB не видит кэш ownerA', () async {
      api.seedWish('u1', wishJson('w1', 'Наушники'));
      await befriend('u1');
      await remote.refreshFriendWishes('u1');

      // ownerB читает свой (пустой) кэш — данные ownerA не видны.
      expect(await db.friendWishesOf(ownerB, 'u1'), isEmpty);
      expect(await db.friendWishesFetchedAt(ownerB, 'u1'), isNull);
    });

    test('TTL: свежий кэш пропускает сеть, stale — обновляет', () async {
      api.seedWish('u1', wishJson('w1', 'Наушники'));
      await befriend('u1');

      await remote.refreshFriendDataIfStale('u1');
      final baseline = api.requests.length;
      expect(api.requests.where((r) => r.contains('/wishes')), isNotEmpty);

      // Свежий кэш — повторный refresh не трогает wishes-endpoint.
      await remote.refreshFriendDataIfStale('u1');
      expect(
        api.requests.where((r) => r.contains('/wishes')).length,
        lessThanOrEqualTo(2), // pull + первый refresh
      );
      expect(api.requests.length, greaterThan(baseline)); // profile GET был
    });
  });

  group('account isolation + logout', () {
    test('clearAccountData снимает все friends-таблицы аккаунта', () async {
      api.seedWish('u1', {
        'id': 'w1',
        'title': 'Наушники',
        'description': null,
        'price': null,
        'link': null,
        'image_url': null,
        'created_at': '2025-09-01T00:00:00.000Z',
        'updated_at': '2025-09-01T00:00:00.000Z',
      });
      await repo.addFriend(friendOf('u1'));
      await remote.refreshFriendWishes('u1');
      await sync();

      await db.clearAccountData(ownerA);

      expect(await repo.getFriends(), isEmpty);
      expect(await db.cachedUserById(ownerA, 'u1'), isNull);
      expect(await db.friendWishesOf(ownerA, 'u1'), isEmpty);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('операции ownerA не отправляются, пока attach ownerB', () async {
      await offline(() => repo.addFriend(friendOf('u1')));
      engine.detach();

      // Смена аккаунта: attach под ownerB — outbox ownerA молчит.
      api.requests.clear();
      engine.attach(ownerB);
      await sync();

      expect(mutatingRequests(), isEmpty);
      expect(await outboxOf(ownerA), isNotEmpty); // операция ждёт ownerA

      engine.detach();
      engine.attach(ownerA);
      await sync();
      expect(api.friendsOf(ownerA), contains('u1'));
    });
  });

  group('account switch / stale responses', () {
    test('401 на pull → auth-expired flow, а не «offline»', () async {
      api.failures['GET /friends'] = 401;

      await sync();

      expect(unauthorizedCalled, isTrue);
    });

    test('in-flight 401 чужого аккаунта не сносит новую сессию', () async {
      final gate = gated.hold('POST', '/friends');
      api.failures['POST /friends'] = 401;
      await repo.addFriend(friendOf('u1'));
      await gate.entered.future; // POST аккаунта A в полёте

      // Захватить будущее текущего прогона до detach.
      final run = engine.requestSync();
      // logout A → login B: ответ A приходит уже вне его сессии.
      engine.detach();
      engine.attach(ownerB);
      gate.release();
      await run;

      // 401 старого токена НЕ должен сработать как auth-expired
      // нового аккаунта (clearCredentials стёр бы токен B).
      expect(unauthorizedCalled, isFalse);
    });

    test('успешный ответ после detach не снимает outbox-операцию', () async {
      final gate = gated.hold('POST', '/friends');
      await repo.addFriend(friendOf('u1'));
      await gate.entered.future; // POST в полёте

      final run = engine.requestSync();
      engine.detach();
      gate.release();
      await run;

      // Операция не «завершена» ответом отсоединённой сессии:
      // остаётся pending — при reattach доедет как 409-reconcile.
      final ops = await outboxOf(ownerA);
      expect(ops.single.operation, 'create');
      expect(ops.single.status, 'pending');
    });

    test('snapshot в полёте + detach → reconcile не пишет строки', () async {
      api.seedFriendship(ownerA, 'u1');
      final gate = gated.hold('GET', '/friends');
      final run = sync();
      await gate.entered.future; // pull аккаунта A в полёте

      engine.detach();
      gate.release();
      await run;

      // Snapshot отсоединённого аккаунта не reconcil'ится.
      expect(await friendshipRow(ownerA, 'u1'), isNull);
    });

    test('refreshFriendWishes: ответ после смены аккаунта не воскрешает '
        'кэш', () async {
      await repo.addFriend(friendOf('u1'));
      await sync();
      api.seedWish('u1', {
        'id': 'fw-1',
        'title': 'Желание друга',
        'description': null,
        'price': null,
        'link': null,
        'image_url': null,
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      });

      final gate = gated.hold('GET', '/friends/u1/wishes');
      final run = remote.refreshFriendWishes('u1');
      await gate.entered.future; // GET в полёте

      // Logout A: аккаунт сменился до прихода ответа — кэш писать нельзя.
      await prefs.clearCurrentUserId();
      gate.release();
      await run;

      expect(await db.friendWishesOf(ownerA, 'u1'), isEmpty);
    });

    test(
      'searchUsers: результаты после смены аккаунта не пишутся в кэш',
      () async {
        final gate = gated.hold('GET', '/users/search');
        final run = remote.searchUsers('anna');
        await gate.entered.future; // GET в полёте

        await prefs.clearCurrentUserId();
        gate.release();
        final results = await run;

        // Результаты возвращаются caller'у (read-only), но в Drift
        // для разлогиненного аккаунта ничего не пишется.
        expect(results, isNotEmpty);
        expect(await db.cachedUserById(ownerA, 'u1'), isNull);
      },
    );
  });
}

/// Барьер для одного запроса: `entered` — запрос в полёте,
/// `release()` — отпустить на обработку fake API.
class _Gate {
  final entered = Completer<void>();
  final _release = Completer<void>();
  void release() => _release.complete();
}

/// Обёртка над [FakeApiAdapter], умеющая «держать» первый
/// запрос, совпадающий с ключом 'METHOD /path-prefix'.
class _GatedAdapter implements HttpClientAdapter {
  _GatedAdapter(this._inner);

  final FakeApiAdapter _inner;
  final _gates = <String, _Gate>{};

  /// Удерживать первый запрос `method path-prefix`.
  _Gate hold(String method, String prefix) {
    final gate = _Gate();
    _gates['$method $prefix'] = gate;
    return gate;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final entry in _gates.entries) {
      final parts = entry.key.split(' ');
      if (options.method == parts[0] && options.path.startsWith(parts[1])) {
        entry.value.entered.complete();
        await entry.value._release.future;
        break;
      }
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
