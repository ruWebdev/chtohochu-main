# ADR-002: Laravel as backend

## Status

Accepted

## Context

ЧтоХочу is a server-authoritative social wishlist and collaborative
shopping-list application. The backend is the single source of truth for all
shared business state (AGENTS.md §5). It must provide, in one cohesive system:

- **Authentication** — token-based auth for the Flutter mobile clients and
  cookie/token auth for the web cabinets, with secure credential issuance and
  revocation.
- **A versioned REST API** (`/api/v1/`) consumed by Flutter and three Nuxt web
  apps, with request validation, authorization, resource serialization and
  backward compatibility for already-shipped mobile clients.
- **Realtime** — WebSocket-based broadcasting for collaborative shopping lists,
  invitations, notifications and presence, where events are only emitted after
  the authoritative PostgreSQL transaction commits (AGENTS.md §22).
- **Queues and scheduling** — asynchronous jobs for push notifications, email,
  image processing and external integrations, plus a scheduler for recurring
  tasks. Jobs must tolerate retries and be idempotent for dangerous side effects
  (AGENTS.md §34).
- **Notifications** — multi-channel notifications (database, broadcast, mail,
  push) tied to domain events.
- **Integrations** — S3-compatible object storage for user uploads, FCM for
  push, and future payment/external service integrations.
- **Transactional integrity** — multi-record atomic mutations (e.g. creating a
  shared list + owner membership + permissions + activity in one transaction)
  must never leave partial state behind (AGENTS.md §19).

The team is small. The architecture must be a **modular monolith** by default
(AGENTS.md §4): no microservices, no second backend runtime, no Kafka, no
Elasticsearch, no Kubernetes unless a concrete requirement forces an ADR. The
chosen framework must therefore deliver all of the above as first-party,
batteries-included capabilities so we do not assemble a distributed system from
loose libraries just to get auth, queues and WebSockets.

## Decision

Use **Laravel 13** on **PHP 8.4+** as the backend framework, with the following
first-party stack:

- **PostgreSQL** as the authoritative relational database (see ADR-005).
- **Redis** for queues, cache, locks and realtime infrastructure — never as
  authoritative business storage (AGENTS.md §20).
- **Laravel Reverb** as the WebSocket realtime transport (see ADR-006).
- **Laravel Horizon** for queue monitoring and worker management.
- **Laravel Queue** + **Laravel Scheduler** for async jobs and recurring tasks.
- **Laravel Sanctum** for API token auth (mobile) and cookie/token auth (web).
- **Laravel Notifications** for multi-channel notifications.

The backend is organized as a **modular monolith** along domain boundaries
(`Domain/Users`, `Domain/Wishlists`, `Domain/ShoppingLists`, etc.) as described
in AGENTS.md §15. Controllers stay thin (§16); business logic lives in
application operations and domain services (§17).

## Consequences

**Positive**

- **Batteries included.** Auth (Sanctum), migrations, ORM (Eloquent), queues,
  scheduler, notifications, broadcasting, validation, rate limiting, file
  storage abstraction and testing helpers are all first-party and documented
  together. We do not need to evaluate, integrate and version-pin a dozen
  separate libraries to get a production backend.
- **First-party realtime.** Reverb is a Laravel package, so the realtime
  channel shares the same auth, event broadcasting and deployment story as the
  REST API. There is no second runtime to operate.
- **Transactional correctness fits naturally.** DB transactions, model events
  and broadcasting can be composed so that events fire only after commit,
  satisfying the realtime event flow in AGENTS.md §22.
- **Single runtime, single deployable.** A modular monolith on one runtime
  matches the "simplest architecture that satisfies current requirements"
  principle (§5). No service-to-service network calls, no distributed
  transactions, no inter-service auth.
- **Strong queue story.** Horizon gives visibility into job throughput,
  failures and retries, which is essential for the idempotent-retry
  requirements in §29 and §34.
- **Mature ecosystem.** PHP 8.4 + Laravel 13 have mature tooling, static
  analysis (PHPStan/Pest), and a large pool of documentation and contributors.

**Negative**

- **PHP is the only backend language.** Any library only available in Node/Go
  must be invoked via an external process or a small sidecar, which adds
  operational complexity. This is acceptable until a concrete requirement
  appears.
- **Long-running tasks are not PHP's strength.** CPU-bound work should be
  deferred to queued jobs or external workers. This is already the prescribed
  pattern (§34), so it is not a real limitation for this product.
- **Eloquent is active-record.** For complex domain logic we must be
  disciplined to keep business rules in domain/application services and not in
  controllers or fat models (§16, §17). The modular monolith structure
  mitigates this.
- **Horizontal scaling of WebSockets** requires running Reverb in a scalable
  mode (Redis pub/sub adapter) once connection counts grow. This is a future
  operational concern, not an architectural blocker.

## Alternatives considered

### Node.js / NestJS (TypeScript)

A NestJS modular monolith on Node.js with TypeORM/Prisma, BullMQ for queues,
Socket.io for realtime, and Passport for auth.

- **Strengths:** shares TypeScript with the web apps; single language across
  backend and web; excellent realtime/async ecosystem; large talent pool.
- **Rejected because** it is an assembly job, not a batteries-included
  framework. Auth, queues, scheduler, notifications, broadcasting, migrations
  and storage abstractions must each be chosen, integrated and version-pinned
  separately. NestJS provides structure but not the integrated
  auth+queue+notifications+broadcasting+scheduler story that Laravel ships
  out of the box. The realtime story (Socket.io) is not first-party to the
  framework and requires a separate server/process. For a small team that must
  ship auth, API, realtime, queues and notifications together, the integration
  cost is significant. Also, AGENTS.md §4 forbids a second backend runtime;
  choosing Node would make Node the runtime, which is fine in isolation, but
  the integrated capability per unit of effort is lower than Laravel for this
  product's requirements.

### Django (Python)

Django with DRF, Celery for queues, Channels for WebSockets.

- **Strengths:** batteries-included like Laravel; excellent ORM and admin;
  strong for data-heavy domains; Channels provides realtime.
- **Rejected because** Channels/ASGI is a more complex realtime story than
  Reverb's first-party integration, Celery adds a separate broker/process
  model, and the team's tooling preference and ecosystem fit favor Laravel.
  Django is a strong choice generally; the deciding factor is the tighter
  integration of auth + queues + scheduler + notifications + broadcasting in a
  single Laravel runtime with Horizon and Reverb.

### Spring Boot (Java/Kotlin)

Spring Boot with Spring Security, Spring Data JPA, WebSockets/STOMP, and a
JVM-based queue (e.g. RabbitMQ or Kafka).

- **Strengths:** extremely mature, strong typing, excellent for complex
  enterprise domains, very good concurrency support.
- **Rejected because** it is heavier than this product needs. The JVM
  operational profile (memory footprint, startup time, build complexity) and
  the enterprise-leaning configuration model are disproportionate for a small
  team building a modular monolith wishlist app. It also brings more
  infrastructure (separate broker) than the first-party Laravel queue/Reverb
  story. Spring Boot is a great choice for larger, more complex domains; it is
  over-engineered for the current requirements (§5: prefer the simplest
  architecture that satisfies current requirements).

### Go (custom services)

A set of Go services (or a single Go modular monolith) with a chosen router,
GORM/sqlx, a queue client, and a WebSocket library.

- **Strengths:** excellent performance, low memory footprint, single binary
  deployment, great concurrency.
- **Rejected because** Go gives you a language, not a framework. Auth,
  migrations, queues, scheduler, notifications, broadcasting, validation and
  storage abstractions must all be assembled by hand or from third-party
  libraries. The integration and boilerplate cost is the highest of all
  alternatives for a small team that needs all of these capabilities now. Go
  is ideal for high-throughput infrastructural components; it is not the
  fastest path to a feature-complete server-authoritative backend with auth,
  realtime, queues and notifications. Also conflicts with the
  no-second-runtime rule unless it is the only runtime, which would sacrifice
  the integrated Laravel stack.
