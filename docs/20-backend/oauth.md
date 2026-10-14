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

| Method | Path | Auth | Throttle | Purpose |
|--------|------|------|----------|---------|
| `POST` | `/api/v1/auth/vk` | — | `throttle:10,1` | Exchange VK access token for a Sanctum token |
| `POST` | `/api/v1/auth/yandex` | — | `throttle:10,1` | Exchange Yandex access token for a Sanctum token |
| `POST` | `/api/v1/auth/vk/link` | Sanctum | `throttle:10,1` | Confirmed linking of a VK account to the current user |
| `POST` | `/api/v1/auth/yandex/link` | Sanctum | `throttle:10,1` | Confirmed linking of a Yandex account to the current user |

The exchange endpoints are unauthenticated (no Bearer token required); the link endpoints
require an authenticated session and are the **only** way to connect a provider to an
existing account — see [§5](#5-account-linking-and-email-collision). All endpoints are
rate-limited to resist provider-token brute-forcing.

## 2. VK OAuth Flow

### 2.1 Client side (Flutter)

1. The Flutter app opens `OAuthPage` — an incognito `InAppWebView`
   (`flutter_inappwebview`, already used for link previews) — to VK's authorize URL:
   ```
   https://oauth.vk.com/authorize
     ?client_id={VK_APP_ID}
     &redirect_uri={VK_REDIRECT_URI}
     &response_type=token
     &scope=email
     &v=5.199
     &display=mobile
     &state={STATE}
   ```
   `VK_APP_ID` is supplied via `--dart-define` (public identifier, not a secret).
   `STATE` is a one-time random value generated per flow.
2. VK authenticates the user and redirects to `{VK_REDIRECT_URI}#access_token=...&user_id=...&email=...&state=...`.
   The access token is returned in the **URL fragment**, not as a query parameter, so the
   redirect target does not receive it server-side.
3. The WebView's navigation delegate intercepts the redirect, verifies `state` matches the
   value issued in step 1 (a mismatch or provider `error=` is a failure, not a login),
   parses the fragment, extracts `access_token` and `email`, and closes the WebView.
4. The Flutter app POSTs `{"access_token": "...", "email": "..."}` to
   `POST /api/v1/auth/vk` (`email` is forwarded when present — see §2.2).
5. On success it stores the returned Sanctum token in `flutter_secure_storage` and the
   router redirect navigates to the app. On failure it shows the error feedback with retry;
   closing the WebView without a token is a silent cancel.

### 2.2 Backend side (`SocialAuthController::vk`)

1. Validate the request: `access_token` required string, `email` nullable `email|max:255`.
2. Call `fetchVkProfile($accessToken)`, which requests
   `https://api.vk.com/method/users.get` with `fields=id,first_name,last_name,photo_200,domain`
   and the configured API version (`VK_API_VERSION`, default `5.199`).
3. If the response is not OK, contains `error`, or has no `response[0]`, return `null` →
   throw a `ValidationException` with `auth.social_failed` for provider `VK` (→ `422`).
4. Extract `id`, name (`first_name last_name`), `domain`, `photo_200` (→ `avatar_url`).
   `users.get` never returns `email`; the client forwards the email from the redirect
   fragment. If email is absent entirely, a synthetic local email `vk_{id}@vk.local` is used
   so the `users.email` unique constraint is satisfied.
5. Look up an existing user **only** by `vk_id` — never by email (see §5).
   - No match and the (real) email already belongs to an account → `409`
     `{"message": ..., "code": "oauth_link_required"}` — confirmed linking required.
   - No match → create a user inside `DB::transaction` with `name`, generated unique
     `username`, `email` (real or synthetic), random bcrypt password, `vk_id`, `avatar_url`.
   - Match → **backfill only empty fields** (`name`, `avatar_url`, `username`). The
     provider never overwrites an edited profile and never changes the account email.
6. Issue a Sanctum token named `vk_login` and return `200 {"data": {"token": ..., "user": ...}}` —
   the same envelope as `register`/`login` (`UserResource` fields; provider ids are not
   leaked).

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

1. The Flutter app opens `OAuthPage` (incognito `InAppWebView`) to Yandex's authorize URL:
   ```
   https://oauth.yandex.ru/authorize
     ?client_id={YANDEX_CLIENT_ID}
     &response_type=token
     &redirect_uri={YANDEX_REDIRECT_URI}
     &scope=login:email login:info
     &state={STATE}
   ```
   `YANDEX_CLIENT_ID` is supplied via `--dart-define`.
2. Yandex authenticates the user and redirects to `{YANDEX_REDIRECT_URI}#access_token=...&state=...`.
   The token is in the URL fragment.
3. The WebView navigation delegate intercepts the redirect, verifies `state`, parses the
   fragment, extracts `access_token`, and closes the WebView. The Yandex fragment carries
   no `email` — the backend obtains it from the provider profile.
4. The Flutter app POSTs `{"access_token": "..."}` to `POST /api/v1/auth/yandex`.
5. Same as VK: store the Sanctum token; error feedback with retry; silent cancel on close.

### 3.2 Backend side (`SocialAuthController::yandex`)

1. Validate the request: `access_token` is required, string.
2. Resolve the Yandex profile via `Socialite::driver('yandex')->userFromToken($accessToken)`.
   On any throwable, log the error message (not the token) and throw `ValidationException`
   with `auth.social_failed` (→ `422`).
3. Extract `id`, `email`, `name` (resolved via `resolveYandexName`), `login` (nickname or
   `login`), `avatar`. If `id` is missing → `auth.social_no_id` (→ `422`).
4. Look up an existing user **only** by `yandex_id` — never by email (see §5).
   - No match and the provider email already belongs to an account → `409`
     `oauth_link_required`.
   - No match → create a user with `name`, generated unique `username`, `email` (real or
     `yandex_{id}@yandex.local` synthetic), random password, `yandex_id`, `avatar_url`.
   - Match → backfill empty fields only (name/avatar/username); email never changes.
5. Issue a Sanctum token named `yandex_login` and return the same `{data: {token, user}}`
   envelope as `register`/`login`.

## 4. Token Exchange Contract

### 4.1 Request

```http
POST /api/v1/auth/vk HTTP/1.1
Content-Type: application/json

{ "access_token": "vk1.a.MjA...", "email": "ivan@mail.ru" }
```

`email` is optional and used only for VK — it arrives in the provider's redirect fragment
and `users.get` cannot return it. Yandex requests carry `access_token` only; the email is
resolved server-side from the provider profile.

```http
POST /api/v1/auth/yandex HTTP/1.1
Content-Type: application/json

{ "access_token": "y0_AgAAA..." }
```

### 4.2 Success response (`200`)

Same envelope as `register`/`login` — `UserResource` fields, provider ids never exposed:

```json
{
  "data": {
    "token": "3|abcdef0123456789...",
    "user": {
      "id": "uuid",
      "email": "ivan@example.com",
      "name": "Иван",
      "username": "ivan_petrov",
      "avatar_url": "https://...",
      "created_at": "2025-11-20T12:00:00Z",
      "updated_at": "2025-11-20T12:00:00Z"
    }
  }
}
```

The `token` is a Sanctum personal access token. It is treated identically to a
password-issued token: stored in `flutter_secure_storage`, sent as `Authorization: Bearer`,
revocable via `/auth/logout` and `/auth/logout-all`.

### 4.3 Failure responses

| Status | Condition | Body |
|--------|-----------|------|
| `422` | Missing `access_token` | `{"message": "...", "errors": {"access_token": ["..."]}}` |
| `422` | Invalid provider token / provider error / no provider id | `{"message": "...", "errors": {"access_token": ["..."]}}` |
| `409` | Provider email belongs to an existing unlinked account | `{"message": "...", "code": "oauth_link_required"}` |
| `429` | Throttle exceeded | `{"message": "Too many requests."}` |

The client maps `oauth_link_required` to a message explaining that the user should sign in
with email and link the provider in the profile (see §5).

## 5. Account Linking and Email Collision

Login resolves users **only** by `vk_id`/`yandex_id`. There is deliberately **no**
auto-linking by email match: provider emails on the access-token path are not
verified by the backend, and implicit linking would let an account be captured via a
foreign provider profile that happens to share the address.

- Login, provider id unknown and no email collision → a **new** account is created with a
  real provider email or a synthetic local email (`vk_{id}@vk.local`,
  `yandex_{id}@yandex.local`; unique by construction, never deliverable).
- Login, provider id unknown and the email matches an existing account → `409
  oauth_link_required`, no token issued, nothing is written.
- Linking an existing account is only possible through the **confirmed** flow:
  the user first authenticates (any method), then calls `POST /auth/{provider}/link`
  with a provider access token obtained through the same WebView flow. The client exposes
  this as «Привязать VK / Привязать Яндекс» in Profile → Account.

### 5.1 Link endpoint contract

```http
POST /api/v1/auth/{provider}/link
Authorization: Bearer <sanctum-token>
Content-Type: application/json

{ "access_token": "...", "email": "..." /* optional, VK only */ }
```

Success `200`: `{"data": {"user": {...UserResource...}}}` — the updated profile (the link
also backfills empty `name`/`avatar_url`/`username`). The call is **idempotent**: linking
the same provider account again succeeds as a no-op.

| Status | Condition | Body `code` |
|--------|-----------|-------------|
| `401` | Unauthenticated | — |
| `422` | Missing/invalid provider token | `access_token` validation error |
| `409` | Provider account is linked to a **different** user | `oauth_provider_taken` |
| `409` | User already has a **different** account of this provider | `oauth_already_linked` |

Unlink is a future capability (§10.6): it must refuse to remove the last auth method of an
account and requires distinguishing user-set passwords from generated ones.

## 6. Email Verification for OAuth Users

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
uses `InAppWebView` (from `flutter_inappwebview`, already used for link previews — the doc
previously named `webview_flutter`; the navigation-delegate contract is identical) rather
than a platform browser tab because the app must intercept the redirect and extract the
access token from the URL fragment. A platform browser tab does not reliably expose the
fragment to the app.

### 7.2 Implementation contract

- `OAuthPage` (`features/auth/presentation/pages/oauth_page.dart`) hosts an `InAppWebView`
  and a navigation delegate (`shouldOverrideUrlLoading`).
- The WebView runs in **incognito** mode — provider cookies are not persisted between
  sessions, so each login is a fresh consent.
- The delegate watches for navigations to `{VK|YANDEX}_REDIRECT_URI` and parses the
  fragment **before** allowing the navigation to complete. The redirect target itself does
  not need to exist as a real page; it is a sentinel.
- A one-time `state` is generated per flow and **must** match the value echoed in the
  fragment; mismatch or `error=` in the fragment is a failure, never a login.
- On success: extract `access_token` (and `email` for VK), close the WebView, call the
  exchange endpoint, store the Sanctum token, navigate to home.
- On user cancel (close button): pop the page, no token exchange, no error shown.
- On provider error in the fragment or load failure: show the error card with retry.

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

### 9.1 Backend environment variables

```dotenv
# VK
VK_APP_ID=...
VK_APP_SECRET=...
VK_SERVICE_TOKEN=...
VK_API_VERSION=5.199
VK_CLIENT_ID=...          # Socialite driver (web flow)
VK_CLIENT_SECRET=...
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

### 9.2 Flutter `--dart-define` parameters

| Define | Required | Meaning |
|--------|----------|---------|
| `VK_APP_ID` | for VK login | Public application id of the VK app |
| `YANDEX_CLIENT_ID` | for Yandex login | Public client id of the Yandex app |
| `VK_REDIRECT_URI` | optional | Sentinel redirect, default `https://{app-host}/oauth/vk/redirect` (derived from `API_BASE_URL`: `api.*` → `app.*`) |
| `YANDEX_REDIRECT_URI` | optional | Same pattern, `/oauth/yandex/redirect` |

Client ids are **public identifiers** — they may ship inside the client. Provider secrets
must never be delivered to the client. When a client id is absent from the build, the
corresponding button shows an informational «скоро будет доступно» instead of starting the
flow — the feature degrades gracefully per build.

```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.chtohochu.test \
  --dart-define=VK_APP_ID=... \
  --dart-define=YANDEX_CLIENT_ID=...
```

### 9.3 Owner checklist (external setup)

1. **VK**: create/enable a standalone app at <https://dev.vk.com>; copy `VK_APP_ID`,
   `VK_APP_SECRET`, `VK_SERVICE_TOKEN`; register `VK_REDIRECT_URI`
   (`https://app.chtohochu.ru/oauth/vk/redirect` for prod, `https://app.chtohochu.test/...`
   for a local VK app) in the app's allowed redirect URIs.
2. **Yandex**: create an app at <https://oauth.yandex.ru>; enable scopes `login:email` and
   `login:info`; copy `YANDEX_CLIENT_ID`/`YANDEX_CLIENT_SECRET`; register
   `YANDEX_REDIRECT_URI` as a Callback URI.
3. Fill backend `.env` (§9.1) and pass client dart-defines (§9.2) per environment.

## 10. Security Considerations

1. **The provider access token is a secret.** It is sent only to `/api/v1/auth/{provider}`
   over HTTPS and is never logged. The existing VK logging logs the `users.get` response
   body, not the access token; this must be preserved in any refactor.
2. **Provider token validation is server-side.** The backend does not trust the client's
   claim about the user's identity; it calls the provider's API with the token and uses the
   returned `id` as the source of truth.
3. **Throttling.** The exchange endpoints are rate-limited to 10/min/IP to resist
   token-guessing and enumeration.
4. **Account takeover via email collision.** There is no implicit linking by email:
   provider `id` is the only link key, and connecting a provider to an existing account
   requires the confirmed `/auth/{provider}/link` call inside an authenticated session.
   A `409 oauth_link_required` response reveals account existence — the same information a
   duplicate-email registration already exposes.
5. **Synthetic emails** (`@vk.local`, `@yandex.local`) must never be deliverable. They exist
   only to satisfy the `users.email` unique constraint. They must not be used for
   notifications; notifications to OAuth-only users without a real email must be suppressed
   or routed to in-app only.
6. **Token revocation on link/unlink.** Linking a new provider to an existing account does
   not revoke existing tokens. Unlinking a provider (a future capability) must not lock the
   user out if they have a password; if they have no password and no other provider, unlink
   must be refused — note that OAuth-created users currently carry a random bcrypt
   password, so the lockout check requires distinguishing user-set passwords first.
7. **No silent re-linking.** If the user already has a *different* provider account linked,
   or the provider account belongs to a different user, `/auth/{provider}/link` refuses
   with `409` (`oauth_already_linked` / `oauth_provider_taken`) — the existing id is never
   overwritten. Covered by `SocialAuthApiTest`.
8. **Provider token provenance (client).** The client verifies the `state` echoed in the
   redirect fragment against the value it generated; a fragment without a matching `state`
   or with `error=` is treated as failure, so an attacker cannot inject a foreign
   provider token into the WebView flow.

## 11. Testing

`tests/Feature/SocialAuthApiTest.php` covers, per provider: happy path (new user),
existing user by provider id, email collision → `409 oauth_link_required`, invalid token
→ `422`, missing token → `422`, link attach / idempotency / `oauth_provider_taken` /
`oauth_already_linked` / unauthenticated link → `401`.

Still recommended (not yet covered): throttle `429` after 10 attempts; username
generation edge cases (collisions, short bases, non-Latin); synthetic email uniqueness
across providers.
