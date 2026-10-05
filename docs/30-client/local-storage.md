# Flutter Local Data

## 1. Purpose

This document defines how the ЧтоХочу Flutter client persists data on-device. It covers Drift as the local source of truth for offline-capable domains, secure storage for credentials, SharedPreferences for simple preferences, what data should be offline-capable, schema management, and the rules for generated code.

This implements AGENTS.md §8 (Drift for offline-capable local persistence; secure storage for credentials only) and the local-data rule (the UI observes local persisted state; the network synchronizes that state).

---

## 2. Storage Tiers

| Tier | Technology | Stores | Encrypted | Lifetime |
|------|-----------|--------|-----------|----------|
| Relational local DB | Drift (SQLite) | offline-capable domain entities, sync queue | no (app sandbox) | until logout / uninstall |
| Secure storage | flutter_secure_storage | auth tokens, refresh tokens | yes (Keystore/Keychain) | until logout / expiry |
| Simple preferences | SharedPreferences | flags, theme, last-used ids, UI prefs | no | until cleared |

### 2.1 What goes where

- **Drift**: entities the app must render while offline and reconcile with the server (wishlists, wishes, shopping lists, items, friendships, notifications list).
- **Secure storage**: credentials only — access token, refresh token. Never preferences, never entities, never logs.
- **SharedPreferences**: small scalar preferences — theme mode, locale, onboarding-complete flag, last-selected wishlist id, notification badge last-seen. Never credentials, never business state.

Credentials MUST NOT be stored in SharedPreferences, Drift, plain files, logs, or analytics (AGENTS.md §12).

---

## 3. Drift as Local Source of Truth

For offline-capable domains, Drift is the persisted local source of truth. The UI observes Drift; the network synchronizes Drift.

```text
UI
  ↓
Notifier
  ↓
Repository
  ↓
LocalDataSource (Drift DAO)
  ↓
AppDatabase (SQLite)
```

This prevents "online UI state" and "offline UI state" from becoming competing sources of truth. There is one source: Drift. The repository writes to Drift (local-first) and enqueues sync; the sync worker later pushes to the server; realtime events reconcile Drift.

### 3.1 What should be offline-capable

Initial offline-capable domains (AGENTS.md §24 / §8):

- wishlists;
- wishes;
- shared shopping lists;
- shopping list items;
- friends (where appropriate).

Not every endpoint needs offline support. Read-only, rarely-accessed, or large data (e.g. public discovery feeds) may be online-only — the repository fetches from the network and returns DTOs without persisting them. Reserve Drift for data the user expects to see while offline and that they can meaningfully mutate offline.

### 3.2 What should NOT be in Drift

- Credentials (use secure storage).
- Ephemeral UI state (use provider state / in-memory).
- Large blobs (images) — store file paths/URLs in Drift, cache files in the OS image cache.
- Server-derived transient data that has no offline value (e.g. presence lists).
- Analytics events (use an analytics sink, not the local DB).

### 3.3 Wish images

A wish has one **primary** image and N **additional** images (ADR-014, ADR-015):

- `wishes.image_url` — the primary reference: either a remote `http(s)` URL or a local file path (`Documents/media/wishes/`). Local paths are never sent to the API as `image_url`.
- `wish_images` — additional images only: `id`, `owner_id`, `wish_id`, `local_path`, `remote_url`, `sort_order`, `created_at`. Rows are created atomically with the wish inside the same transaction; `sort_order` starts at 1. No SQL-level FK — the cascade is enforced by the repository/sync engine so tombstoned wishes keep their images until the server DELETE is confirmed.
- Upload lifecycle (ADR-015): `wishes.image_upload_status`/`image_upload_id` and `wish_images.upload_status`/`upload_id` track `pending → uploading → uploaded | failed` per image. `client_id`/`upload_id` are stable per row — retries never create duplicate S3 objects.
- Photos are stored under `Documents/media/{wishes,avatars,shopping}/` after `MediaImageProcessor` (orientation, max 2048 px, JPEG q82 for photos). A one-time `MediaStorageMigration` moves legacy `Documents/wish_photos/` files and rewrites paths.
- Remote objects live in one shared physical S3 bucket under purpose root prefixes: `chtohochu-avatars/`, `chtohochu-wish-images/`, `chtohochu-shopping-images/` (ADR-015). Local `Documents/media/...` paths and remote keys are different layers — never mixed.
- Pull reconcile never erases local image references when the server returns `image_url: null`, and never touches `wish_images`.
- Deleting a wish cascades its `wish_images` rows and best-effort removes the local files; tombstoned wishes keep their images until the server DELETE is confirmed. Remote objects are removed asynchronously by the `DeleteMediaObjects` job — local delete never blocks on S3.

---

## 4. Drift Structure

```text
core/database/
├── tables/            # Drift table definitions
├── daos/              # Data Access Objects per feature scope
├── migrations/        # Migration strategy + schema versions
└── app_database.dart  # @DriftDatabase root
```

### 4.1 Tables

Tables are plain Drift table classes. They mirror the server entity shape enough to render the UI and to reconcile, but they are NOT required to be a 1:1 copy of the server schema. Local-only columns (e.g. `sync_status`, `pending_operation_id`, `local_dirty`) are allowed and expected.

```dart
@DataClassName('ShoppingListItemEntity')
class ShoppingListItems extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().customConstraint('REFERENCES shopping_lists(id) ON DELETE CASCADE')();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  TextColumn get checkedBy => text().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))(); // synced | pending | conflict
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 4.2 DAOs

Each feature scope gets a DAO. DAOs are the only objects that touch table classes directly. Local data sources wrap DAOs and return domain entities (mapped).

```dart
@DriftAccessor(tables: [ShoppingLists, ShoppingListItems])
class ShoppingListDao extends DatabaseAccessor<AppDatabase> with _$ShoppingListDaoMixin {
  ShoppingListDao(super.db);

  Stream<List<ShoppingListItemEntity>> watchItems(String listId) {
    return (select(items)..where((t) => t.listId.equals(listId))).watch();
  }

  Future<void> upsertItem(ShoppingListItemEntity entity) {
    return into(items).insertOnConflictUpdate(entity);
  }
}
```

### 4.3 Local data sources

Feature repositories depend on a `LocalDataSource` abstraction, not on `AppDatabase` or DAOs directly. This keeps repositories testable with an in-memory/fake local source and enforces the boundary (UI MUST NOT access `AppDatabase` directly — AGENTS.md §8).

```text
Repository  →  ShoppingListLocalDataSource  →  ShoppingListDao  →  AppDatabase
```

---

## 5. Schema Management

### 5.1 Migrations

Every schema change is a migration. Drift migrations are defined in `core/database/migrations/` and wired into the `AppDatabase` `schemaVersion` + `MigrationStrategy`.

```dart
@DriftDatabase(
  tables: [ShoppingLists, ShoppingListItems, Wishlists, Wishes, Friendships, Notifications, SyncOperations],
  daos: [ShoppingListDao, WishlistDao, ...],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(...);
      if (from < 3) await m.createTable(syncOperations);
      if (from < 4) await m.addColumn(items, items.checkedBy);
    },
  );
}
```

Rules:

- Never edit a shipped migration. Add a new step for the next version.
- `schemaVersion` increments by 1 per released schema change.
- Destructive migrations (column drops, type changes) require an ADR and a data-preservation plan. Prefer additive changes (add column, add table) where possible.
- Test migrations: `drift_dev` provides schema snapshot tests; verify upgrade paths from each supported prior version.

### 5.2 Schema integrity

- Use foreign keys with `ON DELETE CASCADE` where the child has no meaning without the parent (e.g. items when a list is deleted).
- Use unique constraints where the server enforces uniqueness (e.g. `(list_id, name)` if the server does).
- Index foreign-key columns and frequently-filtered columns (`list_id`, `wishlist_id`, `user_id`).
- Revisions are per-entity integers; the local DB stores the last-known server revision to support conflict detection (see `docs/30-client/offline-first.md`).

---

## 6. Generated Code Rules

Drift, Freezed, json_serializable, and Retrofit all generate code:

```text
*.g.dart          # Drift, json_serializable, Retrofit
*.freezed.dart    # Freezed
```

Rules (AGENTS.md §8, §15):

- Generated code MUST NOT be edited manually.
- Modify the source (table class, Freezed model, Retrofit interface) and regenerate.
- Generated files are committed to the repo (so CI and reviewers see the actual code), but never hand-edited.
- Regenerate after changing any annotated source:
  - `dart run build_runner build --delete-conflicting-outputs`
- `flutter analyze` must pass on generated + hand-written code together.

If generated code conflicts with a hand edit, the hand edit is wrong. Fix the source, regenerate.

---

## 7. Secure Storage

`flutter_secure_storage` stores credentials only.

```dart
class SecureStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  SecureStorage(this._storage);

  Future<void> writeTokens({required String access, required String refresh}) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
```

Rules:

- Store access + refresh tokens. On token refresh, overwrite both.
- On logout, call `clear()` and also clear session-scoped Drift tables (shopping lists, wishlists, etc.) — do not leave another user's data on the device.
- Configure platform options (iOS Keychain accessibility, Android EncryptedSharedPreferences) per platform; do not leave defaults that allow backup of secrets.
- Never log token values. Never put tokens in analytics.

---

## 8. SharedPreferences

`SharedPreferences` is for small scalar preferences only.

Typical keys:

- `theme_mode` (`light` / `dark` / `system`);
- `locale` (language tag);
- `onboarding_complete` (bool);
- `last_wishlist_id` (string);
- `notifications_badge_last_seen` (int).

Rules:

- No credentials.
- No business entities.
- No large values (SharedPreferences is loaded into memory; keep it small).
- Wrap in a typed `Preferences` service so callers do not use raw string keys scattered across the app.

```dart
class Preferences {
  final SharedPreferences _prefs;
  Preferences(this._prefs);

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == (_prefs.getString('theme_mode') ?? 'system'),
    orElse: () => ThemeMode.system,
  );
  Future<void> setThemeMode(ThemeMode mode) => _prefs.setString('theme_mode', mode.name);
}
```

---

## 9. Logout and Data Reset

On logout:

1. Stop the realtime client.
2. Stop/clear the sync queue of session-scoped operations.
3. Clear secure storage (tokens).
4. Clear session-scoped Drift tables (or delete the whole DB file for simplicity, then recreate empty).
5. Clear session-scoped SharedPreferences keys (keep device-level prefs like theme if desired — decide per key).
6. Reset providers / navigate to login.

This guarantees no user A data is visible to user B after a re-login on a shared device.

---

## 10. Testing

- DAO tests with an in-memory Drift database (`NativeDatabase.memory()`).
- Local data source tests with a fake DAO or in-memory DB.
- Repository tests with fake local + fake remote data sources.
- Migration tests: verify upgrade from each prior `schemaVersion` to current.
- Secure storage: test write/read/clear with a fake; never assert on real Keychain/Keystore in unit tests.
- Logout reset test: after logout, Drift session tables are empty and secure storage is cleared.

See `docs/10-development/testing.md`.
