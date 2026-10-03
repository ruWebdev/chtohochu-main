# Application Boundaries — ЧтоХочу

This document defines the hard boundaries between the five applications in the ЧтоХочу system. It specifies what each app owns, what it must not import, and how apps communicate. These boundaries are enforced by code review and must not be violated without an approved ADR.

---

## 1. Boundary Principles

1. **No app imports another app's source code.** Cross-app sharing happens through `packages/` or the API contract.
2. **Business logic lives in the backend.** Apps contain presentation logic, state management, and data transport — not business rules.
3. **The API contract is the interface.** All inter-app communication flows through the Laravel REST API or Reverb WebSocket events.
4. **Shared types are not shared logic.** `packages/` may contain TypeScript type definitions and utility functions, but never business logic.
5. **Each app deploys independently.** No build-time coupling between apps.

---

## 2. Flutter Client (`apps/client`)

### 2.1 What it owns

| Owns | Description |
|------|-------------|
| UI rendering | All mobile screens, widgets, navigation, theming |
| State management | Riverpod 3 (per AGENTS.md). Presentation state, optimistic updates |
| Local persistence | Drift database — the local source of truth for offline-capable domains |
| Data transport | Dio HTTP client, Retrofit API interfaces, WebSocket client for Reverb |
| Offline sync | Sync worker, sync operations queue, conflict reconciliation |
| Push handling | FCM token registration, push notification routing, deep link handling |
| Auth token storage | Sanctum tokens stored in flutter_secure_storage |
| Feature modules | Each feature owns its data, domain (optional), and presentation layers |

### 2.2 What it must NOT do

| Must not | Rationale |
|----------|-----------|
| Import from `apps/public-web`, `apps/admin`, `apps/seller` | No cross-app source imports |
| Import from `backend/api/` | Backend is PHP; Flutter is Dart. Communication is via API only |
| Implement business rules | Authorization, validation, and domain invariants are backend responsibilities |
| Trust client-side permissions for security | Client may hide UI for UX, but backend enforces all authorization |
| Access PostgreSQL directly | All data flows through the Laravel API |
| Use Firebase/Firestore as primary database | PostgreSQL is the source of truth. FCM is push transport only |
| Instantiate Dio outside the core network layer | HTTP access is centralized; feature code uses repositories, not Dio |
| Access `AppDatabase` (Drift) directly from UI | Feature code accesses Drift through local data sources |

### 2.3 How it communicates

```
Flutter Client
  │
  ├── HTTP (Dio) ──────────► backend/api  (REST: /api/v1/*)
  │                            Auth: Sanctum bearer token
  │
  ├── WebSocket ───────────► Reverb (WSS: wss://app.chtohochu.ru/app/)
  │                            Auth: Sanctum token in connection headers
  │
  ├── Push (FCM) ◄───────── backend/api (via Laravel Queue + Notifications)
  │                            One-way: server → client
  │
  └── Deep links ◄───────── External (share URLs, push payloads)
                               Resolved via GoRouter + SharePreviewPage
```

---

## 3. Public Web (`apps/public-web`)

### 3.1 What it owns

| Owns | Description |
|------|-------------|
| Landing page | Marketing site at `chtohochu.ru` — SSR for SEO |
| Personal cabinet | Authenticated user cabinet at `lk.chtohochu.ru` — SSR with cookie auth |
| Web auth flows | Login, register, password reset, email verification (Laravel Breeze) |
| Share preview | Web-based share token resolution for non-app users |
| Profile viewing/editing | Basic profile management via web |
| Wishlist viewing | Authenticated web users can view and interact with wishlists |

### 3.2 What it must NOT do

| Must not | Rationale |
|----------|-----------|
| Import from `apps/client`, `apps/admin`, `apps/seller` | No cross-app source imports |
| Implement business rules | Business logic stays in backend |
| Implement offline sync | Web is online-only. Offline is a Flutter concern |
| Manage WebSocket connections for collaborative editing | Web may consume realtime events for notifications, but collaborative editing is a Flutter domain |
| Directly access the database | All data flows through the Laravel API or Inertia |
| Define API contracts | The API contract is defined by the backend; web consumes it |

### 3.3 How it communicates

```
Public Web (Nuxt SSR)
  │
  ├── HTTP ($fetch) ──────► backend/api (REST: /api/v1/*)
  │                          Auth: Sanctum cookie (web guard)
  │
  ├── Inertia.js ─────────► backend/api (web routes)
  │                          Server-side rendering with Inertia
  │                          Auth: Laravel session (cookie)
  │
  ├── WebSocket (optional) ► Reverb (for live notifications in cabinet)
  │                          Auth: Sanctum/cookie
  │
  └── SSR server ─────────► backend/api (server-side data fetching)
                               Nuxt server routes proxy to API
```

### 3.4 Special: Inertia vs. API

The public web uses two patterns:

1. **Inertia.js** — for the authenticated cabinet (`lk.chtohochu.ru`). Laravel serves Inertia pages with server-side data, Nuxt renders them as SPA-like pages. Auth uses Laravel sessions (cookie-based).
2. **Direct API** — for the landing page and share preview. Nuxt SSR fetches data from the API using `$fetch`. No session needed for public content.

---

## 4. Seller Cabinet (`apps/seller`)

### 4.1 What it owns

| Owns | Description |
|------|-------------|
| Seller auth | Separate authentication flow for merchant accounts (future) |
| Product catalog management | CRUD for products, categories, images (future) |
| Offer management | Create and manage promotional offers (future) |
| Order/inquiry management | View and manage customer inquiries (future) |

> **Status:** Scaffolded only. No functional implementation in the initial release.

### 4.2 What it must NOT do

| Must not | Rationale |
|----------|-----------|
| Import from `apps/client`, `apps/public-web`, `apps/admin` | No cross-app source imports |
| Implement business rules | Business logic stays in backend |
| Access user-facing features | Seller cabinet is a separate concern from user features |
| Share auth with user cabinet | Seller auth is a separate guard and flow |

### 4.3 How it communicates

```
Seller Cabinet (Nuxt SPA)
  │
  ├── HTTP ($fetch) ──────► backend/api (REST: /api/v1/seller/*)
  │                          Auth: Sanctum token (seller guard)
  │
  └── WebSocket (future) ──► Reverb (for real-time order/inquiry updates)
                               Auth: Sanctum token
```

---

## 5. Admin Panel (`apps/admin`)

### 5.1 What it owns

| Owns | Description |
|------|-------------|
| Admin auth | Separate admin authentication with Spatie role-based permissions |
| User management | View, search, suspend, delete users |
| Content moderation | Review public wishlists, handle reports |
| System monitoring | View queue status (Horizon), logs, health checks |
| Feature flags | Toggle features, manage configuration (future) |

### 5.2 What it must NOT do

| Must not | Rationale |
|----------|-----------|
| Import from `apps/client`, `apps/public-web`, `apps/seller` | No cross-app source imports |
| Implement business rules | Admin panel calls backend operations; it does not replicate logic |
| Share auth with user cabinet | Admin auth is a separate guard with Spatie permissions |
| Be publicly accessible | Admin panel is internal-only, protected by network + auth |
| Directly access the database | All data flows through the Laravel API (admin routes) |

### 5.3 How it communicates

```
Admin Panel (Nuxt SPA)
  │
  ├── HTTP ($fetch) ──────► backend/api (REST: /api/v1/admin/*)
  │                          Auth: Sanctum token + Spatie permission check
  │
  └── WebSocket (optional) ► Reverb (for live system metrics)
                               Auth: Sanctum token + admin role
```

---

## 6. Backend (`backend/api`)

### 6.1 What it owns

| Owns | Description |
|------|-------------|
| Business logic | All domain rules, authorization, validation, invariants |
| Data persistence | PostgreSQL schema, migrations, constraints, transactions |
| API contract | REST endpoints under `/api/v1/`, OpenAPI specification |
| Realtime broadcasting | Broadcast events to Reverb after database commit |
| Auth management | Sanctum token issuance, OAuth (Socialite), session management |
| Push notifications | FCM integration via Laravel Notifications + Queue |
| Queue processing | Horizon-managed workers for async jobs |
| File uploads | S3-compatible storage, upload validation, image processing |
| Broadcast channels | WebSocket channel authorization (`routes/channels.php`) |

### 6.2 What it must NOT do

| Must not | Rationale |
|----------|-----------|
| Import from any `apps/` directory | Backend is the server; apps are clients |
| Contain UI rendering logic | Inertia pages are Vue components; backend serves data + page props, not HTML rendering logic |
| Trust client-supplied ownership or permissions | Every operation re-verifies authorization server-side |
| Use Redis as authoritative business storage | PostgreSQL is the sole source of truth |
| Broadcast events before transaction commit | Events are broadcast only after COMMIT to prevent phantom state |
| Put business logic in controllers | Controllers are thin: receive, authorize, validate, invoke action, respond |

### 6.3 How it communicates

```
Backend (Laravel)
  │
  ├── HTTP REST ──────────► All apps (JSON responses)
  │                          /api/v1/* (versioned)
  │
  ├── Inertia responses ──► public-web (page props + data)
  │                          web routes (lk.chtohochu.ru)
  │
  ├── Broadcast events ───► Reverb (WebSocket)
  │                          After PostgreSQL COMMIT
  │                          Channels: user.{id}, wishlist.{id}, shopping-list.{id}
  │
  ├── Queue jobs ─────────► Horizon workers (async)
  │                          Push notifications, email, image processing
  │
  └── FCM push ───────────► Firebase Cloud Messaging
                               Via Laravel Notifications + Queue
```

---

## 7. Communication Matrix

### 7.1 Who talks to whom

| From \ To | Flutter | public-web | seller | admin | backend | Reverb |
|-----------|:-------:|:----------:|:------:|:-----:|:-------:|:------:|
| **Flutter** | — | ✗ | ✗ | ✗ | HTTP | WSS |
| **public-web** | ✗ | — | ✗ | ✗ | HTTP + Inertia | WSS (opt) |
| **seller** | ✗ | ✗ | — | ✗ | HTTP | WSS (future) |
| **admin** | ✗ | ✗ | ✗ | — | HTTP | WSS (opt) |
| **backend** | FCM push | — | — | — | — | Broadcast |
| **Reverb** | WSS push | WSS push | WSS push | WSS push | — | — |

> ✗ = no direct communication. All cross-app data flows through the backend API or Reverb.

### 7.2 Shared code matrix

| Shared via `packages/` | Flutter | public-web | seller | admin |
|------------------------|:-------:|:----------:|:------:|:-----:|
| `@chtohochu/api-types` | ✗ (Dart) | ✓ | ✓ | ✓ |
| `@chtohochu/api-client` | ✗ (Dart) | ✓ | ✓ | ✓ |
| `@chtohochu/shared-utils` | ✗ (Dart) | ✓ | ✓ | ✓ |
| `@chtohochu/shared-constants` | ✗ (Dart) | ✓ | ✓ | ✓ |

> Flutter does not consume `packages/` (different language). Dart shared code lives in `apps/client/lib/core/` and `apps/client/lib/shared/`.

---

## 8. Boundary Enforcement

### 8.1 Static enforcement

| Boundary | Enforcement mechanism |
|----------|---------------------|
| No cross-app imports (web) | npm workspace boundaries — each app has its own `package.json`; no path aliases to sibling apps |
| No cross-app imports (Flutter) | Dart package boundaries — Flutter is a single app; no sibling app imports possible |
| No backend imports from apps | Language barrier — PHP vs. Dart/TypeScript |
| No direct DB access from apps | Network isolation — PostgreSQL is not exposed outside the Docker internal network |

### 8.2 Runtime enforcement

| Boundary | Enforcement mechanism |
|----------|---------------------|
| Authorization | Backend re-verifies auth, ownership, membership, and permission on every request |
| API versioning | All API routes under `/api/v1/`; breaking changes require compatibility analysis |
| Realtime channel auth | `routes/channels.php` authorizes WebSocket channel subscriptions server-side |
| Rate limiting | Laravel throttle middleware on auth and mutation endpoints |

### 8.3 Review enforcement

The following are caught at code review time and must be rejected:

1. A PR that adds an import from `apps/client` into a Nuxt app (or vice versa).
2. A PR that adds business logic to a controller without an Action/Domain class.
3. A PR that adds a direct database query in a frontend app.
4. A PR that adds a new shared package without demonstrating at least two consumers.
5. A PR that adds a new WebSocket channel without server-side authorization in `channels.php`.
