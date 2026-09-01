# Backend Realtime — ЧтоХочу

> **Status:** Authoritative backend realtime configuration document. See also
> [`realtime-events.md`](./realtime-events.md) for the event envelope contract and
> [`ADR-006-realtime-reverb.md`](../adr/ADR-006-realtime-reverb.md) for the decision
> record.

## 1. Overview

Realtime is delivered over **Laravel Reverb**, a first-party Laravel WebSocket server.
Reverb integrates with Laravel's broadcasting and channel authorization so that
realtime shares the same auth rules as REST. PostgreSQL remains the source of truth;
realtime is transport only.

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
Reverb (WebSocket)
 ↓
Client
 ↓
Repository / reconciliation
 ↓
Local store
 ↓
UI
```

## 2. Reverb Configuration

Reverb is configured in `config/reverb.php` and driven by environment variables:

```env
REVERB_HOST=127.0.0.1
REVERB_PORT=8080
REVERB_SCHEME=https
REVERB_APP_ID=chtohochu
REVERB_APP_KEY=<public-key>
REVERB_APP_SECRET=<secret>
```

In the Docker stack, Reverb runs in its own container and is routed via Traefik at
`wss://ws.chtohochu.test` (see [`local-routing.md`](../10-development/local-routing.md)).

The Redis pub/sub adapter is used so multiple Reverb instances (or queue workers
dispatching broadcasts) fan out consistently. Redis is already in the stack for queues
and cache.

## 3. Broadcasting Events

Events implement `ShouldBroadcast` (or `ShouldBroadcastNow` for non-queued delivery).
Broadcasts are dispatched **after the PostgreSQL transaction commits** — never before.

```php
class ShoppingListItemUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $entityId,
        public int $revision,
        public ?string $actorId,
        public array $payload,
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel("shopping-list.{$this->listId}"),
        ];
    }

    public function broadcastWith(): array
    {
        return [
            'event_id'        => $this->eventId,
            'event_type'      => 'shopping_list.item.updated',
            'entity_type'     => 'shopping_list_item',
            'entity_id'       => $this->entityId,
            'revision'        => $this->revision,
            'actor_id'        => $this->actorId,
            'server_timestamp'=> now()->toIso8601String(),
            'payload'         => $this->payload,
        ];
    }
}
```

The event envelope is defined in [`realtime-events.md`](./realtime-events.md) and MUST
include: `event_id`, `event_type`, `entity_type`, `entity_id`, `revision`,
`actor_id`, `server_timestamp`, `payload`.

## 4. Channel Types

| Channel type | Syntax | Authorization |
|--------------|--------|---------------|
| **Public** | `Channel('public')` | None |
| **Private** | `PrivateChannel('user.{id}')` | Laravel auth + policy |
| **Presence** | `PresenceChannel('shopping-list.{id}')` | Laravel auth + policy + presence metadata |

### 4.1 Private channels

Used for user-scoped events (notifications, personal updates). Authorization is
performed in `routes/channels.php`:

```php
Broadcast::channel('user.{id}', fn ($user, $id) => (int) $user->id === (int) $id);
```

### 4.2 Presence channels

Used for collaborative domains (shared shopping lists) where participants need to know
who else is connected. Authorization reuses the same policy that governs REST access:

```php
Broadcast::channel('shopping-list.{listId}', function ($user, $listId) {
    $list = ShoppingList::find($listId);
    if (!$list || !$user->can('view', $list)) {
        return false;
    }
    return [
        'id' => $user->id,
        'name' => $user->name,
    ];
});
```

## 5. Event Flow

1. A client mutates state via REST (`POST`, `PATCH`, `DELETE`).
2. The backend validates, authorizes, and performs the change inside a PostgreSQL
   transaction.
3. On `COMMIT`, the Application layer dispatches the broadcast event.
4. Laravel's broadcaster sends the event to Reverb (via the Redis adapter).
5. Reverb fans the event out to all authorised subscribers on the channel.
6. Clients reconcile the event against their local store and refetch from the API if
   needed.

### 5.1 Domain Event → Broadcast → Reverb → Client

```text
Domain operation (Application layer)
 ↓
PostgreSQL COMMIT
 ↓
event(new ShoppingListItemUpdated(...))   // ShouldBroadcast
 ↓
Laravel broadcaster → Redis adapter
 ↓
Reverb WebSocket server
 ↓
Authorised clients on the channel
 ↓
Client reconciliation (Drift / web store)
```

Domain logic MUST NOT depend on the WebSocket transport. Broadcasting is an
infrastructure concern triggered from the Application layer after commit.

## 6. Channel Authorization

Channel authorization reuses Laravel's auth and policies — the same rules that govern
REST endpoints. This avoids duplicating authorization between REST and realtime
(AGENTS.md §11).

- Authorization is always server-enforced.
- Client-supplied ownership/permission data MUST NOT be trusted.
- A new WebSocket channel requires server-side authorization in `channels.php`.

## 7. Client Resilience

Clients MUST survive (AGENTS.md §11):

- Lost events.
- Duplicated events (deduplicate by `event_id`).
- Delayed events.
- Out-of-order events (use `revision` to discard stale events).
- Reconnects (refetch and reconcile on reconnect).

Unknown event types MUST NOT crash clients. Duplicate events MUST be safe.

## 8. Non-Goals

- Reverb holds no authoritative business state.
- Domain logic does not depend on WebSocket transport.
- No second realtime runtime (Socket.io, Centrifugo) without an approved ADR.
- No client-to-client messaging; all events originate from the backend after commit.
