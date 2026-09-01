# OAuth Integration

> **Authority:** This document defines OAuth integration for ЧтоХочу. It is normative for the
> mobile (Flutter) and web (Vue 3) clients and the Laravel backend. See
> [`authentication.md`](./authentication.md) for the token model and [`authorization.md`](./authorization.md)
> for post-login authorization.

## 1. Overview

ЧтоХочу supports two OAuth providers:

| Provider | Used for | Config key |
|----------|----------|------------|
| VK (ВКонтакте) | Social login / registration | `services.vk`, `services.vkontakte` |
| Yandex | Social login / registration | `services.yandex` |

Both providers use the **access-token exchange** pattern, not the authorization-code-with-redirect
pattern. The client obtains a provider access token and POSTs it to the backend, which validates
it against the provider's API, resolves or creates a local user, and issues a ЧтоХочу Sanctum
token. This keeps the redirect/consent UX inside the client (Flutter WebView or Yandex SDK) and
keeps the backend stateless with respect to OAuth redirects.

### 1.1 Endpoints

| Method | Path | Throttle | Purpose |
|--------|------|----------|---------|
| `POST` | `/api/v1/auth/vk` | `throttle:10,1` | Exchange VK access token for a Sanctum token |
| `POST` | `/api/v1/auth/yandex` | `throttle:10,1` | Exchange Yandex access token for a Sanctum token |

Both are unauthenticated (no Bearer token required) and are rate-limited to 10 requests per
minute per IP to brute-force provider tokens.

## 2. VK OAuth Flow

### 2.1 Client side (Flutter)

1. The Flutter app opens a `WebViewWidget` to VK's authorize URL:
   ```
   https://oauth.vk.com/authorize
     ?client_id={VK_APP_ID}
     &redirect_uri={VK_REDIRECT_URI}
     &response_type=token
     &scope=email
     &v=5.199
   ```
2. VK authenticates the user and redirects to `{VK_REDIRECT_URI}#access_token=...&user_id=...&email=...`.
   The access token is returned in the **URL fragment**, not as a query parameter, so the
   redirect target does not receive it server-side.
3. The WebView's navigation listener intercepts the redirect, parses the fragment, extracts
   `access_token`, and closes the WebView.
4. The Flutter app POSTs `{"access_token": "..."}` to `POST /api/v1/auth/vk`.
5. On success it stores the returned Sanctum token in `flutter_secure_storage` and navigates
   to the home route. On failure it shows the OAuth error card with a retry button.

### 2.2 Backend side (`SocialAuthController::vk`)

1. Validate the request: `access_token` is required, string.
2. Call `fetchVkProfile($accessToken)`, which requests
   `https://api.vk.com/method/users.get` with `fields=id,first_name,last_name,photo_200,domain`
   and the configured API version (`VK_API_VERSION`, default `5.199`).
3. If the response is not OK, contains `error`, or has no `response[0]`, return `null` →
   throw a `ValidationException` with `auth.social_failed` for provider `VK` (→ `422`).
4. Extract `id`, `first_name`, `last_name`, `domain`. VK does not always return `email` via
   `users.get`; if email is absent, a synthetic local email `vk_{id}@vk.local` is used so the
   `users.email` unique constraint is satisfied.
5. Look up an existing user by `vk_id`, or by `email` when email is present and real.
6. Inside a `DB::transaction`:
   - If no existing user: create one with `name`, generated unique `username`, `email`,
     random bcrypt password, and `vk_id`.
   - If an existing user: update `name`, `email`, and `vk_id` (only non-null values via
     `array_filter`); backfill `username` if missing.
7. Issue a Sanctum token named `vk_login` and return `200 {"user": ..., "token": "..."}`.

### 2.3 Username generation

Because VK users may not have a usable username, the backend generates one:

- Base: the VK `domain` if present, else the email local part, else `vk_{id}`.
- Normalize: lowercase, replace non-`[a-z0-9_]` with `_`, trim underscores, pad to ≥6 chars
  with a random suffix, truncate to 20 chars.
- Uniquify: append `_2`, `_3`, ... until the username is free.

The generated username satisfies the same `^[a-z0-9_]+$` / 6–20 char constraint as
email/password registration.

## 3. Yandex OAuth Flow

### 3.1 Client side (Flutter)

1. The Flutter app opens a `WebViewWidget` to Yandex's authorize URL:
   ```
   https://oauth.yandex.ru/authorize
     ?client_id={YANDEX_CLIENT_ID}
     &response_type=token
     &scope=login:email login:info
   ```
2. Yandex authenticates the user and redirects to `{YANDEX_REDIRECT_URI}#access_token=...`.
   The token is in the URL fragment.
3. The WebView navigation listener intercepts the redirect, parses the fragment, extracts
   `access_token`, and closes the WebView.
4. The Flutter app POSTs `{"access_token": "..."}` to `POST /api/v1/auth/yandex`.
5. On success it stores the Sanctum token and navigates home; on failure it shows the error
   card with retry.

### 3.2 Backend side (`SocialAuthController::yandex`)

1. Validate the request: `access_token` is required, string.
2. Resolve the Yandex profile via `Socialite::driver('yandex')->userFromToken($accessToken)`.
   Socialite calls Yandex's user info endpoint and returns a `User` object with `id`,
   `email`, `nickname`, `name`, and the raw `user` array.
3. On any throwable from Socialite, log the error message (not the token) and throw
   `ValidationException` with `auth.social_failed` for provider `Яндекс` (→ `422`).
4. Extract `id`, `email`, `name` (resolved via `resolveYandexName`, which tries `name`,
   `real_name`, `display_name`, `first_name+last_name`, then email local part), and
   `yandex_login` (nickname or `login`).
5. If `id` is missing, throw `auth.social_no_id` (→ `422`).
6. Look up an existing user by `yandex_id`, or by `email` when present and real.
7. Inside a `DB::transaction`:
   - If no existing user: create one with `name`, generated unique `username`, `email`
     (or `yandex_{id}@yandex.local` synthetic), random bcrypt password, and `yandex_id`.
   - If an existing user: update `name`, `email`, `yandex_id` (non-null only); backfill
     `username` if missing.
8. Issue a Sanctum token named `yandex_login` and return `200 {"user": ..., "token": "..."}`.

## 4. Token Exchange Contract

### 4.1 Request

```http
POST /api/v1/auth/vk HTTP/1.1
Content-Type: application/json

{ "access_token": "vk1.a.MjA..." }
```

```http
POST /api/v1/auth/yandex HTTP/1.1
Content-Type: application/json

{ "access_token": "y0_AgAAA..." }
```

### 4.2 Success response (`200`)

```json
{
  "user": {
    "id": "uuid",
    "name": "Иван",
    "username": "ivan_petrov",
    "email": "ivan@example.com",
    "email_verified_at": "2025-11-20T12:00:00Z",
    "vk_id": "12345678",
    "yandex_id": null,
    "roles": ["User"],
    "permissions": ["..."]
  },
  "token": "3|abcdef0123456789..."
}
```

The `token` is a Sanctum personal access token. It is treated identically to a
password-issued token: stored in `flutter_secure_storage`, sent as `Authorization: Bearer`,
revocable via `/auth/logout` and `/auth/logout-all`.

### 4.3 Failure responses

| Status | Condition | Body |
|--------|-----------|------|
| `422` | Invalid provider token / provider error / no provider id | `{"message": "...", "errors": {"access_token": ["..."]}}` |
| `429` | Throttle exceeded | `{"message": "Too many requests."}` |
| `422` | Missing `access_token` | `{"message": "...", "errors": {"access_token": ["..."]}}` |

## 5. Account Linking and Email Collision

The lookup logic intentionally matches on `vk_id`/`yandex_id` **or** on a real `email`:

```php
User::query()
    ->where('vk_id', $providerId)
    ->when($email, fn($q) => $q->orWhere('email', $email))
    ->first();
```

Consequences:

- A user who previously registered by email and later logs in with VK/Yandex using the same
  email is **linked** to the existing account (the provider id is backfilled onto it).
- A user who logs in with VK/Yandex and no shared email creates a **new** account with a
  synthetic local email (`vk_{id}@vk.local` or `yandex_{id}@yandex.local`).
- Synthetic emails are unique by construction (the provider id is unique) and never collide
  with real emails because they use the reserved `@vk.local` / `@yandex.local` domains.

If a future requirement allows a user to merge accounts, it must be implemented as an
explicit merge flow with email verification, not as an implicit side effect of OAuth login.

## 6. Email Verification for OAuth Users

- VK and Yandex do not guarantee verified emails via the access-token exchange path.
- OAuth-created users start with `email_verified_at = null` unless the provider explicitly
  asserts verification and the trust policy accepts it. The current prototype does **not**
  auto-verify OAuth emails.
- Synthetic local emails (`@vk.local`, `@yandex.local`) are never verified.
- OAuth users who later add/verify a real email follow the standard email verification flow
  (see [`authentication.md`](./authentication.md) §10).

## 7. WebView Usage in Flutter

### 7.1 Why WebView

VK and Yandex OAuth require a browser context for consent and cookie-based session. Flutter
uses `WebViewWidget` (from `webview_flutter`) rather than a platform browser tab because the
app must intercept the redirect and extract the access token from the URL fragment. A
platform browser tab does not reliably expose the fragment to the app.

### 7.2 Implementation contract

- The `OAuthPage` widget hosts a `WebViewWidget` and a navigation delegate.
- The navigation delegate watches for navigations to `{VK_REDIRECT_URI}` / `{YANDEX_REDIRECT_URI}`
  and parses the fragment **before** allowing the navigation to complete. The redirect target
  itself does not need to exist as a real page; it is a sentinel.
- On success: extract `access_token`, close the WebView, call the exchange endpoint, store
  the Sanctum token, navigate to home.
- On user cancel (close button): pop the page, no token exchange.
- On provider error in the fragment (`error=...`): show the error card with retry.
- The WebView must not persist cookies between sessions for the OAuth provider; clear the
  WebView cookie store on open so each login is a fresh consent.

### 7.3 Security constraints

- The redirect URI must use `https` in production. Custom-scheme redirects are not used
  because they can be intercepted by other apps on Android.
- The WebView must not expose the access token to JavaScript running in the page. The token
  is extracted from the navigation URL by the Dart-side delegate, not by injected JS.
- The extracted provider access token is held in memory only for the duration of the
  exchange request. It is never written to disk, never logged, never sent anywhere except
  `/api/v1/auth/{provider}`.
- The returned Sanctum token is stored in `flutter_secure_storage`, same as password login.

## 8. Redirect Handling

### 8.1 Backend

The backend does **not** participate in OAuth redirects. There is no `/oauth/callback` route.
The configured `VK_REDIRECT_URI` / `YANDEX_REDIRECT_URI` are sentinel URLs the client
intercepts; they may resolve to a minimal static page that says "Return to the app" but the
backend does not process the fragment.

### 8.2 Client

The client registers the redirect URI as a navigation sentinel in the WebView delegate. The
URI scheme/host must match exactly what is registered with the provider's developer console.

### 8.3 Web (Vue 3)

The web cabinet may use the same access-token exchange pattern by opening the provider
authorize URL in a popup and reading the fragment via `postMessage`. Alternatively, the web
cabinet may use the authorization-code flow with a real backend callback; if so, that flow
must be documented in an ADR and must not change the mobile contract.

## 9. Configuration

Required environment variables:

```dotenv
# VK
VK_APP_ID=...
VK_APP_SECRET=...
VK_SERVICE_TOKEN=...
VK_API_VERSION=5.199
VK_REDIRECT_URI=https://app.chtohochu.ru/oauth/vk/redirect

# Yandex
YANDEX_CLIENT_ID=...
YANDEX_CLIENT_SECRET=...
YANDEX_REDIRECT_URI=https://app.chtohochu.ru/oauth/yandex/redirect
```

The `services.vk` block holds the API-call credentials used by `fetchVkProfile`. The
`services.vkontakte` block holds the Socialite OAuth credentials (used by the web flow if
enabled). The `services.yandex` block holds the Socialite credentials used by
`Socialite::driver('yandex')`.

## 10. Security Considerations

1. **The provider access token is a secret.** It is sent only to `/api/v1/auth/{provider}`
   over HTTPS and is never logged. The existing VK logging logs the `users.get` response
   body, not the access token; this must be preserved in any refactor.
2. **Provider token validation is server-side.** The backend does not trust the client's
   claim about the user's identity; it calls the provider's API with the token and uses the
   returned `id` as the source of truth.
3. **Throttling.** The exchange endpoints are rate-limited to 10/min/IP to resist
   token-guessing and enumeration.
4. **Account takeover via email collision.** Linking on email is convenient but carries
   takeover risk if an attacker controls the email account at the provider. Mitigation:
   VK/Yandex `id` is the primary link key; email is only a secondary match. If a
   high-risk operation is gated on email-based linking in the future, it must require email
   verification first.
5. **Synthetic emails** (`@vk.local`, `@yandex.local`) must never be deliverable. They exist
   only to satisfy the `users.email` unique constraint. They must not be used for
   notifications; notifications to OAuth-only users without a real email must be suppressed
   or routed to in-app only.
6. **Token revocation on link/unlink.** Linking a new provider to an existing account does
   not revoke existing tokens. Unlinking a provider (a future capability) must not lock the
   user out if they have a password; if they have no password and no other provider, unlink
   must be refused.
7. **No silent re-linking.** If a provider login matches an existing account by email but
   the account already has a different `vk_id`/`yandex_id`, the backend must refuse the
   link rather than overwrite it. (The current `array_filter` + `?:` logic preserves the
   existing id; this behavior must be covered by a test.)

## 11. Testing

- For each provider: happy path (new user), happy path (existing user by provider id),
  existing user by email (linking), missing provider id (422), invalid token (422),
  throttle (429 after 10 attempts).
- Username generation: collisions, short bases, non-Latin input.
- Synthetic email uniqueness across providers.
- Account linking does not overwrite an existing provider id.
- The `/auth/me` response after OAuth login includes correct roles/permissions.
