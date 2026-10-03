# Flutter Offline-First Architecture

## 1. Purpose

This document defines the offline-first architecture for ЧтоХочу Flutter client. It covers the `operation_id` idempotency mechanism, the sync queue, local-first writes, background sync, conflict resolution, revision-based conflict detection, reconnect reconciliation, and retry strategy.

This implements AGENTS.md §8 (Drift for offline-capable persistence) and the synchronization protocol. The backend is authoritative; the client is offline-capable for domains where it provides product value.

> **PostgreSQL is the source of truth. Drift is the persisted local source of truth for offline-capable mobile data. The network synchronizes Drift toward PostgreSQL.**

---

## 2. Principles

1. **Local-first writes.** A mutation writes to Drift and enqueues a sync operation in one local transaction. The UI updates immediately. The network is not on the critical path of the UI.
2. **Idempotent mutations.** Every retryable mutation carries a stable `operation_id`. Replaying the same operation on the server MUST NOT create duplicate business effects.
3. **Revision-based conflict detection.** Each entity has a server-assigned `revision`. The client records the `base_revision` it acted on; the server detects when that base is stale.
4. **Server authority.** Conflicts are resolved per-entity by a defined policy, never by universal "last write wins."
5. **Survivability.** A mutation must survive temporary network failure, app restart, process termination, retry, and WebSocket disconnect.

---

## 3. operation_id — Idempotent Mutations

Every retryable local mutation receives a stable, client-generated `operation_id` (UUID). The same ID is reused for all retries of that operation.

### 3.1 Lifecycle

```text
User action
        ↓
Local DB transaction:
   ├── update entity (optimistic, sync_status = 'pending')
   └── insert sync_operation (operation_id, status = 'pending')
        ↓
UI updates immediately (Drift stream emits)
        ↓
Sync worker picks up pending operation
        ↓
API mutation with header: Idempotency-Key: <operation_id>
        ↓
Server transaction
        ↓
ACK (200/201)  OR  CONFLICT (409)
        ↓
Local reconciliation:
   ├── update entity (revision, sync_status = 'synced' | 'conflict')
   └── update sync_operation (status = 'acked' | 'conflict')
```

### 3.2 Server contract

- The server treats `Idempotency-Key` as a unique constraint on the mutation effect. If the same key is seen twice, the server returns the original result (or a no-op success) instead of creating a second effect.
- The key is scoped to the authenticated user and the operation type to prevent cross-user collisions.
- The server stores the key long enough to cover reasonable retry windows (e.g. 24–72h); older replays are rejected as stale.

### 3.3 Client rules

- Generate `operation_id` once, at the moment the user action is committed to Drift.
- Reuse the exact same `operation_id` across every retry attempt.
- Do not generate a new id on app restart — read pending operations from the sync queue and resume them with their original id.
- If the user repeats the same logical action (e.g. taps "check" twice), that is two operations with two ids; the server's idempotency handles the case where the first is still in flight.

---

## 4. Sync Queue

The sync queue is a Drift table (`sync_operations`) holding pending outgoing mutations. It is the durable record of "things the server has not yet acknowledged."

### 4.1 Sync operation schema

```text
sync_operations
  operation_id        TEXT PRIMARY KEY      # stable UUID
  entity_type         TEXT                  # shopping_list_item | wish | ...
  entity_id           TEXT                  # local/server entity id
  mutation_type       TEXT                  # create | update | delete | check | ...
  payload             TEXT                  # JSON: the mutation arguments
  created_at          INTEGER               # ms since epoch
  base_revision       INTEGER               # entity revision the client acted on (nullable for create)
  attempt_count       INTEGER DEFAULT 0
  status              TEXT                  # pending | in_flight | acked | conflict | dead
  last_error          TEXT                  # nullable, last failure reason
  next_attempt_at     INTEGER               # ms since epoch, for backoff
```

This matches AGENTS.md §28 (sync operation conceptual schema).

### 4.2 Status transitions

```text
pending ──(worker picks up)──▶ in_flight
in_flight ──(ACK)──▶ acked            (→ delete row or mark acked)
in_flight ──(CONFLICT)──▶ conflict    (→ user resolution / auto-merge)
in_flight ──(transient failure)──▶ pending (attempt_count++, backoff)
pending/in_flight ──(max attempts)──▶ dead (surface to user)
```

- `acked` rows may be pruned immediately or retained briefly for diagnostics.
- `conflict` rows block further mutations on that entity until resolved.
- `dead` rows are surfaced to the user ("could not sync, retry?").

### 4.3 Ordering

- The worker drains the queue in `created_at` order per entity to preserve user intent where possible.
- Operations on the same entity are processed sequentially. Operations on different entities may be processed concurrently.
- If operation B depends on operation A's server-assigned id (e.g. add item to a list created locally), the worker awaits A's ACK before sending B; the local entity references A's local id, and the repository rewrites it to the server id on ACK.

---

## 5. Local-First Writes

A repository mutation for an offline-capable domain:

```dart
Future<void> setChecked(String itemId, bool checked) async {
  await _db.transaction(() async {
    // 1. read current entity + revision
    final current = await _local.getItem(itemId);
    // 2. optimistic local update
    await _local.upsertItem(current.copyWith(
      checked: checked,
      syncStatus: 'pending',
      updatedAt: DateTime.now(),
    ));
    // 3. enqueue sync operation with stable operation_id
    await _syncQueue.enqueue(
      operationId: uuid(),           // generated once here
      entityType: 'shopping_list_item',
      entityId: itemId,
      mutationType: 'check',
      payload: {'checked': checked},
      baseRevision: current.revision,
    );
  });
  // UI updates via the Drift watch stream; no await on network here
}
```

Rules:

- The local write and the sync enqueue are one Drift transaction. Either both happen or neither.
- The repository returns after the local transaction. The UI sees the change via the Drift stream.
- The network call is performed by the sync worker, not by the repository method on the UI's call stack.

---

## 6. Background Sync

The sync worker (`core/sync/`) drains the queue.

### 6.1 Triggers

- **App foregrounded**: start/ensure the worker is active.
- **After a local-first write**: kick the worker to attempt immediate delivery (don't wait for the next tick).
- **Network connectivity restored**: drain the queue.
- **Periodic**: a bounded periodic check (e.g. every 30s while foregrounded) catches operations that became due.
- **Background task** (where supported): a scheduled background fetch for time-sensitive domains, with platform constraints respected.

### 6.2 Worker loop

```text
loop:
  pick oldest pending operation whose next_attempt_at <= now
  mark in_flight
  send mutation (Idempotency-Key: operation_id, base_revision in payload)
  on ACK:
     reconcile entity (server revision, final state)
     mark acked
  on CONFLICT (409):
     mark conflict → trigger conflict resolution
  on transient failure (network, 5xx):
     attempt_count++
     next_attempt_at = now + backoff(attempt_count)
     status = pending
  on permanent failure (4xx non-conflict):
     mark dead, surface to user
```

### 6.3 Concurrency

- The worker processes a bounded number of operations concurrently (e.g. 4).
- Operations on the same entity are serialized (per-entity lock/queue).
- The worker must not block the UI; it runs on a background isolate-friendly scheduler and writes results back to Drift, which the UI observes via streams.

---

## 7. Conflict Resolution

Conflict policy is per collaborative entity (AGENTS.md §30). Universal "last write wins" is forbidden unless explicitly approved for that entity.

### 7.1 Revision-based conflict detection

Each entity has a server-assigned `revision` that increments on every server-side change. The client records the `base_revision` it acted on. On mutation:

```text
client sends:  PATCH /items/{id}  { ... , base_revision: 41 }   (Idempotency-Key: op_id)
server checks: current.revision == base_revision?
   yes → apply, revision becomes 42, return 200 + new state
   no  → return 409 Conflict { server_revision: 45, server_state: {...} }
```

The server is the authority. The client's `base_revision` is a hint for detection, not a claim of authority.

### 7.2 Per-entity policy

Each offline-capable collaborative entity MUST define:

- **revision/version**: integer, server-assigned, monotonic.
- **mutation semantics**: what each mutation means (e.g. `check` is a boolean toggle; `rename` is a field replace; `quantity` is a numeric set).
- **conflict detection**: revision compare (above).
- **merge/reconciliation strategy**: how to combine concurrent changes.
- **server response**: 200 with final state on success; 409 with server state on conflict.
- **client recovery**: what the client does on 409.

#### Shopping list item — reference policy

- `check` / `uncheck`: field-level. If two clients toggle `checked` concurrently, the server applies the later one (last-write-wins **on the `checked` field only**, explicitly approved for this field). The 409 returns the server `checked` value; the client adopts it.
- `rename` / `quantity`: field-level last-write-wins on the changed field, explicitly approved.
- `delete`: if the item was edited after the client's `base_revision`, the server returns 409 with the current state; the client prompts "this item changed, still delete?" or adopts server state.

This is NOT universal last-write-wins. It is per-field, per-entity, explicitly defined. Other entities (e.g. wishes) may use different policies.

### 7.3 Client recovery on 409

```text
on 409:
  server_state = response.body
  if server can auto-merge (field-level policy) and client change is still applicable:
     rebase local change onto server_state, re-send with new base_revision
  else:
     mark sync_operation status = conflict
     store server_state in the entity row (sync_status = 'conflict')
     emit ConflictState to the provider → UI shows resolution prompt
     on user choice (keep mine / keep theirs / merge):
        update local, enqueue a new operation with fresh base_revision
```

Conflicts block further mutations on that entity until resolved. The UI presents a deterministic recovery path; the user is never left with ambiguous state.

---

## 8. Reconnect Reconciliation

Reconnect reconciliation closes gaps in incoming server state after a WebSocket disconnect. It is separate from the sync queue (which handles outgoing mutations). See `docs/20-backend/realtime.md` §8.

```text
WebSocket reconnects
        ↓
for each active entity scope:
   GET /api/v1/<entity>?since=<lastKnownRevision>
        ↓
server returns changes newer than lastKnownRevision (or full set if too old)
        ↓
revision-aware upsert into Drift
        ↓
advance per-entity high-water mark
        ↓
resume realtime event handling
```

Interaction with pending mutations: reconciliation may fetch server state that does not yet reflect pending local mutations. That is expected. When the pending mutation ACKs, it advances state further. If the server state has moved past the mutation's `base_revision`, the mutation returns 409 and conflict resolution runs.

Reconciliation and the sync queue together guarantee convergence: the sync queue pushes pending client changes; reconciliation pulls missed server changes.

---

## 9. Retry Strategy

### 9.1 Backoff

- Exponential backoff with jitter: `delay = min(base * 2^attempt + jitter, maxDelay)`.
- Typical: `base = 1s`, `maxDelay = 5min`, jitter ±25%.
- `next_attempt_at` is stored in the sync operation so retries survive app restart.

### 9.2 Attempt limits

- Transient failures: retry up to a bounded max (e.g. 20 attempts) before marking `dead`.
- Permanent failures (4xx non-conflict): do not retry; mark `dead` and surface to user. Retrying a malformed request wastes resources.
- Conflict (409): not a retryable failure — it goes to conflict resolution, not the retry loop.

### 9.3 Network-aware

- The worker respects connectivity. If offline, it does not spin on retries; it waits for connectivity-restored and then drains.
- The worker stops or pauses on `Unauthorized` (token expired) and lets the auth flow refresh the token before resuming.

### 9.4 Idempotency makes retries safe

Because every retry reuses the `operation_id`, a retry that reaches the server after a partial success (server applied, response lost) is a no-op. This is the core guarantee that makes the queue safe.

---

## 10. Survivability Checklist

A mutation must survive:

- [x] temporary network failure → retry with backoff, same `operation_id`.
- [x] app restart → pending operations are in Drift, worker resumes on launch.
- [x] process termination → Drift is durable; pending rows persist.
- [x] retry → idempotency key prevents duplicate effects.
- [x] WebSocket disconnect → sync queue is independent of WebSocket; REST mutations proceed.
- [x] conflict → revision detection + per-entity policy + user resolution.
- [x] duplicate realtime event → dedup + revision guard (see `docs/20-backend/`).

---

## 11. What Is NOT Offline-First

- Public discovery feeds, search, seller catalog browsing — online-only is acceptable.
- Read-only large data with no offline value.
- Operations that require server-side validation the client cannot meaningfully preview (e.g. payment authorization) — these are online-only by nature; the client shows a loading state and does not fake success.

Do not force offline support onto endpoints where it adds complexity without product value (AGENTS.md §24: not every endpoint needs offline support).

---

## 12. Testing

Offline-first behavior MUST be tested for:

- offline mutation: write while offline → UI updates, sync queue has pending row.
- retry: transient failure → backoff, same `operation_id` reused.
- duplicate mutation: replay same `operation_id` → server no-ops, no double effect.
- conflict: server returns 409 → conflict state, resolution path.
- reconnect: gap in revisions → reconciliation fetches and applies.
- app restart: pending operations resume.
- ordering: dependent operations (create list, then add item) serialize correctly.
- max attempts: operation becomes `dead` after limit.

See `docs/10-development/testing.md`.
