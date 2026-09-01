# API Versioning

> **Authority:** This document defines the API versioning strategy for ЧтоХочу. It is
> normative for all `/api/*` endpoints and for the OpenAPI contract. See
> [`conventions.md`](./conventions.md) and [`errors.md`](./errors.md) for companion rules.

## 1. Strategy

The ЧтоХочу API uses **URL-based versioning**. The version is a mandatory path segment:

```
/api/v1/
```

- The version segment is `v{major}`. There is no minor or patch segment in the URL.
- Minor and patch changes are delivered **additively** under the same `v1` prefix (see §4).
- A new major version (`v2`) is a new URL prefix (`/api/v2/`) that is maintained in parallel
  with `v1` during the deprecation window (see §5).

### 1.1 Why URL versioning

- It is unambiguous and visible in every request, log, and trace.
- It lets `v1` and `v2` coexist on the same infrastructure without content negotiation
  gymnastics.
- It is trivial to route at the reverse proxy and trivial to call from any client.
- It matches the OpenAPI path model 1:1.

### 1.2 What is not used

- **Header-based versioning** (`Accept: application/vnd.chtohochu.v1+json`) is not used. It
  hides the version from logs and is error-prone for mobile clients.
- **Query-based versioning** (`?api_version=1`) is not used. It complicates caching and
  routing.
- **Content negotiation by media type** is not used for versioning; `Content-Type` is
  always `application/json`.

## 2. Backward Compatibility Rules

Within a major version, the API is **backward compatible**. A client written against
`v1.0` must continue to work against any later `v1.x` without code changes.

### 2.1 Compatible (additive) changes

The following changes are allowed within a major version and do **not** require a new
version:

| Change | Allowed? | Notes |
|--------|----------|-------|
| Add a new endpoint | Yes | Additive |
| Add a new optional request field | Yes | Old clients omit it |
| Add a new optional query parameter | Yes | Unknown params are ignored |
| Add a new response field | Yes | Clients ignore unknown fields |
| Add a new enum value | Yes | Clients must treat unknown enum values as "unknown" and not crash |
| Add a new error code | Yes | Clients must treat unknown error codes as the generic HTTP-status fallback |
| Add a new response header | Yes | Clients ignore unknown headers |
| Loosen validation (accept more values) | Yes | e.g. raise a max length |
| Tighten validation (reject more values) | **No** | See §2.2 |
| Change the type of an existing field | **No** | Breaking |
| Remove or rename a field/endpoint/enum value/error code | **No** | Breaking |
| Change a field from optional to required | **No** | Breaking |
| Change default behavior (pagination default, sort order) | **No** | Breaking |
| Change the URL of an existing resource | **No** | Breaking |
| Change the semantics of an existing field | **No** | Breaking (even if the type is unchanged) |
| Change a status code for an existing condition | **No** | Breaking |

### 2.2 Tightening validation is breaking

Loosening validation (accepting more inputs) is additive. **Tightening** validation
(rejecting inputs that were previously accepted) is a breaking change because it can break
clients that were sending the now-rejected input. To tighten validation, either:

1. Introduce a new field/endpoint with the stricter rule and deprecate the old one, or
2. Bump the major version.

### 2.3 New enum values

Adding an enum value is additive **only if** clients handle unknown values gracefully. The
client contract (see [`conventions.md`](./conventions.md) §18) is: unknown enum values
must not crash the client and must be displayed as a fallback label (e.g. "Unknown").
Server-side, enums are stored as strings (or DB enums with a migration path) so adding a
value is a migration, not a schema break.

## 3. Deprecation Policy

### 3.1 Marking deprecation

A deprecated endpoint, field, or parameter is:

- Documented as deprecated in the OpenAPI spec (`deprecated: true`).
- Announced in the changelog.
- Signaled in responses via the `Deprecation` and `Sunset` HTTP headers (RFC 8594 / RFC 9745):

  ```
  Deprecation: @1735689600
  Sunset: Sat, 31 Dec 2026 00:00:00 GMT
  Link: </api/v1/wishes-new>; rel="successor-version"
  ```

- The `Deprecation` header's value is the deprecation timestamp; `Sunset` is the removal
  date. Both are optional but recommended once a successor exists.

### 3.2 Deprecation lifetime

- A deprecated feature is supported (functional, documented) until its `Sunset` date.
- The minimum deprecation window is **6 months** from the deprecation announcement.
- For features known to be used by released mobile clients, the minimum window is
  **12 months**, because mobile clients upgrade on user schedules, not server schedules.
- A deprecated feature is removed only at a **major version bump**. It is never removed
  within `v1`.

### 3.3 Deprecation process

1. Announce deprecation in the changelog and OpenAPI spec.
2. Add `Deprecation` / `Sunset` headers to responses.
3. Notify client teams (Flutter, Web) and update SDK stubs.
4. Track usage via telemetry (endpoint + version). If usage is above a threshold at the
   `Sunset` - 3 months mark, extend the `Sunset` and re-announce.
5. At the next major version, remove the feature from the new version. Keep it in the old
   version until the old version is itself retired (see §5).

## 4. Additive Change Policy

Additive changes are the default way the API evolves within a major version. They are
**low-risk** but not zero-risk. Process:

1. **Document first.** The OpenAPI spec and changelog are updated in the same PR that adds
   the change.
2. **New fields are optional.** A new request field is optional with a sensible default;
   a new response field is simply additional. Never make a new field required at
   introduction.
3. **New endpoints are independently versioned resources.** A new endpoint lives under
   `/api/v1/` and follows the conventions in [`conventions.md`](./conventions.md).
4. **Telemetry before removal.** Before deprecating anything, confirm via telemetry that
   usage is low enough to deprecate, or commit to a long sunset.
5. **Test both shapes.** New response fields are covered by tests that assert the field's
   presence and type; existing tests that assert the full response shape are relaxed to
   ignore extra fields (use subset assertions, not full-equality).

### 4.1 Changelog

Every API change (additive or breaking) is recorded in a dated changelog entry:

```
## 2025-12-01
- Added: `GET /api/v1/auth/devices` (list active tokens).
- Added: `wishes.purchased_at` response field.
- Deprecated: `wishes.is_done` (use `wishes.status`); Sunset 2026-06-01.
```

The changelog is the human-readable companion to the OpenAPI diff.

## 5. Breaking Change Process

A breaking change requires a **new major version**. The process:

1. **Justify.** Document why an additive change or deprecation cannot achieve the goal.
   Breaking changes are expensive for mobile clients and must be rare.
2. **Plan the new version.** Create `/api/v2/` routes in parallel with `/api/v1/`. The two
   versions share controllers/services where possible; the version prefix selects the
   request/response shape (via separate API Resource classes or versioned transformers).
3. **Ship `v2` alongside `v1`.** Both versions are served simultaneously. `v1` continues to
   work unchanged.
4. **Deprecate `v1`.** Announce `v1` deprecation with a `Sunset` date (minimum 12 months
   for API consumers, longer if released mobile clients depend on it). Add `Deprecation`
   and `Sunset` headers to all `v1` responses.
5. **Migrate clients.** Flutter, Web, and any external consumers move to `v2` within the
   sunset window. Mobile clients must ship a version using `v2` before `v1`'s sunset.
6. **Retire `v1`.** After the sunset date, with telemetry confirming negligible usage,
   remove `v1` routes. Return `410 Gone` (with a `Link: rel="successor-version"` to `v2`)
   for a grace period, then remove entirely.

### 5.1 What counts as a breaking change

See the "No" rows in §2.1. Any of those requires a new major version.

### 5.2 Major version cadence

Major versions are expected to be rare (years, not months). The API is designed to evolve
additively for as long as possible. A major version is justified only when the data model
or core semantics need to change in a way that cannot be expressed additively.

## 6. Version Lifetime

| Phase | Behavior |
|-------|----------|
| **Current** | Actively developed; receives additive changes and bug fixes. |
| **Supported** | No new features; receives bug fixes and security fixes. Announced as deprecated with a `Sunset`. |
| **Deprecated** | Receives only critical security fixes. `Deprecation`/`Sunset` headers on all responses. |
| **Retired** | Routes removed; `410 Gone` for a grace period, then 404. |

At most **two** major versions are supported simultaneously (the current one and the
previous one during its deprecation window).

## 7. OpenAPI and Versioning

- The OpenAPI document is versioned per major version: `openapi-v1.yaml`, `openapi-v2.yaml`.
- The document's `info.version` follows semver and tracks additive changes within the
  major version (e.g. `1.4.0`).
- A diff between consecutive `info.version`s must contain only additive changes (per §2.1).
  A diff that contains a breaking change within the same major version is a bug.
- The OpenAPI document is the source of truth for client SDK generation where SDKs are used.

## 8. Client Expectations

Clients MUST:

- Send the version prefix in every request (`/api/v1/...`); never call an unversioned URL.
- Ignore unknown response fields (forward compatibility).
- Treat unknown enum values and unknown error codes as the generic fallback, never crash.
- Honor `Deprecation`/`Sunset` headers and migrate within the sunset window.
- Pin to a major version and migrate deliberately, not opportunistically.

Clients MUST NOT:

- Hard-code the full response shape (use subset assertions; tolerate extra fields).
- Switch on response field *absence* as a feature flag (use a real feature flag or version
  negotiation).
- Assume a field's type from a previous response (types are stable within a major version,
  but new fields may appear with new types).

## 9. Non-Goals

- No automatic client version negotiation. The client picks the version by URL.
- No per-request minor version. Minor versions are additive and invisible in the URL.
- No versioning by authentication token or user segment.
- No "beta" URL prefix. Experimental features are gated by feature flags on existing
  endpoints or by an explicitly documented experimental endpoint, not by a version.
