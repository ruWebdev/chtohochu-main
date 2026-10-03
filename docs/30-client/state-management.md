# Flutter State Management

## 1. Purpose

This document defines how state is managed in the ЧтоХочу Flutter client. It covers Riverpod as the single state-management and dependency-injection system, provider types, generated providers, state design with Freezed, `AsyncValue`, provider composition, scoping, lifecycle, error handling, and testing.

This is the authoritative state-management reference. It implements AGENTS.md §8 (Riverpod for state management and dependency injection).

## 2. Riverpod as the Single System

Riverpod is the **only** state-management and dependency-injection mechanism in the Flutter client. There is no separate DI container and no separate state-management library.

- **State management** — providers hold state, expose it to widgets, and rebuild widgets when state changes.
- **Dependency injection** — providers construct and supply repositories, data sources, and use cases. Feature code resolves dependencies by watching providers, never by calling a global service locator.

```text
Widget  →  Notifier method (intent)  →  Repository / Use case  →  new State
                                                                ↓
Widget (Consumer)  ←  Provider  ←  State
```

Widgets observe providers via `ConsumerWidget` / `ConsumerStatefulWidget`, using `ref.watch` (rebuild on change) and `ref.listen` (side effects on change: navigation, snackbars).

## 3. Provider Types and When to Use Each

| Type | Value | Use case |
|------|-------|----------|
| `Provider` | sync computed value | Dependencies, derived values, repositories, configured Dio |
| `FutureProvider` | `Future<T>` | One-shot async read (fetch and display, no mutations) |
| `StreamProvider` | `Stream<T>` | Expose a stream (Drift watch, realtime, read-only) |
| `NotifierProvider` | mutable sync state | Interactive sync state with methods (toggle, counter) |
| `AsyncNotifierProvider` | mutable async state | Interactive async state with methods (load + mutate) |
| `StreamNotifierProvider` | mutable stream state | Interactive stream state with methods (subscribe + mutate) |

Prefer `Notifier`, `AsyncNotifier`, and `StreamNotifier` for stateful features (AGENTS.md §8). Use `Provider` / `FutureProvider` / `StreamProvider` for read-only dependencies and derived values. Rule of thumb: start with `FutureProvider` for read-only async data; promote to `AsyncNotifierProvider` when the UI triggers mutations that update the same state.

## 4. Generated Providers

All providers are generated with the `@riverpod` annotation from `riverpod_generator`. `riverpod_lint` enforces correct provider usage at analysis time. Do not hand-type `Provider` definitions unless the generator cannot express the case (rare). Run `dart run build_runner build` to generate `.g.dart` files. Generated code MUST NOT be edited manually (AGENTS.md §8, §16).

### 4.1 Notifiers (sync and async)

```dart
@riverpod
class ThemeController extends _$ThemeController {
  @override
  ThemeMode build() => ThemeMode.system;
  void toggle() => state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

@riverpod
class ShoppingListController extends _$ShoppingListController {
  @override
  Future<ShoppingListView> build(String listId) async =>
      ref.watch(shoppingListRepositoryProvider).fetch(listId);
  Future<void> checkItem(String itemId, bool checked) async {
    final repo = ref.read(shoppingListRepositoryProvider);
    await repo.setChecked(itemId, checked);
    state = AsyncData(await repo.fetch(state.value!.list.id));
  }
}
```

### 4.2 Provider, FutureProvider, StreamProvider

```dart
@riverpod
ShoppingListRepository shoppingListRepository(Ref ref) =>
    ShoppingListRepositoryImpl(dio: ref.watch(dioProvider), db: ref.watch(localDatabaseProvider));

@riverpod
Future<Wishlist> wishlistPreview(Ref ref, String id) =>
    ref.watch(wishlistRepositoryProvider).fetch(id);

@riverpod
Stream<List<ShoppingListItem>> shoppingListItemsStream(Ref ref, String listId) =>
    ref.watch(shoppingListRepositoryProvider).watchItems(listId);
```

## 5. State Design with Freezed

State types are immutable and built with Freezed 3.0 (AGENTS.md §8). Freezed generates `==` / `hashCode` / `copyWith`, which Riverpod uses to skip identical rebuilds.

### 5.1 Sealed state classes

Model multi-state UIs as sealed unions. Each variant is a complete snapshot of what the UI should render.

```dart
@freezed
class ShoppingListState with _$ShoppingListState {
  const factory ShoppingListState.initial() = _Initial;
  const factory ShoppingListState.loading() = _Loading;
  const factory ShoppingListState.loaded({
    required ShoppingList list,
    required List<ShoppingListItem> items,
    @Default(false) bool isOffline,
  }) = _Loaded;
  const factory ShoppingListState.error(Failure failure) = _Error;
  const factory ShoppingListState.conflict(ConflictInfo info) = _Conflict;
}
```

Why sealed: `loaded(isOffline: true)` is clearer than `loaded` plus a separate connection state the widget cross-references. But do not model every transient as its own variant — group related flags inside a variant when they vary together.

### 5.2 Immutable state objects with copyWith

For notifiers that hold a single mutable state object, define one Freezed class and update via `copyWith`.

```dart
@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(AuthStatus.unknown) AuthStatus status,
    User? user,
    String? errorMessage,
  }) = _AuthState;
}

@riverpod
class AuthController extends _$AuthController {
  @override
  AuthState build() => const AuthState();
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await ref.read(authRepositoryProvider).login(email, password);
    result.fold(
      (f) => state = state.copyWith(status: AuthStatus.error, errorMessage: f.message),
      (u) => state = state.copyWith(status: AuthStatus.authenticated, user: u),
    );
  }
}
```

A state without correct `==`/`hashCode` causes silent extra rebuilds. Never ship a provider state that is not a Freezed class (or a primitive with value equality).

## 6. AsyncValue for Async State

`AsyncValue<T>` represents the loading/data/error lifecycle in a single type. `AsyncNotifierProvider` and `FutureProvider` expose `AsyncValue<T>` to widgets.

```dart
@riverpod
class WishlistController extends _$WishlistController {
  @override
  Future<Wishlist> build(String id) async =>
      ref.watch(wishlistRepositoryProvider).fetch(id);
  Future<void> addWish(Wish wish) async {
    state = const AsyncLoading<Wishlist>().copyWithPrevious(state);
    try {
      state = AsyncData(await ref.read(wishlistRepositoryProvider).addWish(id, wish));
    } on Failure catch (f) {
      state = AsyncError(f, StackTrace.current);
    }
  }
}
```

In widgets, use `.when` for full pattern matching — `data: (w) => ...`, `loading: () => ...`, `error: (e, _) => ...` callbacks cover every state. Use `.whenData` / `.valueOrNull` / `.hasError` for partial handling when you want to keep previous data visible during a refresh.

## 7. Provider Composition and Dependencies

Providers watch other providers via `ref.watch` (rebuild when dependency changes) or `ref.read` (one-time lookup, usually inside methods).

```dart
@riverpod
ShoppingListView shoppingListView(Ref ref, String listId) {
  final list = ref.watch(shoppingListControllerProvider(listId));
  final items = ref.watch(shoppingListItemsStreamProvider(listId));
  return ShoppingListView(list: list.valueOrNull, items: items.valueOrNull ?? const []);
}
```

- Use `ref.watch` in `build()` and in `Provider`/`FutureProvider`/`StreamProvider` bodies so the provider rebuilds when dependencies change.
- Use `ref.read` inside notifier methods to fetch a dependency at call time without subscribing.
- Never call `ref.read` inside `build()` to avoid rebuilds — that hides the dependency and breaks reactivity.
- Providers must not create circular dependencies.

## 8. Provider Scoping, Overrides, and AutoDispose

### 8.1 ProviderScope at app root

A single `ProviderScope` wraps the app. It is the root of the DI graph.

```dart
void main() => runApp(const ProviderScope(child: ChtoHochuApp()));
```

### 8.2 Overrides for tests and flavors

`ProviderScope(overrides: ...)` replaces a provider's implementation for a subtree. Use this for tests, feature flags, and environment flavors. Nested `ProviderScope`s can override providers for a subtree (e.g. a screen-scoped override). Do not nest `ProviderScope`s for normal app structure — use provider dependencies instead.

```dart
ProviderScope(
  overrides: [
    shoppingListRepositoryProvider.overrideWithValue(FakeShoppingListRepo()),
    dioProvider.overrideWithValue(testDio),
  ],
  child: const ShoppingListPage(),
)
```

### 8.3 AutoDispose vs keepAlive

By default, generated `@riverpod` providers are **autoDispose**: when no widget watches them, they are destroyed and their state is released. This prevents memory leaks for screen-scoped providers.

Use **autoDispose** (default) for: screen-scoped state, parameterized providers created per navigation, and any state that should not outlive the screen that uses it.

Use **keepAlive** for: app-wide singletons (configured Dio, Drift database, auth session) and state that must survive screen transitions (notification badge count, connection state).

```dart
@Riverpod(keepAlive: true)
Dio dio(Ref ref) => buildConfiguredDio();
```

Inside an autoDispose notifier, call `ref.keepAlive()` to retain state past the last listener (e.g. keep a form draft while the user navigates away briefly).

## 9. Family Providers

Family providers accept a parameter and create one instance per argument value. Use them for per-entity state (a wishlist by id, a shopping list by id). The `ShoppingListController` in §4.1 is a family — `ref.watch(shoppingListControllerProvider('list-1'))` gives each distinct `listId` its own independent state.

- The family argument must have value equality (primitives, Freezed classes, or records).
- Do not use a family argument as a substitute for state. If the argument changes during the screen's life, prefer a method on a single notifier.
- AutoDispose families release state for a specific argument when it has no listeners.

## 10. Providers and Repositories

Providers orchestrate; repositories are the data boundary (AGENTS.md §5). Repositories are injected into providers via Riverpod, never via a service locator.

```text
Widget calls notifier method → Notifier calls repository → Repository reads/writes
        → returns domain entity or Failure → Notifier sets new state
```

- Notifiers call repository methods. They do NOT call Dio, Retrofit, Drift DAOs, or secure storage directly.
- Notifiers do NOT hold business state in fields; state lives in `state`. Mutable notifier fields that mirror state are a smell.
- Notifiers may watch repository streams (e.g. a Drift watch) and update state as the stream emits.
- For offline-capable domains, the repository writes locally first (Drift + sync queue) and returns immediately; the notifier sets the optimistic state. The sync worker and realtime events drive later updates.

A stream notifier can watch a repository stream in `build()` and mutate via methods — the `ShoppingListController` in §4.1 shows this pattern with `Future`; for streams, return `repo.watch(listId)` from `build()` and call `repo.setChecked(...)` in methods. State updates come from the repository stream, not from manual state sets.

The notifier does not know whether an update came from the user, a sync ACK, or a realtime event — the repository stream unifies them. This is the local-data rule (AGENTS.md §26): the UI observes local persisted state.

## 11. Error Handling in Providers

### 11.1 Translate failures, do not throw raw

Repository methods return `Result<T>` or throw translated `Failure` exceptions. Notifiers catch and produce error states. Raw Dio/Drift exceptions MUST NOT reach the notifier (repositories map them, per `docs/30-client/flutter-architecture.md` §13).

```dart
try {
  state = AsyncData(await repo.fetch(listId));
} on Failure catch (f) {
  state = AsyncError(f, StackTrace.current);
} catch (e, st) {
  log.error('Unexpected', e, st);
  state = AsyncError(UnknownFailure(), st);
}
```

### 11.2 Error state semantics

- `NetworkFailure` → UI shows "offline / retry" but keeps last cached state where possible (do not blank the screen).
- `ConflictFailure` → UI shows a conflict resolution prompt; the notifier sets `ConflictState` with enough info to resolve.
- `UnauthorizedFailure` → trigger session-expired flow (delegate to `AuthController` / router redirect), do not show a generic error.
- `NotFoundFailure` → UI shows empty/404 state.

### 11.3 Never swallow; side effects belong in widgets

Do not catch an error and set nothing. Always set a state (error or restored previous state). Unexpected errors are logged at error level, then mapped to a generic `UnknownFailure` and an error state. Silent catches hide bugs.

Side effects (navigation, snackbars, dialogs) belong in `ref.listen` callbacks in the widget, not in the notifier. The notifier sets state; the widget reacts. The notifier MUST NOT call `context.go` or show dialogs directly.

```dart
ref.listen<ShoppingListState>(shoppingListControllerProvider(id).notifier, (_, next) {
  if (next is _Conflict) showConflictDialog(context, next.info);
});
```

## 12. Testing Providers

Providers are testable in pure Dart with `ProviderContainer`, no widget tree required.

```dart
test('ShoppingListController emits loaded on fetch', () async {
  final container = ProviderContainer(
    overrides: [shoppingListRepositoryProvider.overrideWithValue(FakeShoppingListRepo())],
  );
  addTearDown(container.dispose);
  await container.read(shoppingListControllerProvider('list-1').notifier).build('list-1');
  expect(container.read(shoppingListControllerProvider('list-1')), isA<AsyncData<ShoppingListView>>());
});
```

- Test notifier method → state transitions, not widget output.
- Override repository providers with fakes/mocks (no real Dio, no real Drift) for unit tests.
- Test error paths: repository returns `Failure` → notifier sets error state.
- Test realtime path: repository stream emits → state reflects reconciled data.
- Test duplicate calls: calling the same method twice does not produce duplicate side effects.
- Always dispose the `ProviderContainer` to release resources.

See `docs/10-development/testing.md`.

## 13. Provider Lifecycle

Riverpod 3 notifiers expose a `build()` method that constructs the initial state and sets up dependencies. Lifecycle hooks:

| Hook | Purpose |
|------|---------|
| `build()` | Construct initial state, `ref.watch` dependencies. Called on creation and on dependency change. |
| `ref.onDispose()` | Register cleanup when the provider is destroyed (cancel subscriptions, close controllers). |
| `ref.keepAlive()` | Prevent autoDispose from destroying the provider after the last listener. |
| `ref.onResume()` / `ref.onCancel()` | React to listener count transitions (optional, advanced). |

Example: in `build()`, subscribe to a repository stream and register `ref.onDispose()` to cancel it when the provider is destroyed or rebuilt.

- Set up subscriptions in `build()` and cancel them in `ref.onDispose()`.
- Do not perform heavy work in constructors; `build()` is the initialization point.
- When a watched dependency changes, `build()` runs again and the previous state is disposed via `ref.onDispose`.

## 14. Domain Layer Independence

Domain logic — entities, value objects, use cases, and repository interfaces — MUST NOT import Riverpod or Flutter (AGENTS.md §6).

```text
presentation (providers, widgets) → domain
data (repositories impl, Drift, Dio) → domain
domain → (nothing framework-specific)
```

- Domain classes are plain Dart. They do not reference `Ref`, `Provider`, `AsyncValue`, or any Flutter widget.
- Providers live in the presentation layer and call domain use cases / repository interfaces.
- Repository implementations live in the data layer and are injected into providers via `Provider`.
- Use cases orchestrate domain logic and are exposed as `Provider`s when they carry dependencies; trivial pass-through calls go directly through the repository provider.

## 15. Anti-Patterns

- Notifier calling Dio / Retrofit / Drift DAOs directly instead of a repository.
- Notifier storing mutable fields that mirror `state`.
- State that is not a Freezed class (or value-equal primitive) — causes silent extra rebuilds.
- One giant state class with booleans instead of sealed variants.
- Side effects (navigation, dialogs) inside a notifier instead of `ref.listen` in the widget.
- Using `ref.read` inside `build()` to avoid rebuilds — hides dependencies and breaks reactivity.
- Circular provider dependencies.
- Swallowing errors with an empty catch.
- Manually editing generated `.g.dart` files.
- Importing Riverpod or Flutter from domain-layer code.
