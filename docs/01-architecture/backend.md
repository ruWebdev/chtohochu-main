# Backend Architecture — ЧтоХочу

## 1. Overview

The ЧтоХочу backend is a **Laravel 13** application running on **PHP 8.3+**. It is a **modular monolith** — a single deployable unit with internal module boundaries, not microservices. It is the single source of truth for all shared business state.

| Attribute | Value |
|-----------|-------|
| Framework | Laravel 13 |
| Language | PHP 8.3+ |
| Architecture | Modular monolith, pragmatic layered architecture |
| Database | PostgreSQL (authoritative) |
| Cache / Queue | Redis |
| Realtime | Laravel Reverb (WebSocket) |
| Queue dashboard | Laravel Horizon |
| Auth | Laravel Sanctum (token + cookie), Laravel Socialite (VK, Yandex) |
| Permissions | Spatie Laravel-Permissions (admin roles) |
| Frontend integration | Inertia.js + Ziggy (for public-web cabinet) |
| API versioning | `/api/v1/` |

---

## 2. Pragmatic Layered Architecture

The backend follows a pragmatic layered architecture. Layers are conceptual — they guide code organization, but Laravel conventions are used where they improve clarity. Do not create layers merely to satisfy a diagram.

```
┌─────────────────────────────────────────────────────┐
│                    HTTP Layer                         │
│         Controllers · Requests · Middleware           │
│  (thin: receive, authorize, validate, delegate)       │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              Application Layer                        │
│         Actions · Application Services                │
│  (orchestrate domain operations, transactions)        │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                 Domain Layer                          │
│       Domain Models · Domain Services · Invariants    │
│  (business rules, entity behavior, authorization)     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              Infrastructure Layer                     │
│    Eloquent · Migrations · Mail · Storage · Redis     │
│  (persistence, external services, technical concerns) │
└──────────────────────────────────────────────────────┘
```

### 2.1 HTTP Layer

The HTTP layer is the entry point for all external requests. It is **thin** — it contains no business logic.

**Responsibilities:**
1. Receive the HTTP request.
2. Authorize (via Laravel policies or explicit checks).
3. Validate (via Form Requests).
4. Invoke an application operation (Action or Application Service).
5. Return a response (JSON Resource, Inertia page, or status code).

**What controllers MUST NOT do:**
- Manipulate many models directly.
- Send notifications.
- Broadcast events.
- Perform complex calculations.
- Implement authorization rules (use policies).
- Contain transaction orchestration (delegate to Actions).

**Current structure:**
```
app/Http/
├── Controllers/
│   ├── Api/                    # API controllers (mobile + web API)
│   │   ├── AuthController.php
│   │   └── SocialAuthController.php
│   ├── Auth/                   # Web auth controllers (Breeze-generated)
│   │   ├── AuthenticatedSessionController.php
│   │   ├── RegisteredUserController.php
│   │   └── ...
│   └── Controller.php          # Base controller
├── Requests/                   # Form request validation
│   └── Auth/
│       ├── LoginRequest.php
│       └── RegisterRequest.php
└── Middleware/                 # HTTP middleware
```

**Controller pattern:**
```php
class AuthController extends Controller
{
    public function login(LoginRequest $request): JsonResponse
    {
        $request->validated();

        $result = AuthenticateUser::run(
            email: $request->string('email'),
            password: $request->string('password'),
            deviceName: $request->string('device_name'),
        );

        if (! $result) {
            throw ValidationException::withMessages([
                'email' => __('auth.failed'),
            ]);
        }

        return response()->json(new AuthTokenResource($result));
    }
}
```

### 2.2 Application Layer

The Application layer contains **Actions** and **Application Services** — explicit operations that orchestrate domain logic and transactions.

**When to create an Action:**
- A mutation involves multiple models that must be atomic.
- A mutation has side effects (notifications, broadcasts, events).
- Business logic is complex enough that it doesn't belong in a controller.
- The same operation is invoked from multiple entry points (API, web, console).

**When NOT to create an Action:**
- A simple single-model CRUD operation that Eloquent handles cleanly.
- The controller would just delegate to a single model method.

**Current structure:**
```
app/Actions/
└── Auth/
    └── (auth actions)
```

**Target structure (as domains grow):**
```
app/Actions/
├── Auth/
├── Friends/
├── Wishlists/
├── ShoppingLists/
└── Notifications/
```

**Action pattern:**
```php
class CreateShoppingList
{
    public function __construct(
        private readonly ShoppingListPolicy $policy,
    ) {}

    public static function run(User $actor, CreateShoppingListData $data): ShoppingList
    {
        return app(self::class)->execute($actor, $data);
    }

    public function execute(User $actor, CreateShoppingListData $data): ShoppingList
    {
        $this->policy->canCreate($actor);

        return DB::transaction(function () use ($actor, $data) {
            $list = ShoppingList::create([
                'owner_id' => $actor->id,
                'title' => $data->title,
                'description' => $data->description,
            ]);

            $list->participants()->create([
                'user_id' => $actor->id,
                'role' => 'owner',
            ]);

            BroadcastShoppingListUpdated::dispatch($list);

            return $list;
        });
    }
}
```

### 2.3 Domain Layer

The Domain layer contains the business rules, entity behavior, and invariants. In a Laravel pragmatic architecture, this is primarily expressed through:

- **Eloquent models** with encapsulated behavior (scopes, accessors, mutators, custom methods).
- **Policies** for authorization rules.
- **Domain services** for cross-entity business logic (when needed).

**Domain modules (target):**
```
app/Domain/
├── Users/
│   ├── Models/User.php
│   ├── Policies/UserPolicy.php
│   └── Data/UserData.php
├── Friends/
│   ├── Models/Friendship.php
│   ├── Policies/FriendshipPolicy.php
│   └── Actions/
├── Wishlists/
│   ├── Models/Wishlist.php
│   ├── Models/Wish.php
│   ├── Policies/WishlistPolicy.php
│   └── Actions/
├── ShoppingLists/
│   ├── Models/ShoppingList.php
│   ├── Models/ShoppingListItem.php
│   ├── Policies/ShoppingListPolicy.php
│   └── Actions/
└── Notifications/
    ├── Models/Event.php
    └── Notifications/
```

**Model rules:**
- Models encapsulate their own behavior — don't spread entity logic across services.
- Use Eloquent scopes for reusable query constraints.
- Use accessors/mutators for derived or normalized attributes.
- Define relationships explicitly and completely.
- Hide mass-assignment vulnerabilities with `$fillable` / `$guarded`.

### 2.4 Infrastructure Layer

The Infrastructure layer handles technical concerns: persistence, external services, storage, mail, cache.

**Components:**
- **Eloquent ORM** — database access (part of Laravel, used throughout).
- **Migrations** — schema evolution (`database/migrations/`).
- **Redis** — cache, queue driver, Reverb backend, ephemeral state.
- **S3-compatible storage** — file uploads (avatars, wish images).
- **Mail** — transactional email via Laravel Mail.
- **Horizon** — queue management and monitoring.

---

## 3. Request Flow

### 3.1 API request (mobile client)

```
Flutter (Dio)
  │
  │  POST /api/v1/shopping-lists/{id}/items
  │  Authorization: Bearer {sanctum-token}
  │  Body: { "text": "Milk", "operation_id": "uuid" }
  │
  ▼
Laravel HTTP Kernel
  │
  ├── Middleware: api (throttle, sanctum)
  │     ├── Rate limiting (throttle:api)
  │     └── Sanctum token authentication → resolves User
  │
  ▼
Controller: ShoppingListItemController@store
  │
  ├── 1. Validate (StoreShoppingListItemRequest)
  │     → rules: text required|string|max:255, operation_id required|uuid
  │
  ├── 2. Authorize (ShoppingListItemPolicy@create)
  │     → verify: user is participant of shopping list
  │
  ├── 3. Invoke Action: AddShoppingListItem::run($user, $list, $data)
  │     │
  │     ▼
  │     Action: DB::transaction {
  │       ├── Check idempotency (operation_id already processed?)
  │       ├── Create ShoppingListItem
  │       ├── Create activity event
  │       └── Broadcast event (after commit)
  │     }
  │
  └── 4. Return: ShoppingListItemResource → JSON
```

### 3.2 Web request (public-web cabinet via Inertia)

```
Browser → lk.chtohochu.ru/wishlists
  │
  ▼
Laravel HTTP Kernel
  │
  ├── Middleware: web (session, csrf, auth)
  │     └── Session-based authentication (cookie)
  │
  ▼
Controller: WishlistController@index (Inertia)
  │
  ├── 1. Authorize (WishlistPolicy@viewAny)
  ├── 2. Fetch wishlists for user
  └── 3. Return Inertia response with page props
        │
        ▼
      Inertia::render('Wishlists/Index', [
        'wishlists' => WishlistResource::collection($wishlists),
      ])
        │
        ▼
      Nuxt/Vue renders the page (SSR + hydration)
```

### 3.3 Realtime broadcast flow

```
Mutation committed to PostgreSQL
  │
  ▼
DB::transaction callback or model event
  │
  ▼
Broadcast event dispatched (after commit)
  │
  ├── Event class implements ShouldBroadcast
  │     → channel: shopping-list.{id}
  │     → event: ShoppingListItemAdded
  │     → payload: { event_id, entity_type, entity_id, revision, actor_id, ... }
  │
  ▼
Laravel Reverb receives broadcast
  │
  ▼
Reverb pushes to all subscribed WebSocket clients
  │
  ▼
Flutter clients reconcile via Repository
```

> **Critical rule:** Broadcast events are dispatched **only after the database transaction commits**. This prevents phantom events for rolled-back transactions.

---

## 4. Modular Monolith

The backend is a modular monolith. Domain code is organized into modules (conceptual, not separate Composer packages). Each module owns its models, policies, actions, events, and notifications.

### 4.1 Module boundaries

| Module | Owns | Does NOT touch |
|--------|------|----------------|
| Users | User model, profile, auth | Shopping list logic |
| Friends | Friendship model, friend requests | Wishlist participant logic (separate concern) |
| Wishlists | Wishlist, Wish models, claims, likes, comments | Shopping list models |
| ShoppingLists | ShoppingList, ShoppingListItem models, participants | Wishlist models |
| Notifications | Events, push notifications, notification preferences | Business state mutations |

### 4.2 Cross-module communication

Modules communicate through:
- **Actions** — one module's action can call another module's action (e.g., `AcceptFriendRequest` may trigger a notification action).
- **Events** — domain events dispatched by one module and listened to by another (e.g., `WishClaimed` → notification module sends push).
- **Models** — read access to other modules' models is allowed (Eloquent relationships), but write access goes through the owning module's actions.

**What modules must NOT do:**
- Directly manipulate another module's database tables bypassing the owning module's models.
- Define authorization rules for another module's resources (use the owning module's policy).
- Broadcast events on behalf of another module (the owning module broadcasts its own events).

---

## 5. Database (PostgreSQL)

PostgreSQL is the authoritative persistence layer. All business state lives here.

### 5.1 Current schema

```
database/migrations/
├── 0001_01_01_000000_create_users_table.php
├── 0001_01_01_000001_create_cache_table.php
├── 0001_01_01_000002_create_jobs_table.php
├── 2025_11_20_164019_create_permission_tables.php
└── 2025_11_22_072131_create_personal_access_tokens_table.php
```

### 5.2 Database rules

1. **Every schema change requires a migration.** No manual schema modifications.
2. **Use foreign keys, unique constraints, check constraints, and indexes.** If PostgreSQL can enforce an invariant, enforce it there.
3. **Transactions for atomic operations.** Any logically atomic multi-record mutation MUST define a transaction boundary.
4. **Appropriate isolation levels.** Use the minimum isolation that guarantees correctness.
5. **No partial state after failure.** A failed atomic operation MUST NOT leave partial domain state behind.

### 5.3 Transaction pattern

```php
DB::transaction(function () use ($actor, $data) {
    $list = ShoppingList::create([...]);
    $list->participants()->create([...]);
    $list->permissions()->create([...]);
    Event::create([...]);
    // If any of these fail, all are rolled back.
});
// Broadcast only after successful commit
BroadcastShoppingListUpdated::dispatch($list);
```

---

## 6. Redis

Redis is used for non-authoritative infrastructure: cache, queues, Reverb backend, and ephemeral state.

| Use case | Rules |
|----------|-------|
| **Queue driver** | Horizon manages workers. Jobs must tolerate retries. Dangerous side effects must be idempotent or unique. |
| **Cache** | Every cache entry requires: explicit TTL, invalidation strategy, consistency expectation, fallback. |
| **Reverb backend** | Reverb uses Redis for pub/sub. Not business state. |
| **Locks** | For concurrency control (e.g., preventing duplicate sync operations). Must have TTL to prevent deadlocks. |
| **Ephemeral state** | Rate limiting counters, presence state, temporary tokens. Never authoritative. |

> **Critical rule:** Redis MUST NOT become authoritative business storage. If Redis loses all data, the system must remain correct — only performance or convenience is affected.

---

## 7. Realtime (Laravel Reverb)

Reverb is the WebSocket transport for realtime events. It is a **delivery mechanism**, never the source of truth.

### 7.1 Channel structure

```
routes/channels.php

// Personal notification channel
Broadcast::channel('user.{userId}', function ($user, $userId) {
    return $user->id === $userId;
}, ['guards' => ['web', 'sanctum']]);

// Shopping list collaboration channel (future)
Broadcast::channel('shopping-list.{listId}', function ($user, $listId) {
    return $user->participatesInShoppingList($listId);
}, ['guards' => ['web', 'sanctum']]);

// Wishlist collaboration channel (future)
Broadcast::channel('wishlist.{wishlistId}', function ($user, $wishlistId) {
    return $user->canViewWishlist($wishlistId);
}, ['guards' => ['web', 'sanctum']]);
```

### 7.2 Event contract

Every realtime event should contain:

```php
class ShoppingListItemAdded implements ShouldBroadcast
{
    public function broadcastWith(): array
    {
        return [
            'event_id'        => $this->event->id,
            'event_type'      => 'shopping_list.item.added',
            'entity_type'     => 'shopping_list_item',
            'entity_id'       => $this->item->id,
            'revision'        => $this->list->revision,
            'actor_id'        => $this->actor->id,
            'server_timestamp'=> now()->toISOString(),
            'payload'         => [
                'shopping_list_id' => $this->list->id,
                'item'             => [...],
            ],
        ];
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel("shopping-list.{$this->list->id}"),
        ];
    }
}
```

### 7.3 Client resilience rules

A correct client MUST survive:
- Lost events (reconnect + refetch).
- Duplicated events (idempotent reconciliation by `event_id`).
- Delayed events (revision-based ordering).
- Out-of-order events (revision comparison, not blind application).
- Reconnects (re-establish subscription, refetch current state).

> Unknown event types MUST NOT crash clients. Duplicate events MUST be safe.

---

## 8. Queue & Horizon

Laravel Queue handles asynchronous operations via Redis. **Horizon** provides dashboard, metrics, and auto-scaling.

### 8.1 Queue usage

| Job type | Queue | Example |
|----------|-------|---------|
| Push notifications | `notifications` | SendFcmNotification, SendEmailNotification |
| Email | `mail` | SendWelcomeEmail, SendFriendRequestEmail |
| Image processing | `images` | ProcessAvatarUpload, ProcessWishImage |
| Broadcast | `broadcasts` | (handled by Laravel automatically) |
| Default | `default` | Fallback for uncategorized jobs |

### 8.2 Job rules

1. **Jobs MUST tolerate retries.** A retried job must not produce duplicate side effects.
2. **Dangerous side effects must be idempotent or unique.** Use `ShouldBeUnique` for jobs that must not run concurrently.
3. **Jobs must not assume fresh state.** Re-fetch models inside the job; don't pass stale data.
4. **Failed jobs must be visible.** Horizon dashboard monitors failed jobs; alerts should be configured.

### 8.3 Horizon configuration

Horizon runs as a separate process in production:

```yaml
# compose.yaml (production)
queue-worker:
  image: ghcr.io/ruwebdev/chtohochu-backend:${TAG:-latest}
  command: php artisan queue:work --tries=3 --max-time=3600
  # Horizon dashboard available at /horizon (admin-only)
```

---

## 9. Authentication & Authorization

### 9.1 Authentication

| Guard | Mechanism | Used by |
|-------|-----------|---------|
| `sanctum` (token) | Bearer token in Authorization header | Flutter client, seller cabinet, admin panel |
| `web` (session) | Cookie-based session | public-web cabinet (Inertia) |
| `sanctum` (cookie) | Sanctum cookie for SPA | (alternative for web SPA if needed) |

**OAuth:** Laravel Socialite handles VK and Yandex OAuth. The flow:
```
Flutter WebView → VK/Yandex OAuth → callback to API →
  → Socialite resolves user → find or create local user →
  → issue Sanctum token → return to Flutter
```

### 9.2 Authorization

The backend is the **final authorization authority**. Every protected operation MUST verify:

1. **Authentication** — the user is who they claim to be.
2. **Ownership** — the user owns the resource (or has been granted access).
3. **Membership** — the user is a participant of the shared entity.
4. **Permission** — the user has the required permission for the specific action.
5. **Resource visibility** — the resource is visible to the user (personal, link, public).

**Implementation:** Laravel Policies encapsulate authorization rules. Controllers call `$this->authorize()` or the policy directly. Actions re-check authorization (defense in depth).

> **Client-supplied ownership or permission information MUST NOT be trusted.** The client may hide UI for UX, but the backend always re-verifies.

---

## 10. API Design

### 10.1 Versioning

All application APIs are versioned under `/api/v1/`. Breaking changes require:
- Explicit compatibility analysis.
- Approval via ADR.
- Consideration of existing mobile clients in production.
- Prefer additive changes (new optional fields, new endpoints) over breaking changes.

### 10.2 Route organization

```
routes/
├── api.php          # API routes (Sanctum-guarded, /api/v1/)
├── auth.php         # Web auth routes (Breeze, session-guarded)
├── channels.php     # Broadcast channel authorization
├── web.php          # Web routes (Inertia pages)
└── console.php      # Console command routes
```

### 10.3 Domain-based API routing

```
/api/v1/
├── auth/
│   ├── register
│   ├── login
│   ├── logout
│   ├── me
│   └── vk / yandex (OAuth)
├── wishlists/
│   ├── (CRUD)
│   ├── {id}/wishes/
│   ├── {id}/participants/
│   └── {id}/share/
├── wishes/
│   ├── (CRUD)
│   ├── {id}/claim/
│   ├── {id}/like/
│   └── {id}/comments/
├── shopping-lists/
│   ├── (CRUD)
│   ├── {id}/items/
│   └── {id}/participants/
├── friends/
│   ├── (list, search)
│   ├── requests/
│   └── {id}/ (remove)
├── events/
│   └── (list, mark-read, delete)
└── share/
    └── {token} (resolve)
```

### 10.4 Response format

All API responses use JSON Resources for consistent serialization:

```php
class WishlistResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id'           => $this->id,
            'title'        => $this->title,
            'description'  => $this->description,
            'emoji'        => $this->emoji,
            'visibility'   => $this->visibility,
            'owner'        => new UserSummaryResource($this->whenLoaded('owner')),
            'participants' => UserSummaryResource::collection($this->whenLoaded('participants')),
            'wishes_count' => $this->whenCounted('wishes'),
            'created_at'   => $this->created_at,
            'updated_at'   => $this->updated_at,
        ];
    }
}
```

**Rules:**
- Use `whenLoaded()` to avoid N+1 queries — only include relationships that were explicitly loaded.
- Use `whenCounted()` for count aggregates.
- Never expose internal fields (passwords, tokens, internal flags) in resources.
- Pagination uses Laravel's standard `LengthAwarePaginator` structure.

---

## 11. Testing

### 11.1 Test structure

```
tests/
├── Feature/           # API tests, integration tests
│   ├── Auth/
│   ├── Wishlists/
│   └── ShoppingLists/
└── Unit/              # Domain logic, model behavior, actions
```

### 11.2 What must be tested

| Category | Tests |
|----------|-------|
| **Domain/Application** | Action behavior, invariants, edge cases |
| **API** | Endpoint contracts, request validation, response format |
| **Authorization** | Every protected operation — allowed and denied cases |
| **Database constraints** | Foreign keys, unique constraints, check constraints |
| **Transactions** | Atomic operations — rollback on failure, no partial state |
| **Concurrency/Conflict** | Collaborative editing, sync conflicts, duplicate mutations |
| **Realtime** | Event broadcasting, channel authorization, event payload shape |
| **Idempotency** | Duplicate operation_id must not create duplicate effects |

### 11.3 Test tools

- **PHPUnit** — primary test framework.
- **Laravel testing helpers** — `RefreshDatabase`, `WithoutMiddleware`, `actingAs`.
- **Faker** — test data generation (configured for `ru_RU` locale).

---

## 12. Configuration

### 12.1 Environment

The backend uses domain-based environment configuration:

```env
# Domains
APP_DOMAIN_LANDING=ch.local
APP_DOMAIN_USER=lk.ch.local
APP_DOMAIN_ADMIN=admin.ch.local
APP_DOMAIN_API=api.ch.local
APP_DOMAIN_APP=app.ch.local

# Database
DB_CONNECTION=pgsql  # PostgreSQL in production

# Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379

# Reverb (WebSocket)
REVERB_APP_ID=...
REVERB_APP_KEY=...
REVERB_APP_SECRET=...
REVERB_HOST=app.ch.local
REVERB_PORT=443
REVERB_SCHEME=https

# OAuth
VK_CLIENT_ID=...
VK_CLIENT_SECRET=...
VK_REDIRECT_URI=https://api.chtohochu.ru/auth/vk/callback
YANDEX_CLIENT_ID=...
YANDEX_CLIENT_SECRET=...
YANDEX_REDIRECT_URI=https://api.chtohochu.ru/auth/yandex/callback
```

### 12.2 Domain-based routing

Routes are bound to specific subdomains:

```php
// routes/api.php — API domain
Route::domain(env('APP_DOMAIN_API'))->middleware(['api'])->group(function () {
    // API routes
});

// routes/auth.php — User cabinet domain
Route::domain(env('APP_DOMAIN_USER'))->middleware(['web'])->group(function () {
    // Web auth routes
});
```

This ensures that API routes are only accessible on `api.chtohochu.ru` and web auth routes only on `lk.chtohochu.ru`.

---

## 13. Deployment

### 13.1 Docker

The backend ships as a Docker image:

```dockerfile
# Dockerfile (simplified)
FROM php:8.3-fpm-alpine
# Install PHP extensions: pdo_pgsql, redis, bcmath, gd, ...
# Install Composer, Node.js (for Vite build)
# Copy application code
# Run composer install --optimize-autoloader --no-dev
# Run npm install && npm run build
```

### 13.2 Production services (Docker Compose)

```yaml
services:
  app:              # Laravel (FPM + Nginx)
    # Serves HTTP API + web routes
  queue-worker:     # Horizon / queue:work
    # Processes async jobs
  reverb:           # php artisan reverb:start
    # WebSocket server (port 8080)
  redis:            # Redis 7
    # Cache, queue, Reverb backend
  # PostgreSQL is external or in a separate container
```

### 13.3 CI/CD

GitHub Actions pipeline:
1. **On push:** run tests (PHPUnit), static analysis (Pint), build Docker image.
2. **On merge to main:** push image to GitHub Container Registry.
3. **On deploy:** pull latest image, run migrations, restart workers.
