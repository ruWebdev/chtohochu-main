# ADR-007: Redis as infrastructure

## Status

Accepted

## Context

ЧтоХочу requires several infrastructure capabilities that are not provided by
PostgreSQL alone (AGENTS.md §4, §7):

- **Cache** — query and view caches to reduce database load on hot paths.
- **Queue backend** — async job processing for push notifications, email, image
  processing, and broadcast dispatch (§7: queues are for async/non-critical work).
- **Distributed locks** — concurrency control for collaborative edits and scheduled
  jobs that must not run concurrently.
- **Rate limiting** — Laravel throttle middleware counters for auth and mutation
  endpoints (§12).
- **Realtime adapter** — Reverb's pub/sub adapter for fanning out broadcasts across
  multiple workers/instances (see ADR-006).

AGENTS.md §7 is explicit: **Redis is infrastructure only — never authoritative
business storage.** PostgreSQL is the sole source of truth for business state. Redis
may hold caches, queues, locks, and Reverb infrastructure, but never authoritative
business data. This means the choice of Redis is about operational capabilities, not
about where business state lives.

The backend is a modular monolith on a single runtime (§4): no microservices, no
Kafka. The infrastructure choice should fit this constraint — ideally a single,
well-understood service that covers all five capabilities.

## Decision

Use **Redis** as the single infrastructure service for cache, queues, locks, rate
limiting, and the Reverb pub/sub adapter.

Redis is already named in the stack (AGENTS.md §4) and is the default Laravel cache
and queue backend. Using one service for all five capabilities keeps the operational
surface small and matches the modular-monolith constraint.

**Redis is never authoritative business storage.** All business state lives in
PostgreSQL. Redis data is ephemeral or reconstructable: caches can be rebuilt, queues
are processed and completed, locks expire, rate-limit counters reset, and Reverb
adapter state is transport-only. Losing Redis does not lose business state — it
degrades performance and async throughput until Redis is restored.

## Consequences

**Positive**

- **One service, five capabilities.** Cache, queues, locks, rate limiting, and the
  Reverb adapter are all served by a single well-understood service. This minimises
  operational surface and matches the modular-monolith philosophy.
- **First-class Laravel integration.** Redis is Laravel's default cache and queue
  backend; Horizon and Reverb are built around it. No custom integration glue.
- **Performance.** In-memory operations for cache, locks, and rate-limit counters are
  fast and keep latency off the request path.
- **Reverb fan-out.** The Redis pub/sub adapter lets Reverb scale horizontally when
  needed, reusing the same Redis instance already required for queues.
- **Reconstructable.** Because Redis holds no authoritative state, disaster recovery
  for Redis is "restart and rebuild" — no point-in-time recovery needed for business
  correctness.

**Negative**

- **Single point of degradation.** If Redis is unavailable, caching, queues, locks,
  rate limiting, and Reverb fan-out degrade simultaneously. We mitigate by running
  Redis reliably (Docker volume, monitoring) and by ensuring the application fails
  safely (e.g. cache miss falls through to the database; queue jobs are retried).
- **Operational responsibility.** We must run Redis reliably: persistence
  configuration, memory monitoring, eviction policy. This is standard and
  well-understood.
- **Temptation to misuse.** Because Redis is convenient, there is a temptation to
  store business state in it. AGENTS.md §7 forbids this; code review must enforce it.

## Alternatives considered

### Memcached

Mature, simple in-memory key/value cache.

- **Strengths:** very fast; simple; well-supported by Laravel as a cache backend.
- **Rejected because** it is a cache only. It does not support queues, pub/sub, or
  persistent data structures, so it cannot serve as the queue backend or the Reverb
  adapter. Choosing Memcached for cache would require a *second* service (e.g. Redis
  or a database-backed queue) for queues and the Reverb adapter, increasing the
  operational surface for no benefit. Redis covers everything Memcached covers plus
  the other four capabilities. Introducing a second infrastructure service without a
  concrete requirement conflicts with the modular-monolith, minimal-surface approach
  (§5: do not introduce infrastructure without a concrete requirement).

### In-memory / application-process storage

Store caches and locks in the PHP process or opcache; use the database for queues.

- **Strengths:** zero additional services.
- **Rejected because** it does not work across multiple workers/processes (cache and
  locks would be per-process, not shared), it cannot serve as the Reverb pub/sub
  adapter (which needs cross-process fan-out), and database-backed queues are
  significantly slower and more contention-prone than Redis for the job throughput
  the platform needs. The application runs multiple PHP-FPM workers plus a queue
  worker plus a scheduler plus Reverb — shared infrastructure state must be
  cross-process, which requires an external service. In-process storage is a
  non-starter for a multi-process deployment.
