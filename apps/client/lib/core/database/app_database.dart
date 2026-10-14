import 'dart:convert';

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

  /// Путь к локальному файлу primary-изображения — иммутабельный
  /// display-source. `image_url` переключается на remote URL после
  /// upload, но UI продолжает показывать локальный файл — источник
  /// изображения никогда не меняется вживую (бесшовный local→remote).
  TextColumn get imageLocalPath => text().nullable()();

  /// Upload-статус primary-изображения (ADR-015):
  /// `null` — локального изображения нет или оно удалённое;
  /// pending → uploading → uploaded | failed.
  TextColumn get imageUploadStatus => text().nullable()();

  /// Стабильный idempotency-ключ (`client_id` media upload) —
  /// retry запроса инструкций возвращает тот же upload на сервере.
  TextColumn get imageUploadId => text().nullable()();

  /// Приоритет желания: `later | normal | high` (default `normal`).
  /// Скалярное поле — группировка выполняется только в UI,
  /// отдельных таблиц нет.
  TextColumn get priority => text().withDefault(const Constant('normal'))();

  /// Локальный список желаний, в котором лежит желание
  /// (`wish_lists.id`); `null` — вне списков. Local-only связь:
  /// сервер списков пока не знает, в outbox не попадает.
  TextColumn get listId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Soft-delete tombstone до доставки DELETE на сервер.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Дополнительные изображения желаний — source of truth для UI.
///
/// Нормализованная таблица (не JSON внутри `wishes`): каждое
/// изображение — отдельная строка со своим `owner_id` и ссылкой
/// `wish_id` на родительское желание. Primary-изображение
/// остаётся `wishes.image_url` — здесь живут только additional.
///
/// `local_path` — файл на устройстве (`Documents/wish_photos/`),
/// `remote_url` — задел под будущий upload (S3): строка
/// заполняется после загрузки, до этого upload pipeline может
/// определять незагруженные изображения по `remote_url IS NULL`.
///
/// Изображения — local-only сущность: сервер их пока не знает,
/// outbox-операций нет, tombstone не нужен. Живут и умирают
/// вместе с родительским желанием (каскад в repository/sync).
@TableIndex(name: 'wish_images_wish', columns: {#wishId})
@TableIndex(name: 'wish_images_owner', columns: {#ownerId})
@DataClassName('WishImageRow')
class WishImages extends Table {
  /// UUID изображения — клиентский, как у всех сущностей.
  TextColumn get id => text()();

  /// Владелец строки = текущий аккаунт (SQL-изоляция).
  TextColumn get ownerId => text()();

  /// Родительское желание (локальный = серверный UUID).
  TextColumn get wishId => text()();

  /// Путь к файлу на устройстве (`Documents/media/wishes/…`).
  TextColumn get localPath => text().nullable()();

  /// URL после загрузки на сервер/CDN. null = ещё не загружено.
  TextColumn get remoteUrl => text().nullable()();

  /// Upload lifecycle (ADR-015): pending → uploading → uploaded | failed.
  TextColumn get uploadStatus =>
      text().withDefault(const Constant('pending'))();

  /// Стабильный idempotency-ключ (`client_id` media upload).
  TextColumn get uploadId => text().nullable()();

  /// Порядок отображения: 1, 2, … (primary — wishes.image_url).
  IntColumn get sortOrder => integer()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Списки желаний — группировка wishes пользователя.
///
/// Те же правила, что у [Wishes]: `owner_id`-скоп, tombstone
/// `deleted_at` до доставки DELETE, клиентский UUID как PK.
/// Желание ссылается через `wishes.list_id` (максимум один
/// список на желание); при удалении списка желания
/// разгруппировываются (`list_id` → null), не удаляются.
@TableIndex(name: 'wish_lists_owner_created', columns: {#ownerId, #createdAt})
@DataClassName('WishListRow')
class WishLists extends Table {
  /// UUID списка — генерируется клиентом.
  TextColumn get id => text()();

  /// Владелец строки = текущий аккаунт (SQL-изоляция).
  TextColumn get ownerId => text()();

  TextColumn get title => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Tombstone до доставки DELETE /wish-lists/{id}.
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

  /// Серверный владелец списка (UUID пользователя). Для собственных
  /// списков совпадает с `ownerId`; для shared-списков — id
  /// владельца. Определяет роль в UI: owner-only действия
  /// (переименование, удаление, управление участниками).
  TextColumn get ownerUserId => text().withDefault(const Constant(''))();

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

  /// Путь к локальному фото позиции (media/shopping/).
  /// Только локально: backend позиций изображения не хранит —
  /// в outbox/API-payload колонка не попадает.
  TextColumn get imageLocalPath => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Участники совместного списка покупок (owner-scoped проекция).
///
/// Снимок серверного состава списка: владелец (`role='owner'`) и
/// members (`role='member'`). Профильные поля денормализованы —
/// тот же набор, что у `PublicUserResource`. Локальные pending-
/// мутации защищены outbox'ом entityType 'shopping_list_member':
/// entityId = `'<listId>:<memberId>'`.
@TableIndex(
  name: 'shopping_list_members_owner_list',
  columns: {#ownerId, #listId},
)
@DataClassName('ShoppingListMemberRow')
class ShoppingListMembers extends Table {
  /// Текущий аккаунт — владелец проекции.
  TextColumn get ownerId => text()();

  /// Список, к которому относится участник.
  TextColumn get listId => text()();

  /// UUID пользователя-участника (как в backend).
  TextColumn get memberId => text()();

  /// 'owner' | 'member'.
  TextColumn get role => text().withDefault(const Constant('member'))();

  TextColumn get name => text().nullable()();

  TextColumn get username => text().nullable()();

  TextColumn get avatarUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Tombstone для pending-remove: reconcile не воскрешает
  /// строку, пока DELETE не уехал на сервер.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {ownerId, listId, memberId};
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

  /// Тип сущности: 'wish' | 'wish_list' | 'shopping_list' |
  /// 'shopping_item' | 'friendship' | 'profile'.
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
    WishImages,
    WishLists,
    ShoppingLists,
    ShoppingItems,
    ShoppingListMembers,
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
  int get schemaVersion => 12;

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
      if (from < 4) {
        // Дополнительные локальные изображения желаний.
        // Существующие image_url не мигрируются — они остаются
        // primary-изображениями в wishes.
        await migrator.createTable(wishImages);
      }
      if (from < 5) {
        // Media upload lifecycle (ADR-015): статус + idempotency-key.
        await migrator.addColumn(wishes, wishes.imageUploadStatus);
        await migrator.addColumn(wishes, wishes.imageUploadId);
        if (from >= 4) {
          // wish_images, созданная в шаге v4, уже содержит эти
          // колонки — addColumn нужен только для реальной v4-базы.
          await migrator.addColumn(wishImages, wishImages.uploadStatus);
          await migrator.addColumn(wishImages, wishImages.uploadId);
        }
        // Существующие локальные пути ожидают upload; remote —
        // уже доставлены (status irrelevant).
        await customStatement(
          "UPDATE wishes SET image_upload_status = 'pending' "
          'WHERE image_url IS NOT NULL '
          "AND image_url NOT LIKE 'http%'",
        );
      }
      if (from < 6) {
        // Отдельный display-source primary-изображения: локальный
        // путь перестаёт зависеть от переключения image_url → remote.
        await migrator.addColumn(wishes, wishes.imageLocalPath);
        await customStatement(
          'UPDATE wishes SET image_local_path = image_url '
          'WHERE image_url IS NOT NULL '
          "AND image_url NOT LIKE 'http%'",
        );
      }
      if (from >= 2 && from < 7) {
        // Локальное фото позиции списка покупок (media/shopping/).
        // Только local path — backend позиций изображения не хранит.
        // При апгрейде v1→v7 таблица создана выше уже с этой колонкой.
        await migrator.addColumn(shoppingItems, shoppingItems.imageLocalPath);
      }
      if (from < 8) {
        // Списки желаний (local-only) + связь wishes.list_id.
        await migrator.createTable(wishLists);
        await migrator.addColumn(wishes, wishes.listId);
      }
      if (from == 8) {
        // WishList — серверная сущность: tombstone-колонка.
        // Списки, созданные local-only в v8, никогда не имели
        // outbox-операций — backfill'им create, чтобы они
        // доехали до сервера обычным push-циклом.
        await migrator.addColumn(wishLists, wishLists.deletedAt);
        final unsynced = await select(wishLists).get();
        final migratedAt = DateTime.now();
        for (final row in unsynced) {
          await into(outboxEntries).insert(
            OutboxEntriesCompanion(
              ownerId: Value(row.ownerId),
              entityType: const Value('wish_list'),
              entityId: Value(row.id),
              operation: const Value('create'),
              payloadJson: Value(
                jsonEncode({'id': row.id, 'title': row.title}),
              ),
              createdAt: Value(migratedAt),
            ),
          );
        }
      }
      if (from < 10) {
        // Membership стал серверным (wishes.list_id → API).
        // Локальные привязки доезжают до сервера: встраиваем
        // list_id в существующий pending payload желания или
        // ставим отдельный update. Живой список-цель обязателен
        // (иначе PATCH получил бы 422 — чужой/удалённый список
        // сервером отклоняется).
        final liveListIds = (await (select(
          wishLists,
        )..where((l) => l.deletedAt.isNull())).get()).map((l) => l.id).toSet();
        // selectOnly, а не select(wishes): на этом шаге таблица
        // ещё в форме < v10 — колонок поздних схем (priority и т.п.)
        // нет, полный row-mapping упал бы на старой базе.
        final members =
            await (selectOnly(wishes)
                  ..addColumns([wishes.id, wishes.listId, wishes.ownerId])
                  ..where(
                    wishes.listId.isNotNull() & wishes.deletedAt.isNull(),
                  ))
                .get();
        final migratedAt = DateTime.now();
        for (final w in members) {
          final wishId = w.read(wishes.id)!;
          final wishOwnerId = w.read(wishes.ownerId)!;
          final wishListId = w.read(wishes.listId);
          if (!liveListIds.contains(wishListId)) continue;
          final ops = await opsFor(wishOwnerId, wishId);
          // Удаляемое желание не трогаем: update после delete —
          // висячий PATCH на уже удалённую сущность.
          if (ops.any((o) => o.operation == 'delete')) continue;
          final carried = ops.where((o) => o.payloadJson != null).toList();
          if (carried.isEmpty) {
            await into(outboxEntries).insert(
              OutboxEntriesCompanion(
                ownerId: Value(wishOwnerId),
                entityType: const Value('wish'),
                entityId: Value(wishId),
                operation: const Value('update'),
                payloadJson: Value(jsonEncode({'list_id': wishListId})),
                createdAt: Value(migratedAt),
              ),
            );
          } else {
            for (final op in carried) {
              final payload =
                  jsonDecode(op.payloadJson!) as Map<String, dynamic>;
              payload['list_id'] = wishListId;
              await (update(
                outboxEntries,
              )..where((o) => o.id.equals(op.id))).write(
                OutboxEntriesCompanion(payloadJson: Value(jsonEncode(payload))),
              );
            }
          }
        }
      }
      if (from < 11) {
        // Совместные списки покупок: участники + серверный
        // owner_id списка. Существующие локальные списки —
        // собственные: owner_user_id = owner_id аккаунта.
        await migrator.createTable(shoppingListMembers);
        if (from >= 2) {
          await migrator.addColumn(shoppingLists, shoppingLists.ownerUserId);
          await customStatement(
            'UPDATE shopping_lists SET owner_user_id = owner_id',
          );
        }
      }
      if (from < 12) {
        // Приоритет желания (later|normal|high). Существующие
        // строки получают 'normal' через column default.
        await migrator.addColumn(wishes, wishes.priority);
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

  /// Реактивные желания конкретного списка (owner-scoped, без
  /// tombstone) — экран списка желаний. Стрим реагирует на
  /// изменение `list_id`: убранное желание исчезает,
  /// добавленное появляется.
  Stream<List<WishRow>> watchWishesInList(String ownerId, String listId) {
    return (select(wishes)
          ..where(
            (w) =>
                w.ownerId.equals(ownerId) &
                w.listId.equals(listId) &
                w.deletedAt.isNull(),
          )
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

  // ── Wish images ─────────────────────────────────────────

  /// Реактивные дополнительные изображения желания
  /// (owner-scoped), упорядоченные по `sort_order`.
  Stream<List<WishImageRow>> watchWishImages(String ownerId, String wishId) {
    return (select(wishImages)
          ..where((i) => i.wishId.equals(wishId) & i.ownerId.equals(ownerId))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .watch();
  }

  /// Дополнительные изображения желания (snapshot-чтение).
  Future<List<WishImageRow>> wishImagesOf(String ownerId, String wishId) {
    return (select(wishImages)
          ..where((i) => i.wishId.equals(wishId) & i.ownerId.equals(ownerId))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .get();
  }

  /// Удалить все изображения желания. Возвращает `local_path`
  /// удалённых строк — вызывающий код может убрать файлы.
  Future<List<String>> deleteWishImages(String ownerId, String wishId) async {
    final rows = await (select(
      wishImages,
    )..where((i) => i.wishId.equals(wishId) & i.ownerId.equals(ownerId))).get();
    if (rows.isEmpty) return const [];
    await (delete(
      wishImages,
    )..where((i) => i.wishId.equals(wishId) & i.ownerId.equals(ownerId))).go();
    return [
      for (final r in rows)
        if (r.localPath != null) r.localPath!,
    ];
  }

  /// Одна строка доп.изображения (owner-scoped).
  Future<WishImageRow?> wishImageById(String ownerId, String imageId) {
    return (select(wishImages)
          ..where((i) => i.id.equals(imageId) & i.ownerId.equals(ownerId)))
        .getSingleOrNull();
  }

  /// Вставить строку доп.изображения.
  Future<void> insertWishImage(WishImagesCompanion row) =>
      into(wishImages).insert(row);

  /// Удалить строку доп.изображения; возвращает `local_path`
  /// удалённой строки (для cleanup файла) или `null`.
  Future<String?> deleteWishImageRow(String ownerId, String imageId) async {
    final row = await wishImageById(ownerId, imageId);
    if (row == null) return null;
    await (delete(
      wishImages,
    )..where((i) => i.id.equals(imageId) & i.ownerId.equals(ownerId))).go();
    return row.localPath;
  }

  /// Обновить `sort_order` существующей строки.
  Future<void> setWishImageSortOrder(
    String ownerId,
    String imageId,
    int sortOrder,
  ) {
    return (update(wishImages)
          ..where((i) => i.id.equals(imageId) & i.ownerId.equals(ownerId)))
        .write(WishImagesCompanion(sortOrder: Value(sortOrder)));
  }

  /// Upsert серверного изображения при pull-reconcile.
  ///
  /// Новая строка помечается `uploaded` — сервер знает только
  /// доставленные изображения. У существующей обновляются
  /// `remote_url`/`sort_order`; `local_path` не трогается —
  /// локальный файл иммутабелен как источник отображения.
  Future<void> upsertRemoteWishImage({
    required String ownerId,
    required String wishId,
    required String id,
    required String url,
    required int sortOrder,
  }) async {
    final existing = await wishImageById(ownerId, id);
    if (existing == null) {
      await into(wishImages).insert(
        WishImagesCompanion(
          id: Value(id),
          ownerId: Value(ownerId),
          wishId: Value(wishId),
          remoteUrl: Value(url),
          uploadStatus: const Value('uploaded'),
          sortOrder: Value(sortOrder),
          createdAt: Value(DateTime.now()),
        ),
      );
    } else {
      await (update(
        wishImages,
      )..where((i) => i.id.equals(id) & i.ownerId.equals(ownerId))).write(
        WishImagesCompanion(
          remoteUrl: Value(url),
          uploadStatus: const Value('uploaded'),
          sortOrder: Value(sortOrder),
        ),
      );
    }
  }

  // ── Media upload queue (ADR-015) ────────────────────────

  /// Желания с primary-изображением, ожидающим upload
  /// (`pending`/`uploading`; `uploading` после сбоя процесса
  /// retry'ится как pending — idempotent через `client_id`).
  Future<List<WishRow>> wishesPendingImageUpload(String ownerId) {
    return (select(wishes)..where(
          (w) =>
              w.ownerId.equals(ownerId) &
              w.deletedAt.isNull() &
              w.imageUploadStatus.isIn(['pending', 'uploading']),
        ))
        .get();
  }

  /// Дополнительные изображения, ожидающие upload.
  Future<List<WishImageRow>> wishImagesPendingUpload(String ownerId) {
    return (select(wishImages)..where(
          (i) =>
              i.ownerId.equals(ownerId) &
              i.uploadStatus.isIn(['pending', 'uploading']) &
              i.localPath.isNotNull(),
        ))
        .get();
  }

  /// Статус upload primary-изображения желания.
  Future<void> setWishImageUploadState(
    String ownerId,
    String wishId, {
    required String status,
    String? uploadId,
    String? remoteUrl,
  }) {
    return (update(
      wishes,
    )..where((w) => w.id.equals(wishId) & w.ownerId.equals(ownerId))).write(
      WishesCompanion(
        imageUploadStatus: Value(status),
        imageUploadId: uploadId != null
            ? Value(uploadId)
            : const Value.absent(),
        imageUrl: remoteUrl != null ? Value(remoteUrl) : const Value.absent(),
      ),
    );
  }

  /// Статус upload дополнительного изображения.
  Future<void> setWishImageRowUploadState(
    String ownerId,
    String imageId, {
    required String status,
    String? uploadId,
    String? remoteUrl,
  }) {
    return (update(
      wishImages,
    )..where((i) => i.id.equals(imageId) & i.ownerId.equals(ownerId))).write(
      WishImagesCompanion(
        uploadStatus: Value(status),
        uploadId: uploadId != null ? Value(uploadId) : const Value.absent(),
        remoteUrl: remoteUrl != null ? Value(remoteUrl) : const Value.absent(),
      ),
    );
  }

  /// Локальные пути всех изображений аккаунта: `local_path`
  /// дополнительных + `image_local_path` желаний (fallback —
  /// локальный `image_url` строк до миграции v6).
  /// Используется для best-effort очистки файлов при
  /// удалении аккаунта/желания.
  Future<List<String>> localWishImagePaths(String ownerId) async {
    final imageRows = await (select(
      wishImages,
    )..where((i) => i.ownerId.equals(ownerId))).get();
    final wishRows = await (select(
      wishes,
    )..where((w) => w.ownerId.equals(ownerId))).get();
    bool isRemote(String ref) =>
        ref.startsWith('http://') || ref.startsWith('https://');
    return {
      for (final r in imageRows)
        if (r.localPath != null) r.localPath!,
      for (final w in wishRows)
        if (w.imageLocalPath != null)
          w.imageLocalPath!
        else if (w.imageUrl != null && !isRemote(w.imageUrl!))
          w.imageUrl!,
    }.toList();
  }

  // ── Wish lists ───────────────────────────────────────────

  /// Реактивные списки желаний аккаунта с желаниями (join).
  /// Возвращает строки `list + nullable wish` — группировка в
  /// репозитории. Желания отфильтрованы по owner/tombstone в join.
  Stream<List<TypedResult>> watchWishListsWithWishes(String ownerId) {
    final w = wishes;
    final query =
        select(wishLists).join([
            leftOuterJoin(
              w,
              w.listId.equalsExp(wishLists.id) &
                  w.ownerId.equals(ownerId) &
                  w.deletedAt.isNull(),
            ),
          ])
          ..where(
            wishLists.ownerId.equals(ownerId) & wishLists.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(wishLists.createdAt)]);
    return query.watch();
  }

  // ── Shopping ─────────────────────────────────────────────

  /// Реактивные списки покупок аккаунта с позициями и участниками
  /// (join). Возвращает строки `list + nullable item + nullable
  /// member` — декартово произведение группируется в репозитории
  /// по id. Items и members отфильтрованы по owner/tombstone.
  Stream<List<TypedResult>> watchShoppingListsWithItems(String ownerId) {
    final items = shoppingItems;
    final members = shoppingListMembers;
    final query =
        select(shoppingLists).join([
            leftOuterJoin(
              items,
              items.listId.equalsExp(shoppingLists.id) &
                  items.ownerId.equals(ownerId) &
                  items.deletedAt.isNull(),
            ),
            leftOuterJoin(
              members,
              members.listId.equalsExp(shoppingLists.id) &
                  members.ownerId.equals(ownerId) &
                  members.deletedAt.isNull(),
            ),
          ])
          ..where(
            shoppingLists.ownerId.equals(ownerId) &
                shoppingLists.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.desc(shoppingLists.createdAt),
            OrderingTerm.asc(items.createdAt),
            OrderingTerm.asc(members.createdAt),
          ]);
    return query.watch();
  }

  /// Живые участники списка (owner-scoped), в порядке добавления.
  Future<List<ShoppingListMemberRow>> shoppingListMembersOf(
    String ownerId,
    String listId,
  ) {
    return (select(shoppingListMembers)
          ..where(
            (m) =>
                m.ownerId.equals(ownerId) &
                m.listId.equals(listId) &
                m.deletedAt.isNull(),
          )
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }

  /// Участник списка включая tombstone (для reconcile/outbox).
  Future<ShoppingListMemberRow?> shoppingListMemberByIdAny(
    String ownerId,
    String listId,
    String memberId,
  ) {
    return (select(shoppingListMembers)..where(
          (m) =>
              m.ownerId.equals(ownerId) &
              m.listId.equals(listId) &
              m.memberId.equals(memberId),
        ))
        .getSingleOrNull();
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

  /// Убрать `list_id` удаляемого списка из payload'ов неотправленных
  /// wish-операций: без этого PATCH/POST ушёл бы с уже несуществующим
  /// списком на сервере и получил бы permanent 422.
  Future<void> nullListIdInWishOps(String ownerId, String listId) async {
    final ops =
        await (select(outboxEntries)..where(
              (o) =>
                  o.ownerId.equals(ownerId) &
                  o.entityType.equals('wish') &
                  o.operation.equals('delete').not() &
                  o.payloadJson.isNotNull(),
            ))
            .get();
    for (final op in ops) {
      final payload = jsonDecode(op.payloadJson!) as Map<String, dynamic>;
      if (payload['list_id'] != listId) continue;
      payload['list_id'] = null;
      await (update(outboxEntries)..where((o) => o.id.equals(op.id))).write(
        OutboxEntriesCompanion(payloadJson: Value(jsonEncode(payload))),
      );
    }
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
  ///
  /// Возвращает пути локальных файлов изображений — вызывающий
  /// код удаляет их best-effort (файлы могут уже отсутствовать).
  Future<List<String>> clearAccountData(String ownerId) async {
    final imagePaths = await localWishImagePaths(ownerId);
    await transaction(() async {
      await (delete(wishes)..where((w) => w.ownerId.equals(ownerId))).go();
      await (delete(wishImages)..where((i) => i.ownerId.equals(ownerId))).go();
      await (delete(wishLists)..where((l) => l.ownerId.equals(ownerId))).go();
      await (delete(
        shoppingLists,
      )..where((l) => l.ownerId.equals(ownerId))).go();
      await (delete(
        shoppingItems,
      )..where((i) => i.ownerId.equals(ownerId))).go();
      await (delete(
        shoppingListMembers,
      )..where((m) => m.ownerId.equals(ownerId))).go();
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
    return imagePaths;
  }
}
