# Monorepo Structure — ЧтоХочу

## 1. Repository Layout

The ЧтоХочу project is a single Git repository containing all applications, the backend, shared packages, infrastructure, and documentation. This is a **monorepo** — all code lives in one repository, deployed as separate artifacts.

```
ChtoHochu/
│
├── apps/                          # All runnable applications
│   ├── client/                    # Flutter mobile app (iOS, Android)
│   │   ├── lib/                   # Dart source code
│   │   │   ├── app/               # App shell: router, theme, DI, app.dart
│   │   │   ├── core/              # Cross-feature infrastructure
│   │   │   │   ├── config/        # Environment configuration
│   │   │   │   ├── constants/     # API constants, storage keys
│   │   │   │   ├── database/      # Drift database, tables, DAOs
│   │   │   │   ├── network/       # Dio API client, interceptors
│   │   │   │   ├── services/      # Secure storage, OAuth, app storage
│   │   │   │   └── errors/        # Failures, exceptions
│   │   │   ├── shared/            # Shared UI components
│   │   │   │   └── ui/            # Buttons, cards, inputs, navigation, sheets
│   │   │   ├── features/          # Feature-first modules
│   │   │   │   ├── auth/          # Authentication (data/domain/presentation)
│   │   │   │   ├── friends/       # Friends feature
│   │   │   │   ├── home/          # Home / wishlist hub
│   │   │   │   ├── onboarding/    # Pre-auth + post-auth onboarding
│   │   │   │   ├── shopping/      # Shopping lists
│   │   │   │   ├── splash/        # Splash / bootstrap
│   │   │   │   └── user/          # Profile and settings
│   │   │   └── main.dart          # Entry point
│   │   ├── test/                  # Unit + widget tests
│   │   ├── integration_test/      # Integration tests
│   │   ├── android/               # Android platform config
│   │   ├── ios/                   # iOS platform config
│   │   ├── assets/                # Images, fonts, static assets
│   │   └── pubspec.yaml           # Flutter dependencies
│   │
│   ├── public-web/                # Nuxt 4 SSR — landing + cabinet
│   │   ├── app/                   # Nuxt app directory
│   │   │   ├── pages/             # File-based routes
│   │   │   ├── components/        # Vue components
│   │   │   └── composables/       # Vue composables (state, API)
│   │   ├── server/                # Nitro server routes / middleware
│   │   ├── public/                # Static assets (favicon, images)
│   │   ├── nuxt.config.ts         # Nuxt configuration
│   │   ├── package.json           # Node dependencies
│   │   └── tsconfig.json          # TypeScript config
│   │
│   ├── seller/                    # Nuxt 4 SPA — seller cabinet (future)
│   │   ├── app/                   # Same structure as public-web
│   │   ├── server/
│   │   ├── public/
│   │   ├── nuxt.config.ts         # ssr: false (SPA mode)
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── admin/                     # Nuxt 4 SPA — admin panel
│       ├── app/                   # Same structure as public-web
│       ├── server/
│       ├── public/
│       ├── nuxt.config.ts         # ssr: false (SPA mode)
│       ├── package.json
│       └── tsconfig.json
│
├── backend/                       # Backend services
│   └── api/                       # Laravel API (modular monolith)
│       ├── app/                   # PHP application code
│       │   ├── Http/              # HTTP layer
│       │   │   ├── Controllers/   # Thin controllers (Api/, Auth/)
│       │   │   ├── Requests/      # Form request validation
│       │   │   └── Middleware/    # HTTP middleware
│       │   ├── Actions/           # Application operations / actions
│       │   ├── Models/            # Eloquent domain models
│       │   └── Providers/         # Service providers
│       ├── routes/                # Route definitions
│       │   ├── api.php            # API routes (Sanctum)
│       │   ├── auth.php           # Web auth routes (cabinet)
│       │   ├── channels.php       # Broadcast channel authorization
│       │   ├── web.php            # Web routes (Inertia)
│       │   └── console.php        # Console command routes
│       ├── database/              # Migrations, factories, seeders
│       │   ├── migrations/        # Schema migrations
│       │   ├── factories/         # Model factories
│       │   └── seeders/           # Database seeders
│       ├── config/                # Laravel configuration
│       ├── tests/                 # PHPUnit tests
│       ├── docker/                # Backend-specific Docker config
│       ├── compose.yaml           # Production Docker Compose
│       ├── Dockerfile             # Backend image
│       ├── composer.json          # PHP dependencies
│       └── .env.example           # Environment template
│
├── packages/                      # Shared code across apps
│   └── (shared packages — see §4)
│
├── infrastructure/                # Deployment infrastructure
│   ├── docker/                    # Docker Compose files, images
│   └── nginx/                     # Nginx/Traefik configuration
│
├── docs/                          # All project documentation
│   ├── 00-product/                # Product vision, scope, terminology
│   ├── 01-architecture/           # Architecture overview, boundaries
│   ├── 02-authentication/         # Auth flows and contracts
│   ├── 03-api/                    # API contracts and conventions
│   ├── 04-database/               # Schema and migration docs
│   ├── 05-realtime/               # WebSocket event contracts
│   ├── 06-notifications/          # Push and in-app notification docs
│   ├── 07-flutter/                # Flutter-specific architecture
│   ├── 08-web/                    # Web-specific architecture
│   ├── 09-security/               # Security policies
│   ├── 10-development/            # Dev setup, CI/CD, conventions
│   └── decisions/                 # Architecture Decision Records (ADRs)
│
├── AGENTS.md                      # Engineering contract (authoritative)
└── README.md                      # Project overview
```

## 2. Top-Level Directory Reference

| Directory | Purpose | Deployable? |
|-----------|---------|:-----------:|
| `apps/` | All runnable client applications — Flutter mobile, Nuxt web apps | Yes (each app independently) |
| `backend/` | Backend services. Currently contains only `api/` (the Laravel monolith) | Yes |
| `packages/` | Shared code consumed by multiple apps (TypeScript types, API clients, utilities) | No (published as workspace packages) |
| `infrastructure/` | Docker Compose files, Nginx/Traefik configs, deployment scripts | No (configuration) |
| `docs/` | All project documentation, organized by numbered domain | No |
| `AGENTS.md` | The engineering contract — architecture rules, stack, boundaries | No |
| `README.md` | Project overview, setup instructions | No |

## 3. Application Boundaries

Each application in `apps/` is an independently buildable and deployable unit. Applications do not import each other's source code. They communicate exclusively through:

1. **The Laravel API** (REST over HTTPS)
2. **Reverb WebSocket** (realtime events)
3. **Shared packages** in `packages/` (types, contracts, utilities — not business logic)

```
apps/client  ◄──── API + WebSocket ────►  backend/api
apps/public-web  ◄──── API (HTTP) ────►  backend/api
apps/seller  ◄──── API (HTTP) ────►  backend/api
apps/admin  ◄──── API (HTTP) ────►  backend/api

apps/client  ◄──── packages/* ────►  apps/public-web
                 (shared types only)
```

> **Rule:** No app imports source code from another app. Cross-app sharing happens through `packages/` or through the API contract.

See [application-boundaries.md](./application-boundaries.md) for the full boundary specification.

## 4. Shared Code in `packages/`

The `packages/` directory holds code shared across multiple applications. It is currently empty — packages are added when a concrete sharing need arises, not preemptively.

### 4.1 What belongs in `packages/`

| Include | Exclude |
|---------|---------|
| TypeScript API type definitions (request/response shapes) | Business logic |
| API client wrappers (typed HTTP functions) | State management |
| Shared validation schemas (zod, etc.) | UI components |
| Shared constants (API paths, event names) | Feature-specific code |
| Shared utility functions (formatting, parsing) | Backend PHP code |

### 4.2 Package naming convention

```
packages/
├── api-types/          # TypeScript types matching the OpenAPI/Laravel API
├── api-client/         # Typed HTTP client wrapping fetch/$fetch
├── shared-utils/       # Pure utility functions (date, string, validation)
└── shared-constants/   # API paths, event names, storage keys
```

### 4.3 Consumption model

Nuxt apps consume packages via npm workspace aliases:

```json
// apps/public-web/package.json
{
  "dependencies": {
    "@chtohochu/api-types": "workspace:*",
    "@chtohochu/api-client": "workspace:*"
  }
}
```

Flutter does not consume `packages/` (Dart packages are managed via `pubspec.yaml` and the Flutter pub ecosystem). If shared Dart code is needed between Flutter features, it lives in `apps/client/lib/core/` or `apps/client/lib/shared/`, not in `packages/`.

### 4.4 Rules

1. **No business logic in packages.** Packages hold types, contracts, and utilities. Business rules live in the backend or in feature-specific code.
2. **No app-specific code in packages.** If code is only used by one app, it stays in that app.
3. **Packages must be framework-agnostic** (for web packages) — no Nuxt or Vue imports in `api-types` or `shared-utils`.
4. **Adding a package requires justification.** Do not create packages preemptively. Create them when at least two apps need the same code.
5. **Package changes require versioning awareness.** Since apps deploy independently, a breaking change in a shared package must be coordinated with all consuming apps.

## 5. Backend Structure

The backend lives at `backend/api/` and follows Laravel conventions with a pragmatic layered architecture:

```
backend/api/
├── app/
│   ├── Http/                    # HTTP layer (thin)
│   │   ├── Controllers/
│   │   │   ├── Api/             # API controllers (mobile + web API)
│   │   │   └── Auth/            # Web auth controllers (Breeze)
│   │   ├── Requests/            # Form request validation
│   │   └── Middleware/
│   ├── Actions/                 # Application operations
│   │   └── Auth/                # Auth-specific actions
│   ├── Models/                  # Eloquent models (domain data)
│   └── Providers/               # Service providers
├── routes/
├── database/
├── config/
└── tests/
```

As the system grows, the backend will organize domain code into modules:

```
app/
├── Domain/
│   ├── Users/
│   ├── Friends/
│   ├── Wishlists/
│   ├── ShoppingLists/
│   └── Notifications/
├── Application/                 # Actions, DTOs, orchestration
├── Infrastructure/              # External concerns (storage, mail, etc.)
└── Http/                        # Controllers, requests, resources
```

See [backend.md](./backend.md) for the full backend architecture specification.

## 6. Documentation Structure

Documentation is organized in numbered directories by domain, not by app:

| Directory | Content |
|-----------|---------|
| `00-product/` | Product vision, terminology, scope, screen inventory |
| `01-architecture/` | System overview, monorepo, boundaries, frontend, backend |
| `02-authentication/` | Auth flows, token management, OAuth |
| `03-api/` | API contracts, conventions, OpenAPI |
| `04-database/` | Schema design, migration policies |
| `05-realtime/` | WebSocket event contracts, channel authorization |
| `06-notifications/` | Push, in-app, email notification docs |
| `07-flutter/` | Flutter-specific patterns, sync, offline |
| `08-web/` | Nuxt-specific patterns, SSR, cabinet |
| `09-security/` | Security policies, threat models |
| `10-development/` | Dev setup, CI/CD, coding conventions |
| `decisions/` | Architecture Decision Records (ADRs) |

> **Rule:** Documentation is organized by concern, not by app. A feature that spans Flutter, web, and backend is documented in the relevant domain directory, not split across app directories.

## 7. Working in the Monorepo

### 7.1 Local development

Each app has its own dev server and dependency manager:

| App | Start dev | Dependencies |
|-----|-----------|-------------|
| `apps/client` | `flutter run` | `flutter pub get` |
| `apps/public-web` | `npm run dev` (Nuxt) | `npm install` |
| `apps/seller` | `npm run dev` (Nuxt) | `npm install` |
| `apps/admin` | `npm run dev` (Nuxt) | `npm install` |
| `backend/api` | `php artisan serve` or `composer dev` | `composer install` + `npm install` |

### 7.2 CI/CD

GitHub Actions workflows live in `backend/api/.github/workflows/` (and will be added at the root for cross-app workflows). Each app has its own build, test, and deploy pipeline:

```
Push to main
  │
  ├─ backend/api  → run tests → build Docker image → push to GHCR
  ├─ apps/client  → run tests → build Flutter → deploy to stores
  ├─ apps/public-web → build Nuxt → deploy to static/hosting
  ├─ apps/admin   → build Nuxt → deploy
  └─ apps/seller  → build Nuxt → deploy (when implemented)
```

### 7.3 Versioning

The monorepo does not use a single version number. Each app is versioned independently:

| App | Version source | Current |
|-----|---------------|---------|
| `apps/client` | `pubspec.yaml` | `2.0.0+1` |
| `apps/public-web` | `package.json` | per-release |
| `apps/admin` | `package.json` | per-release |
| `apps/seller` | `package.json` | per-release |
| `backend/api` | `composer.json` + Git tags | per-release |
