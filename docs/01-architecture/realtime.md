# Realtime Architecture

## 1. Purpose

This document defines the realtime architecture for ЧтоХочу: how server-side state changes are delivered to connected clients in near-realtime, how connections are managed, and how clients remain correct under unreliable network conditions.

Realtime is a **transport mechanism**. It is never the source of truth.

> **PostgreSQL is the source of truth. Realtime is transport only.**

A client that receives no realtime events at all must still be able to reach a correct state by reading the REST API. A client that receives duplicate, lost, delayed, or out-of-order events must still converge to the correct state.

---

## 2. Technology

| Component | Technology | Role |
|-----------|-----------|------|
| WebSocket server | Laravel Reverb | Pub/sub fan-out to connected clients |
| Event bus | Laravel Broadcasting | Bridges domain events to Reverb channels |
| Auth | Laravel Sanctum | Authenticates private/presence channel subscriptions |
| Client transport | Flutter WebSocket client | Subscribes to channels, receives events |
| Source of truth | PostgreSQL | Authoritative business state |

Reverb runs as a first-party Laravel service. It is not a separate application runtime. It shares the Laravel auth and authorization context.

Redis is used as Reverb's internal pub/sub backbone. Redis MUST NOT hold authoritative business state.

---

## 3. Event Flow

The canonical flow from a mutation to a delivered realtime event:

```text
Client mutation (REST)
        ↓
Laravel controller / Application operation
        ↓
PostgreSQL transaction
        ↓
COMMIT
        ↓
Domain Event dispatched
        ↓
Broadcast (ShouldBroadcast)
        ↓
Reverb fan-out to channel subscribers
        ↓
Flutter WebSocket client
        ↓
Realtime handler → Repository reconciliation
        ↓
Drift (local DB)
        ↓
provider / UI
```

### Critical ordering rules

1. **The broadcast happens AFTER commit.** An event MUST NOT be sent for uncommitted state. Laravel's `ShouldBroadcast` events dispatched after a committed transaction satisfy this; events dispatched inside a transaction that later rolls back MUST NOT reach clients.
2. **The REST mutation response and the realtime event are independent.** The client that performed the mutation receives the REST response. Other clients (and potentially the same client on another connection) receive the realtime event. The client MUST NOT assume the realtime event will arrive for its own mutation.
3. **The realtime handler MUST NOT become a second business-state manager.** It reconciles local state toward the server state; it does not compute business outcomes.

---

## 4. Channels

### 4.1 Channel types

| Type | Prefix | Auth | Use |
|------|--------|------|-----|
| Private | `private-` | Sanctum-authenticated user | Per-user, per-entity updates |
| Presence | `presence-` | Sanctum + membership verified | Collaborative lists, who-is-online |

Public channels (`public-`) are NOT used for application data. All application events go through private or presence channels so that authorization is always enforced.

### 4.2 Channel naming conventions

Channels are named by entity scope, not by feature module. See `docs/20-backend/realtime-events.md` for the full convention.

```text
private-user.{userId}                 # personal notifications, friend events
private-wishlist.{wishlistId}         # wishlist + wish changes
private-shopping-list.{listId}        # collaborative shopping list
presence-shopping-list.{listId}       # collaborative list + presence
private-friends.{userId}              # friendship events for this user
```

### 4.3 Authorization

Channel authorization is enforced server-side by Laravel's broadcast authorization callbacks (`routes/channels.php`). The backend verifies:

- **Authentication**: the connection holds a valid Sanctum token.
- **Ownership / membership**: the user is allowed to see the entity behind the channel name.

Client-supplied user IDs or membership claims are ignored. The backend resolves the authenticated user from the WebSocket handshake / auth ticket.

Authorization is re-evaluated on subscription and on every event delivery path that touches the entity. If a user is removed from a shopping list, subsequent events for that list MUST NOT be delivered to them; Reverb disconnects or the client is instructed to unsubscribe.

---

## 5. Connection Lifecycle

### 5.1 Connect

```text
App startup / login
        ↓
Resolve auth token (secure storage)
        ↓
Open WebSocket to Reverb endpoint
        ↓
Send subscription requests (private-/presence- channels)
        ↓
Server authorizes each subscription
        ↓
Subscribed → ready to receive events
```

### 5.2 Disconnect

Disconnects may be:

- **intentional** (logout, app backgrounded with cleanup);
- **network-driven** (connection lost, server restart, sleep);
- **server-driven** (auth revoked, version mismatch, idle timeout).

On disconnect the client enters a `disconnected` state. The UI continues to function against local (Drift) state. No data is lost by a disconnect alone.

### 5.3 Reconnect

The client uses exponential backoff with jitter, capped at a maximum delay. Reconnect attempts continue until either:

- the connection is re-established; or
- the user explicitly logs out / kills the session.

On a successful reconnect the client MUST run **reconnect reconciliation** (§8) before resuming normal event handling. Re-subscribing without reconciliation can leave gaps.

```text
WebSocket reconnected
        ↓
Re-subscribe to channels
        ↓
Run reconnect reconciliation (fetch missed state via REST)
        ↓
Resume event handling
```

---

## 6. Authentication

### 6.1 Handshake

The WebSocket connection authenticates using the Sanctum token. Reverb validates the token via Laravel's auth system. An invalid or expired token results in a connection rejection; the client treats this as an auth failure and triggers a token refresh or logout flow.

### 6.2 Private channels

Subscription to a `private-` channel requires a signed auth ticket. The Flutter client requests the ticket from `POST {api}/api/v1/broadcasting/auth` using the Sanctum Bearer token, then presents it to Reverb on subscribe.

### 6.3 Presence channels

`presence-` channels additionally carry user identity (id, display name, avatar URL). Presence is used for collaborative shopping lists to show who is currently viewing/editing. Presence data is ephemeral — it is not business state and MUST NOT be persisted as such.

A user leaving a presence channel (disconnect, background, logout) is a transport event, not a business event. Do not model "user went offline" as domain state.

---

## 7. Event Ordering, Duplicates, Missed Events

A correct client must survive:

- **lost events** (network drop between commit and delivery);
- **duplicated events** (reconnect re-delivery, at-least-once transport);
- **delayed events** (slow network, backpressure);
- **out-of-order events** (fan-out race, multiple channels).

### 7.1 Ordering

Events are NOT guaranteed to be delivered in commit order across channels or even within a single channel under all failure modes. The client uses the `revision` field to decide whether an event is stale:

- If `event.revision <= localRevision` for the same entity, the event is stale → discard (or use for idempotent confirmation only).
- If `event.revision > localRevision`, apply the event and advance local revision.

Events for different entities are independent; there is no global ordering guarantee the client should rely on.

### 7.2 Duplicate handling

Every event carries a unique `event_id`. The client tracks recently seen `event_id`s (a bounded LRU, e.g. last 256 per channel, or a time-windowed set). A duplicate `event_id` is discarded.

Duplicate handling is also reinforced by revision checks: a duplicate event will have a revision the client has already seen.

### 7.3 Missed events

Because delivery is at-least-once at best and at-most-once under failure, the client MUST NOT rely on receiving every event. The mechanism that closes gaps is **reconnect reconciliation** (§8) plus periodic/triggered refetch. Realtime is an optimization on top of REST, not a replacement for it.

---

## 8. Synchronization After Reconnect

Reconnect reconciliation is the process of bringing local state back in line with the server after a connection gap. It runs on every successful reconnect.

### 8.1 Strategy

```text
Reconnect established
        ↓
For each active entity scope:
   GET /api/v1/<entity>?since=<lastKnownRevision>
        ↓
Server returns changes newer than lastKnownRevision
        ↓
Client applies changes to Drift (revision-aware upsert)
        ↓
Advance local high-water mark
        ↓
Resume realtime event handling
```

The `since` cursor is the highest revision the client has seen for that entity scope. If the server cannot serve a delta from that revision (e.g. it is too old, or the server does not retain the history), the client falls back to a full refetch for that scope.

### 8.2 What reconciliation is NOT

- It is NOT a sync engine. It does not push local mutations; that is the sync queue (see `docs/30-client/offline-first.md`).
- It is NOT a replacement for the sync queue. Reconnect reconciliation reads server state; the sync queue writes pending local mutations.
- It is NOT a second source of truth. The result of reconciliation is that Drift matches PostgreSQL for the scopes fetched.

### 8.3 Interaction with pending mutations

If the client has pending outgoing mutations in the sync queue, reconciliation may fetch server state that does not yet reflect those mutations. This is expected. The reconciliation applies server state; when the pending mutations later ACK, they advance state further. Conflict detection (revision-based) handles the case where the server state has moved past the mutation's `base_revision`.

---

## 9. Client Responsibilities

The Flutter realtime client (in `core/realtime/`) is responsible for:

1. Managing the WebSocket connection and reconnect backoff.
2. Subscribing to and unsubscribing from channels based on the active route / feature scope.
3. Authenticating channel subscriptions via the backend.
4. Receiving events, deduplicating by `event_id`, and filtering by `revision`.
5. Forwarding valid events to the relevant repositories for reconciliation.
6. Exposing connection status (connected / reconnecting / disconnected) to the UI.

The realtime client MUST NOT:

- hold business state;
- compute business outcomes;
- bypass repositories to write directly to Drift tables outside the reconciliation path;
- block the UI thread on event handling.

### Event hand-off

```text
WebSocket event received
        ↓
Parse envelope (event_id, event_type, entity_type, entity_id, revision, ...)
        ↓
Deduplicate (event_id seen? → drop)
        ↓
Route by entity_type → repository.applyRealtimeEvent(event)
        ↓
Repository reconciles into Drift (revision-aware)
        ↓
Drift stream emits → provider → UI
```

Repositories expose a single `applyRealtimeEvent` entry point. The realtime client does not know the internals of each repository.

---

## 10. Server Responsibilities

The backend is responsible for:

1. Dispatching broadcast events only after a committed transaction.
2. Filling the full event envelope (see `docs/20-backend/realtime-events.md`).
3. Enforcing channel authorization on subscribe and on every delivery path.
4. Supporting delta reads (`?since=<revision>`) for reconnect reconciliation.
5. Ensuring events are idempotent to re-deliver (clients deduplicate, but the server should not fabricate distinct `event_id`s for the same logical change).
6. Not relying on the client being connected. A disconnected client is normal; the server does not buffer events indefinitely for offline clients.

---

## 11. Failure Modes and Guarantees

| Failure | Behavior | Guarantee |
|---------|----------|-----------|
| WebSocket drops mid-event | Event may be lost | Reconnect reconciliation refetches; no data loss |
| Event delivered twice | Client dedupes by `event_id` + revision | No double application |
| Event arrives out of order | Revision check discards stale | Local state monotonic in revision |
| Auth token expires | Connection rejected; client refreshes or logs out | No unauthorized access |
| Server restarts | Clients reconnect + reconcile | No data loss |
| Client offline for long time | `since` cursor too old → full refetch | Correctness preserved |
| Reverb unavailable | REST still works; realtime degraded | App remains functional |

---

## 12. What Realtime Is Not

- Not a queue. It does not guarantee delivery.
- Not a sync mechanism. It does not push local mutations.
- Not the source of truth. PostgreSQL is.
- Not a replacement for REST reads. Reconnect reconciliation and initial loads use REST.
- Not a presence-of-truth signal. Presence channels show who is connected, not who is allowed or who owns what.

---

## 13. Testing Requirements

Realtime behavior MUST be tested for:

- duplicate event handling (same `event_id` delivered twice);
- out-of-order event handling (older revision after newer);
- reconnect reconciliation (gap between revisions closed);
- authorization (user removed from list stops receiving events);
- lost event (no crash, state converges on next refetch);
- unknown event type (client ignores without crashing).

See `docs/10-development/testing.md`.
