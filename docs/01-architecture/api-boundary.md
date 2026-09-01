# API Boundary — ЧтоХочу

> **Status:** Authoritative. The backend API is the shared contract consumed by every
> client. Conflicts with `AGENTS.md` must be resolved via an ADR in `docs/adr/`.

## 1. Purpose

The ЧтоХочу backend exposes a single REST API under `/api/v1/` that is the **shared
contract** between all client applications:

| Consumer | Type | Auth | Transport |
|----------|------|------|-----------|
| `apps/client` | Flutter | Sanctum tokens | REST + WebSocket |
| `apps/public-web` | Nuxt 4 SSR | Sanctum cookie / none (public) | REST + Inertia |
| `apps/seller` | Nuxt 4 SPA | Sanctum tokens | REST + WebSocket |
| `apps/admin` | Nuxt 4 SPA | Sanctum tokens | REST + WebSocket |

The API is the **only** interface between clients and the backend. No client reads
PostgreSQL, Redis, or Reverb directly. The API defines request/response shapes, error
formats, pagination, authentication, and realtime channel authorization.

## 2. The API Is the Contract

The API contract is the single source of truth for inter-application communication.
It is documented in the OpenAPI specification and the `docs/20-backend/` family:

- [`api-versioning.md`](../20-backend/api-versioning.md) — versioning strategy.
- [`api-errors.md`](../20-backend/api-errors.md) — error format.
- [`api.md`](../20-backend/api.md) — endpoint conventions.
- [`realtime-events.md`](../20-backend/realtime-events.md) — WebSocket event envelope.

Clients consume the contract; they do not define it. When a client needs new data or
behaviour, the change starts in the backend and the contract is updated first.

## 3. API Versioning

The API uses **URL-based versioning**: `/api/v1/`, `/api/v2/`. The version segment is
mandatory and visible in every request, log, and trace.

- Minor and patch changes are delivered **additively** under the same `v1` prefix.
- A new major version (`v2`) is a new URL prefix maintained in parallel during a
  deprecation window.
- At most two major versions are supported simultaneously.

See [`api-versioning.md`](../20-backend/api-versioning.md) for the full versioning
policy, compatibility rules, and deprecation process.

## 4. Contract Documentation

The contract is documented in two complementary forms:

| Artifact | Audience | Purpose |
|----------|----------|---------|
| OpenAPI specification (`openapi-v1.yaml`) | Machines, SDK generators | Formal, machine-readable contract |
| `docs/20-backend/*.md` | Engineers | Human-readable rules, conventions, examples |

Rules:

1. **Document first.** The OpenAPI spec and changelog are updated in the same PR that
   adds or changes an endpoint.
2. **The OpenAPI document is the source of truth** for client SDK generation where SDKs
   are used.
3. **The changelog** records every API change (additive or breaking) with a dated entry.
4. Documentation MUST NOT diverge from implementation. A PR that changes behaviour
   without updating the contract is incomplete and must be rejected at review.

## 5. Breaking Change Process

Breaking changes are expensive, especially for released mobile clients that upgrade on
user schedules. They require a **new major version** and a deliberate migration.

1. **Justify.** Document why an additive change or deprecation cannot achieve the goal.
2. **Plan the new version.** Create `/api/v2/` routes in parallel with `/api/v1/`.
3. **Ship `v2` alongside `v1`.** Both versions are served simultaneously.
4. **Deprecate `v1`.** Announce with a `Sunset` date (minimum 12 months for API
   consumers with released mobile clients).
5. **Migrate clients.** Flutter, web, and any external consumers move to `v2` within
   the sunset window.
6. **Retire `v1`.** After sunset, with telemetry confirming negligible usage, remove
   `v1` routes.

See [`api-versioning.md`](../20-backend/api-versioning.md) §5 for the full process and
§2.1 for what counts as a breaking change.

## 6. Client Expectations

### 6.1 Clients MUST

- Send the version prefix in every request (`/api/v1/...`); never call an unversioned URL.
- Ignore unknown response fields (forward compatibility).
- Treat unknown enum values and unknown error codes as the generic fallback; never crash.
- Honor `Deprecation` / `Sunset` headers and migrate within the sunset window.
- Pin to a major version and migrate deliberately.
- Reconcile realtime events against their local store and refetch from the API when
  needed; realtime is transport, not a source of truth.

### 6.2 Clients MUST NOT

- Hard-code the full response shape (use subset assertions; tolerate extra fields).
- Switch on response field *absence* as a feature flag.
- Assume a field's type from a previous response.
- Trust client-side ownership or permission data for security; the backend re-verifies
  authorization on every request.
- Define or extend the API contract unilaterally.

## 7. Authentication Boundary

All authenticated consumers use **Laravel Sanctum**:

- **Flutter, seller, admin** — bearer tokens (API tokens).
- **public-web cabinet** — cookie-based session (Sanctum stateful domains).

OAuth (VK, Yandex) is handled server-side via Laravel Socialite; clients receive a
Sanctum token after the OAuth callback. See
[`authentication.md`](./authentication.md) and [`oauth.md`](../20-backend/oauth.md).

## 8. Realtime Boundary

Realtime events are delivered over **Laravel Reverb** and share the same authorization
rules as REST. Channel authorization is defined in `routes/channels.php` and reuses
Laravel policies/gates.

- Events are broadcast **only after the PostgreSQL transaction commits**.
- The event envelope is defined in
  [`realtime-events.md`](../20-backend/realtime-events.md).
- Clients must survive lost, duplicated, delayed, and out-of-order events.
- Realtime is a delivery mechanism, not a source of truth.

See [`realtime.md`](../20-backend/realtime.md) for backend realtime configuration.

## 9. Boundary Enforcement

| Boundary | Enforcement |
|----------|-------------|
| No direct DB access from clients | PostgreSQL is not exposed outside the Docker internal network |
| Authorization | Backend re-verifies auth, ownership, membership, and permission on every request |
| API versioning | All API routes under `/api/v1/`; breaking changes require a new major version |
| Realtime channel auth | `routes/channels.php` authorizes subscriptions server-side |
| Rate limiting | Laravel throttle middleware on auth and mutation endpoints |
| CORS | Configured per application in the backend |

## 10. Non-Goals

- No GraphQL without an approved ADR.
- No second backend runtime.
- No client-to-client communication; all data flows through the backend.
- No client-defined contract extensions.
