import 'dart:io';

import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/sync/sync_engine.dart';
import 'package:chtohochu/features/friends/data/friends_remote_service.dart';
import 'package:chtohochu/features/friends/data/friends_repository.dart';
import 'package:chtohochu/features/friends/domain/friend.dart';
import 'package:chtohochu/features/profile/data/profile_repository.dart';
import 'package:chtohochu/features/shopping/data/shopping_repository.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_app.dart';

/// Реальная disk persistence — НЕ in-memory.
///
/// Доказывает, что Wish и outbox переживают полный restart процесса:
/// create offline → close DB → reopen → данные на месте → sync →
/// close → reopen → synced entity сохранена.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const owner = 'user-a';

  late Directory dir;
  late File dbFile;

  AppDatabase openDb() => AppDatabase.forTesting(
    DatabaseConnection(
      NativeDatabase.createInBackground(dbFile),
      closeStreamsSynchronously: true,
    ),
  );

  setUp(() async {
    setupTestStorage(
      preferences: {'current_user_id': owner},
      secureStorage: {'access_token': 'token-a'},
    );
    dir = await Directory.systemTemp.createTemp('chtohochu_drift_test_');
    dbFile = File('${dir.path}/app.db');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('Wish и outbox переживают полный restart БД', () async {
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    // ── Сессия 1: offline create, close ──────────────────────
    var db = openDb();
    var repo = DriftWishRepository(db, prefs);
    final wish = await repo.createWish(title: 'Дисковая книга', price: 700);

    var outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox.single.operation, 'create');
    await db.close();

    // ── Сессия 2: reopen — данные на месте, outbox ждёт sync ──
    db = openDb();
    repo = DriftWishRepository(db, prefs);
    final restored = await repo.getWishes();
    expect(restored.single.id, wish.id);
    expect(restored.single.title, 'Дисковая книга');
    outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox.single.entityId, wish.id);

    // Sync после restart: outbox ушёл на сервер.
    final api = FakeApiAdapter(autoUserId: owner);
    final engine = SyncEngine(
      db: db,
      dio: createTestApiClient(api),
      onUnauthorized: () {},
      onStatus: (_) {},
    );
    engine.attach(owner);
    await engine.requestSync();
    engine.detach();

    expect(api.wishesOf(owner).single['id'], wish.id);
    outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox, isEmpty);
    await db.close();

    // ── Сессия 3: reopen — synced entity сохранена ────────────
    db = openDb();
    repo = DriftWishRepository(db, prefs);
    final finalWishes = await repo.getWishes();
    expect(finalWishes.single.id, wish.id);
    expect(
      await (db.select(
        db.outboxEntries,
      )..where((o) => o.ownerId.equals(owner))).get(),
      isEmpty,
    );
    await db.close();
  });

  test(
    'offline delete после restart выживает как tombstone + outbox',
    () async {
      final prefs = PreferencesService(await SharedPreferences.getInstance());

      // Сессия 1: create + sync (сущность на сервере).
      var db = openDb();
      var repo = DriftWishRepository(db, prefs);
      final api = FakeApiAdapter(autoUserId: owner);
      var engine = SyncEngine(
        db: db,
        dio: createTestApiClient(api),
        onUnauthorized: () {},
        onStatus: (_) {},
      );
      engine.attach(owner);
      final wish = await repo.createWish(title: 'К удалению');
      await engine.requestSync();
      expect(api.wishesOf(owner), hasLength(1));
      engine.detach();
      await db.close();

      // Сессия 2 (offline): delete → tombstone + outbox; restart.
      api.failures['DELETE /wishes'] = 'network';
      db = openDb();
      repo = DriftWishRepository(db, prefs);
      await repo.deleteWish(wish.id);
      await db.close();

      // Сессия 3: tombstone пережил restart; sync завершает delete.
      db = openDb();
      repo = DriftWishRepository(db, prefs);
      expect(await repo.getWishes(), isEmpty); // скрыто из UI
      var outbox = await (db.select(
        db.outboxEntries,
      )..where((o) => o.ownerId.equals(owner))).get();
      expect(outbox.single.operation, 'delete');

      api.failures.clear();
      engine = SyncEngine(
        db: db,
        dio: createTestApiClient(api),
        onUnauthorized: () {},
        onStatus: (_) {},
      );
      engine.attach(owner);
      await engine.requestSync();
      engine.detach();

      expect(api.wishesOf(owner), isEmpty);
      expect(
        await (db.select(db.wishes)..where((w) => w.id.equals(wish.id))).get(),
        isEmpty, // физическое удаление после 204
      );
      await db.close();
    },
  );

  test('ShoppingList + ShoppingItem + outbox переживают restart', () async {
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    // ── Сессия 1: offline create list + item + check, close ──
    var db = openDb();
    var repo = DriftShoppingRepository(db, prefs);
    final list = await repo.createList(title: 'Дисковый список');
    final item = await repo.addItem(
      listId: list.id,
      title: 'Дисковая позиция',
      quantity: 3,
    );
    await repo.updateItem(item.copyWith(isChecked: true), listId: list.id);

    var outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox.length, 2); // create list + create item (check схлопнут)
    await db.close();

    // ── Сессия 2: reopen — список, позиция и outbox на месте ──
    db = openDb();
    repo = DriftShoppingRepository(db, prefs);
    final restored = await repo.getLists();
    expect(restored.single.id, list.id);
    expect(restored.single.title, 'Дисковый список');
    expect(restored.single.items.single.title, 'Дисковая позиция');
    expect(restored.single.items.single.isChecked, isTrue);
    outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox.length, 2);

    // Sync после restart: обе операции ушли, позиция в итоге checked.
    final api = FakeApiAdapter(autoUserId: owner);
    var engine = SyncEngine(
      db: db,
      dio: createTestApiClient(api),
      onUnauthorized: () {},
      onStatus: (_) {},
    );
    engine.attach(owner);
    await engine.requestSync();
    engine.detach();

    expect(api.shoppingListsOf(owner).single['id'], list.id);
    expect(api.shoppingItemOf(owner, item.id)!['is_checked'], isTrue);
    outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox, isEmpty);
    await db.close();

    // ── Сессия 3: reopen — synced состояние на диске ─────────
    db = openDb();
    repo = DriftShoppingRepository(db, prefs);
    final finalLists = await repo.getLists();
    expect(finalLists.single.items.single.isChecked, isTrue);
    await db.close();
  });

  test(
    'Friendship + cached user + friend wishes + outbox переживают restart',
    () async {
      final prefs = PreferencesService(await SharedPreferences.getInstance());
      final api = FakeApiAdapter(autoUserId: owner)
        ..seedUser('u1', name: 'Анна Соколова', username: 'anna.s')
        ..seedFriendship(owner, 'u1')
        ..seedWish('u1', {
          'id': 'w1',
          'title': 'Дисковые наушники',
          'description': null,
          'price': 1000,
          'link': null,
          'image_url': null,
          'created_at': '2025-09-01T00:00:00.000Z',
          'updated_at': '2025-09-01T00:00:00.000Z',
        });

      // ── Сессия 1: pull импортирует дружбу; кэш желаний; close ──
      var db = openDb();
      var engine = SyncEngine(
        db: db,
        dio: createTestApiClient(api),
        onUnauthorized: () {},
        onStatus: (_) {},
      );
      engine.attach(owner);
      await engine.requestSync();
      var remote = FriendsRemoteService(createTestApiClient(api), db, prefs);
      await remote.refreshFriendWishes('u1');
      // Плюс ещё одна локальная дружба оффлайн (outbox должен выжить).
      var repo = DriftFriendsRepository(db, prefs);
      engine.detach(); // оффлайн: мутация копится
      api.seedUser('u2', name: 'Максим Орлов', username: 'max_orlov');
      await repo.addFriend(
        const Friend(id: 'u2', name: 'Максим Орлов', username: 'max_orlov'),
      );
      await db.close();

      // ── Сессия 2: reopen — всё на месте без сети ──────────────
      db = openDb();
      repo = DriftFriendsRepository(db, prefs);
      final friends = await repo.getFriends();
      expect(friends.map((f) => f.id).toSet(), {'u1', 'u2'});
      final anna = friends.firstWhere((f) => f.id == 'u1');
      expect(anna.name, 'Анна Соколова');
      expect(anna.wishes.single.title, 'Дисковые наушники');
      var outbox = await (db.select(
        db.outboxEntries,
      )..where((o) => o.ownerId.equals(owner))).get();
      expect(outbox.single.entityType, 'friendship');
      expect(outbox.single.entityId, 'u2');

      // Sync после restart: pending add доезжает.
      engine = SyncEngine(
        db: db,
        dio: createTestApiClient(api),
        onUnauthorized: () {},
        onStatus: (_) {},
      );
      engine.attach(owner);
      await engine.requestSync();
      engine.detach();
      expect(api.friendsOf(owner), containsAll({'u1', 'u2'}));
      outbox = await (db.select(
        db.outboxEntries,
      )..where((o) => o.ownerId.equals(owner))).get();
      expect(outbox, isEmpty);
      await db.close();

      // ── Сессия 3: synced состояние на диске ───────────────────
      db = openDb();
      repo = DriftFriendsRepository(db, prefs);
      final finalFriends = await repo.getFriends();
      expect(finalFriends, hasLength(2));
      expect(
        finalFriends.firstWhere((f) => f.id == 'u1').wishes.single.id,
        'w1',
      );
      await db.close();
    },
  );

  test('Profile + pending update переживают полный restart', () async {
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    // ── Сессия 1: профиль (как _persist при логине) + offline
    // update → outbox pending; close ───────────────────────────
    var db = openDb();
    await db.upsertProfile(
      const ProfilesCompanion(
        id: Value(owner),
        email: Value('user@chtohochu.ru'),
        name: Value('user'),
        username: Value('user'),
      ),
    );
    var repo = DriftProfileRepository(db, prefs);
    await repo.updateProfile(name: 'Дисковое имя', username: 'disk.u');

    var outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox.single.entityType, 'profile');
    expect(outbox.single.operation, 'update');
    await db.close();

    // ── Сессия 2: reopen — профиль и outbox на месте ──────────
    db = openDb();
    repo = DriftProfileRepository(db, prefs);
    final restored = (await repo.getProfile())!;
    expect(restored.name, 'Дисковое имя');
    expect(restored.username, 'disk.u');
    outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox.single.entityId, owner);

    // Sync после restart: PATCH /me доезжает.
    final api = FakeApiAdapter(autoUserId: owner);
    final engine = SyncEngine(
      db: db,
      dio: createTestApiClient(api),
      onUnauthorized: () {},
      onStatus: (_) {},
    );
    engine.attach(owner);
    await engine.requestSync();
    engine.detach();

    expect(api.serverUser(owner)!['name'], 'Дисковое имя');
    expect(api.serverUser(owner)!['username'], 'disk.u');
    expect(
      await (db.select(
        db.outboxEntries,
      )..where((o) => o.ownerId.equals(owner))).get(),
      isEmpty,
    );
    await db.close();

    // ── Сессия 3: reopen — synced состояние на диске ──────────
    db = openDb();
    repo = DriftProfileRepository(db, prefs);
    final finalProfile = (await repo.getProfile())!;
    expect(finalProfile.name, 'Дисковое имя');
    expect(finalProfile.username, 'disk.u');
    await db.close();
  });

  test('schema v1 → v3: данные старой схемы сохраняются, новые '
      'таблицы созданы', () async {
    // Имитация установки со старой схемой: v1 = wishes + profiles +
    // outbox_entries (shopping v2, friends v3 появились миграциями).
    // Создаём файл руками, выставляем user_version=1 — drift должен
    // выполнить onUpgrade при первом открытии AppDatabase.
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE wishes (
        id TEXT NOT NULL PRIMARY KEY,
        owner_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        price INTEGER,
        link TEXT,
        image_url TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      );
      CREATE TABLE profiles (
        id TEXT NOT NULL PRIMARY KEY,
        email TEXT NOT NULL,
        name TEXT,
        username TEXT,
        avatar_url TEXT,
        updated_at INTEGER
      );
      CREATE TABLE outbox_entries (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        owner_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT,
        created_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        next_retry_at INTEGER,
        status TEXT NOT NULL DEFAULT 'pending'
      );
      PRAGMA user_version = 1;
      ''');
    // Старые данные: wish + pending outbox + профиль.
    raw.execute(
      "INSERT INTO wishes VALUES ('w1','user-a','Старое желание',"
      "NULL,500,NULL,NULL,1735689600,1735689600,NULL)",
    );
    raw.execute(
      "INSERT INTO profiles VALUES ('user-a','a@x.ru','Старое имя',"
      "'old.u',NULL,1735689600)",
    );
    raw.execute(
      "INSERT INTO outbox_entries (owner_id,entity_type,entity_id,"
      "operation,payload_json,created_at) VALUES "
      "('user-a','wish','w1','create','{\"title\":\"Старое желание\"}',"
      "1735689600)",
    );
    raw.close();

    // Открытие актуальной базой → onUpgrade 1→3.
    final db = openDb();

    // Данные v1 на месте.
    final wish = (await db.wishById(owner, 'w1'))!;
    expect(wish.title, 'Старое желание');
    expect((await db.profileById(owner))!.name, 'Старое имя');
    final outbox = await (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(owner))).get();
    expect(outbox.single.operation, 'create');

    // Новые таблицы созданы и работают.
    final prefs = PreferencesService(await SharedPreferences.getInstance());
    final shop = DriftShoppingRepository(db, prefs);
    await shop.createList(title: 'Новый список');
    expect((await shop.getLists()).single.title, 'Новый список');
    final friends = DriftFriendsRepository(db, prefs);
    await friends.addFriend(
      const Friend(id: 'u1', name: 'Анна', username: 'anna'),
    );
    expect((await friends.getFriends()).single.id, 'u1');

    // Pending outbox из v1 остаётся доставляемым.
    final api = FakeApiAdapter(autoUserId: owner);
    final engine = SyncEngine(
      db: db,
      dio: createTestApiClient(api),
      onUnauthorized: () {},
      onStatus: (_) {},
    );
    engine.attach(owner);
    await engine.requestSync();
    engine.detach();
    expect(api.wishesOf(owner).single['title'], 'Старое желание');
    await db.close();
  });

  test('wish_images переживают полный restart БД', () async {
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    // ── Сессия 1: wish + изображения, close ─────────────────
    var db = openDb();
    var repo = DriftWishRepository(db, prefs);
    final wish = await repo.createWish(
      title: 'Дрель с фото',
      imageUrl: '/tmp/primary.jpg',
      additionalImagePaths: ['/tmp/one.jpg', '/tmp/two.jpg'],
    );
    await db.close();

    // ── Сессия 2: reopen — изображения и порядок на месте ──
    db = openDb();
    repo = DriftWishRepository(db, prefs);
    final restored = (await repo.getWishes()).single;
    expect(restored.id, wish.id);
    expect(restored.imageUrl, '/tmp/primary.jpg');

    final images = await repo.watchWishImages(wish.id).first;
    expect(images.map((i) => i.localPath), ['/tmp/one.jpg', '/tmp/two.jpg']);
    expect(images.map((i) => i.sortOrder), [1, 2]);
    await db.close();
  });

  test('pending upload state переживает restart (retry после сети)', () async {
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    // ── Сессия 1: wish + фото, sync так и не случился ────────
    var db = openDb();
    var repo = DriftWishRepository(db, prefs);
    final wish = await repo.createWish(
      title: 'Оффлайн-фото',
      imageUrl: '/tmp/primary.jpg',
      additionalImagePaths: ['/tmp/extra.jpg'],
    );
    await db.close();

    // ── Сессия 2: upload-queue видит pending после restart ───
    db = openDb();
    repo = DriftWishRepository(db, prefs);
    final pending = await db.wishesPendingImageUpload(owner);
    expect(pending.single.id, wish.id);
    expect(pending.single.imageUploadStatus, 'pending');
    expect(pending.single.imageUploadId, isNotNull); // client_id

    final pendingImages = await db.wishImagesPendingUpload(owner);
    expect(pendingImages.single.wishId, wish.id);
    expect(pendingImages.single.uploadStatus, 'pending');
    expect(pendingImages.single.uploadId, isNotNull);
    await db.close();
  });
}
