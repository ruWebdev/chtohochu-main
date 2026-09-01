# Database Architecture

> **Authority:** This document defines the database architecture for ЧтоХочу. It is
> normative for the backend and for any component that reads or writes durable state. See
> [`conventions.md`](./conventions.md) for naming and schema conventions.

## 1. Sources of Truth

ЧтоХочу has three persistence tiers, each with a clearly defined role. There is exactly one
authoritative source per class of data.

| Tier | Technology | Role | Authority |
|------|------------|------|-----------|
| Backend primary store | PostgreSQL | All shared business state | **Authoritative** for the system |
| Backend cache / queue / lock / realtime | Redis | Ephemeral, derived, and infrastructure state | Never authoritative |
| Mobile local store | Drift (SQLite) | Offline-capable mobile data | Authoritative **on device** for offline-capable domains, reconciled to PostgreSQL |

### 1.1 PostgreSQL is authoritative

PostgreSQL is the single source of truth for all shared business state: users, profiles,
wishes, wishlists, friends, shopping lists, items, participants, permissions, notifications
metadata. If PostgreSQL and any other store disagree, PostgreSQL wins. Every other store is
rebuildable from PostgreSQL.

This is mandated by AGENTS.md §5 ("PostgreSQL is the backend source of truth") and §18.

### 1.2 Redis is never authoritative

Redis holds:

- **Cache** — derived views of PostgreSQL data, with a TTL and an invalidation strategy.
- **Queues** — Laravel Queue job payloads (transient).
- **Locks** — short-lived coordination locks (e.g. to serialize a sync mutation per
  entity).
- **Reverb infrastructure** — WebSocket subscription/presence state.
- **Ephemeral state** — rate-limit counters, throttle buckets, idempotency key replay
  cache.

Redis MUST NOT hold business state that cannot be reconstructed from PostgreSQL. If a Redis
key is lost, the system must continue to function correctly (possibly slower). Caching
requires an explicit TTL, invalidation strategy, consistency expectation, and fallback
(AGENTS.md §20).

### 1.3 Drift is the mobile local source of truth

For offline-capable domains (wishlists, wishes, shared shopping lists, items, friends where
appropriate), Drift is the local source of truth **on the device**. The UI reads from
Drift; the network syncs Drift to PostgreSQL. This prevents competing "online" and
"offline" UI states (AGENTS.md §26). Drift is never authoritative beyond the device; on
reconciliation, PostgreSQL wins.

## 2. PostgreSQL

### 2.1 Role

PostgreSQL stores:

- **Identity**: `users`, `personal_access_tokens`, `password_reset_tokens`, `sessions`.
- **Authorization**: Spatie `roles`, `permissions`, `model_has_roles`,
  `model_has_permissions`, `role_has_permissions`.
- **Social graph**: friends, friendships, invitations.
- **Wishlist domain**: wishlists, wishes, wish media.
- **Shopping domain**: shopping lists, items, participants, memberships.
- **Notifications**: notification records (the transport is async; the record is durable).
- **Audit**: role assignments, moderation actions, suspensions.
- **Sync metadata**: server-side revision counters, conflict resolution records.

### 2.2 Integrity enforcement

PostgreSQL enforces invariants that the application cannot enforce alone (AGENTS.md §18):

- **Foreign keys** on every relationship. `ON DELETE` is explicit per relationship
  (`CASCADE`, `SET NULL`, `RESTRICT` — chosen deliberately, never defaulted).
- **Unique constraints** for natural keys (email, username, `vk_id`, `yandex_id`,
  membership pairs).
- **Check constraints** for enum-like columns where a DB enum is not appropriate, and for
  range/invariant checks (e.g. `revision >= 0`, `quantity > 0`).
- **Indexes** on every foreign key, every column used in a filter/sort, and every unique
  constraint. Composite indexes for common multi-column query patterns.
- **Exclusion constraints** where overlapping ranges must be prevented (rare; used only
  when a concrete requirement exists).

If PostgreSQL can safely enforce an invariant, prefer enforcing it there rather than in
application code. Application-level checks are a complement, not a substitute.

### 2.3 Isolation and durability

- Default transaction isolation is **Read Committed**. Operations that require stronger
  guarantees (e.g. collaborative revision bumping) use **Repeatable Read** or
  `SELECT ... FOR UPDATE` explicitly.
- `synchronous_commit` is on (default). Durability is not traded for latency without an
  explicit ADR.
- Write-ahead logging (WAL) and point-in-time recovery are configured in infrastructure.

## 3. Redis

### 3.1 Usage map

| Use | Key pattern | TTL | Invalidation | Fallback |
|-----|-------------|-----|--------------|----------|
| Application cache | `cht:{domain}:{id}` | per data type | Event-driven (tagged) + TTL | Re-fetch from PostgreSQL |
| Queue | Laravel Queue internals | transient | n/a | Jobs are idempotent and retryable |
| Lock | `lock:{resource}:{id}` | short, with auto-release | Release on completion | Lock contention → wait or `409` |
| Reverb | Reverb-managed | Reverb-managed | Reverb-managed | Reconnect; state rebuilt from PostgreSQL |
| Rate limit | Laravel throttle buckets | sliding window | n/a | Reject (`429`) |
| Idempotency replay | `idem:{key}` | 24h | TTL | Re-execute the operation |

### 3.2 Cache rules

- Every cache entry has a TTL. No entry is cached forever.
- Every cache entry has an invalidation strategy: event-driven (invalidate on write) or
  TTL-only (acceptable for slowly-changing derived data).
- Every cache entry has a consistency expectation: "eventually consistent within TTL" or
  "strong via invalidation". The expectation is documented per cache key family.
- Every cache use has a fallback: on Redis miss or error, the request is served from
  PostgreSQL. Redis unavailability must not cause user-visible failure.

### 3.3 Locks

Distributed locks (Redis) are used to serialize operations that must not run concurrently
on the same entity, e.g. a sync mutation that reads-then-writes a revision. Locks are
short-lived, auto-releasing, and acquired with a unique token to prevent accidental release
by a non-owner. A lock is an optimization to reduce conflicts; correctness is still
guaranteed by PostgreSQL constraints and revision checks, not by the lock alone.

## 4. Drift (Mobile)

### 4.1 Role

Drift is a SQLite-backed relational store on the mobile device. It holds:

- Offline-capable domain entities (wishlists, wishes, shopping lists, items, friends).
- Pending sync operations (`sync_operations` table) with `operation_id`, `entity_type`,
  `entity_id`, `mutation_type`, `payload`, `status`, `attempt_count`, `last_error`,
  `base_revision`, `created_at`.
- Local-only presentation state that must survive app restart (e.g. draft inputs) — kept
  minimal and clearly separated from domain state.

### 4.2 Boundaries

- UI accesses Drift through local data sources and repositories, never directly
  (AGENTS.md §25).
- Generated Drift code is never edited manually.
- Drift schema changes are managed by Drift migrations, separate from Laravel migrations.

### 4.3 Reconciliation

Drift is reconciled to PostgreSQL via the sync protocol (AGENTS.md §27). On reconciliation,
PostgreSQL is authoritative. Conflicts are resolved per the entity's conflict policy
(AGENTS.md §30); "last write wins" is not the default.

## 5. Schema Management

### 5.1 Migrations are mandatory

Every schema change requires a migration (AGENTS.md §18). No `ALTER TABLE` is ever run
manually against any environment, including local development. The migration is the record
of the change and must be reversible.

### 5.2 Laravel migrations

Backend schema is managed by Laravel migrations in `backend/api/database/migrations/`:

- Migration filenames are timestamped (`YYYY_MM_DD_HHMMSS_description.php`).
- Every migration defines `up()` and `down()`. `down()` must restore the previous schema
  state. Irreversible migrations (e.g. data-destructive column drops) must throw in
  `down()` and document why.
- Migrations are run in timestamp order. The team avoids editing a released migration;
  fixes are new migrations.
- Migrations are tested: a migration's `up()` then `down()` then `up()` must leave the
  schema in a valid state.

### 5.3 Drift migrations

Mobile schema is managed by Drift's migration system in
`mobile/lib/core/database/migrations/`. Drift schema changes are versioned independently of
Laravel migrations because the mobile client ships on its own schedule and must tolerate
older server schemas.

### 5.4 Zero-downtime migrations

Schema changes to tables with non-trivial size, or to columns in active use, must be
deployed in a zero-downtime sequence:

1. Add the new column/enum value/index (additive migration).
2. Deploy code that writes to the new column/enum value but still reads from the old.
3. Backfill existing rows (queued, batched).
4. Deploy code that reads from the new column/enum value.
5. (Later, in a separate release) drop the old column/index in a new migration, after
   confirming no code path references it.

Destructive changes (drop column, rename column, change type) are never bundled with the
additive change that introduces the replacement. They are a separate, later migration.

## 6. Transaction Requirements

### 6.1 Atomic multi-record mutations

Any logically atomic multi-record mutation MUST define a transaction boundary
(AGENTS.md §19). Partial domain state MUST NOT be left behind after a failed atomic
operation.

Example — creating a shared shopping list:

```
BEGIN
 ├── insert shopping_list
 ├── insert owner membership
 ├── insert initial permissions
 ├── insert activity record
 └── broadcast event (after COMMIT)
COMMIT
```

The broadcast happens **after** COMMIT, never inside the transaction. Realtime is a
delivery mechanism, not part of the transaction (AGENTS.md §21, §22).

### 6.2 Transaction boundaries

Transactions are defined at the application-operation layer (`App\Actions\...`,
`App\Application\...`), not in controllers. Controllers orchestrate; they do not own
transactions (AGENTS.md §16).

### 6.3 Nested transactions

Laravel's `DB::transaction` nested calls savepoint. Inner "transactions" are savepoints;
the outer commit is the real commit. This is used when an operation composes sub-operations
that may independently fail and roll back without aborting the whole.

### 6.4 Idempotency inside transactions

Retryable mutations are idempotent at the operation level (AGENTS.md §29). Within a
transaction, unique constraints and revision checks provide the idempotency guarantee: a
replayed operation either matches the existing result (no-op) or is rejected as a conflict.
The transaction ensures the operation and its idempotency record are committed together.

### 6.5 Isolation for collaborative edits

Collaborative entities (shared shopping lists, wishlists with participants) use
revision-based optimistic concurrency. The mutation:

1. Reads the current `revision` (within the transaction, with `FOR UPDATE` or under
   Repeatable Read).
2. Applies the change, bumps `revision`.
3. Commits. If another writer committed first, the `revision` check fails and the
   transaction is retried or returns `409 revision_conflict`.

See AGENTS.md §30 and [`../05-realtime/`](../05-realtime/) for the conflict policy per
entity.

## 7. Backups and Recovery

- PostgreSQL is backed up on a schedule (WAL archiving + base backups) supporting
  point-in-time recovery. The recovery objective and retention are defined in
  infrastructure configuration.
- Redis is **not** backed up. It is rebuildable from PostgreSQL. A Redis flush is a
  performance event, not a data-loss event.
- Drift data is **not** backed up server-side. It is device-local and reconciled to
  PostgreSQL. A device lost without sync loses only pending (un-acked) mutations, which the
  sync protocol is designed to minimize.

## 8. Data Integrity Across Tiers

| Concern | Mechanism |
|---------|-----------|
| Cross-tier consistency | PostgreSQL authoritative; Redis/Drift derived and reconciled |
| Lost writes (mobile) | Sync protocol with `operation_id` retry and server ACK |
| Duplicate writes (mobile) | Idempotency via `operation_id` + unique constraints |
| Out-of-order events | Revision counters; client reconciles to highest revision |
| Conflict | Per-entity policy; server decides; client reconciles |
| Cache staleness | TTL + event-driven invalidation; fallback to PostgreSQL |
| Lock failure | Correctness via DB constraints; lock is optimization |

## 9. Non-Goals

- No multi-master / write-anywhere PostgreSQL. PostgreSQL is single primary (with
  read replicas for read scaling, but writes go to the primary).
- No Redis as authoritative business store.
- No Firebase/Firestore as primary database (AGENTS.md §4).
- No Elasticsearch / search engine as a source of truth (search indexes are derived and
  rebuildable).
- No schema changes outside migrations.
- No application-level enforcement of invariants that PostgreSQL can enforce.
