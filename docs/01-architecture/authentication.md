# Authentication Architecture

> **Authority:** This document defines the authentication architecture for the ЧтоХочу backend.
> It is normative for backend, mobile, and web implementations. Conflicts with code must be
> resolved either by aligning the code to this document or by recording an ADR in
> `docs/decisions/` that supersedes it.

## 1. Overview

ЧтоХочу authenticates users through two parallel mechanisms, depending on the client:

| Client | Mechanism | Guard | Credential |
|--------|-----------|-------|------------|
| Mobile (Flutter) | Token-based (Sanctum personal access tokens) | `sanctum` | Bearer token in `Authorization` header |
| Web (Vue 3) | Session-based (Laravel sessions + cookies) | `web` | Encrypted session cookie + CSRF token |
| OAuth providers (VK, Yandex) | Provider access token exchanged for a Sanctum token (mobile) or session (web) | `sanctum` / `web` | Provider access token, exchanged once |

The existing prototype uses **Sanctum single access tokens**. There are **no refresh tokens**.
A token is long-lived until it expires or is explicitly revoked. See §6 for lifetime policy.

OAuth integration is documented separately in [`oauth.md`](./oauth.md). Authorization (roles,
permissions, capability checks) is documented separately in [`authorization.md`](./authorization.md).

## 2. Guards and Configuration

Two authentication guards are configured:

```php
// config/auth.php (conceptual)
'guards' => [
    'web' => [
        'driver' => 'session',
        'provider' => 'users',
    ],
    'sanctum' => [
        'driver' => 'sanctum',
        'provider' => 'users',
    ],
],
```

- The **`web`** guard is used by browser routes that render HTML or rely on cookies
  (Vue cabinet server-rendered shell, email verification links, password reset links).
- The **`sanctum`** guard is used by all `/api/v1/*` JSON routes consumed by Flutter and by
  the Vue SPA when it operates as an API client.

The `users` provider is the default Eloquent provider on `App\Models\User`, which uses UUID
primary keys (`HasUuids`) and the `HasApiTokens` and `HasRoles` traits.

API routes are mounted on a dedicated API host (`APP_DOMAIN_API`) under the `api` middleware
group. Web routes are mounted on the primary web host under the `web` middleware group. The
two hosts are separated so that cookie/session middleware is never applied to API traffic and
Bearer-token middleware is never applied to browser traffic.

## 3. Registration

### 3.1 Email/password registration

`POST /api/v1/auth/register`

Request body:

```json
{
  "username": "jane_doe",
  "email": "jane@example.com",
  "password": "********"
}
```

Validation rules (enforced server-side in `RegisterRequest`):

| Field | Rules |
|-------|-------|
| `username` | required, string, 6–20 chars, `^[a-z0-9_]+$`, unique (case-insensitive) |
| `email` | required, email, unique |
| `password` | required, string, min length per password policy |

`RegisterUserAction` creates the user inside a database transaction. The `username` is
lowercased before persistence. On success the response is `201 Created`:

```json
{
  "user": { "id": "uuid", "username": "jane_doe", "email": "jane@example.com", "..." : "..." },
  "token": "1|abcdef0123456789..."
}
```

The token is a Sanctum personal access token named `auth`. Its `plainTextToken` is returned
**exactly once**. The server stores only the SHA-256 hash of the token; the plaintext is never
persisted and never logged.

A username availability check is available without authentication:

`GET /api/v1/auth/username/check?username=jane_doe` → `200 {"available": true}`

### 3.2 OAuth registration

OAuth providers do not have a separate registration endpoint. A user is created on first
successful OAuth login. See [`oauth.md`](./oauth.md).

## 4. Login

`POST /api/v1/auth/login`

Request body:

```json
{
  "email": "jane@example.com",
  "password": "********"
}
```

The `LoginRequest` form request enforces rate limiting (`throttle` + `ensureIsNotRateLimited`)
on failed attempts. Credentials are verified via `Auth::attempt` against the `web` provider's
credential store (the same `users` table). On failure the response is `422` with
`{"message": "auth.failed"}`. On success a new Sanctum token named `auth` is issued:

```json
{
  "user": { "..." : "..." },
  "token": "2|abcdef0123456789..."
}
```

The plaintext token is returned exactly once.

## 5. Token Model

### 5.1 Storage

Tokens are stored in the `personal_access_tokens` table:

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | Auto-increment primary key |
| `tokenable_type` / `tokenable_id` | polymorphic | `App\Models\User` + UUID |
| `name` | text | Human label, e.g. `auth`, `vk_login`, `yandex_login`, `ios-iphone-15` |
| `token` | string(64), unique | SHA-256 hash of the plaintext token |
| `abilities` | text, nullable | JSON array of abilities (default `["*"]`) |
| `last_used_at` | timestamp, nullable | Updated on token use |
| `expires_at` | timestamp, nullable, indexed | Optional expiry |
| `created_at` / `updated_at` | timestamps | |

### 5.2 Plaintext format

Sanctum's plaintext token format is `{id}|{sha256-hashed-random}`. The client treats this
string as opaque and sends it verbatim in the `Authorization` header:

```
Authorization: Bearer 2|abcdef0123456789...
```

### 5.3 No refresh tokens

The prototype deliberately does **not** use refresh tokens. Rationale:

- A single long-lived token simplifies the mobile client (no token-refresh interceptor, no
  race between concurrent refreshes).
- Revocation is explicit and device-scoped (see §7).
- Token theft risk is mitigated by short-lived optional expiry, secure storage on the client,
  and device-list revocation, not by rotation.

If a stolen-token rotation strategy becomes a requirement, it must be introduced via an ADR
that defines the refresh flow, the token family, and reuse detection.

## 6. Token Lifetime and Expiry

| Parameter | Default | Configurable via |
|-----------|---------|------------------|
| Token expiry (`expires_at`) | Optional; set per token at creation if policy requires | `Sanctum::useExpiry()` + token creation args |
| Expiration enforcement | `expires_at` is checked on every authenticated request | Sanctum middleware |
| `last_used_at` update | Updated on each authenticated API request | Sanctum |

Recommended policy (apply when hardening):

- Mobile tokens: 90-day rolling expiry, refreshed by re-issue on `expires_at` approach.
- Web SPA tokens: 7-day expiry, re-issued on session extension.
- OAuth-issued tokens: same lifetime as password-issued tokens.

Expiry is **not** a substitute for revocation. A compromised token must be revoked explicitly.

## 7. Token Creation and Revocation

### 7.1 Creation

Tokens are created with `$user->createToken($name, $abilities = ['*'])`. The `name` SHOULD be
device-descriptive for user-facing token management, e.g. `ios-iphone-15` or `web-chrome`.
The prototype currently uses generic names (`auth`, `vk_login`, `yandex_login`); device-scoped
names are the target state.

### 7.2 Revocation endpoints

| Action | Endpoint | Effect |
|--------|----------|--------|
| Logout current device | `POST /api/v1/auth/logout` | Deletes the token used by the current request (`currentAccessToken()->delete()`) |
| Logout all devices | `POST /api/v1/auth/logout-all` | Deletes **all** tokens for the user (`tokens()->delete()`) |

Both require `auth:sanctum`. Both return `200 {"message": "..."}`.

### 7.3 Programmatic revocation

Application code may revoke tokens directly:

```php
$user->tokens()->where('id', $tokenId)->delete();        // revoke one
$user->tokens()->where('name', 'web-chrome')->delete();  // revoke by device
$user->tokens()->delete();                               // revoke all
```

Revocation is immediate and durable (a `DELETE` against `personal_access_tokens`). A revoked
token is rejected on the next authenticated request with `401`.

## 8. Device and Session Management

### 8.1 Token-as-device model

Because each token corresponds to one login on one device, the token list **is** the device
list. The target UI surface is:

`GET /api/v1/auth/devices` → list of `{ id, name, last_used_at, created_at, expires_at }`

`DELETE /api/v1/auth/devices/{id}` → revoke a specific device

(These endpoints are not yet implemented in the prototype; they are the contracted target.)

### 8.2 Web sessions

Web sessions are stored in the `sessions` table (database driver). The `user_id` column is
indexed for per-user session lookup. Web session management (logout from other browser tabs)
is handled by Laravel's session driver and is separate from Sanctum token management.

### 8.3 Naming convention

Token names SHOULD follow `<platform>-<device>` (e.g. `ios-iphone-15`, `android-pixel-8`,
`web-chrome`, `web-firefox`). Generic names (`auth`) are accepted for backward compatibility
but must not be used for new logins once device naming is implemented.

## 9. Password Recovery Flow

The flow follows Laravel's standard reset pipeline, adapted to a JSON + deep-link client.

### 9.1 Request a reset link

`POST /api/v1/auth/forgot-password`

```json
{ "email": "jane@example.com" }
```

- Always returns `200` regardless of whether the email exists, to prevent email enumeration.
- If the email exists, a signed reset link is generated and sent via a queued notification.
- The reset token is stored in `password_reset_tokens` (email → hashed token).

### 9.2 Reset password

`POST /api/v1/auth/reset-password`

```json
{ "token": "...", "email": "jane@example.com", "password": "********" }
```

- Validates the token against `password_reset_tokens`.
- On success: updates the user's password, invalidates the reset token, and **revokes all
  existing Sanctum tokens** for the user (forced re-login on every device).
- Returns `200 {"message": "password.reset"}`.

### 9.3 Invalidation on password change

Any password change — via reset, via `PUT /api/v1/auth/password`, or via an admin action —
MUST revoke all of the user's tokens except optionally the token used by the requesting
device. This limits the blast radius of a compromised password.

## 10. Email Verification

### 10.1 Marking

New email/password registrations start with `email_verified_at = null`. OAuth users created
from a provider that returns a verified email MAY be marked verified at creation time, subject
to provider trust policy (see [`oauth.md`](./oauth.md)).

### 10.2 Verification flow

1. `POST /api/v1/auth/email/verification-notification` (authenticated) — queues a signed
   verification link notification. Idempotent; rate-limited.
2. The user clicks the signed link, which hits a web-guard route that verifies the signature,
   marks `email_verified_at = now()`, and redirects to the app.
3. `GET /api/v1/auth/me` exposes `email_verified_at` so the client can gate features that
   require a verified email.

### 10.3 Feature gating

Features that send invitations, perform email-based recovery, or expose public profile
contact points MUST require a verified email. The check is enforced server-side via
middleware or policy, never only on the client.

## 11. The `/auth/me` Endpoint

`GET /api/v1/auth/me` (requires `auth:sanctum`) returns the authenticated user:

```json
{
  "user": {
    "id": "uuid",
    "name": "Jane",
    "username": "jane_doe",
    "email": "jane@example.com",
    "email_verified_at": "2025-11-20T12:00:00Z",
    "vk_id": null,
    "yandex_id": null,
    "roles": ["User"],
    "permissions": ["..."]
  }
}
```

`roles` and `permissions` are included so the client can render UX affordances. They are
**not** authoritative; see [`authorization.md`](./authorization.md).

## 12. Client Credential Storage

### 12.1 Mobile (Flutter)

- The Sanctum plaintext token is stored in **`flutter_secure_storage`** (Keystore/Keychain).
- It MUST NOT be stored in `SharedPreferences`, Drift, plain files, logs, or analytics.
- On logout, the token is removed from secure storage before the `/auth/logout` call is made
  (or immediately after, with a best-effort network call).
- On "logout all", the local token is removed and the server is asked to delete every token.

### 12.2 Web (Vue 3)

- The web cabinet uses session cookies set by the `web` guard. The browser handles storage.
- If the Vue SPA consumes the API directly with a Bearer token, the token MUST be held in
  memory or in a `HttpOnly` cookie; it MUST NOT be persisted in `localStorage` or
  `sessionStorage` for production deployments.

## 13. Security Considerations

1. **HTTPS is mandatory.** Tokens and session cookies must never transit an unencrypted
   channel. HSTS is enabled at the reverse proxy.
2. **Tokens are bearer credentials.** Treat them as passwords. Never log the plaintext token,
   never put it in URLs, never echo it in error responses.
3. **Rate limiting** is applied to login, registration, username check, and OAuth endpoints
   (`throttle:10,1` on OAuth; `ensureIsNotRateLimited` on login). Sensitive endpoints may use
   stricter limits.
4. **Password hashing** uses Laravel's default bcrypt driver via the `hashed` cast on the
   `password` attribute. Do not bypass the cast.
5. **Email enumeration** is mitigated: `forgot-password` returns a constant response;
   `username/check` is the only endpoint that intentionally reveals username availability
   (required by the registration UX).
6. **CSRF** protection applies to the `web` guard and any cookie-authenticated mutation. API
   routes under `sanctum` are CSRF-exempt because they use Bearer tokens, not cookies.
7. **Token revocation on security events**: password reset, password change, suspected
   compromise (admin action), and role downgrade MUST revoke tokens as described in §9.3.
8. **No client-trusted auth state.** The client may cache `roles`/`permissions` for UX, but
   every protected operation is re-authorized server-side.
9. **Logging hygiene.** `AuthController` and `SocialAuthController` must never log the
   plaintext token, the password, or the full provider access token. The existing VK logging
   logs the provider's response body, not the access token; this must be preserved.
10. **Session fixation** is mitigated by Laravel's `RegenerateSessionId` on login and on
    privilege change.

## 14. Endpoint Reference

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `POST` | `/api/v1/auth/register` | none | Email/password registration |
| `GET` | `/api/v1/auth/username/check` | none | Username availability |
| `POST` | `/api/v1/auth/login` | none | Email/password login |
| `POST` | `/api/v1/auth/vk` | none (throttled) | Exchange VK access token for Sanctum token |
| `POST` | `/api/v1/auth/yandex` | none (throttled) | Exchange Yandex access token for Sanctum token |
| `GET` | `/api/v1/auth/me` | `sanctum` | Current user + roles + permissions |
| `POST` | `/api/v1/auth/logout` | `sanctum` | Revoke current token |
| `POST` | `/api/v1/auth/logout-all` | `sanctum` | Revoke all tokens |
| `POST` | `/api/v1/auth/forgot-password` | none | Send password reset link |
| `POST` | `/api/v1/auth/reset-password` | none | Reset password (revokes all tokens) |
| `PUT` | `/api/v1/auth/password` | `sanctum` | Change password (revokes other tokens) |
| `POST` | `/api/v1/auth/email/verification-notification` | `sanctum` | Resend verification email |
| `GET` | `/api/v1/auth/devices` | `sanctum` | List active tokens (target) |
| `DELETE` | `/api/v1/auth/devices/{id}` | `sanctum` | Revoke a specific token (target) |

## 15. Non-Goals

- No OAuth2 refresh-token flow.
- No multi-factor authentication in the prototype. MFA is a future capability and must be
  introduced via ADR.
- No token rotation / token families. Revocation is explicit.
- No anonymous/public authentication. All protected resources require a valid token or
  session.
