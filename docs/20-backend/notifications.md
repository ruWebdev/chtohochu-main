# Notifications Architecture

## 1. Purpose

This document defines how ЧтоХочу generates, delivers, and manages notifications across channels. It covers Laravel Notifications, the delivery channels (database, FCM push, email), queue-based delivery, notification preferences, and the notification settings model.

Notifications inform the user that something happened. They are **not** a synchronization mechanism and **not** a source of truth. A lost notification MUST NOT cause data inconsistency.

---

## 2. Technology

| Component | Technology | Role |
|-----------|-----------|------|
| Notification engine | Laravel Notifications | Build, route, queue, deliver notifications |
| Database channel | `database` | In-app notification center (persisted list) |
| Push channel | Firebase Cloud Messaging (FCM) | Out-of-app push |
| Email channel | Laravel Mail (SMTP/transactional provider) | Email notifications |
| Queue | Laravel Horizon (Redis queue) | Async delivery |
| Source of truth | PostgreSQL | Notification records, preferences, settings |

Laravel Notifications is the single engine. All notification types are PHP classes extending `Notification`. Routing (which channels a given notification goes to) is decided per-recipient based on preferences (§6).

---

## 3. Notification Types

Notification types correspond to product events the user should know about. Each is a `Notification` subclass.

### 3.1 Initial notification types

| Notification | Trigger | Default channels |
|--------------|---------|------------------|
| `FriendRequestReceived` | Someone sends a friend request | database, push |
| `FriendRequestAccepted` | Recipient accepts a friend request | database, push |
| `WishlistShared` | Someone shares a wishlist with the user | database, push |
| `WishReserved` | Someone reserves a wish the user owns | database, push |
| `WishPurchased` | Someone marks a wish as purchased | database, push |
| `ShoppingListShared` | Someone shares a shopping list | database, push |
| `ShoppingListItemAdded` | Participant adds an item to a shared list | database, push |
| `ShoppingListItemAssigned` | An item is assigned to the user | database, push |
| `ShoppingListMention` | User is @-mentioned in a list | database, push, email |
| `SystemAnnouncement` | Admin/system broadcast | database, push |

Each notification type defines:

- a readable `via($notifiable)` decision (which channels, based on preferences);
- a `toDatabase()` representation (structured data for the in-app center);
- a `toFcm()` representation (push payload — identifiers + metadata, not full state);
- a `toMail()` representation where email is supported.

### 3.2 Payload rules

- The **database** channel stores structured data: type, actor, entity refs, timestamps. This powers the in-app notification center.
- The **FCM** channel carries identifiers and event metadata (entity type, entity id, notification id), NOT a duplicate of authoritative domain state. The client uses the identifiers to navigate or fetch state. See §5.
- The **email** channel renders a full human-readable message (email is not interactive; it must be self-contained).

---

## 4. Channels

### 4.1 Database channel

The `database` channel writes a row to the `notifications` table (Laravel's polymorphic notifications table or a dedicated table). This is the source for the in-app notification center:

- list notifications (paginated, cursor-based);
- mark as read / unread;
- delete;
- unread count (badge).

The database channel is synchronous relative to the queue job but the job itself is async. The notification row is the authoritative record of "this notification exists for this user."

### 4.2 FCM push channel

FCM is the push transport for iOS, Android, and web push (via FCM web push). The `toFcm()` payload:

```json
{
  "notification": {
    "title": "New friend request",
    "body": "Alex wants to be your friend"
  },
  "data": {
    "notification_id": "...",
    "type": "friend_request_received",
    "entity_type": "friend_request",
    "entity_id": "..."
  }
}
```

Rules:

- The `data` section carries identifiers and routing metadata.
- The `notification` section carries display text for the system tray/banner.
- The payload MUST NOT duplicate authoritative domain state. The client fetches fresh state on tap.
- Push delivery is best-effort. FCM may delay, throttle, or drop messages. The app MUST remain correct without receiving the push.

### 4.3 Email channel

Email is used for a subset of notification types (e.g. `ShoppingListMention`, digest summaries). Email is rendered server-side via Markdown/Mailable templates and sent through the queue. Email is not interactive beyond deep links back into the app.

---

## 5. FCM as Push Transport, Not Sync

> **Push is NOT a synchronization mechanism. A lost push MUST NOT cause data inconsistency.**

FCM's role:

- wake the user / draw attention;
- provide a deep-link entry point into the app;
- carry just enough metadata for the client to know where to navigate.

FCM's role is NOT:

- delivering business state;
- guaranteeing delivery;
- replacing REST reads or realtime WebSocket events;
- a trigger to mutate local state blindly.

When a push is tapped, the client:

1. Opens the app at the deep link (entity screen).
2. Fetches current state via REST for that entity.
3. Reconciles local state.

If the push is never received, the user still sees the notification in the in-app center (database channel) and the underlying state change via REST/realtime. Correctness does not depend on push delivery.

---

## 6. Notification Preferences

Each user has notification preferences that control which channels each notification type uses. Preferences are user-editable and have sensible defaults.

### 6.1 Preference model

Preferences are keyed by notification type and channel:

```text
notification_preferences
  user_id
  type            # e.g. "friend_request_received"
  channel         # "database" | "push" | "email"
  enabled         # boolean
```

A notification is delivered to a channel only if:

1. the channel is enabled for that type in the user's preferences; AND
2. the channel is technically available (e.g. push requires a registered FCM token).

### 6.2 Defaults

| Type | database | push | email |
|------|----------|------|-------|
| FriendRequestReceived | on | on | off |
| FriendRequestAccepted | on | on | off |
| WishlistShared | on | on | off |
| WishReserved | on | on | off |
| WishPurchased | on | on | off |
| ShoppingListShared | on | on | off |
| ShoppingListItemAdded | on | on | off |
| ShoppingListItemAssigned | on | on | off |
| ShoppingListMention | on | on | on |
| SystemAnnouncement | on | on | off |

The `database` channel is on for all types by default; the in-app center always reflects what happened. Users may mute types entirely (database off) only for non-critical types. Critical security/account notifications cannot be fully muted.

### 6.3 Quiet hours

Optional: a user may configure quiet hours during which push is suppressed (the database row is still written; push is skipped or held). If held, a digest may be sent at the end of the quiet window. Quiet hours affect push and email only, never the database channel.

---

## 7. Notification Settings Model

Beyond per-type preferences, the user has global notification settings:

```text
notification_settings
  user_id
  push_enabled_global       # master switch for FCM
  email_enabled_global      # master switch for email
  quiet_hours_start         # nullable, HH:mm
  quiet_hours_end           # nullable, HH:mm
  quiet_hours_timezone      # IANA tz
  digest_email              # none | daily | weekly
  language                  # notification language override (fallback to profile)
```

Effective channel decision for a notification:

```text
channel enabled =
    global switch for channel is ON
  AND preference for (type, channel) is enabled
  AND (not in quiet hours OR channel == database)
  AND channel is technically available (FCM token registered for push)
```

This decision is evaluated in `via($notifiable)` on the Notification class, using the user's settings + preferences loaded eagerly.

---

## 8. Queue-Based Delivery

Notifications are dispatched to the queue, not sent inline with the request that triggered them.

```text
Domain event / Application operation
        ↓
Notification created (database row written in transaction OR queued)
        ↓
Dispatched to Laravel Horizon queue
        ↓
Worker processes job:
   - resolve channels via via()
   - send FCM via FCM SDK
   - send email via Mailer
        ↓
Job acked / retried on failure
```

Rules:

- The database channel row is written first (so the in-app center is consistent even if push/email fail).
- FCM and email sends are queued separately or as part of the notification job.
- Jobs MUST tolerate retries. A transient FCM failure retries; a permanent failure (invalid token) is logged and the token is pruned.
- Jobs with dangerous side effects (e.g. sending an email that could spam) MUST be idempotent or unique. Use Laravel's `ShouldBeUnique` for notification jobs where duplicate delivery is harmful.
- FCM token registration is a separate flow: the client registers its token via REST; the backend stores it per-device. A user may have multiple devices/tokens.

### 8.1 FCM token lifecycle

```text
App login / FCM SDK yields token
        ↓
POST /api/v1/devices  { token, platform }
        ↓
Backend stores device token for user
        ↓
Push jobs fan out to all of the user's active tokens
        ↓
On logout / token rotation: DELETE /api/v1/devices/{token}
```

Invalid tokens (FCM responds with unregistered) are pruned by the worker after a failed send.

---

## 9. Read State and Badge

- The in-app notification center reads from the `notifications` table.
- `read_at` is set when the user opens the notification (or marks all read).
- The unread count is exposed via `GET /api/v1/notifications/unread-count` and updated in realtime via `notification.read` / `notification.created` events (see `docs/20-backend/realtime-events.md`).
- The app badge count mirrors the unread count for the current user. Badge updates are best-effort; the source of truth is the backend `notifications` table.

---

## 10. Localization

Notification display text (title, body) is rendered in the user's notification language (from `notification_settings.language` or profile language). FCM `notification.title`/`body` are localized server-side before sending, because the OS banner renders the provided text. The `data` section is language-independent (identifiers only).

Email templates are localized per-recipient.

---

## 11. What Notifications Are Not

- Not a sync mechanism. Lost notifications do not corrupt state.
- Not a realtime channel. Realtime WebSocket events are a separate transport (see `docs/20-backend/`). A `notification.created` realtime event may accompany a notification, but the notification system does not depend on the WebSocket.
- Not a security boundary. Notifications are informational; authorization is enforced when the user opens the referenced entity.
- Not a place to duplicate domain state. Notifications reference entities by ID; they do not store authoritative copies.

---

## 12. Testing Requirements

Notifications MUST be tested for:

- correct channel selection based on preferences + settings + quiet hours;
- database row is always written (even when push/email are off);
- FCM payload contains identifiers, not full state;
- queue job retries on transient failure;
- invalid FCM token is pruned;
- idempotency: re-running a notification job does not double-send (where required);
- preference changes take effect on the next notification;
- unread count is accurate after read/deleted events.

See `docs/10-development/testing.md`.
