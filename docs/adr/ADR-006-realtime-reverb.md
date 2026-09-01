# ADR-006: Laravel Reverb as realtime transport

## Status

Accepted

## Context

ЧтоХочу has genuine realtime, collaborative requirements (AGENTS.md §21):

- **Shared shopping lists** — two or more users editing the same list
  simultaneously, with live additions, edits, check/uncheck and deletions
  (§32). This is the reference collaborative domain.
- **Invitations** — a recipient should see an invitation appear without
  reloading.
- **Notifications** — in-app notifications should arrive live.
- **Presence** — where required, participants should know who else is viewing/
  editing a list.

The fundamental rule (§21) is that **PostgreSQL is the source of truth and
realtime is only a delivery mechanism**. A correct client must survive lost,
duplicate, delayed, out-of-order events and reconnects. The realtime channel
must never become a second business-state manager (§22).

The required event flow (§22) is:

```text
Client mutation
 ↓
Laravel
 ↓
PostgreSQL transaction
 ↓
COMMIT
 ↓
Broadcast event
 ↓
WebSocket server
 ↓
Client
 ↓
Repository / reconciliation
 ↓
Local DB
 ↓
UI
```

This means the WebSocket server must be tightly integrated with Laravel's
broadcasting and auth: events are broadcast by Laravel after commit, channels
are authorized through Laravel's auth (Sanctum), and the event envelope
(`event_id`, `entity_type`, `entity_id`, `revision`, `actor_id`,
`server_timestamp`, payload/refetch — §23) is produced by Laravel.

The backend is a modular monolith on a single runtime (§4): no second backend
runtime, no microservices, no Kafka. The realtime transport should fit this
constraint — ideally being part of the Laravel application rather than a
separate service with its own auth, deployment and operational story.

## Decision

Use **Laravel Reverb** as the WebSocket-based realtime transport.

Reverb is a first-party Laravel WebSocket server. It integrates with Laravel's
existing broadcasting, channel authorization and event system, so:

- **Channel authorization** goes through Laravel's normal auth middleware
  (Sanctum for mobile/web API tokens), reusing the same authorization rules as
  REST (§14).
- **Events are broadcast by Laravel** after the PostgreSQL transaction commits,
  using Laravel's `Broadcast::event()` / `ShouldBroadcast` contract, satisfying
  the §22 event flow.
- **The event envelope** (§23) is authored in Laravel and consumed unchanged by
  Flutter and the web clients.
- **Redis is used as the pub/sub adapter** so multiple Reverb/queue workers can
  fan out broadcasts consistently (Redis is already in the stack for queues and
  cache — §20).
- **Horizon** manages the queue workers that may dispatch broadcast jobs
  alongside notification and push jobs.

Reverb is the transport only. It holds no authoritative business state. Clients
reconcile realtime events against their local store (Drift on mobile, Pinia/API
cache on web) and refetch from the API when needed. Unknown event types must not
crash clients; duplicate events must be safe (§23).

## Consequences

**Positive**

- **First-party Laravel integration.** Reverb shares Laravel's auth, broadcasting
  and deployment story. There is no second runtime, no separate auth service,
  no separate event schema to maintain. This directly satisfies the
  no-second-runtime modular-monolith constraint (§4).
- **Correct event flow by construction.** Because broadcasts are dispatched by
  Laravel after commit (via queued or sync broadcast events), the §22 flow is
  the natural implementation, not a custom integration.
- **Reusable channel authorization.** Private/presence channel authorization
  uses the same Laravel policies/gates as REST endpoints, so authorization
  rules are not duplicated between REST and realtime (§14).
- **Redis-backed fan-out.** Reverb's Redis adapter lets us scale horizontally
  when needed without changing the application code, reusing the Redis instance
  already required for queues.
- **Operational simplicity.** One process model (Laravel + Reverb + Horizon),
  one monitoring story, one set of deployment artifacts.
- **Standard WebSocket protocol.** Reverb implements the standard WebSocket
  protocol compatible with Laravel Echo and any WebSocket client, so Flutter
  and the web apps can connect with standard tooling.

**Negative**

- **Reverb is newer than some alternatives.** It is less battle-tested than
  Pusher (the hosted service) or Socket.io. We mitigate by keeping the client
  resilient (§21): lost/duplicate/out-of-order events must not corrupt state,
  and the client can always refetch from the API. Realtime is a transport, not
  the source of truth.
- **Self-hosted operational responsibility.** Unlike Pusher, Reverb is
  self-hosted, so we are responsible for running and scaling the WebSocket
  server. This is acceptable within the Docker/Nginx infrastructure (§3) and
  preferable to depending on an external hosted service for a core transport.
- **Horizontal scaling at high connection counts** requires the Redis adapter
  and potentially multiple Reverb instances behind a load balancer with sticky
  sessions or the Redis pub/sub fan-out. This is a future operational concern,
  not an architectural blocker, and the path is clear.

## Alternatives considered

### Socket.io (Node.js)

A standalone Node.js Socket.io server, with Laravel broadcasting events to it
via a Redis adapter or HTTP webhook.

- **Rejected because** it introduces a second backend runtime (Node.js) to
  operate alongside Laravel, which conflicts with the modular-monolith,
  no-second-runtime constraint (§4). It also requires bridging Laravel's auth
  and event system to a separate Node process, duplicating channel
  authorization and event schema. The integration glue is exactly what Reverb
  eliminates by being first-party. Socket.io is a capable transport; the cost
  is the operational and integration overhead of a second runtime, which this
  product explicitly avoids.

### Pusher (hosted)

Use Pusher Channels as the hosted WebSocket transport, with Laravel's Pusher
  broadcast driver.

- **Strengths:** zero operational responsibility for the WebSocket server;
  mature; excellent Laravel integration (Laravel ships a Pusher driver).
- **Rejected because** it introduces a hard external dependency and per-
  connection/per-message cost for a core transport. For a collaborative app
  where realtime is central (not a nice-to-have), depending on a hosted
  service for a core capability and paying per connection/message at scale is
  unattractive. It also means the realtime transport is not self-contained in
  our infrastructure (§3 lists self-hosted PostgreSQL, Redis, S3). Pusher is a
  good choice for getting started fast or for non-core realtime; here Reverb
  gives the same Laravel integration with self-hosted control. If operational
  burden ever outweighs the cost, a switch to Pusher is possible later with
  minimal application code changes (Laravel broadcast driver swap), so this
  alternative remains a viable fallback.

### Soketi (open-source Pusher-compatible, Node.js)

Self-hosted Pusher-protocol WebSocket server written in Node.js, usable with
Laravel's Pusher driver.

- **Strengths:** self-hosted; Pusher-protocol compatible; good performance.
- **Rejected because** like Socket.io it is a Node.js process — a second
  runtime to operate (§4). It is also a community project (less active than
  Reverb's first-party Laravel backing) and effectively deprecated in favor of
  Reverb within the Laravel ecosystem. Choosing it would trade first-party
  integration for a second-runtime, community-maintained server. Not
  justified.

### Centrifugo

A standalone, self-hosted realtime server (Go) with its own protocol, JWT auth
and pub/sub backends, integrated with Laravel via API.

- **Strengths:** very high performance; feature-rich (presence, history,
  recovery); language-agnostic.
- **Rejected because** it is a separate service with its own auth model (JWT),
  its own protocol and its own operational profile. Integrating it with
  Laravel's broadcasting and channel authorization requires custom bridging,
  duplicating auth logic outside Laravel policies. It is a second runtime (Go)
  and a second auth boundary. Centrifugo is an excellent choice for
  high-throughput, cross-stack realtime platforms; its power and complexity are
  disproportionate for a Laravel modular monolith that already has a
  first-party WebSocket server (Reverb) integrated with its auth and
  broadcasting. The additional operational surface and integration glue are
  not justified by current requirements (§5: do not introduce infrastructure
  without a concrete requirement).
