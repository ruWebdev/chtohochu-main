# Testing Strategy

> **Status:** Authoritative testing strategy document.
> Conflicts with `AGENTS.md` must be resolved via an ADR in `docs/adr/`.

## 1. Principles

1. **Critical behavior MUST be tested.** Not every line — every critical path.
2. **Tests verify behavior, not implementation.** Test what the system does, not how it does it.
3. **Tests are fast.** Unit tests run in seconds; the full suite runs in minutes.
4. **Tests are deterministic.** No flaky tests; no reliance on external services in unit tests.
5. **Tests are maintainable.** Clear names, minimal setup, readable assertions.
6. **Tests run in CI on every PR.** No merge without green tests.

## 2. Test Pyramid

```text
        ┌───────────┐
        │   E2E     │  Few, slow, high-confidence
        ├───────────┤
        │ Integration│  Moderate, real components
        ├───────────┤
        │   Unit     │  Many, fast, isolated
        └───────────┘
```

| Layer | Count | Speed | Confidence |
|-------|-------|-------|------------|
| Unit | Many (thousands) | Fast (<1s each) | Low (isolated) |
| Integration / Feature | Moderate (hundreds) | Medium | Medium |
| E2E | Few (tens) | Slow | High (full stack) |

## 3. Backend Tests (Laravel / PHP)

### 3.1 Test types

| Type | Framework | Purpose |
|------|-----------|---------|
| Unit | PHPUnit (`tests/Unit/`) | Pure PHP logic: domain services, value objects, mappers |
| Feature | PHPUnit (`tests/Feature/`) | HTTP-level API tests with database, middleware, auth |
| Integration | PHPUnit (`tests/Feature/`) | Multi-component: jobs, events, broadcasts, transactions |
| Authorization | PHPUnit (`tests/Feature/Authorization/`) | Verify access control for every protected endpoint |
| Business rules | PHPUnit (`tests/Unit/` or `tests/Feature/`) | Domain invariants, conflict resolution, sync logic |

### 3.2 Unit tests

Test pure logic in isolation — no database, no HTTP, no filesystem.

```php
// tests/Unit/Domain/WishlistVisibilityTest.php
class WishlistVisibilityTest extends TestCase
{
    public function test_personal_wishlist_is_not_visible_to_other_users(): void
    {
        $owner = User::factory()->make(['id' => 1]);
        $other = User::factory()->make(['id' => 2]);
        $wishlist = Wishlist::factory()->make([
            'user_id' => $owner->id,
            'visibility' => 'personal',
        ]);

        $this->assertFalse($wishlist->isVisibleTo($other));
    }

    public function test_public_wishlist_is_visible_to_anyone(): void
    {
        $owner = User::factory()->make(['id' => 1]);
        $guest = User::factory()->make(['id' => 2]);
        $wishlist = Wishlist::factory()->make([
            'user_id' => $owner->id,
            'visibility' => 'public',
        ]);

        $this->assertTrue($wishlist->isVisibleTo($guest));
    }
}
```

### 3.3 Feature / API tests

Test the full HTTP request → response cycle, including middleware, validation, authorization, database, and serialization.

```php
// tests/Feature/Api/WishlistControllerTest.php
class WishlistControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_create_wishlist(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test', ['user:write'])->plainTextToken;

        $response = $this->withToken($token)
            ->postJson('/api/v1/wishlists', [
                'title' => 'My Birthday',
                'visibility' => 'personal',
            ]);

        $response->assertCreated()
            ->assertJsonPath('data.title', 'My Birthday')
            ->assertJsonPath('data.visibility', 'personal');

        $this->assertDatabaseHas('wishlists', [
            'user_id' => $user->id,
            'title' => 'My Birthday',
        ]);
    }

    public function test_unauthenticated_request_is_rejected(): void
    {
        $this->postJson('/api/v1/wishlists', [
            'title' => 'Test',
        ])->assertUnauthorized();
    }

    public function test_validation_rejects_missing_title(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withToken($token)
            ->postJson('/api/v1/wishlists', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);
    }
}
```

### 3.4 Authorization tests

Every protected endpoint MUST have authorization tests covering:

| Scenario | Expected |
|----------|----------|
| Unauthenticated request | 401 |
| Authenticated, no ownership/membership | 403 |
| Authenticated, owns resource | 200 |
| Authenticated, member with read permission | 200 |
| Authenticated, member without write permission (for mutations) | 403 |
| Token with wrong ability | 403 |

```php
// tests/Feature/Authorization/WishlistAuthorizationTest.php
class WishlistAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_cannot_view_other_users_personal_wishlist(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $wishlist = Wishlist::factory()->create([
            'user_id' => $owner->id,
            'visibility' => 'personal',
        ]);

        $this->actingAs($other)
            ->getJson("/api/v1/wishlists/{$wishlist->id}")
            ->assertForbidden();
    }

    public function test_member_can_view_shared_wishlist(): void
    {
        $owner = User::factory()->create();
        $member = User::factory()->create();
        $wishlist = Wishlist::factory()->create([
            'user_id' => $owner->id,
            'visibility' => 'link',
        ]);
        $wishlist->members()->attach($member, ['role' => 'member']);

        $this->actingAs($member)
            ->getJson("/api/v1/wishlists/{$wishlist->id}")
            ->assertOk();
    }
}
```

### 3.5 Business rules / domain tests

Test complex domain logic: conflict resolution, sync idempotency, collaborative editing rules.

```php
// tests/Feature/Sync/IdempotencyTest.php
class IdempotencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_duplicate_operation_id_does_not_create_duplicate_wish(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test', ['user:write'])->plainTextToken;
        $operationId = Str::uuid()->toString();

        $first = $this->withToken($token)
            ->withHeader('X-Operation-Id', $operationId)
            ->postJson('/api/v1/wishlists/1/wishes', [
                'title' => 'New Phone',
            ]);

        $second = $this->withToken($token)
            ->withHeader('X-Operation-Id', $operationId)
            ->postJson('/api/v1/wishlists/1/wishes', [
                'title' => 'New Phone',
            ]);

        $first->assertCreated();
        $second->assertCreated(); // returns original result, not 409

        $this->assertDatabaseCount('wishes', 1);
    }
}
```

### 3.6 Transaction tests

```php
public function test_create_shared_list_is_atomic(): void
{
    // Simulate failure during membership creation
    // Verify no partial state (list without membership) exists
}
```

### 3.7 Concurrency / conflict tests

```php
public function test_concurrent_edits_detect_conflict(): void
{
    // Two users edit the same shopping list item simultaneously
    // Verify revision-based conflict detection works
}
```

### 3.8 Backend test commands

```bash
php artisan test                          # all tests
php artisan test --filter=Wishlist        # filter by name
php artisan test --parallel               # parallel execution
php artisan test tests/Feature/Authorization  # specific directory
php artisan test --coverage               # with coverage report
```

## 4. Flutter Tests

### 4.1 Test types

| Type | Framework | Location | Purpose |
|------|-----------|----------|---------|
| Unit | `flutter test` | `test/` | Pure Dart logic: mappers, validators, domain services |
| Notifier | `flutter test` | `test/features/` | Riverpod Notifier state transitions |
| Repository | `flutter test` | `test/features/` | Repository logic with mocked data sources |
| Widget | `flutter test` | `test/features/` | Single widget rendering and interaction |
| Integration | `integration_test/` | `integration_test/` | Full app flows on device/emulator |

### 4.2 Unit tests

```dart
// test/features/wishlist/domain/wishlist_visibility_test.dart
void main() {
  test('personal wishlist is not visible to other users', () {
    final wishlist = Wishlist(
      id: '1',
      ownerId: 'user-a',
      visibility: Visibility.personal,
    );

    expect(wishlist.isVisibleTo('user-b'), isFalse);
  });
}
```

### 4.3 Notifier tests

Riverpod Notifiers are tested with a `ProviderContainer` and overridden providers.

```dart
// test/features/wishlist/presentation/wishlist_notifier_test.dart
void main() {
  late ProviderContainer container;
  late MockWishlistRepository mockRepository;

  setUp(() {
    mockRepository = MockWishlistRepository();
    container = ProviderContainer(
      overrides: [
        wishlistRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('loadWishlists sets state to data on success', () async {
    when(() => mockRepository.getWishlists()).thenAnswer(
      (_) async => [Wishlist(id: '1', title: 'Test')],
    );

    final notifier = container.read(wishlistNotifierProvider.notifier);
    await notifier.loadWishlists();

    final state = container.read(wishlistNotifierProvider);
    expect(state, isA<AsyncData<List<Wishlist>>>());
    expect(state.value!.length, 1);
  });

  test('loadWishlists sets state to error on failure', () async {
    when(() => mockRepository.getWishlists())
        .thenThrow(ServerException());

    final notifier = container.read(wishlistNotifierProvider.notifier);
    await notifier.loadWishlists();

    final state = container.read(wishlistNotifierProvider);
    expect(state, isA<AsyncError>());
  });
}
```

### 4.4 Repository tests

Repositories are tested with mocked remote and local data sources.

```dart
// test/features/wishlist/data/wishlist_repository_test.dart
void main() {
  late WishlistRepository repository;
  late MockRemoteDataSource mockRemote;
  late MockLocalDataSource mockLocal;

  setUp(() {
    mockRemote = MockRemoteDataSource();
    mockLocal = MockLocalDataSource();
    repository = WishlistRepository(
      remote: mockRemote,
      local: mockLocal,
    );
  });

  test('getWishlists fetches from remote and caches locally', () async {
    final remoteWishlists = [WishlistDto(id: '1', title: 'Remote')];
    when(() => mockRemote.fetchWishlists())
        .thenAnswer((_) async => remoteWishlists);
    when(() => mockLocal.cacheWishlists(any()))
        .thenAnswer((_) async {});

    final result = await repository.getWishlists();

    expect(result.length, 1);
    verify(() => mockLocal.cacheWishlists(any())).called(1);
  });

  test('getWishlists falls back to local cache on network failure', () async {
    when(() => mockRemote.fetchWishlists())
        .thenThrow(DioException.connectionTimeout(
      requestOptions: RequestOptions(path: '/'),
      timeout: const Duration(seconds: 5),
    ));
    when(() => mockLocal.getCachedWishlists())
        .thenAnswer((_) async => [Wishlist(id: '1', title: 'Cached')]);

    final result = await repository.getWishlists();

    expect(result.length, 1);
    expect(result.first.title, 'Cached');
  });
}
```

### 4.5 Widget tests

```dart
// test/features/wishlist/presentation/wishlist_card_test.dart
void main() {
  testWidgets('displays wishlist title and wish count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WishlistCard(
          wishlist: Wishlist(
            id: '1',
            title: 'My Birthday',
            wishCount: 5,
          ),
        ),
      ),
    );

    expect(find.text('My Birthday'), findsOneWidget);
    expect(find.textContaining('5'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WishlistCard(
          wishlist: Wishlist(id: '1', title: 'Test', wishCount: 0),
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(WishlistCard));
    expect(tapped, isTrue);
  });
}
```

### 4.6 Integration tests

```dart
// integration_test/wishlist_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user can create a wishlist and add a wish', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Login
    await tester.enterText(find.byKey(Key('emailField')), 'test@chtohochu.ru');
    await tester.enterText(find.byKey(Key('passwordField')), 'password');
    await tester.tap(find.byKey(Key('loginButton')));
    await tester.pumpAndSettle();

    // Create wishlist
    await tester.tap(find.byKey(Key('createWishlistFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('titleField')), 'Test List');
    await tester.tap(find.byKey(Key('saveButton')));
    await tester.pumpAndSettle();

    expect(find.text('Test List'), findsOneWidget);
  });
}
```

### 4.7 Flutter test commands

```bash
flutter test                                    # all unit + widget tests
flutter test test/features/wishlist             # specific directory
flutter test --plain-name "wishlist"            # filter by name
flutter test --coverage                         # with coverage
integration_test/                               # run integration tests
flutter test integration_test/wishlist_flow_test.dart -d emulator-5554
```

## 5. Nuxt Tests (Public Web, Seller, Admin)

### 5.1 Test types

| Type | Framework | Location | Purpose |
|------|-----------|----------|---------|
| Unit | Vitest | `test/unit/` | Pure functions, composables, utilities |
| Component | Vitest + Vue Test Utils | `test/components/` | Component rendering and interaction |
| E2E | Playwright | `e2e/` | Full browser flow |

### 5.2 Unit tests

```ts
// test/unit/composables/useShareToken.test.ts
import { describe, it, expect } from 'vitest';
import { useShareToken } from '~/composables/useShareToken';

describe('useShareToken', () => {
  it('resolves wishlist share token', async () => {
    const { resolve } = useShareToken();
    const result = await resolve('abc123');
    expect(result.type).toBe('wishlist');
    expect(result.entityId).toBe('wl-1');
  });

  it('returns error for invalid token', async () => {
    const { resolve } = useShareToken();
    const result = await resolve('invalid');
    expect(result.error).toBe('token_not_found');
  });
});
```

### 5.3 Component tests

```ts
// test/components/ProductCard.test.ts
import { mount } from '@vue/test-utils';
import ProductCard from '~/components/products/ProductCard.vue';

describe('ProductCard', () => {
  it('renders product name and price', () => {
    const wrapper = mount(ProductCard, {
      props: {
        product: {
          id: '1',
          name: 'Test Product',
          price: 999,
          imageUrl: '/test.jpg',
        },
      },
    });

    expect(wrapper.text()).toContain('Test Product');
    expect(wrapper.text()).toContain('999');
  });

  it('emits edit event on button click', async () => {
    const wrapper = mount(ProductCard, {
      props: { product: { id: '1', name: 'Test', price: 100 } },
    });

    await wrapper.find('[data-test="edit-button"]').trigger('click');
    expect(wrapper.emitted('edit')).toBeTruthy();
  });
});
```

### 5.4 E2E tests (Playwright)

```ts
// e2e/seller-login.spec.ts
import { test, expect } from '@playwright/test';

test('seller can log in and see dashboard', async ({ page }) => {
  await page.goto('http://localhost:3003/login');

  await page.fill('[data-test="email"]', 'seller@chtohochu.ru');
  await page.fill('[data-test="password"]', 'password');
  await page.click('[data-test="submit"]');

  await expect(page).toHaveURL('http://localhost:3003/');
  await expect(page.locator('h1')).toContainText('Dashboard');
});
```

### 5.5 Nuxt test commands

```bash
npm run test          # Vitest (unit + component)
npm run test:e2e      # Playwright (E2E)
npm run test:coverage # Vitest with coverage
```

## 6. Test Naming Conventions

### 6.1 Backend (PHPUnit)

* Method names use `test_` prefix with snake_case descriptive sentence.
* Or use `#[Test]` attribute with camelCase method names.

```php
// Good
public function test_authenticated_user_can_create_wishlist(): void
public function test_unauthenticated_request_returns_401(): void
public function test_duplicate_operation_id_is_idempotent(): void

// With attribute
#[Test]
public function authenticatedUserCanCreateWishlist(): void
```

### 6.2 Flutter (Dart)

* Test descriptions are full sentences describing the behavior and expected outcome.

```dart
// Good
test('personal wishlist is not visible to other users', () { ... });
testWidgets('displays wishlist title and wish count', (tester) async { ... });
test('loadWishlists sets state to data on success', () async { ... });
```

### 6.3 Nuxt (Vitest)

* `describe` blocks name the unit under test.
* `it` blocks describe the behavior in plain language.

```ts
describe('ProductCard', () => {
  it('renders product name and price', () => { ... });
  it('emits edit event on button click', async () => { ... });
});
```

## 7. Test Data Management

### 7.1 Backend

| Tool | Usage |
|------|-------|
| Model factories | `User::factory()->create()`, `Wishlist::factory()->create()` |
| Database refresh | `use RefreshDatabase` trait — each test gets a clean DB |
| Seeders | `DatabaseSeeder` for development data; test-specific seeders for integration tests |
| Fixtures | Static JSON fixtures for API contract tests |

### 7.2 Flutter

| Tool | Usage |
|------|-------|
| Mocktail | Mock classes for data sources, repositories |
| Fixture files | `test/fixtures/` for JSON responses |
| Fakes | Simple fake implementations for value objects |

### 7.3 Nuxt

| Tool | Usage |
|------|-------|
| MSW (Mock Service Worker) | Mock API responses in component/E2E tests |
| Test data factories | Functions that generate consistent test objects |

### 7.4 Rules

* No test depends on another test's state.
* No test relies on external services (real APIs, real FCM, real OAuth providers).
* Test data is explicit — no magic global state.
* Factories produce valid entities by default; invalid states are explicit overrides.

## 8. Coverage Expectations

### 8.1 Minimum coverage targets

| Area | Target | Rationale |
|------|--------|-----------|
| Backend domain/services | 90% | Business logic is critical |
| Backend API controllers | 80% | Thin but must verify auth/validation |
| Backend authorization | 100% | Every protected endpoint tested |
| Backend sync/idempotency | 100% | Correctness is critical |
| Flutter repositories | 80% | Data boundary |
| Flutter notifiers | 80% | State logic |
| Flutter widgets | 60% | Key interactions, not every pixel |
| Nuxt composables | 80% | Logic |
| Nuxt components | 60% | Key components |

### 8.2 What MUST be covered

* Every authorization rule.
* Every sync mutation (create, update, delete, retry, conflict).
* Every idempotency guarantee.
* Every realtime event handler (duplicate, unknown, out-of-order).
* Every validation rule on critical endpoints.
* Every transaction boundary.
* Every conflict resolution strategy.

### 8.3 What does NOT require coverage

* Trivial getters/setters.
* Generated code (`*.g.dart`, `*.freezed.dart`, Drift generated).
* Pure UI styling (colors, padding) — covered by widget smoke tests.
* Third-party library behavior.

## 9. CI Integration

Tests run in CI on every PR. The pipeline:

```text
[1] Lint / Static Analysis
[2] Backend tests (php artisan test --parallel)
[3] Flutter tests (flutter test)
[4] Nuxt tests (npm run test)
[5] Coverage report generation
[6] Coverage threshold check (fail if below target)
```

A PR cannot merge if any test stage fails or coverage drops below the threshold for the changed files.

## 10. Sync / Realtime Test Matrix

The following scenarios MUST be tested for offline-capable domains:

| Scenario | Test |
|----------|------|
| Normal mutation (online) | Mutation succeeds, local DB updated, server updated |
| Mutation with network failure | Mutation queued locally, retried on reconnect, succeeds |
| Mutation retry after app restart | Queued mutation survives restart, retried, succeeds |
| Duplicate mutation (same operation_id) | Server returns original result, no duplicate effect |
| Conflict (concurrent edit) | Server returns conflict, client reconciles |
| Duplicate realtime event | Client ignores duplicate (event_id dedup) |
| Unknown realtime event type | Client ignores without crashing |
| Out-of-order events | Client reconciles by revision/timestamp |
| Reconnect after disconnect | Client re-subscribes and reconciles state |
| Offline read | Client serves from local DB (Drift) |
