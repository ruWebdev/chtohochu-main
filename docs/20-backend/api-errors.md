# API Errors

> **Authority:** This document defines the error response format for the ЧтоХочу HTTP API.
> It is normative for all `/api/v1/*` endpoints. Every error response produced by the API
> MUST conform to this document.

## 1. Principles

1. **Machine-readable first.** Errors exist so the client can decide what to do. The
   `message` is for humans; structured fields (`errors`, status code, headers) drive client
   logic.
2. **Consistent shape.** Every error response is a JSON object with the same envelope.
   Clients parse one shape, not many.
3. **No stack traces in production.** Internal details are logged server-side; the response
   contains only an opaque reference (`error.code` / request id) the user can quote.
4. **Stable codes.** `error.code` values are versioned identifiers that never change within
   a major version. Clients may switch on them.
5. **Localized messages.** The `message` and `errors.{field}` strings are localized
   server-side per `Accept-Language` / user locale. The codes are not localized.

## 2. HTTP Status Codes

| Code | Name | When used |
|------|------|-----------|
| `200` | OK | Successful read, successful update, successful non-creation action |
| `201` | Created | Resource created; `Location` header set |
| `204` | No Content | Successful delete or action with no body |
| `400` | Bad Request | Malformed request: bad cursor, conflicting query params, unreadable JSON, missing required header |
| `401` | Unauthorized | No token, invalid token, expired token |
| `403` | Forbidden | Authenticated but lacks capability/ownership/membership; or visibility denial |
| `404` | Not Found | Resource does not exist, or exists but is not visible to the requester (visibility denial returns `404`, not `403`, to avoid leaking existence) |
| `409` | Conflict | Idempotency key reuse with a different body; concurrent edit conflict (revision mismatch); unique-constraint violation that is not a validation error |
| `422` | Unprocessable Entity | Validation failure (semantically valid JSON that fails business rules) |
| `429` | Too Many Requests | Rate limit exceeded |
| `500` | Internal Server Error | Unexpected server error; response contains a request id, no stack trace |

### 2.1 Codes not used in v1

- `405 Method Not Allowed`: Laravel returns this automatically for unsupported verbs on
  defined routes; it is not part of the application contract but is handled per §3.
- `408 Request Timeout`, `502`, `503`, `504`: produced by infrastructure, not the
  application. Clients must handle them as transient network failures.
- `301`/`302`: redirects are not used by the API. Trailing-slash mismatches return `404`,
  not a redirect.

### 2.2 401 vs 403

- `401`: the requester is **not authenticated** (no/invalid/expired token). The client
  should attempt to re-authenticate.
- `403`: the requester **is authenticated** but is not allowed to perform the operation.
  Re-authenticating will not help; the client should show a permission-denied state.

### 2.3 404 vs 403 for hidden resources

For a resource the requester is not authorized to see, the API returns `404`, not `403`,
when the resource's existence itself is sensitive (e.g. a private wishlist belonging to
another user). This prevents existence disclosure. For resources whose existence is public
but whose mutation is restricted (e.g. a public wishlist the requester cannot edit), `403`
is appropriate.

## 3. Error Response Body

Every error response is a JSON object with this shape:

```json
{
  "message": "The given data was invalid.",
  "error": {
    "code": "validation_failed",
    "request_id": "req_01HABCDEF..."
  },
  "errors": {
    "email": ["The email field is required."]
  }
}
```

| Field | Type | Always present | Description |
|-------|------|----------------|-------------|
| `message` | string | Yes | Human-readable summary, localized. Suitable for a toast/alert. |
| `error.code` | string | Yes on `4xx`/`5xx` | Stable machine-readable code (see §4). |
| `error.request_id` | string | Yes on `5xx`, recommended on `4xx` | Opaque id for support correlation; also sent in `X-Request-Id` header. |
| `errors` | object | Only on `422` (and `400` for field-level errors) | Map of field name → array of localized message strings. |

The `errors` object is present only when the failure is field-level (validation or
malformed-field). For non-field errors (auth, authorization, not-found, conflict, rate
limit, server error) `errors` is omitted and `message` + `error.code` carry the meaning.

### 3.1 Minimal examples

`401`:
```json
{ "message": "Unauthenticated.", "error": { "code": "unauthenticated" } }
```

`403`:
```json
{ "message": "This action is unauthorized.", "error": { "code": "forbidden" } }
```

`404`:
```json
{ "message": "Not found.", "error": { "code": "not_found" } }
```

`429`:
```json
{ "message": "Too many requests. Try again in 57 seconds.", "error": { "code": "rate_limited" } }
```

`500`:
```json
{
  "message": "Server error. Please try again later.",
  "error": { "code": "internal_error", "request_id": "req_01HABCDEF..." }
}
```

## 4. Error Codes

Stable, lowercase snake_case identifiers. New codes may be added in minor versions; existing
codes are never renamed or removed within a major version.

| Code | HTTP | Meaning |
|------|-----|---------|
| `unauthenticated` | 401 | No/invalid/expired token |
| `forbidden` | 403 | Authenticated but not authorized |
| `not_found` | 404 | Resource does not exist or is not visible |
| `validation_failed` | 422 | One or more fields failed validation |
| `bad_request` | 400 | Malformed request (not field-level) |
| `conflict` | 409 | Generic conflict (use a more specific code when available) |
| `idempotency_conflict` | 409 | `Idempotency-Key` reused with a different body |
| `revision_conflict` | 409 | Optimistic concurrency / revision mismatch |
| `rate_limited` | 429 | Rate limit exceeded |
| `internal_error` | 500 | Unexpected server error |
| `service_unavailable` | 503 | Maintenance / degraded (when produced by the app) |

Provider-specific codes (e.g. OAuth failures) reuse `validation_failed` with field-level
`errors` entries; the field name identifies the provider context (e.g.
`errors.access_token`).

## 5. Validation Error Format (`422`)

Validation failures use Laravel's standard validation error shape, which matches the
contracted envelope:

```json
{
  "message": "The given data was invalid.",
  "error": { "code": "validation_failed" },
  "errors": {
    "email": ["The email field is required."],
    "password": ["The password field is required."]
  }
}
```

Rules:

- `errors` is an object whose keys are the request field names (dot-notation for nested
  arrays/objects: `items.0.title`, `wishes.*.url`).
- Each value is an **array** of localized message strings, even when there is one message.
  Clients must handle the array.
- The `message` is a generic summary ("The given data was invalid."), not a concatenation
  of field messages. The client renders field messages next to the corresponding inputs.
- Validation messages are localized server-side.
- The HTTP status is `422`, never `400`, for semantically-valid JSON that fails business
  rules. `400` is reserved for malformed JSON / structural problems.

### 5.1 Field name stability

Field names in `errors` are the request field names as the client sent them. They are
stable across versions. Renaming a request field is a breaking change (see
[`versioning.md`](./versioning.md)).

## 6. Idempotency Error Format (`409`)

When a client reuses an `Idempotency-Key` with a request body that differs from the
original, the server responds:

```json
{
  "message": "Idempotency key was reused with a different request body.",
  "error": { "code": "idempotency_conflict" }
}
```

When the key is reused with the **same** body, the server replays the original response
(status, body, headers) and adds:

```
Idempotency-Replay: true
```

so the client can distinguish a replay from a fresh success.

If the original request is still in flight, the server responds `409` with
`error.code = idempotency_conflict` and a message indicating the original is pending; the
client should retry the same key after a short backoff.

## 7. Conflict Error Format (`409`)

For optimistic-concurrency conflicts (revision mismatch on collaborative entities):

```json
{
  "message": "The resource was modified by another client. Refresh and try again.",
  "error": {
    "code": "revision_conflict",
    "current_revision": 17
  }
}
```

`error.current_revision` is the server's current revision, which the client should use as
the new base for a retry. See AGENTS.md §30 (Conflict Resolution) for the per-entity
conflict policy.

For unique-constraint conflicts that are not validation errors (e.g. attempting to add a
participant who is already a member):

```json
{
  "message": "The participant is already a member of this list.",
  "error": { "code": "conflict" }
}
```

## 8. Rate Limit Error Format (`429`)

```json
{
  "message": "Too many requests. Try again in 57 seconds.",
  "error": { "code": "rate_limited" }
}
```

Headers:

| Header | Meaning |
|--------|---------|
| `Retry-After: 57` | Seconds until the client may retry |
| `X-RateLimit-Limit: 60` | The limit per window |
| `X-RateLimit-Remaining: 0` | Requests remaining in the current window |
| `X-RateLimit-Reset: 1732100400` | Unix timestamp when the window resets |

The client MUST honor `Retry-After` and MUST NOT retry in a tight loop.

## 9. Internal Error Format (`500`)

```json
{
  "message": "Server error. Please try again later.",
  "error": {
    "code": "internal_error",
    "request_id": "req_01HABCDEF..."
  }
}
```

- The response never contains a stack trace, file path, or SQL.
- The `request_id` is also written to the server log alongside the exception, so support
  can correlate.
- The `request_id` is returned in the `X-Request-Id` response header for all responses
  (success and error) so clients can quote it pre-emptively.

## 10. Request Id

Every API response includes:

```
X-Request-Id: req_01HABCDEF...
```

- Generated by the server (ULID/UUID) if the client did not send `X-Request-Id`.
- If the client sends `X-Request-Id`, the server echoes it back (after validating format).
- The id is logged with the request and any exception.
- Clients SHOULD include the id in bug reports and support tickets.

## 11. Error Handling by the Client

The Flutter and Vue clients MUST translate infrastructure errors (Dio exceptions, network
failures) into application-level failures and never surface raw HTTP details to the UI. The
mapping is:

| HTTP / condition | Client failure type | UI behavior |
|------------------|---------------------|-------------|
| `400`/`422` | `ValidationFailure(errors)` | Render field errors inline |
| `401` | `UnauthenticatedFailure` | Clear token, route to sign-in |
| `403` | `ForbiddenFailure` | Show permission-denied state |
| `404` | `NotFoundFailure` | Show not-found state |
| `409` `idempotency_conflict` | `IdempotencyConflictFailure` | Surface as a bug (client reused key wrongly) |
| `409` `revision_conflict` | `RevisionConflictFailure` | Refetch, rebase, retry per sync policy |
| `429` | `RateLimitedFailure(retryAfter)` | Show "try again in Ns", schedule retry |
| `5xx` | `ServerFailure(requestId)` | Show generic error with request id, offer retry |
| Network error | `NetworkFailure` | Show offline state, queue mutation for sync |

Raw Dio/HTTP exceptions MUST NOT reach presentation (AGENTS.md §11).

## 12. Logging

- `4xx` errors are logged at `info` or `warning` level with `request_id`, route, and
  validation errors (no credentials, no tokens).
- `5xx` errors are logged at `error` level with `request_id`, route, stack trace, and user
  id (never the token or password).
- Validation error messages are logged without the input values (to avoid logging
  sensitive data such as passwords).
- OAuth provider errors are logged with the provider's error message, never with the
  provider access token.

## 13. Testing

Every error path is tested at the API level:

- `401` for missing/invalid/expired token on a protected endpoint.
- `403` for authenticated-but-unauthorized access.
- `404` for missing and for hidden resources.
- `422` for each validation rule, asserting the exact `errors` keys and that the value is
  an array.
- `409` for idempotency-key reuse with same body (replay) and different body (conflict).
- `409` for revision conflict, asserting `current_revision` is returned.
- `429` for rate-limited endpoints, asserting `Retry-After` and `X-RateLimit-*` headers.
- `500` path is tested via a forced exception, asserting no stack trace in the body and
  `request_id` present.
