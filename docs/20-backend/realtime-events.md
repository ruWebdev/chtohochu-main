# Realtime Event Contract

## 1. Purpose

This document defines the wire contract for realtime events delivered over Laravel Reverb to connected clients. It specifies the event envelope, channel naming, event types for the initial product domains, and the rules for duplicate and unknown event handling.

This is a **contract**. The backend MUST emit events matching this shape, and the Flutter client MUST consume them per these rules. Changes to this contract are breaking changes and require compatibility analysis (see AGENTS.md §10).

---

## 2. Event Envelope

Every realtime event is delivered as a JSON envelope. All fields are required unless explicitly marked optional.

```json
{
  "event_id": "01HXY9KRZ8QJ7P3M4N2A1B0C6D",
  "event_type": "shopping_list.item.updated",
  "entity_type": "shopping_list_item",
  "entity_id": "f3c1a2e4-...",
  "revision": 42,
  "actor_id": "a1b2c3d4-...",
  "server_timestamp": "2025-09-01T12:34:56.789Z",
  "payload": { }
}
```

### 2.1 Field definitions

| Field | Type | Description |
|-------|------|-------------|
| `event_id` | string (ULID/UUID) | Globally unique identifier for this event. Used for deduplication. Stable across re-delivery. |
| `event_type` | string | Dotted, namespaced type: `<domain>.<entity>.<action>`. See §4. |
| `entity_type` | string | The kind of entity this event concerns. See §3. |
| `entity_id` | string | The ID of the entity. Stable server-assigned identifier. |
| `revision` | integer | Monotonically increasing per-entity revision. Used for ordering and staleness. |
| `actor_id` | string \| null | The user whose action caused the event. `null` for system-generated events. |
| `server_timestamp` | string (ISO 8601, UTC, ms) | When the server committed the change. Not a client clock. |
| `payload` | object \| string | Either the entity delta/snapshot, or a refetch instruction. See §2.2. |

### 2.2 Payload variants

A `payload` is one of:

1. **Snapshot** — the full current state of the entity after the change. The client replaces its local copy.
2. **Delta** — the changed fields only. The client merges them. Only used when the field set is unambiguous and the entity is not collaborative-sensitive.
3. **Refetch instruction** — a directive to refetch the entity via REST. Used for large payloads, complex derived state, or when the server cannot cheaply serialize the full snapshot.

```json
{ "refetch": "shopping_list_item", "id": "f3c1a2e4-..." }
```

The client treats a refetch instruction as a trigger to `GET /api/v1/<entity>/{id}` and reconcile. Refetch instructions MUST NOT be the only way to learn about a change; they are an optimization for payload size, and reconnect reconciliation (see `docs/05-realtime/architecture.md` §8) closes any gap if a refetch fails.

### 2.3 Field rules

- `event_id` MUST be unique per logical event. Re-delivery of the same event reuses the same `event_id`.
- `revision` is scoped to `(entity_type, entity_id)`. It is not global. Two different entities can have the same revision number.
- `revision` MUST increase with each change to that entity. The client uses it only to discard stale events and to advance a per-entity high-water mark.
- `server_timestamp` is for ordering/audit only. Clients MUST NOT use it as a revision substitute.
- `actor_id` is informational. The client MUST NOT use it for authorization. It may be used to suppress echo (see §5) and for UI hints ("edited by X").

---

## 3. Entity Types

Entity types are stable strings. They are the canonical names used in `entity_type` and in channel routing.

| `entity_type` | Description |
|---------------|-------------|
| `wishlist` | A wishlist container |
| `wish` | An item within a wishlist |
| `shopping_list` | A shared shopping list |
| `shopping_list_item` | An item within a shopping list |
| `friendship` | A friendship relation between two users |
| `friend_request` | An invitation to become friends |
| `notification` | An in-app notification |

New entity types are additive. Existing types MUST NOT be renamed. Clients MUST handle unknown `entity_type` values gracefully (log + drop, no crash).

---

## 4. Event Types

Event types follow the pattern `<domain>.<entity>.<action>`. Actions are lowercased verbs from the set: `created`, `updated`, `deleted`, plus domain-specific actions where needed (e.g. `checked`, `unchecked`, `accepted`, `declined`).

### 4.1 Wishes

| `event_type` | `entity_type` | Payload | Channel |
|--------------|---------------|---------|---------|
| `wish.created` | `wish` | snapshot | `private-wishlist.{wishlistId}` |
| `wish.updated` | `wish` | snapshot or delta | `private-wishlist.{wishlistId}` |
| `wish.deleted` | `wish` | `{ "deleted": true }` | `private-wishlist.{wishlistId}` |

### 4.2 Wishlists

| `event_type` | `entity_type` | Payload | Channel |
|--------------|---------------|---------|---------|
| `wishlist.created` | `wishlist` | snapshot | `private-user.{userId}` |
| `wishlist.updated` | `wishlist` | snapshot or delta | `private-wishlist.{wishlistId}` |
| `wishlist.deleted` | `wishlist` | `{ "deleted": true }` | `private-wishlist.{wishlistId}` |

### 4.3 Shopping Lists

Shopping lists are the reference collaborative domain. Events go to a presence channel so all participants receive them and see presence.

| `event_type` | `entity_type` | Payload | Channel |
|--------------|---------------|---------|---------|
| `shopping_list.created` | `shopping_list` | snapshot | `private-user.{userId}` |
| `shopping_list.updated` | `shopping_list` | snapshot or delta | `presence-shopping-list.{listId}` |
| `shopping_list.deleted` | `shopping_list` | `{ "deleted": true }` | `presence-shopping-list.{listId}` |
| `shopping_list.item.created` | `shopping_list_item` | snapshot | `presence-shopping-list.{listId}` |
| `shopping_list.item.updated` | `shopping_list_item` | snapshot or delta | `presence-shopping-list.{listId}` |
| `shopping_list.item.deleted` | `shopping_list_item` | `{ "deleted": true }` | `presence-shopping-list.{listId}` |
| `shopping_list.item.checked` | `shopping_list_item` | `{ "checked": true, "checked_by": "<userId>" }` | `presence-shopping-list.{listId}` |
| `shopping_list.item.unchecked` | `shopping_list_item` | `{ "checked": false }` | `presence-shopping-list.{listId}` |
| `shopping_list.participant.joined` | `shopping_list` | `{ "user_id": "...", "role": "..." }` | `presence-shopping-list.{listId}` |
| `shopping_list.participant.left` | `shopping_list` | `{ "user_id": "..." }` | `presence-shopping-list.{listId}` |

### 4.4 Friends

| `event_type` | `entity_type` | Payload | Channel |
|--------------|---------------|---------|---------|
| `friend.request.sent` | `friend_request` | snapshot | `private-friends.{targetUserId}` |
| `friend.request.accepted` | `friend_request` | snapshot | `private-friends.{senderUserId}` |
| `friend.request.declined` | `friend_request` | `{ "declined": true }` | `private-friends.{senderUserId}` |
| `friend.added` | `friendship` | snapshot | `private-friends.{userId}` |
| `friend.removed` | `friendship` | `{ "deleted": true }` | `private-friends.{userId}` |

### 4.5 Notifications

Notification events drive the in-app notification center and badges.

| `event_type` | `entity_type` | Payload | Channel |
|--------------|---------------|---------|---------|
| `notification.created` | `notification` | snapshot | `private-user.{userId}` |
| `notification.read` | `notification` | `{ "read_at": "..." }` | `private-user.{userId}` |
| `notification.deleted` | `notification` | `{ "deleted": true }` | `private-user.{userId}` |

A `notification.created` realtime event and an FCM push notification are independent delivery paths for the same logical notification. See `docs/06-notifications/architecture.md`. The realtime event is the in-app delivery; the push is the out-of-app nudge. Either may arrive without the other.

---

## 5. Channel Naming Conventions

Channels are named by entity scope. The convention is:

```text
private-<scope>.<id>
presence-<scope>.<id>
```

| Channel | Type | Subscribers |
|---------|------|-------------|
| `private-user.{userId}` | private | The user themselves |
| `private-wishlist.{wishlistId}` | private | Wishlist owner + viewers with access |
| `private-friends.{userId}` | private | The user themselves |
| `private-shopping-list.{listId}` | private | (fallback, used when presence not needed) |
| `presence-shopping-list.{listId}` | presence | All current participants |

Rules:

- Channel names are stable strings. Do not encode transient state into channel names.
- A user subscribes to `private-user.{ownId}` for the lifetime of their session.
- Feature-scoped channels (wishlist, shopping list) are subscribed on demand when the user navigates to the relevant screen, and unsubscribed on leave.
- Presence channels are subscribed when the user is actively viewing/editing the collaborative entity.

### Echo suppression

When `actor_id` equals the current user's ID, the event reflects the user's own mutation. The client MAY use this to skip redundant local application (the local state already reflects the change from the optimistic update). This is an optimization only — applying the event anyway MUST be safe (idempotent, revision-checked).

---

## 6. Duplicate Event Handling

Duplicates arise from: reconnect re-delivery, Reverb fan-out retries, or the same logical change being broadcast more than once under the same `event_id`.

Client handling:

1. Maintain a bounded dedupe set keyed by `event_id` (e.g. LRU of last N per channel, or a time-windowed set).
2. On receipt, if `event_id` is in the set → discard.
3. Otherwise, apply the event and record `event_id`.
4. As a second line of defense, check `revision`: if `event.revision <= localRevision(entity)`, the event is stale → discard.

Both checks are required. `event_id` dedupe catches exact re-delivery; revision check catches logically stale events (e.g. a delayed older event arriving after a newer one).

Applying a duplicate MUST NOT produce a second business effect. Event application is idempotent: upsert by `(entity_type, entity_id)` with revision guard.

---

## 7. Unknown Event Type Handling

The client will encounter unknown `event_type` or `entity_type` values when:

- the backend has been upgraded and the client has not;
- a new domain ships before the client supports it;
- a malformed/test event is received.

Handling:

1. Do NOT crash.
2. Do NOT discard the connection.
3. Log the unknown type at debug/warning level (with `event_id`, `event_type`, `entity_type`).
4. Drop the event.
5. Continue processing subsequent events normally.

Unknown events MUST NOT leave local state partially applied. If the client cannot route an event, it applies nothing.

```dart
final handler = registry[event.eventType];
if (handler == null) {
  log.warning('Unknown event_type: ${event.eventType} (id=${event.eventId})');
  return; // drop, continue
}
handler.apply(event);
```

This guarantees backward compatibility: an older client continues to function against a newer backend, simply ignoring events it does not understand. See AGENTS.md §10 (additive changes preferred).

---

## 8. Versioning and Compatibility

- The envelope shape is versioned implicitly by the API version (`/api/v1`). Breaking changes to the envelope require a new API version or a documented compatibility window.
- New `event_type` / `entity_type` values are additive and safe.
- Removing or renaming an existing `event_type` is a breaking change and requires compatibility analysis.
- New optional fields MAY be added to `payload`. The client MUST ignore unknown payload fields it does not understand.
- `event_id`, `event_type`, `entity_type`, `entity_id`, `revision` are the stable core. They MUST NOT be removed or renamed.

---

## 9. Example End-to-End

User A checks an item in a shared shopping list while User B is viewing the same list.

```text
User A taps "check"
        ↓
Flutter: optimistic local write (Drift) + sync queue entry
        ↓
REST: PATCH /api/v1/shopping-lists/{listId}/items/{itemId}  (Idempotency-Key: <operation_id>)
        ↓
Laravel: authorize A is participant, validate, transaction:
           - UPDATE shopping_list_items SET checked=true, revision=revision+1
           - COMMIT
        ↓
Broadcast: shopping_list.item.checked  (revision=42, actor_id=A)
        ↓
Reverb → presence-shopping-list.{listId}
        ↓
User B's client receives event
        ↓
Dedupe (new event_id) → revision 42 > local 41 → apply
        ↓
Drift upsert → provider → UI shows item checked by A
```

User A's own client receives the same event (it is subscribed to the presence channel). `actor_id === A`, so A's client MAY skip re-application (its optimistic update already set the state). If it applies anyway, the revision guard makes it a no-op.

---

## 10. Testing Requirements

The event contract MUST be tested for:

- envelope parsing (all required fields present);
- duplicate `event_id` is dropped;
- stale `revision` is dropped;
- unknown `event_type` does not crash and is dropped;
- unknown `entity_type` does not crash and is dropped;
- refetch instruction triggers a REST fetch and reconciliation;
- echo suppression (`actor_id === self`) is safe whether skipped or applied.

See `docs/10-development/testing.md`.
