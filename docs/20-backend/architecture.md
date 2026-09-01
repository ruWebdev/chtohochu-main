# Backend Architecture — ЧтоХочу

> **Status:** Authoritative backend architecture document. See also
> [`docs/01-architecture/backend.md`](../01-architecture/backend.md) for the layered
> architecture overview and [`api.md`](./api.md), [`realtime.md`](./realtime.md),
> [`queues.md`](./queues.md) for specialised topics.

## 1. Overview

The ЧтоХочу backend is a **Laravel 13** application running on **PHP 8.3+**. It is a
**modular monolith** — a single deployable unit with internal module boundaries, not
microservices. It is the single source of truth for all shared business state.

| Attribute | Value |
|-----------|-------|
| Framework | Laravel 13 |
| Language | PHP 8.3+ |
| Architecture | Modular monolith, pragmatic layered architecture |
| Database | PostgreSQL (authoritative) |
| Cache / Queue / Locks | Redis |
| Realtime | Laravel Reverb (WebSocket) |
| Queue dashboard | Laravel Horizon |
| Auth | Laravel Sanctum (token + cookie), Laravel Socialite (VK, Yandex) |
| Permissions | Spatie Laravel-Permissions (admin roles) |
| Frontend integration | Inertia.js + Ziggy (for public-web cabinet) |
| API versioning | `/api/v1/` |

## 2. Layered Architecture

The backend follows a pragmatic layered architecture. Layers are conceptual — they
guide code organization, but Laravel conventions are used where they improve clarity.

```text
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

Thin entry point. Responsibilities: receive, authorize (via policies), validate (via
Form Requests), invoke an application operation, return a response (JSON Resource or
Inertia page). Controllers MUST NOT contain business logic, transaction orchestration,
notifications, or broadcasts.

### 2.2 Application Layer

Actions and application services orchestrate domain operations. They own transactions,
dispatch notifications, and broadcast events **after commit**. This is where
multi-model use cases live.

### 2.3 Domain Layer

Domain models, domain services, and invariants. Business rules and entity behaviour
live here. The domain layer does not depend on framework-specific infrastructure
(Eloquent, HTTP, mail). Authorization rules are expressed as policies and invoked from
the HTTP and Application layers.

### 2.4 Infrastructure Layer

Eloquent models, migrations, mail, storage, Redis, and external service clients.
Persistence and technical concerns live here. Redis is infrastructure only — never
authoritative business storage.

## 3. Modular Monolith

The backend is organised as a **modular monolith**: a single Laravel application with
internal module boundaries by feature/domain. Each module groups its controllers,
actions, domain models, policies, migrations, and tests.

```text
app/
├── Modules/
│   ├── Auth/
│   ├── Wishlists/
│   ├── ShoppingLists/
│   ├── Friends/
│   ├── Invitations/
│   ├── Notifications/
│   └── ...
├── Http/
├── Domain/
├── Application/
└── Infrastructure/
```

Rules:

- Modules communicate through application services and domain events, not by reaching
  into each other's internals.
- Cross-module queries go through a module's public API (action or service), not
  direct Eloquent queries on another module's models.
- A second backend runtime is forbidden (AGENTS.md §16). No microservices, no Node.js
  sidecar, no Kafka.

## 4. PostgreSQL

PostgreSQL is the authoritative persistence layer. See
[`database.md`](./database.md) and [`database-conventions.md`](./database-conventions.md).

- Every schema change requires a migration.
- Foreign keys, unique constraints, check constraints, and indexes enforce invariants
  at the database level.
- Atomic multi-record mutations use transactions.
- PostgreSQL is the source of truth; Redis and Reverb never hold authoritative
  business state.

## 5. Redis

Redis is infrastructure only (AGENTS.md §7). It serves:

- **Cache** — query and view caches.
- **Queues** — the backend for Horizon/queue workers.
- **Locks** — distributed locks for concurrency control.
- **Rate limiting** — throttle middleware counters.
- **Reverb adapter** — pub/sub fan-out for the WebSocket server.

Redis MUST NOT store authoritative business state. See
[`ADR-007-redis.md`](../adr/ADR-007-redis.md).

## 6. Queues

Queues handle async and non-critical work: push notifications, email, image
processing, and broadcast dispatch. Workers are managed by **Laravel Horizon**. Jobs
with side effects MUST be idempotent or unique. See [`queues.md`](./queues.md).

## 7. Scheduler

The Laravel scheduler (`php artisan schedule:work` / `schedule:run` in production)
dispatches scheduled commands and jobs onto the queue. In the Docker stack, a
dedicated `scheduler` container runs the scheduler. Scheduled jobs that perform
mutations MUST be idempotent.

## 8. Sanctum Auth

Laravel Sanctum provides authentication:

- **API tokens** for Flutter, seller, and admin clients.
- **Cookie sessions** (stateful domains) for the public-web cabinet.

OAuth (VK, Yandex) is handled by Laravel Socialite; after the provider callback, a
Sanctum token is issued. See [`authentication.md`](../01-architecture/authentication.md)
and [`oauth.md`](./oauth.md).

## 9. Spatie Permissions

Admin authorization uses **Spatie Laravel-Permissions** for role-based access control.
Roles and permissions are enforced server-side via middleware and policies. The admin
panel is a separate guard; it is not a normal user application (AGENTS.md §5). See
[`authorization.md`](./authorization.md).

## 10. Realtime

Laravel Reverb is the WebSocket transport. Events are broadcast after the PostgreSQL
transaction commits. Channel authorization reuses Laravel policies via
`routes/channels.php`. See [`realtime.md`](./realtime.md) and
[`realtime-events.md`](./realtime-events.md).

## 11. Backend Rules (Summary)

From AGENTS.md §7:

- Controllers are thin: receive, authorize, validate, invoke, respond.
- Business logic belongs in Domain or Application layers.
- Every schema change requires a migration.
- Atomic multi-record mutations require transactions.
- Authorization is always server-enforced.
- Client-supplied ownership/permission data MUST NOT be trusted.
- Use PostgreSQL constraints (FK, unique, check, indexes).
- Redis is infrastructure only — never authoritative business storage.
- Queues are for async/non-critical work.
- Jobs with side effects MUST be idempotent or unique.

## 12. Non-Goals

- No microservices or second backend runtime (AGENTS.md §16).
- No Kafka, Elasticsearch, or Kubernetes without an approved ADR.
- No GraphQL without an approved ADR.
- No business logic in controllers or UI widgets.
