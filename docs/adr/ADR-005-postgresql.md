# ADR-005: PostgreSQL as primary database

## Status

Accepted

## Context

ЧтоХочу is a server-authoritative application. The backend is the single source
of truth for all shared business state (AGENTS.md §5), and PostgreSQL is
explicitly named as the authoritative persistence layer (§18).

The data model is relational and integrity-critical:

- **Users** have **profiles**, **friends** (bidirectional relationships with
  status), **wishlists**, and participate in **shared shopping lists**.
- **Wishlists** contain **wishes**; wishes can be reserved/fulfilled by other
  users, creating cross-user relationships.
- **Shared shopping lists** have **participants** with **permissions**
  (owner/editor/viewer), and contain **items** that can be added, edited,
  checked/unchecked and deleted by multiple participants simultaneously.
- **Invitations** link a sender, a recipient and a target resource (list or
  friendship) with a lifecycle (pending/accepted/declined/expired).
- **Notifications** reference actors, targets and read state.
- **Sync operations** (§28) track `operation_id`, `entity_type`, `mutation_type`,
  `base_revision`, `attempt_count`, `status` — a structured, queryable queue of
  pending client mutations.

Many invariants are relational and must be enforced at the database level to be
trustworthy regardless of application bugs or concurrent clients:

- a participant cannot be added to a list twice (unique constraint);
- an owner membership must exist for every list (foreign key + not null);
- a wishlist's `visibility` must be one of the allowed values (check
  constraint);
- an invitation cannot reference a non-existent user (foreign key);
- revision numbers must be monotonic per entity for conflict detection (§30);
- atomic multi-record mutations (create list + owner membership + permissions +
  activity) must be all-or-nothing (§19).

The system also requires: transactions with appropriate isolation for
concurrent collaborative edits; indexes for fast list/participant/item queries;
check constraints for enum-like values; and migrations for every schema change
(§18). Performance needs are modest (no Kafka, no Elasticsearch, no
microservices — §4) but correctness needs are high.

## Decision

Use **PostgreSQL** as the primary and authoritative relational database for the
Laravel backend.

Enforce invariants in PostgreSQL wherever it can safely do so (AGENTS.md §18):

- **foreign keys** for every reference relationship;
- **unique constraints** for membership uniqueness, invitation uniqueness, etc.;
- **check constraints** for enum-like columns and domain rules;
- **indexes** on foreign keys, lookup columns and revision/entity_id pairs used
  by sync and realtime;
- **transactions** with appropriate isolation for every logically atomic
  multi-record mutation (§19);
- **migrations** for every schema change — no out-of-band schema modification.

PostgreSQL is the source of truth. Redis may hold caches, queues, locks and
Reverb infrastructure, but never authoritative business state (§20). Realtime
events are emitted only after the PostgreSQL transaction commits (§22).

## Consequences

**Positive**

- **Strong integrity guarantees.** Foreign keys, unique/check constraints and
  transactions enforce invariants at the database level, independent of
  application code. This is the cheapest, most reliable place to enforce them
  (§18).
- **Transactional correctness for collaborative edits.** PostgreSQL's MVCC and
  isolation levels give us the building blocks for the conflict-detection and
  revision-based reconciliation required by §30, without external
  infrastructure.
- **Rich types and features.** JSONB for flexible payloads (e.g. sync operation
  payloads, notification metadata), arrays, enums, generated columns, partial
  indexes, and row-level security if needed for multi-tenant admin scenarios.
- **Mature ecosystem.** Excellent tooling for backups, replication, point-in-
  time recovery, monitoring; first-class support in Laravel via Eloquent/Postgres
  driver; well-understood operational profile.
- **Single source of truth simplifies reasoning.** Every client — Flutter,
  web-public, web-seller, web-admin — reconciles against one authoritative
  store. Realtime is a delivery mechanism, not a datastore (§21).

**Negative**

- **Single vertical scaling point.** The modular monolith (§4) means one
  primary PostgreSQL instance. Horizontal scaling (read replicas, sharding) is
  available but not needed now and should not be introduced prematurely (§5:
  do not introduce infrastructure without a concrete requirement).
- **No schemaless flexibility.** Every change requires a migration. This is a
  feature, not a bug, for integrity-critical business state, but it means
  schema evolution is deliberate and versioned.
- **Operational responsibility.** We must run PostgreSQL reliably: backups,
  monitoring, connection pooling (PgBouncer) at scale. This is standard and
  well-understood.

## Alternatives considered

### MySQL

Mature, widely deployed, good Laravel support.

- **Rejected because** PostgreSQL's constraint system, JSONB, richer index
  types (partial, expression), generated columns and stricter SQL conformance
  are a better fit for the integrity-critical, revision-tracking,
  collaborative-edit data model. MySQL's historical permissiveness (silent
  truncation, non-strict mode, weaker check constraint support prior to recent
  versions) is a liability for a system that relies on database-level
  invariants. MySQL is a capable database; PostgreSQL is the better fit for
  this product's correctness requirements and is already the contracted choice
  in AGENTS.md §3 and §18.

### MongoDB

Document-oriented, schemaless, horizontally scalable.

- **Rejected because** the data model is fundamentally relational: users,
  friendships, wishlists, wishes, list participants, permissions, invitations
  and sync operations are all connected by reference relationships that need
  foreign-key integrity, unique constraints and transactions. MongoDB's
  schemaless documents are a poor fit for enforcing these invariants; it lacks
  multi-document transactions with the same integrity guarantees (historically
  and practically for this model), and denormalizing this data would create
  consistency problems exactly where the product needs correctness. MongoDB is
  good for schemaless, append-heavy, horizontally scaled content; ЧтоХочу's
  authoritative business state is the opposite of that. Also, AGENTS.md §4
  forbids introducing infrastructure without a concrete requirement, and no
  requirement justifies a second database engine.

### SQLite

Embedded, file-based, zero-configuration.

- **Rejected because** SQLite is excellent as an embedded/local database (and
  is in fact the spiritual model for Drift on mobile), but it is not
  appropriate as the server's authoritative database for a multi-user,
  concurrent, collaborative-edit application with realtime broadcasts and
  queued jobs. Its concurrency model (single writer) and lack of a network
  server make it unsuitable for a backend serving many simultaneous clients
  with collaborative writes. It is the right tool for the mobile local store
  (via Drift) and the wrong tool for the server source of truth.
