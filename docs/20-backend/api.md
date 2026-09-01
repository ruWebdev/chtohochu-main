# API Conventions

> **Authority:** This document defines the conventions for the ЧтоХочу HTTP API. It is
> normative for all `/api/v1/*` endpoints. See [`errors.md`](./errors.md) for the error
> response format and [`versioning.md`](./versioning.md) for the versioning policy.

## 1. Style

The API is **RESTful** over HTTP/1.1 (HTTP/2 where the reverse proxy supports it). Resources
are named with plural nouns; operations are expressed via HTTP verbs; state transfers as
JSON. The API is **not** RPC-style and is **not** GraphQL (GraphQL is an explicit
non-choice per AGENTS.md §4).

The API is **stateless** from the server's perspective: every request carries its own
authentication and no server-side session is required for API traffic (Sanctum bearer
tokens). This permits horizontal scaling behind a load balancer without session affinity.

## 2. URL Conventions

### 2.1 Base path

All application APIs are served under:

```
/api/v1/
```

The version segment is **mandatory** and is part of the URL. See [`versioning.md`](./versioning.md).

The API is served from a dedicated API host (`APP_DOMAIN_API`, e.g. `api.chtohochu.ru`),
separate from the web host. This keeps cookie/session middleware off API traffic.

### 2.2 Resource naming

- Plural nouns: `/wishes`, `/wishlists`, `/shopping-lists`, `/friends`, `/users`.
- Lowercase, hyphen-separated multi-word resources: `/shopping-lists`, not `/shoppingLists`.
- Nested resources express a relationship owned by the parent:
  `/wishlists/{wishlist}/wishes`, `/shopping-lists/{list}/items`.
- Nesting is limited to **one level**. Deeper relationships are accessed at the top level
  with a filter: `/wishes?wishlist_id={id}` rather than `/wishlists/{id}/wishes/{id}/images`.
- A resource identifier is the UUID primary key: `/wishes/{uuid}`.

### 2.3 Trailing slashes

No trailing slashes. `/wishes` is correct; `/wishes/` is a `404` (or a redirect, but
redirects are discouraged because they hide client bugs).

### 2.4 Verb mapping

| Verb | Semantics | Idempotent | Safe |
|------|-----------|------------|------|
| `GET` | Read a resource or collection. | Yes | Yes |
| `POST` | Create a resource, or trigger a non-CRUD action (action endpoints, see §3). | No | No |
| `PUT` | Replace a resource at a known URL. | Yes | No |
| `PATCH` | Apply a partial update to a resource. | No | No |
| `DELETE` | Remove a resource (or revoke, or deactivate). | Yes | No |

`PUT` for replacement requires the client to send all writable fields; omitted fields are
set to their defaults. `PATCH` for partial update touches only the supplied fields. The
prototype prefers `PATCH` for updates; `PUT` is reserved for true full-replacement cases.

## 3. Action Endpoints

Some operations are not naturally CRUD. These are expressed as `POST` to a sub-path under
the resource, named with a verb:

| Endpoint | Purpose |
|----------|---------|
| `POST /api/v1/auth/login` | Authenticate (not a resource creation) |
| `POST /api/v1/auth/logout` | Revoke current token |
| `POST /api/v1/shopping-lists/{list}/items/{item}/toggle` | Check/uncheck a shopping item |
| `POST /api/v1/wishlists/{id}/invite` | Invite a participant |
| `POST /api/v1/friends/{id}/accept` | Accept a friend request |

Action endpoints return the affected resource (or a small action result envelope) with the
appropriate status code, not a bare `200 OK`.

## 4. Request Format

- **Content type:** `application/json; charset=utf-8` for all `POST`/`PUT`/`PATCH` bodies.
- **Body:** JSON object. Form-encoded bodies are not accepted by API routes.
- **Encoding:** UTF-8.
- **Empty body:** `POST`/`PUT`/`PATCH` with no fields sends `{}` or no body; the server
  treats an absent body as `{}`.
- **Dates:** ISO 8601 with timezone, e.g. `2025-11-20T12:00:00Z`. The server stores and
  returns UTC.
- **UUIDs:** lowercase canonical form.
- **Booleans:** JSON `true`/`false`, not `1`/`0` or `"true"`.

## 5. Response Format

- **Content type:** `application/json; charset=utf-8`.
- **Body:** a JSON object. Collections are wrapped:
  ```json
  {
    "data": [ /* ... */ ],
    "meta": { "cursor": { "next": "..." } }
  }
  ```
  Single resources are wrapped:
  ```json
  { "data": { "id": "...", "type": "wish", "..." : "..." } }
  ```
  (Wrapping is the target state; the prototype currently returns some resources unwrapped.
  New endpoints MUST wrap; existing ones are migrated with the next major version.)
- **Resource shape:** Laravel API Resources (`JsonResource`) are the serialization layer.
  Controllers return resources, not Eloquent models directly, so output shape is stable and
  explicit.
- **Dates** in responses are ISO 8601 UTC.
- **`id`** is always a string UUID, even though it is stored as a UUID in PostgreSQL.

## 6. Authentication

- API authentication uses **Laravel Sanctum bearer tokens** (see
  [`../02-authentication/authentication.md`](../02-authentication/authentication.md)).
- The token is sent in the `Authorization` header:
  ```
  Authorization: Bearer 2|abcdef0123456789...
  ```
- Tokens are not sent in query strings or cookies for API traffic.
- Unauthenticated requests to protected endpoints return `401` (see [`errors.md`](./errors.md)).
- Authenticated but unauthorized requests return `403`.
- The `/auth/me` endpoint is the canonical way to validate a token and fetch the current
  user's roles/permissions.

## 7. Pagination

### 7.1 Cursor-based (preferred)

Collections use **cursor-based pagination** to remain stable under inserts and to perform
well on large tables. The response includes a `meta.cursor` object:

```json
{
  "data": [ /* items */ ],
  "meta": {
    "cursor": {
      "next": "eyJpZCI6IjEyMzQ1Njc4OS0uLi4iLCJvcmRlcl9ieSI6ImlkLmFzYyJ9"
    }
  }
}
```

The client passes the `next` cursor back as a query parameter:

```
GET /api/v1/wishes?cursor=eyJpZCI6...
```

When `meta.cursor.next` is `null`, there is no more data.

### 7.2 Why cursor, not offset

Offset pagination (`?page=2&per_page=20`) is unstable under concurrent inserts (items shift
between pages, duplicates and skips appear) and degrades on deep offsets. Cursor pagination
keyset-scans on an indexed sort column and is immune to both.

### 7.3 Page size

- Default page size: `20`.
- Maximum page size: `100`. Requests for `per_page` above 100 are clamped to 100, not
  rejected.
- The page size parameter is named `per_page`.

### 7.4 Offset pagination (legacy)

Offset pagination is permitted only for small, stable, administrative collections where
total count is required and deep pagination is not. New collection endpoints MUST use cursor
pagination.

## 8. Filtering

Filters are query parameters named after the resource field, with optional operators:

| Pattern | Example | Meaning |
|---------|---------|---------|
| `?field=value` | `?status=active` | Equality |
| `?field__in=a,b` | `?status__in=active,pending` | Set membership |
| `?field__gt=value` | `?created_at__gt=2025-01-01T00:00:00Z` | Greater than |
| `?field__gte=value` | `?created_at__gte=...` | Greater than or equal |
| `?field__lt=value` | `?created_at__lt=...` | Less than |
| `?field__lte=value` | `?created_at__lte=...` | Less than or equal |
| `?field__null=true` | `?completed_at__null=true` | Field is null |
| `?q=term` | `?q=red+balloon` | Full-text / search (resource-specific) |

- Unknown filter parameters are **ignored**, not rejected, to preserve forward/backward
  compatibility. (They are logged at `debug` level to help catch client typos.)
- Filter values are URL-encoded.
- Filters are combined with AND. OR filters are not supported via query string; clients
  that need OR issue multiple requests or use a dedicated search endpoint.
- Filters are applied server-side, after authorization. A filter never broadens access
  beyond what the user is authorized to read.

## 9. Sorting

- `?sort=field` — ascending.
- `?sort=-field` — descending (leading hyphen).
- Multiple sort keys: `?sort=-created_at,title`.
- Sort fields must be whitelisted per endpoint (to avoid scanning unindexed columns).
  Unknown sort fields are ignored.
- Cursor-paginated endpoints require the sort key to match the cursor's `order_by`; mixing
  `?sort=` with a cursor from a different sort is a `400`.

## 10. Field Selection

Clients may request a subset of fields to reduce payload:

```
GET /api/v1/wishes?fields=id,title,url,created_at
```

- `fields` is a comma-separated list of top-level resource attributes.
- Unknown fields are ignored.
- `id` and `type` are always included.
- Field selection is a payload optimization, not a security mechanism. The server still
  authorizes the full resource; fields are not hidden for security reasons (use resource
  variants or separate endpoints for that).
- Nested resource fields use dot notation: `?fields=id,title,owner.name`.

## 11. Status Codes

See [`errors.md`](./errors.md) for the full table. The success codes used:

| Code | Meaning |
|------|---------|
| `200 OK` | Successful read, successful non-creation action, successful update |
| `201 Created` | Resource created; `Location` header points to the new resource |
| `204 No Content` | Successful deletion or empty response (e.g. logout) |

The prototype currently returns `200` for logout with a JSON body; new action endpoints that
have no meaningful body SHOULD return `204`.

## 12. Rate Limiting

- Rate limiting is enforced by Laravel's `throttle` middleware, backed by Redis.
- Default API limit: `60` requests per minute per authenticated user (or per IP for
  unauthenticated endpoints). Subject to tuning per endpoint.
- Auth-sensitive endpoints are stricter: login, registration, OAuth exchange use
  `throttle:10,1` or `ensureIsNotRateLimited`.
- When the limit is exceeded, the response is `429 Too Many Requests` with `Retry-After`
  and `X-RateLimit-*` headers (see [`errors.md`](./errors.md)).
- Rate limits are per-token for authenticated requests and per-IP for unauthenticated
  requests.

## 13. Idempotency

Retryable mutations (especially sync mutations from offline mobile clients) MUST be
idempotent. The mechanism is an `Idempotency-Key` header:

```
POST /api/v1/wishes
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

- The key is a client-generated UUID, reused for retries of the same logical operation.
- The server caches the first response (for 24h) and replays it for subsequent requests
  with the same key and same request body.
- A request with the same key but a **different** body is a `409 Conflict` (see
  [`errors.md`](./errors.md)).
- Idempotency applies to `POST`, `PUT`, `PATCH`, and `DELETE` of idempotent-by-key
  resources. `GET` is inherently idempotent and does not need the key.

See AGENTS.md §29 (Idempotency) and [`../07-flutter/`](../07-flutter/) sync docs for the
mobile-side `operation_id` contract.

## 14. Caching

- `GET` responses that are publicly cacheable include `Cache-Control: public, max-age=...`
  and an `ETag`.
- Authenticated/personalized responses include `Cache-Control: private, max-age=0,
  must-revalidate` and an `ETag`, so the client can short-circuit with `If-None-Match` →
  `304 Not Modified`.
- `POST`/`PUT`/`PATCH`/`DELETE` responses are never cacheable.
- The server never relies on client caching for correctness; caching is a latency/throughput
  optimization only.

## 15. Headers

### 15.1 Request headers

| Header | Purpose |
|--------|---------|
| `Authorization: Bearer <token>` | Sanctum authentication |
| `Content-Type: application/json` | Request body format |
| `Accept: application/json` | Required for API routes |
| `Idempotency-Key: <uuid>` | Idempotent mutation (see §13) |
| `If-None-Match: <etag>` | Conditional GET |
| `Accept-Language: ru` | Locale preference (see §16) |

### 15.2 Response headers

| Header | Purpose |
|--------|---------|
| `Content-Type: application/json; charset=utf-8` | Response body format |
| `Location: <url>` | New resource URL on `201` |
| `ETag: <hash>` | Resource version for conditional GET |
| `Cache-Control: ...` | Caching directive |
| `X-RateLimit-Limit` / `X-RateLimit-Remaining` | Rate limit state |
| `Retry-After` | Seconds until retry on `429`/`503` |

## 16. Localization

- User-facing strings in API responses (error `message`, notification text) are localized
  server-side based on `Accept-Language` (preferred) or the user's `locale` attribute.
- The default locale is `ru`. English is supported as a secondary locale.
- Machine-readable fields (`error.code`, `errors.{field}` keys, enum values) are never
  localized; they are stable identifiers the client switches on.

## 17. Time

- All timestamps are UTC, ISO 8601, with a trailing `Z` (or an explicit offset).
- The server stores `timestamp` columns as UTC. The client converts to local time for
  display only.
- Date-only values (e.g. a wish's "desired by" date) use `YYYY-MM-DD`.

## 18. Enums

Enum values are lowercase snake_case strings, stable across versions:

| Enum | Values |
|------|--------|
| `visibility` | `public`, `shared`, `friends`, `private` |
| `wishlist_status` | `active`, `archived` |
| `shopping_item_status` | `open`, `done` |
| `friendship_status` | `pending`, `accepted`, `blocked` |

New enum values may be added in a minor version (additive). Existing values are never
renamed or removed without a major version bump.

## 19. OpenAPI

- The machine-readable API contract SHOULD be maintained as an OpenAPI 3.1 document.
- The OpenAPI spec is generated from (or kept in sync with) the route definitions and
  request/response schemas, not hand-maintained separately.
- Breaking changes to the spec require the versioning process in [`versioning.md`](./versioning.md).

## 20. Non-Goals

- No GraphQL.
- No bulk/batch endpoints in v1 (a future `POST /api/v1/batch` may be added via ADR if a
  concrete requirement emerges).
- No WebSocket-over-HTTP long-polling. Realtime uses Reverb (see
  [`../05-realtime/`](../05-realtime/)).
- No server-driven UI / BFF schema. The API returns data; the client renders.
