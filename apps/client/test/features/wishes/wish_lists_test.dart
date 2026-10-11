import 'dart:convert';

import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:chtohochu/features/wishes/domain/wish_list.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Тесты сущности WishList на уровне репозитория: создание
/// с outbox-операцией, реактивный стрим со счётчиком, связь
/// wishes.listId, update/delete lifecycle, owner-изоляция.
/// Push/pull — в sync_wish_lists_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ownerA = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const ownerB = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  late AppDatabase db;
  late DriftWishRepository repo;

  setUp(() async {
    setupTestStorage(
      preferences: {'current_user_id': ownerA},
      secureStorage: {'access_token': 't'},
    );
    final prefs = PreferencesService(await SharedPreferences.getInstance());
    db = createTestDatabase();
    repo = DriftWishRepository(db, prefs);
  });

  tearDown(() => db.close());

  test('createWishList сохраняет в Drift и ставит outbox create', () async {
    final list = await repo.createWishList(title: 'Подарки');

    final row = await (db.select(
      db.wishLists,
    )..where((l) => l.id.equals(list.id))).getSingle();
    expect(row.title, 'Подарки');
    expect(row.ownerId, ownerA);
    expect(row.deletedAt, isNull);

    final ops = await db.select(db.outboxEntries).get();
    expect(ops.single.entityType, 'wish_list');
    expect(ops.single.entityId, list.id);
    expect(ops.single.operation, 'create');
    expect(ops.single.payloadJson, contains(list.id));
  });

  test('updateWishList переименовывает и ставит outbox update', () async {
    final list = await repo.createWishList(title: 'Старое');

    await repo.updateWishList(list.copyWith(title: 'Новое'));

    final row = await (db.select(
      db.wishLists,
    )..where((l) => l.id.equals(list.id))).getSingle();
    expect(row.title, 'Новое');
    // create + update компактируются в один create с новым title.
    final ops = await db.select(db.outboxEntries).get();
    expect(ops.single.operation, 'create');
    expect(ops.single.payloadJson, contains('Новое'));
  });

  test('deleteWishList синхронизированного списка: tombstone + '
      'outbox delete, желания разгруппированы, не удалены', () async {
    // Список, уже доставленный на сервер (outbox-операций нет —
    // как после успешного pull/push).
    final now = DateTime.now();
    await db
        .into(db.wishLists)
        .insert(
          WishListsCompanion(
            id: const Value('synced-list'),
            ownerId: const Value(ownerA),
            title: const Value('L'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final list = WishList(id: 'synced-list', title: 'L', createdAt: now);
    final wish = await repo.createWish(title: 'W');
    await repo.assignWishToList(wish.id, list.id);

    await repo.deleteWishList(list.id);

    final row = await (db.select(
      db.wishLists,
    )..where((l) => l.id.equals(list.id))).getSingle();
    expect(row.deletedAt, isNotNull);
    // Список скрыт из стрима, хотя строка ещё жива (tombstone).
    expect(await repo.watchWishLists().first, isEmpty);

    // Желание живо, связь снята.
    final wishRow = await (db.select(
      db.wishes,
    )..where((w) => w.id.equals(wish.id))).getSingle();
    expect(wishRow.deletedAt, isNull);
    expect(wishRow.listId, isNull);

    // Компактификация: create списка снят, остался delete.
    final ops = await (db.select(
      db.outboxEntries,
    )..where((o) => o.entityId.equals(list.id))).get();
    expect(ops.single.operation, 'delete');
  });

  test('deleteWishList несинхронизированного списка — физическое '
      'удаление, outbox пуст', () async {
    final list = await repo.createWishList(title: 'L');
    // create ещё в outbox — delete должен снести строку без delete-op.
    await repo.deleteWishList(list.id);

    expect(
      await (db.select(
        db.wishLists,
      )..where((l) => l.id.equals(list.id))).getSingleOrNull(),
      isNull,
    );
    expect(
      (await db.select(db.outboxEntries).get()).where(
        (o) => o.entityId == list.id,
      ),
      isEmpty,
    );
  });

  test('watchWishLists отдаёт списки со счётчиком желаний', () async {
    final list = await repo.createWishList(title: 'Подарки');
    await repo.createWishList(title: 'Пустой');

    // Два желания в списке — через доменный механизм membership.
    for (final t in ['A', 'B']) {
      final wish = await repo.createWish(title: t);
      await repo.assignWishToList(wish.id, list.id);
    }

    final lists = await repo.watchWishLists().first;
    expect(lists, hasLength(2));
    final gifts = lists.firstWhere((l) => l.title == 'Подарки');
    expect(gifts.wishCount, 2);
    expect(lists.firstWhere((l) => l.title == 'Пустой').wishCount, 0);
    // Новые списки первые (createdAt DESC).
    expect(lists.last.title, 'Подарки');
    expect(lists.first.title, 'Пустой');
  });

  test('wish.listId сохраняется в домене желания', () async {
    final list = await repo.createWishList(title: 'L');
    final wish = await repo.createWish(title: 'W', listId: list.id);

    final loaded = await repo.getWishById(wish.id);
    expect(loaded!.listId, list.id);
  });

  test('membership уходит в outbox: create с listId и '
      'assignWishToList(null)', () async {
    final list = await repo.createWishList(title: 'L');
    final wish = await repo.createWish(title: 'W', listId: list.id);

    // create-операция желания несёт membership в payload.
    var ops = await db.opsFor(ownerA, wish.id);
    var payload = jsonDecode(ops.single.payloadJson!) as Map<String, dynamic>;
    expect(payload['list_id'], list.id);

    // list → null: update с явным null.
    await repo.assignWishToList(wish.id, null);
    // create+update скомпактируются в create с list_id: null.
    ops = await db.opsFor(ownerA, wish.id);
    payload = jsonDecode(ops.single.payloadJson!) as Map<String, dynamic>;
    expect(ops.single.operation, 'create');
    expect(payload.containsKey('list_id'), isTrue);
    expect(payload['list_id'], isNull);
  });

  test('списки изолированы по owner_id', () async {
    await repo.createWishList(title: 'Чужой?');
    // Строка owner B напрямую — стрим A её не видит.
    await db
        .into(db.wishLists)
        .insert(
          WishListsCompanion(
            id: const Value('other-list'),
            ownerId: const Value(ownerB),
            title: const Value('Чужой'),
            createdAt: Value(DateTime(2025)),
            updatedAt: Value(DateTime(2025)),
          ),
        );

    final lists = await repo.watchWishLists().first;
    expect(lists.map((l) => l.title), ['Чужой?']);
    expect(lists.single.wishCount, 0);
  });
}
