import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Локальные желания — source of truth для UI.
///
/// Все строки scope'нуты по `owner_id` (id текущего пользователя):
/// запросы всегда фильтруют по нему и `deleted_at IS NULL`.
/// Tombstone (`deleted_at`) нужен, пока DELETE не ушёл на сервер
/// через outbox — после успешного sync строка удаляется физически.
@TableIndex(name: 'wishes_owner_created', columns: {#ownerId, #createdAt})
@DataClassName('WishRow')
class Wishes extends Table {
  /// UUID сущности — генерируется клиентом до локальной записи
  /// и никогда не меняется при sync (client id == server id).
  TextColumn get id => text()();

  /// Владелец строки = текущий аккаунт. Изоляция аккаунтов
  /// на уровне SQL, а не в памяти.
  TextColumn get ownerId => text()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  IntColumn get price => integer().nullable()();

  TextColumn get link => text().nullable()();

  TextColumn get imageUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Soft-delete tombstone до доставки DELETE на сервер.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Списки покупок — source of truth для UI.
///
/// Те же правила, что у [Wishes]: `owner_id`-скоп, tombstone
/// `deleted_at` до доставки DELETE, клиентский UUID как PK.
@TableIndex(
  name: 'shopping_lists_owner_created',
  columns: {#ownerId, #createdAt},
)
@DataClassName('ShoppingListRow')
class ShoppingLists extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  TextColumn get title => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Позиции списков покупок.
///
/// Нормализованная таблица (не JSON внутри списка): каждая позиция —
/// отдельная строка со своим `owner_id` и ссылкой `list_id` на
/// родительский список. Все запросы scope'нуты по `owner_id`.
@TableIndex(name: 'shopping_items_list', columns: {#listId})
@TableIndex(name: 'shopping_items_owner', columns: {#ownerId})
@DataClassName('ShoppingItemRow')
class ShoppingItems extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  /// Родительский список (локальный = серверный UUID).
  TextColumn get listId => text()();

  TextColumn get title => text()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Дружеские связи текущего аккаунта (owner-scoped проекция).
///
/// Backend дружба симметрична и не отдаёт свой UUID клиенту —
/// identity связи на проводе это `friend_id` (id другого
/// пользователя). Локально PK = (owner_id, friend_id): пара
/// уникальна для аккаунта, entityId в outbox = friend_id.
@TableIndex(name: 'friendships_owner', columns: {#ownerId})
@DataClassName('FriendshipRow')
class Friendships extends Table {
  /// Текущий аккаунт — владелец проекции.
  TextColumn get ownerId => text()();

  /// Другой участник дружбы (UUID пользователя).
  TextColumn get friendId => text()();

  /// Backend моделирует дружбу как мгновенно принятую; колонка —
  /// задел под будущие состояния, сейчас всегда 'accepted'.
  TextColumn get status => text().withDefault(const Constant('accepted'))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Soft-delete tombstone до доставки DELETE /friends/{user}.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {ownerId, friendId};
}

/// Публичные проекции других пользователей (cache, не источник).
///
/// Хранит ровно поля `PublicUserResource`: id/name/username/
/// avatar_url. Никаких email/приватных данных. Owner-scoped:
/// кэш аккаунта A недоступен аккаунту B и удаляется при logout.
@TableIndex(name: 'cached_users_owner', columns: {#ownerId})
@DataClassName('CachedUserRow')
class CachedUsers extends Table {
  /// Текущий аккаунт — владелец кэша.
  TextColumn get ownerId => text()();

  /// UUID пользователя (как в backend).
  TextColumn get userId => text()();

  TextColumn get name => text().nullable()();

  TextColumn get username => text().nullable()();

  TextColumn get avatarUrl => text().nullable()();

  /// Когда проекция последний раз обновлена из сети.
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ownerId, userId};
}

/// Закэшированные желания друзей (read-only проекция).
///
/// ВАЖНО: `owner_id` здесь — владелец КЭША (текущий аккаунт),
/// а не автор желания. Автор — `friend_id`. Эта таблица не
/// смешивается с `wishes` владельца — чужие желания не могут
/// попасть в основной список желаний пользователя.
///
/// Remote wins: у текущего пользователя нет локальных мутаций
/// чужих желаний — snapshot refresh затирает и вычищает кэш.
@TableIndex(name: 'friend_wishes_owner_friend', columns: {#ownerId, #friendId})
@DataClassName('FriendWishRow')
class FriendWishes extends Table {
  /// UUID желания (серверный — wish id автора).
  TextColumn get id => text()();

  /// Владелец кэша = текущий аккаунт.
  TextColumn get ownerId => text()();

  /// Автор желания = друг (UUID пользователя).
  TextColumn get friendId => text()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  IntColumn get price => integer().nullable()();

  TextColumn get link => text().nullable()();

  TextColumn get imageUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Время последнего snapshot refresh (TTL-гейт в UI-слое).
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ownerId, friendId, id};
}

/// Очередь исходящих операций (offline outbox).
///
/// Строка создаётся в той же транзакции, что и локальная мутация
/// сущности — не бывает «сущности без outbox» и наоборот.
/// Обрабатывается SyncEngine в порядке `id ASC` (FIFO).
@TableIndex(name: 'outbox_owner_id', columns: {#ownerId, #id})
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get ownerId => text()();

  /// Тип сущности. Пока только 'wish'; extension point для
  /// будущих shopping/friends.
  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  /// 'create' | 'update' | 'delete'.
  TextColumn get operation => text()();

  /// Последний известный snapshot полей для create/update (JSON).
  /// Для delete payload не нужен.
  TextColumn get payloadJson => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  /// Следующая попытка — exponential backoff. null = можно сейчас.
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  /// 'pending' | 'failed' (422 — permanent, не ретраим).
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

/// Профили известных аккаунтов (persisted user identity).
///
/// Нужен для cold start offline: access token (secure storage)
/// + current_user_id (prefs) + строка профиля = сессия без сети.
class Profiles extends Table {
  TextColumn get id => text()();

  TextColumn get email => text()();

  TextColumn get name => text().nullable()();

  TextColumn get username => text().nullable()();

  TextColumn get avatarUrl => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Локальная база приложения. Единая на все account-scoped данные;
/// изоляция — через owner_id-колонки, а не отдельные файлы БД.
@DriftDatabase(
  tables: [
    Wishes,
    ShoppingLists,
    ShoppingItems,
    Friendships,
    CachedUsers,
    FriendWishes,
    OutboxEntries,
    Profiles,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'chtohochu'));

  /// Для unit-тестов — in-memory база.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Shopping domain: списки и позиции (offline-first slice 2).
        await migrator.createTable(shoppingLists);
        await migrator.createTable(shoppingItems);
      }
      if (from < 3) {
        // Friends domain: связи, публичные проекции, кэш чужих
        // желаний (offline-first slice 3).
        await migrator.createTable(friendships);
        await migrator.createTable(cachedUsers);
        await migrator.createTable(friendWishes);
      }
    },
  );

  // ── Profiles ─────────────────────────────────────────────

  Future<Profile?> profileById(String id) =>
      (select(profiles)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Реактивный профиль аккаунта — UI читает только его.
  /// `id` — это и есть owner_id (профиль идентифицирован аккаунтом).
  Stream<Profile?> watchProfile(String id) =>
      (select(profiles)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<void> upsertProfile(ProfilesCompanion profile) =>
      into(profiles).insertOnConflictUpdate(profile);

  // ── Wishes ───────────────────────────────────────────────

  /// Реактивный список желаний аккаунта — UI читает только его.
  Stream<List<WishRow>> watchWishes(String ownerId) {
    return (select(wishes)
          ..where((w) => w.ownerId.equals(ownerId) & w.deletedAt.isNull())
          ..orderBy([(w) => OrderingTerm.desc(w.createdAt)]))
        .watch();
  }

  Stream<WishRow?> watchWish(String ownerId, String id) {
    return (select(wishes)..where(
          (w) =>
              w.id.equals(id) &
              w.ownerId.equals(ownerId) &
              w.deletedAt.isNull(),
        ))
        .watchSingleOrNull();
  }

  Future<WishRow?> wishById(String ownerId, String id) {
    return (select(wishes)..where(
          (w) =>
              w.id.equals(id) &
              w.ownerId.equals(ownerId) &
              w.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<bool> hasWishes(String ownerId) async {
    final count = wishes.id.count();
    final query = selectOnly(wishes)
      ..addColumns([count])
      ..where(wishes.ownerId.equals(ownerId) & wishes.deletedAt.isNull());
    return (await query.getSingle()).read(count)! > 0;
  }

  // ── Shopping ─────────────────────────────────────────────

  /// Реактивные списки покупок аккаунта с позициями (join).
  /// Возвращает строки `list + nullable item` — группировка в
  /// репозитории. Items отфильтрованы по owner/tombstone в join.
  Stream<List<TypedResult>> watchShoppingListsWithItems(String ownerId) {
    final items = shoppingItems;
    final query =
        select(shoppingLists).join([
            leftOuterJoin(
              items,
              items.listId.equalsExp(shoppingLists.id) &
                  items.ownerId.equals(ownerId) &
                  items.deletedAt.isNull(),
            ),
          ])
          ..where(
            shoppingLists.ownerId.equals(ownerId) &
                shoppingLists.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.desc(shoppingLists.createdAt),
            OrderingTerm.asc(items.createdAt),
          ]);
    return query.watch();
  }

  Future<ShoppingListRow?> shoppingListById(String ownerId, String id) {
    return (select(shoppingLists)..where(
          (l) =>
              l.id.equals(id) &
              l.ownerId.equals(ownerId) &
              l.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  /// Позиции списка (живые, owner-scoped), в порядке добавления.
  Future<List<ShoppingItemRow>> shoppingItemsOf(String ownerId, String listId) {
    return (select(shoppingItems)
          ..where(
            (i) =>
                i.listId.equals(listId) &
                i.ownerId.equals(ownerId) &
                i.deletedAt.isNull(),
          )
          ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
        .get();
  }

  /// Позиция по id (включая tombstone — нужен sync/drop path).
  Future<ShoppingItemRow?> shoppingItemByIdAny(String ownerId, String id) {
    return (select(shoppingItems)
          ..where((i) => i.id.equals(id) & i.ownerId.equals(ownerId)))
        .getSingleOrNull();
  }

  // ── Friends ──────────────────────────────────────────────

  /// Реактивные друзья аккаунта: friendship ⨝ cached_user ⨝
  /// friend_wishes. Возвращает строки `friendship + cachedUser? +
  /// friendWish?` — группировка в репозитории. Изменение любой
  /// из трёх таблиц переизлучает стрим.
  Stream<List<TypedResult>> watchFriendsData(String ownerId) {
    final users = cachedUsers;
    final wishes = friendWishes;
    final query =
        select(friendships).join([
            leftOuterJoin(
              users,
              users.userId.equalsExp(friendships.friendId) &
                  users.ownerId.equals(ownerId),
            ),
            leftOuterJoin(
              wishes,
              wishes.friendId.equalsExp(friendships.friendId) &
                  wishes.ownerId.equals(ownerId),
            ),
          ])
          ..where(
            friendships.ownerId.equals(ownerId) &
                friendships.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(friendships.createdAt),
            OrderingTerm.desc(wishes.createdAt),
          ]);
    return query.watch();
  }

  /// Связь по friend_id (включая tombstone — sync/drop path).
  Future<FriendshipRow?> friendshipByIdAny(String ownerId, String friendId) {
    return (select(friendships)..where(
          (f) => f.friendId.equals(friendId) & f.ownerId.equals(ownerId),
        ))
        .getSingleOrNull();
  }

  /// Закэшированные желания друга (owner-scoped), новые первыми.
  Future<List<FriendWishRow>> friendWishesOf(String ownerId, String friendId) {
    return (select(friendWishes)
          ..where(
            (w) => w.ownerId.equals(ownerId) & w.friendId.equals(friendId),
          )
          ..orderBy([(w) => OrderingTerm.desc(w.createdAt)]))
        .get();
  }

  /// Свежесть кэша желаний друга (max fetched_at), null = ни разу.
  Future<DateTime?> friendWishesFetchedAt(
    String ownerId,
    String friendId,
  ) async {
    final maxFetched = friendWishes.fetchedAt.max();
    final row =
        await (selectOnly(friendWishes)
              ..addColumns([maxFetched])
              ..where(
                friendWishes.ownerId.equals(ownerId) &
                    friendWishes.friendId.equals(friendId),
              ))
            .getSingle();
    return row.read(maxFetched);
  }

  /// Публичная проекция пользователя из кэша текущего аккаунта.
  Future<CachedUserRow?> cachedUserById(String ownerId, String userId) {
    return (select(cachedUsers)
          ..where((u) => u.userId.equals(userId) & u.ownerId.equals(ownerId)))
        .getSingleOrNull();
  }

  /// Атомарная замена кэша желаний друга snapshot'ом с сервера.
  /// Remote wins — чужие желания не редактируются локально.
  Future<void> replaceFriendWishes(
    String ownerId,
    String friendId,
    List<FriendWishesCompanion> snapshot,
  ) {
    return transaction(() async {
      await (delete(friendWishes)..where(
            (w) => w.ownerId.equals(ownerId) & w.friendId.equals(friendId),
          ))
          .go();
      for (final w in snapshot) {
        await into(friendWishes).insertOnConflictUpdate(w);
      }
    });
  }

  // ── Outbox ───────────────────────────────────────────────

  /// Pending-операции аккаунта в порядке постановки (FIFO),
  /// с учётом backoff и permanent-failed.
  Future<List<OutboxEntry>> dueOutbox(String ownerId, DateTime now) {
    return (select(outboxEntries)
          ..where(
            (o) =>
                o.ownerId.equals(ownerId) &
                o.status.equals('pending') &
                (o.nextRetryAt.isNull() |
                    o.nextRetryAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([(o) => OrderingTerm.asc(o.id)]))
        .get();
  }

  /// Число pending+failed операций аккаунта (для logout-guard).
  Stream<int> watchOutboxCount(String ownerId) {
    final count = outboxEntries.id.count();
    return (selectOnly(outboxEntries)
          ..addColumns([count])
          ..where(outboxEntries.ownerId.equals(ownerId)))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  Future<int> outboxCount(String ownerId) async {
    final count = outboxEntries.id.count();
    final row =
        await (selectOnly(outboxEntries)
              ..addColumns([count])
              ..where(outboxEntries.ownerId.equals(ownerId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Операция по первичному ключу — SyncEngine проверяет, не
  /// изменилась ли операция, пока её HTTP-запрос был в полёте.
  Future<OutboxEntry?> outboxEntryById(int id) {
    return (select(
      outboxEntries,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
  }

  /// Все незавершённые операции сущности (pending и failed) —
  /// используется compaction внутри мутационных транзакций.
  Future<List<OutboxEntry>> opsFor(String ownerId, String entityId) {
    return (select(outboxEntries)..where(
          (o) => o.ownerId.equals(ownerId) & o.entityId.equals(entityId),
        ))
        .get();
  }

  /// Сущности с НЕЗАВЕРШЁННЫМИ outbox-операциями (pending + failed).
  /// Snapshot pull их не трогает: pending — локальное состояние новее
  /// серверного; failed — данные пользователя не должны молча
  /// удаляться из-за того, что сервер о сущности не знает.
  Future<Set<String>> pendingEntityIds(String ownerId) async {
    final rows =
        await (selectOnly(outboxEntries)
              ..addColumns([outboxEntries.entityId])
              ..where(outboxEntries.ownerId.equals(ownerId)))
            .get();
    return rows.map((r) => r.read(outboxEntries.entityId)!).toSet();
  }

  /// Очистить все account-scoped данные пользователя (logout).
  Future<void> clearAccountData(String ownerId) async {
    await transaction(() async {
      await (delete(wishes)..where((w) => w.ownerId.equals(ownerId))).go();
      await (delete(
        shoppingLists,
      )..where((l) => l.ownerId.equals(ownerId))).go();
      await (delete(
        shoppingItems,
      )..where((i) => i.ownerId.equals(ownerId))).go();
      await (delete(friendships)..where((f) => f.ownerId.equals(ownerId))).go();
      await (delete(
        friendWishes,
      )..where((w) => w.ownerId.equals(ownerId))).go();
      await (delete(cachedUsers)..where((u) => u.ownerId.equals(ownerId))).go();
      await (delete(
        outboxEntries,
      )..where((o) => o.ownerId.equals(ownerId))).go();
      await (delete(profiles)..where((p) => p.id.equals(ownerId))).go();
    });
  }
}
