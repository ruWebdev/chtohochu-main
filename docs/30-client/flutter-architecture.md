# Flutter Architecture

## 1. Purpose

This document defines the architecture of the ЧтоХочу Flutter client (`apps/client`). It covers the feature-first project structure, the three layers (presentation / domain / data), the state-management and dependency-injection approach, networking, navigation, local persistence, and the dependency direction between layers.

This is the authoritative Flutter architecture reference. It implements AGENTS.md §6 and §8.

---

## 2. Stack

| Concern | Technology |
|---------|-----------|
| State management | Riverpod (`flutter_riverpod` 3.0) |
| Dependency injection | Riverpod (providers are the composition root) |
| Generated providers | `riverpod_generator` + `@riverpod` annotation |
| Provider linting | `riverpod_lint` |
| Navigation | GoRouter |
| Networking | Dio + Retrofit |
| Models & state types | Freezed + `json_serializable` |
| Local DB | Drift |
| Secure storage | `flutter_secure_storage` |
| Design system | Material 3 (`app/theme/`) |
| Localization | Flutter localizations (ARB) |
| Code generation | `build_runner` |

Riverpod is the **single** state-management and dependency-injection system. There is no separate service locator. Providers wire implementations to abstractions; widgets and notifiers consume them.

---

## 3. Project Structure

Flutter uses **feature-first** architecture. Each feature owns its full vertical slice. Cross-feature infrastructure lives in `core/` and `shared/`.

```text
apps/client/lib/

├── app/
│   ├── router/            # GoRouter configuration, route guards
│   ├── theme/             # Design system: colors, typography, spacing
│   └── app.dart           # MaterialApp.router root with ProviderScope
│
├── core/
│   ├── config/            # environment, flavors, app config
│   ├── constants/
│   ├── database/          # Drift AppDatabase, tables, DAOs, migrations
│   ├── network/           # Dio instance, interceptors, Retrofit api clients base
│   ├── realtime/          # WebSocket client, event routing
│   ├── sync/              # sync queue, sync worker, operation_id management
│   ├── notifications/     # FCM registration, local notification handling
│   ├── storage/           # secure storage wrapper
│   ├── errors/            # Failure types, error mapping
│   └── logging/
│
├── shared/
│   └── ui/                # reusable widgets, component primitives
│
├── features/
│   └── <feature>/
│       ├── data/
│       │   ├── datasources/   # remote + local data sources
│       │   ├── dtos/          # Freezed API models
│       │   ├── mappers/       # DTO ↔ domain / DTO ↔ Drift entity
│       │   ├── repositories/  # Repository implementations
│       │   └── api/           # Retrofit interfaces for this feature
│       ├── domain/
│       │   ├── entities/      # domain models (Freezed, no Flutter/Dio/Drift)
│       │   ├── repositories/  # abstract repository contracts
│       │   └── usecases/      # orchestration (only when non-trivial)
│       └── presentation/
│           ├── providers/     # Riverpod Notifier / AsyncNotifier / StreamNotifier
│           ├── states/        # Freezed state types
│           ├── pages/         # full screens
│           ├── widgets/       # feature-specific widgets
│           └── extensions/    # presentation-only helpers
│
└── main.dart              # entrypoint, runApp with ProviderScope
```

### 3.1 What a feature owns

A feature owns its:

- API DTOs and Retrofit interface;
- remote and local data sources;
- repository interface (in `domain/`) and implementation (in `data/`);
- domain entities;
- use cases (when justified);
- Riverpod providers (state notifiers) and Freezed state types;
- pages and feature-specific widgets.

### 3.2 What does NOT go in a feature

- Cross-feature infrastructure → `core/`.
- Reusable UI primitives → `shared/ui/`.
- Design tokens → `app/theme/`.
- Feature-specific code MUST NOT be moved into `core/` or `shared/` to "share" it. If two features need the same logic, put a contract in `core/` or a shared package and let each feature use it without duplicating domain concepts.

---

## 4. Layers

### 4.1 Presentation

Contains:

- Pages (full screens);
- widgets (feature-specific);
- Riverpod providers (`Notifier` / `AsyncNotifier` / `StreamNotifier`);
- Freezed state types;
- presentation-only models/extensions.

Presentation MUST NOT directly access:

- Dio / Retrofit;
- Drift (`AppDatabase`);
- secure storage;
- Firebase / platform APIs.

Presentation talks to providers. Providers talk to repositories (or use cases). That is the only allowed direction. Widgets read provider state with `ref.watch` and trigger actions with `ref.read`.

### 4.2 Domain

The domain layer holds pure business models and repository contracts. It is **optional but recommended** for non-trivial features (AGENTS.md §8: use cases are required for meaningful orchestration, not for trivial CRUD).

Domain contains:

- entities (Freezed immutable models);
- repository abstractions (abstract classes);
- use cases (when orchestration is non-trivial).

Domain MUST NOT depend on:

- Flutter (no `package:flutter`);
- Riverpod (`flutter_riverpod`, `riverpod_annotation`);
- Dio / Retrofit;
- Drift;
- Firebase;
- platform APIs.

This keeps domain testable in pure Dart and reusable. Domain logic is resolved by providers, never resolving its own dependencies.

### 4.3 Data

Contains:

- repository implementations;
- remote data sources (Retrofit API clients);
- local data sources (Drift DAOs);
- DTOs (Freezed API models);
- mappers (DTO ↔ domain, DTO ↔ Drift entity);
- sync adapters (where the feature participates in offline sync).

Data implements the domain's repository contracts. Data depends on domain; domain does not depend on data.

---

## 5. Dependency Direction

```text
presentation → domain
data → domain
domain → (nothing framework-specific)
```

Concretely:

```text
Widget
  ↓ (ref.watch / ref.read)
Notifier / AsyncNotifier / StreamNotifier
  ↓ (calls)
UseCase (when present)  OR  Repository (directly)
  ↓
Repository (abstract, in domain)
  ↑ (implemented by)
RepositoryImpl (in data)
  ↓
RemoteDataSource (Retrofit)   LocalDataSource (Drift DAO)
  ↓                              ↓
Dio                            AppDatabase
```

Key rules:

- Presentation depends on domain abstractions (repository contracts, use cases, entities), never on data implementations.
- Data depends on domain (implements contracts, returns domain entities).
- Domain depends on nothing framework-specific.
- Riverpod wires implementations to abstractions via providers. Presentation and domain never reach outside the composition root to resolve dependencies inside business logic; they receive dependencies via constructor injection from providers. Only providers (the composition root) construct repositories and data sources.

---

## 6. Dependency Injection (Riverpod)

Riverpod is the dependency-injection system. There is no separate service locator. Providers are the composition root: they construct Dio, `AppDatabase`, secure storage, repositories, data sources, and notifiers, and they inject dependencies into each other.

### 6.1 Provider-based wiring

```dart
// core/network/dio_provider.dart
@riverpod
Dio dio(DioRef ref) {
  final env = ref.watch(envProvider);
  return buildDio(env); // base URL, interceptors, timeouts
}

// core/database/app_database_provider.dart
@riverpod
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

// features/shopping_list/data/shopping_list_repository_provider.dart
@riverpod
ShoppingListRepository shoppingListRepository(ShoppingListRepositoryRef ref) {
  return ShoppingListRepositoryImpl(
    remote: ShoppingListApi(ref.watch(dioProvider)),
    local: ShoppingListLocalDataSource(ref.watch(appDatabaseProvider)),
    syncQueue: ref.watch(syncQueueProvider),
  );
}
```

`ShoppingListApi` is a Retrofit interface; `ShoppingListRepositoryImpl` implements the domain abstract class `ShoppingListRepository`. The provider returns the abstract type, so consumers depend on the contract, not the implementation.

### 6.2 Rules

- Expose abstract types from providers when the consumer should not know the implementation (`ShoppingListRepository`, not `ShoppingListRepositoryImpl`).
- Use `Provider` for stateless services (Dio, `AppDatabase`, repositories, APIs).
- Use `NotifierProvider` / `AsyncNotifierProvider` / `StreamNotifierProvider` for stateful components (see `docs/07-flutter/state-management.md`).
- Do not store business state in a `Provider`. Business state lives in notifiers and Drift, not in a plain provider.
- Do not scatter provider lookups inside domain logic. Domain classes receive dependencies via constructors; providers construct them.

---

## 7. Networking (Dio + Retrofit)

HTTP access is centralized. Feature code MUST NOT instantiate Dio (AGENTS.md §8).

```text
Notifier
  ↓
Repository
  ↓
RemoteDataSource (Retrofit interface)
  ↓
Dio (single configured instance from a provider)
```

- One `Dio` instance is configured in `core/network/` with base URL, interceptors (auth token, logging, error mapping, idempotency key), and timeouts. It is exposed via a Riverpod provider.
- Each feature defines a Retrofit interface (`abstract class` with `@GET`/`@POST`/etc.) in `features/<feature>/data/api/`.
- Retrofit generates the implementation (`*.g.dart`). Generated code is not edited.
- Raw Dio/Retrofit exceptions MUST NOT reach presentation. Repositories translate them into domain `Failure` types (see `core/errors/`).

See `docs/03-api/` for the REST contract and `docs/07-flutter/offline-first.md` for idempotency keys.

---

## 8. Navigation (GoRouter)

GoRouter is the single navigator. Routes are declared in `app/router/`.

- Route guards handle auth state (redirect to login when unauthenticated) by watching an auth provider.
- Deep links (from FCM push, web links) map to routes by entity type/id.
- Feature routes are grouped but registered in the single `GoRouter` config; features do not own their own `Navigator` unless a nested navigator is explicitly justified.
- Provider scoping follows route boundaries: a provider needed for a screen is scoped to that screen's subtree via `ProviderScope` overrides or autoDispose, and disposed when the route is popped.

```dart
GoRoute(
  path: '/shopping-lists/:id',
  builder: (context, state) {
    final listId = state.pathParameters['id']!;
    return ShoppingListPage(listId: listId);
  },
),
```

The page reads its providers via `ref.watch`; providers are autoDisposed when the subtree is removed.

---

## 9. Local Persistence (Drift)

Drift is the relational local persistence layer for offline-capable domains. See `docs/07-flutter/local-data.md` for the full treatment.

```text
core/database/
├── tables/
├── daos/
├── migrations/
└── app_database.dart
```

- Feature code accesses Drift through local data sources, never `AppDatabase` directly.
- Generated Drift code MUST NOT be edited manually.
- Drift is the persisted local source of truth for offline-capable mobile data; the network synchronizes that state.

---

## 10. Realtime

The realtime client lives in `core/realtime/`. It manages the WebSocket connection, subscriptions, dedup, and routing of events to repositories. See `docs/05-realtime/architecture.md`.

- Notifiers do not subscribe to WebSocket channels directly.
- Repositories expose `applyRealtimeEvent(event)`; the realtime client routes by `entity_type` to the right repository.
- Connection status is surfaced to the UI via a dedicated connection provider (`StreamNotifier`).

---

## 11. Sync

The sync queue and worker live in `core/sync/`. They handle pending mutations, retries, and conflict reconciliation. See `docs/07-flutter/offline-first.md`.

- Notifiers enqueue mutations via repositories; repositories write to Drift + sync queue in a single local transaction.
- The sync worker drains the queue against the REST API with idempotency keys.
- Conflicts are resolved by revision-based detection per entity.

---

## 12. Generated Code

Code generation is used for Riverpod providers, Freezed models, Retrofit clients, and Drift queries. Rules (AGENTS.md §8):

- Generated files (`*.g.dart`, `*.freezed.dart`) MUST NOT be edited manually.
- Run `dart run build_runner build --delete-conflicting-outputs` to regenerate.
- Generated files are committed so CI does not require generation for analysis.
- Never suppress `riverpod_lint` warnings without justification; fix the provider definition.

### 12.1 Riverpod code generation

Prefer generated providers via `riverpod_generator`. The `@riverpod` annotation generates the provider and its ref type, and `riverpod_lint` enforces correct usage.

```dart
@riverpod
class ShoppingListNotifier extends _$ShoppingListNotifier {
  @override
  ShoppingListState build(String listId) {
    _load();
    return const ShoppingListState.loading();
  }

  Future<void> _load() async {
    final repo = ref.watch(shoppingListRepositoryProvider);
    // ...
  }
}
```

This generates `shoppingListNotifierProvider` and the `ShoppingListNotifierRef` type. Always use the generated names; do not declare providers manually unless code generation is impossible.

---

## 13. Bootstrap

```text
main()
  ↓
load env / flavor
  ↓
runApp(ProviderScope(child: AppWidget))
  ↓
providers lazily construct Dio, AppDatabase, secure storage, repositories
  ↓
auth provider drives initial route + realtime/sync lifecycle
  ↓
run migrations (via AppDatabase provider)
  ↓
register FCM token
  ↓
start realtime client (after auth)
  ↓
start sync worker
```

`ProviderScope` is placed at the app root in `main.dart`. Providers are lazily constructed on first read. Auth state drives the initial route and the realtime/sync lifecycle. On logout: stop realtime, clear sync queue of session-scoped ops, clear secure storage, reset Drift session-scoped tables, navigate to login.

```dart
void main() {
  runApp(
    ProviderScope(
      child: const AppWidget(),
    ),
  );
}
```

---

## 14. Error Handling

- Infrastructure errors (Dio, Drift, secure storage) are caught in data sources / repositories and mapped to domain `Failure` subtypes (`NetworkFailure`, `NotFoundFailure`, `ConflictFailure`, `UnauthorizedFailure`, `CacheFailure`, ...).
- Notifiers translate `Failure` into meaningful state (`ErrorState`, `OfflineState`, `ConflictState`) rather than exposing exception types to widgets.
- Widgets render error states from the provider state; they do not catch exceptions.
- Unexpected errors are logged (never swallowed silently) and surfaced as a generic error state.

---

## 15. File Size and Cohesion

- Prefer methods < 40 lines, files < 300 lines (AGENTS.md review signals, not absolute laws).
- Do not split cohesive code artificially. A notifier with its state in one file is fine if the file stays readable.
- Do not create classes merely to satisfy a diagram (e.g. a `UseCase` that just delegates to a repository is noise — call the repository directly).

---

## 16. Testing

- Unit tests for Riverpod providers/notifiers (actions → expected state) using `ProviderContainer` with overrides.
- Repository tests with mock data sources (fake remote, in-memory local).
- Widget tests for key screens with provider overrides.
- Integration tests for critical flows: auth, wishlist CRUD, shopping list collaboration, offline mutation + sync.

See `docs/10-development/testing.md`.

---

## 17. Related Documents

- `docs/07-flutter/state-management.md` — Riverpod provider design, state types, testing.
- `docs/07-flutter/local-data.md` — Drift, secure storage.
- `docs/07-flutter/offline-first.md` — sync queue, operation_id, conflict resolution.
- `docs/07-flutter/ui.md` — Material 3, design system, localization.
- `docs/05-realtime/` — realtime transport and event contract.
- `docs/03-api/` — REST contract consumed by Retrofit.
