# ЧтоХочу (chtohochu)

A social wishlist and collaborative shopping-list platform.

## Repository

```
git@github.com:ruWebdev/chtohochu-main.git
```

## Structure

```
/
├── apps/
│   ├── client/              # Flutter client (iOS, Android, web)
│   ├── public-web/          # Nuxt 4 public website (SSR, SEO)
│   ├── seller/              # Nuxt 4 seller cabinet (SPA)
│   └── admin/               # Nuxt 4 admin panel (SPA)
├── backend/
│   └── api/                 # Laravel API
├── packages/                # Shared packages (only where justified)
├── infrastructure/
│   └── docker/              # Docker, Traefik, deployment configs
├── docs/                    # Architecture documentation
├── .github/                 # CI workflows, CODEOWNERS, PR template
├── AGENTS.md                # Engineering contract (read this first)
├── README.md                # This file
└── Makefile                 # Local development commands
```

## Prerequisites

- Flutter 3.27+
- PHP 8.3+
- Node.js 22+
- Docker & Docker Compose
- mkcert (for local HTTPS)

## Quick Start

### 1. Local infrastructure (Docker)

```bash
make up
```

This starts: Traefik, PostgreSQL, Redis, Laravel, queue worker, scheduler, Reverb, mail catcher.

### 2. Backend

```bash
cd backend/api
composer install
cp .env.example .env
php artisan key:generate
make migrate
```

### 3. Flutter client

```bash
cd apps/client
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### 4. Nuxt apps

```bash
cd apps/public-web  # or apps/seller, apps/admin
npm install
npm run dev
```

## Local Domains

| Domain | Application |
|--------|-------------|
| `www.chtohochu.test` | Public Web |
| `app.chtohochu.test` | Flutter Web / user client |
| `seller.chtohochu.test` | Seller |
| `admin.chtohochu.test` | Admin |
| `api.chtohochu.test` | Laravel API |

Add to `/etc/hosts`:
```
127.0.0.1 chtohochu.test
127.0.0.1 www.chtohochu.test
127.0.0.1 app.chtohochu.test
127.0.0.1 seller.chtohochu.test
127.0.0.1 admin.chtohochu.test
127.0.0.1 api.chtohochu.test
```

## Documentation

- **[AGENTS.md](AGENTS.md)** — Engineering contract (read before making changes)
- **[docs/](docs/)** — Architecture documentation
  - `00-project/` — Vision, scope, terminology, prototype reset
  - `01-architecture/` — Overview, monorepo, boundaries, auth, realtime, security
  - `10-development/` — Setup, git workflow, docker, routing, HTTPS, environments, testing
  - `20-backend/` — Architecture, API, auth, realtime, queues, database
  - `30-client/` — Flutter architecture, state management, local storage, offline
  - `40-web/` — Web architecture, public-web, seller, admin
  - `50-infrastructure/` — Local development, deployment
  - `adr/` — Architecture Decision Records

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Client | Flutter, Riverpod, Drift, GoRouter, Dio, Retrofit, Freezed |
| Web | Nuxt 4, Vue 3, TypeScript |
| Backend | Laravel, PHP 8.3+, PostgreSQL, Redis |
| Realtime | Laravel Reverb (WebSocket) |
| Auth | Laravel Sanctum |
| Infra | Docker, Traefik, GitHub Actions |

## Status

This repository is in the **architectural bootstrap** phase. Product features are not yet implemented. See `docs/00-project/prototype-reset.md` for details.
