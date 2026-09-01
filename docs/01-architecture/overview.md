# System Architecture Overview — ЧтоХочу

## 1. System at a Glance

ЧтоХочу is a multi-app system with a single authoritative backend. Five applications serve different audiences and surfaces, all backed by one Laravel modular monolith.

```
                    ┌─────────────────────────────────────────────┐
                    │              External Users                  │
                    │                                              │
                    │  Mobile users    Web visitors   Sellers      │
                    │  (iOS/Android)   (browsers)     (future)     │
                    └──────┬───────────┬──────────────┬────────────┘
                           │           │              │
                     HTTPS │     HTTPS │        HTTPS │
                           │           │              │
          ┌────────────────▼───────────▼──────────────▼────────┐
          │                 Traefik (reverse proxy)              │
          │   SNI-based routing by subdomain + path prefix       │
          └───────┬────────────┬──────────────┬───────────┬──────┘
                  │            │              │           │
          chtohochu.ru    lk.chtohochu   admin.chto   app.chtohochu.ru
          (public-web)    (public-web)   (admin)      (WS + app links)
                  │            │              │           │
          ┌───────▼────┐ ┌────▼─────┐ ┌──────▼──────┐ ┌──▼──────────┐
          │  Nuxt 4    │ │  Nuxt 4  │ │   Nuxt 4   │ │   Nuxt 4    │
          │  SSR       │ │  SSR     │ │   SPA      │ │   (seller)  │
          │  (landing) │ │(cabinet) │ │  (admin)   │ │   (future)  │
          └───────┬────┘ └────┬─────┘ └──────┬─────┘ └──────┬──────┘
                  │           │              │              │
                  │     api.chtohochu.ru     │              │
                  │           │              │              │
                  │    ┌──────▼──────────────▼──────────────▼──┐
                  │    │           Laravel Backend (API)        │
                  │    │         PHP 8.3+ / Laravel 13          │
                  │    │                                        │
                  │    │  ┌─────────┐  ┌──────────┐  ┌────────┐│
                  │    │  │  HTTP   │  │ Actions/  │  │ Domain ││
                  │    │  │  Layer  │→ │ Application│→ │ Models ││
                  │    │  └─────────┘  └──────────┘  └────┬───┘│
                  │    │                                   │    │
                  │    │  ┌───────────────────────────────▼───┐│
                  │    │  │       Eloquent / Domain Models     ││
                  │    │  └───────────────────────────────┬───┘│
                  │    └──────────────────────────────────┼────┘
                  │                                       │
                  │    ┌──────────────┐  ┌───────────────▼────┐
                  │    │    Redis     │  │    PostgreSQL      │
                  │    │  (cache,     │  │  (source of truth) │
                  │    │   queues,    │  │  users, wishlists, │
                  │    │   Reverb)    │  │  shopping lists,   │
                  │    └──────┬───────┘  │  friends, events   │
                  │           │         └────────────────────┘
                  │    ┌──────▼───────┐
                  │    │   Reverb     │  WebSocket server
                  │    │  (realtime)  │  (port 8080, behind Traefik)
                  │    └──────┬───────┘
                  │           │ WSS
                  │           │
          ┌───────▼───────────▼───────────────────────────────┐
          │              Flutter Client (mobile)               │
          │                                                   │
          │  Dio (HTTP) ──────────────► Laravel API            │
          │  WebSocket ───────────────► Reverb                 │
          │  FCM (push) ◄───────────── Laravel Queue           │
          │  Drift (local DB) ◄────── sync from API/Reverb     │
          └───────────────────────────────────────────────────┘
```

## 2. The Five Applications

### 2.1 Flutter Client (`apps/client`)

| Attribute | Value |
|-----------|-------|
| Surface | iOS, Android (mobile-first) |
| Role | Primary end-user application |
| State management | Riverpod 3 (per AGENTS.md) |
| Local persistence | Drift (SQLite) — offline-first |
| HTTP | Dio + Retrofit |
| Realtime | WebSocket → Reverb |
| Push | Firebase Cloud Messaging |
| Auth | Sanctum token (stored in flutter_secure_storage) |
| Routing | GoRouter |
| Models | Freezed + json_serializable |

The Flutter client is the richest surface. It is offline-first for wishlists, wishes, and shopping lists. It uses Drift as the local source of truth and syncs with the backend via REST mutations and WebSocket events.

### 2.2 Public Web (`apps/public-web`)

| Attribute | Value |
|-----------|-------|
| Surface | Browser (desktop + mobile) |
| Role | Landing page + personal cabinet + share preview |
| Framework | Nuxt 4, Vue 3, TypeScript |
| Rendering | SSR (server-side rendering) |
| Domains | `chtohochu.ru` (landing), `lk.chtohochu.ru` (cabinet) |
| API | Consumes Laravel API at `api.chtohochu.ru` |
| Auth | Cookie-based (Sanctum web guard) for cabinet; token for API |

The public web serves two purposes: the marketing landing page (public, SSR for SEO) and the authenticated personal cabinet (SSR with cookie auth). It also resolves share tokens for non-app users, rendering wishlist previews in the browser.

### 2.3 Seller Cabinet (`apps/seller`)

| Attribute | Value |
|-----------|-------|
| Surface | Browser (desktop) |
| Role | Seller product catalog management (future domain) |
| Framework | Nuxt 4, Vue 3, TypeScript |
| Rendering | SPA (ssr: false) |
| Domain | Dedicated seller subdomain (provisioned) |
| Status | Scaffolded, not functionally implemented in initial release |

The seller cabinet is architecturally provisioned — the Nuxt app exists in the monorepo with the standard structure — but has no functional implementation in the initial release. It is listed here for completeness and to document that the architecture does not block it.

### 2.4 Admin Panel (`apps/admin`)

| Attribute | Value |
|-----------|-------|
| Surface | Browser (desktop, internal) |
| Role | Platform administration — user management, content moderation, system monitoring |
| Framework | Nuxt 4, Vue 3, TypeScript |
| Rendering | SPA (ssr: false) |
| Domain | `admin.chtohochu.ru` |
| Auth | Separate admin guard (Spatie permissions) |
| Status | Scaffolded, minimal implementation in initial release |

The admin panel is an internal tool. It runs as a SPA (no SSR needed — not public-facing). It uses Spatie Laravel-Permissions for role-based access control.

### 2.5 Laravel Backend (`backend/api`)

| Attribute | Value |
|-----------|-------|
| Role | Single authoritative API + realtime broadcaster |
| Framework | Laravel 13, PHP 8.3+ |
| Architecture | Modular monolith, pragmatic layered architecture |
| Database | PostgreSQL (source of truth) |
| Cache/Queue | Redis |
| Realtime | Laravel Reverb (WebSocket server) |
| Queue management | Laravel Horizon |
| Auth | Laravel Sanctum (token for mobile/API, cookie for web) |
| OAuth | Laravel Socialite (VK, Yandex) |
| Permissions | Spatie Laravel-Permissions (admin roles) |
| API versioning | `/api/v1/` |

The backend is the brain of the system. It owns all business logic, authorization, data integrity, and realtime event broadcasting. No other app contains business rules.

## 3. Technology Stack Summary

```
┌─────────────────────────────────────────────────────────────┐
│                      Technology Stack                        │
├──────────────┬──────────────────────────────────────────────┤
│ Mobile       │ Flutter, Dart, Riverpod 3, Drift,            │
│              │ GoRouter, Dio, Retrofit, Freezed, FCM         │
├──────────────┼──────────────────────────────────────────────┤
│ Web          │ Nuxt 4, Vue 3, TypeScript, Vite, Pinia,       │
│              │ Vue Router                                    │
├──────────────┼──────────────────────────────────────────────┤
│ Backend      │ Laravel 13, PHP 8.3+, Sanctum, Socialite,     │
│              │ Spatie Permission, Reverb, Horizon            │
├──────────────┼──────────────────────────────────────────────┤
│ Database     │ PostgreSQL (primary), Redis (cache/queue/WS)  │
├──────────────┼──────────────────────────────────────────────┤
│ Realtime     │ Laravel Reverb (WebSocket server)             │
├──────────────┼──────────────────────────────────────────────┤
│ Queue        │ Laravel Queue + Horizon (Redis driver)        │
├──────────────┼──────────────────────────────────────────────┤
│ Infrastructure│ Docker, Traefik, S3-compatible storage,      │
│              │ GitHub Actions                                │
└──────────────┴──────────────────────────────────────────────┘
```

## 4. Data Flow

### 4.1 Read flow (online)

```
User action (e.g. open wishlist)
  │
  ▼
Flutter: Notifier queries Repository
  │
  ▼
Repository checks Drift (local cache)
  │
  ├─ Cache hit → return local data → UI renders immediately
  │
  └─ Cache miss / stale → Repository calls RemoteDataSource
       │
       ▼
     Dio HTTP GET → api.chtohochu.ru/api/v1/wishlists/{id}
       │
       ▼
     Laravel: Controller → Action → Domain Model → PostgreSQL
       │
       ▼
     JSON response → RemoteDataSource → Repository
       │
       ▼
     Repository writes to Drift (local cache update)
       │
       ▼
     Riverpod emits → UI re-renders
```

### 4.2 Write flow (online, optimistic)

```
User action (e.g. add item to shopping list)
  │
  ▼
Flutter: Notifier calls Repository.addItem()
  │
  ├─ Local: Drift transaction
  │    ├── insert ShoppingListItem (status: pending_sync)
  │    └── create SyncOperation (operation_id, payload)
  │
  └─ UI updates immediately (optimistic)
       │
       ▼
  Sync worker picks up pending operation
       │
       ▼
  Dio HTTP POST → api.chtohochu.ru/api/v1/shopping-lists/{id}/items
       │
       ▼
  Laravel: Controller → Action → PostgreSQL transaction
       │
       ▼
  COMMIT → Broadcast event via Reverb
       │
       ├─ ACK response → Sync worker marks operation as completed
       │                 → Drift: item status → synced
       │
       └─ WebSocket event → other participants' clients reconcile
```

### 4.3 Write flow (offline)

```
User action (offline)
  │
  ▼
Repository: Drift transaction (entity + sync operation)
  │
  ▼
UI updates immediately (optimistic, from local DB)
  │
  ▼
Sync operation queued (status: pending)
  │
  ... (hours pass, app may restart) ...
  │
  ▼
Connectivity restored / app restart
  │
  ▼
Sync worker processes pending operations
  │
  ├─ Success → reconcile local state with server response
  │
  └─ Conflict → apply conflict policy → reconcile or surface to user
```

### 4.4 Realtime event flow

```
Participant A mutates shopping list
  │
  ▼
Laravel receives mutation
  │
  ▼
PostgreSQL transaction (BEGIN → COMMIT)
  │
  ▼
Laravel broadcasts event (after commit)
  │
  ▼
Reverb WebSocket server receives broadcast
  │
  ▼
Reverb pushes to all subscribed clients (Participant B, C, ...)
  │
  ▼
Flutter client receives WebSocket event
  │
  ▼
Realtime handler → Repository.reconcile()
  │
  ▼
Drift updated → Riverpod emits → UI re-renders
```

> **Fundamental rule:** PostgreSQL is the source of truth. Realtime is a delivery mechanism. A correct client must survive lost, duplicated, delayed, and out-of-order events.

## 5. Infrastructure

### 5.1 Container topology (production)

```
┌──────────────────────────────────────────────────┐
│                   Docker Host                     │
│                                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    │
│  │  Traefik  │───►│  Laravel  │    │  Queue   │    │
│  │ (proxy)   │    │  (app)    │    │  Worker  │    │
│  │  :443     │    │  :80     │    │  (Horizon)│    │
│  └─────┬─────┘    └─────┬────┘    └─────┬────┘    │
│        │                 │               │         │
│        │    ┌────────────▼───┐   ┌──────▼──────┐  │
│        └───►│    Reverb      │   │   Redis     │  │
│             │  (WebSocket)   │   │  (cache/q)  │  │
│             │    :8080       │   │    :6379    │  │
│             └────────────────┘   └─────────────┘  │
│                                                   │
│             ┌────────────────────────────┐        │
│             │       PostgreSQL            │        │
│             │     (external or container) │        │
│             │        :5432                │        │
│             └────────────────────────────┘        │
└──────────────────────────────────────────────────┘
```

### 5.2 Service responsibilities

| Service | Role | Port |
|---------|------|------|
| **Traefik** | TLS termination, SNI routing by subdomain, WebSocket upgrade for Reverb | 443 (HTTPS) |
| **Laravel app** | HTTP API, web routes, Inertia SSR for cabinet | 80 (internal) |
| **Queue worker** | Processes jobs: push notifications, email, image processing | — (headless) |
| **Reverb** | WebSocket server for realtime events | 8080 (internal) |
| **Redis** | Queue driver, cache, Reverb pub/sub backend, ephemeral state | 6379 (internal) |
| **PostgreSQL** | Authoritative data store — all business state | 5432 (internal) |

### 5.3 Domain routing

| Domain | Target | Purpose |
|--------|--------|---------|
| `chtohochu.ru` | public-web (Nuxt SSR) | Landing page |
| `lk.chtohochu.ru` | public-web (Nuxt SSR) | Personal cabinet, web auth |
| `admin.chtohochu.ru` | admin (Nuxt SPA) | Admin panel |
| `api.chtohochu.ru` | Laravel (HTTP) | REST API |
| `app.chtohochu.ru` | Reverb (WebSocket) + Laravel (app links) | Realtime + deep link resolution |
| `seller.chtohochu.ru` | seller (Nuxt SPA) | Seller cabinet (future) |

## 6. Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **Modular monolith** (not microservices) | Single team, single deploy unit, simpler ops. Split requires ADR. |
| **PostgreSQL as sole source of truth** | ACID guarantees, foreign keys, constraints. Redis is never authoritative. |
| **Drift as mobile local source of truth** | Offline-first requires a real local database, not just in-memory cache. |
| **Reverb for WebSocket** | Laravel-native, integrates with broadcast events, Redis-backed. |
| **Horizon for queue management** | Dashboard, metrics, auto-scaling for queue workers. |
| **Sanctum for auth** | Token-based for mobile, cookie-based for web — single package. |
| **Traefik for routing** | Automatic TLS, SNI-based routing, WebSocket support, label-based config. |
| **Nuxt SSR for public-web** | SEO for landing page, fast first paint for cabinet. |
| **Nuxt SPA for admin/seller** | Internal tools, no SEO need, simpler deployment. |
