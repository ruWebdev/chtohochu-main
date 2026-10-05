# ЧтоХочу — Engineering & Architecture Contract

## 1. Project Identity

**Product name:** ЧтоХочу

**Canonical identifier:** `chtohochu`

Use `chtohochu` consistently for repository structure, Docker, service names, package names, local domains, environment names, documentation, infrastructure, scripts, and CI/CD.

Do NOT use `what-i-want`, `what_i_want`, or `what-i-want-app` as identifiers.

---

## 2. Repository

**Canonical Git repository:**

```
git@github.com:ruWebdev/chtohochu-main.git
```

This is the ONLY repository. Do NOT:
- create another repository;
- split into multiple repositories;
- create nested Git repositories;
- change the `origin` remote without explicit instruction.

---

## 3. Source of Truth Hierarchy

```text
Product requirements
        ↓
Architecture documentation (docs/)
        ↓
AGENTS.md (this file)
        ↓
ADRs (docs/adr/)
        ↓
Implementation
        ↓
Existing prototype
```

The existing prototype is the **lowest** architectural authority.

AI agents MUST NOT silently change architecture. If a task requires an architectural change, the agent MUST:
1. Stop.
2. Explain the conflict.
3. Propose a solution.
4. Request approval.
5. Document the decision in an ADR.

---

## 4. Monorepo Structure

```text
/
├── apps/
│   ├── client/              # Flutter (iOS, Android, web)
│   ├── public-web/          # Nuxt 4 (marketing, SEO, public pages)
│   ├── seller/              # Nuxt 4 (seller cabinet, SPA)
│   └── admin/               # Nuxt 4 (admin/backoffice, SPA)
│
├── backend/
│   └── api/                 # Laravel (API, auth, business logic)
│
├── packages/                # Shared packages (only where justified)
│
├── infrastructure/
│   └── docker/              # Docker, Traefik, deployment configs
│
├── docs/                    # Architecture documentation
│   ├── 00-project/          # Vision, scope, terminology, prototype reset
│   ├── 01-architecture/     # Overview, monorepo, boundaries, auth, realtime, security
│   ├── 10-development/      # Setup, git workflow, docker, routing, HTTPS, environments, testing
│   ├── 20-backend/          # Architecture, API, auth, realtime, queues, database
│   ├── 30-client/           # Flutter architecture, state management, local storage, offline
│   ├── 40-web/              # Web architecture, public-web, seller, admin
│   ├── 50-infrastructure/   # Local development, deployment
│   └── adr/                 # Architecture Decision Records
│
├── .github/
│   ├── workflows/           # CI pipelines (path-aware)
│   ├── CODEOWNERS
│   └── pull_request_template.md
│
├── AGENTS.md                # This file
├── README.md
└── Makefile                 # Local development commands
```

---

## 5. Technology Stack

### Client (Flutter)

* Flutter
* Dart
* Riverpod (`flutter_riverpod`) — state management AND dependency injection
* `riverpod_generator` — generated providers
* GoRouter — navigation
* Dio + Retrofit — HTTP client and typed API clients
* Freezed + json_serializable — immutable models and state types
* Drift — local relational database
* flutter_secure_storage — credential storage
* Firebase Messaging — push notifications (transport only)
* Material 3

Do NOT use `flutter_bloc`, `equatable`, `get_it`, or `injectable` without an approved ADR.

### Web (Nuxt 4)

* Nuxt 4
* Vue 3 (Composition API, `<script setup lang="ts">`)
* TypeScript (strict mode)
* Vue Router
* Composables

### Backend (Laravel)

* Laravel
* PHP 8.3+
* PostgreSQL — primary database
* Redis — cache, queues, locks, rate limiting, realtime
* Laravel Reverb — WebSocket transport
* Laravel Sanctum — authentication
* Laravel Notifications
* Spatie Permission — authorization

### Infrastructure

* Docker
* Traefik — local reverse proxy
* PostgreSQL 16
* Redis 7
* S3-compatible object storage
* GitHub Actions (CI/CD)

---

## 6. Application Boundaries

| Application | Type | Auth | Domain | Purpose |
|-------------|------|------|--------|---------|
| `apps/client` | Flutter | Sanctum tokens | app.chtohochu.test | User client (mobile + web) |
| `apps/public-web` | Nuxt 4 SSR | None | www.chtohochu.test | Marketing, SEO, public content |
| `apps/seller` | Nuxt 4 SPA | Sanctum tokens | seller.chtohochu.test | Seller dashboard |
| `apps/admin` | Nuxt 4 SPA | Sanctum tokens | admin.chtohochu.test | Admin/backoffice |
| `backend/api` | Laravel | Central | api.chtohochu.test | API, auth, business rules, realtime |

Rules:
* `public-web` MUST NOT import code from `client`, `seller`, or `admin`.
* `seller` MUST NOT contain admin functionality.
* `admin` MUST NOT be treated as a normal user application.
* All apps communicate with the backend via REST API and WebSocket.
* No app shares business logic with another app except through `packages/`.

---

## 7. Domain Architecture

Local: `*.chtohochu.test`
Production: `*.chtohochu.ru`

```
www.chtohochu.test  → Public Web
app.chtohochu.test  → Flutter Web / user client
seller.chtohochu.test → Seller
admin.chtohochu.test  → Admin
api.chtohochu.test    → Laravel API
```

All local traffic enters through Traefik reverse proxy. Do NOT map domains to Docker container IPs directly.

---

## 8. Dependency Rules

### Flutter

```text
presentation → domain
data → domain
domain → (nothing framework-specific)
```

Domain MUST NOT depend on: Flutter, Dio/Retrofit, Drift, Firebase, Riverpod, platform APIs.

### Backend

```text
HTTP → Application → Domain
Infrastructure → Domain
Domain → (nothing framework-specific)
```

### Cross-app

* No app imports another app's source code.
* Shared types/contracts belong in `packages/`.
* The backend is the authoritative source for all shared state.

---

## 9. Backend Rules

* Controllers are thin: receive, authorize, validate, invoke, respond.
* Business logic belongs in Domain or Application layers.
* Every schema change requires a migration.
* Atomic multi-record mutations require transactions.
* Authorization is always server-enforced.
* Client-supplied ownership/permission data MUST NOT be trusted.
* Use PostgreSQL constraints (FK, unique, check, indexes).
* Redis is infrastructure only — never authoritative business storage.
* Queues are for async/non-critical work (push, email, image processing).
* Jobs with side effects MUST be idempotent or unique.

---

## 10. Flutter Rules

* Feature-first structure: `features/<feature>/{data,domain,presentation}`.
* Riverpod for state management and dependency injection. Prefer `Notifier`, `AsyncNotifier`, `StreamNotifier` and generated providers (`riverpod_generator`).
* GoRouter for navigation.
* Dio + Retrofit for HTTP. Feature code MUST NOT instantiate Dio.
* Freezed for immutable models and state types.
* Drift for offline-capable local persistence.
* Secure storage for credentials only.
* Material 3 with centralized design system (`app/theme/`).
* All user-facing strings MUST be localized.
* Generated code MUST NOT be edited manually.
* Android `applicationId` is `com.nd.chtohochu` (matches the Google Play package). The Gradle `namespace` (`ru.nd.chtohochu`) is separate and MUST NOT be treated as the store identity.
* Release builds MUST be signed with the dedicated upload keystore (`apps/client/android/app/chtohochu-upload.jks`, alias `chtohochu`) via `key.properties`. NEVER sign `release` with the debug keystore. Keystore and `key.properties` are git-ignored; back them up outside the repository. See ADR-013.
* Do NOT introduce `flutter_bloc`, `equatable`, `get_it`, or `injectable` without an approved ADR.
* Do NOT perform a mechanical BLoC → Riverpod migration. The prototype is disposable.

---

## 11. Nuxt Rules

* Vue 3 Composition API with `<script setup lang="ts">`.
* TypeScript strict mode.
* Composables for reusable logic.
* `public-web`: SSR enabled for SEO.
* `seller` and `admin`: SPA mode (`ssr: false`).
* Each Nuxt app has its own design system.
* Runtime config for API base URL via environment variables.

---

## 12. API Rules

* REST API under `/api/v1/`.
* JSON request/response bodies.
* Bearer token authentication (Sanctum).
* Cursor-based pagination preferred.
* Standard error format: `{ "message": "...", "errors": { ... } }`.
* Idempotency keys for retry-safe mutations.
* Rate limiting on auth and mutation endpoints.
* Additive changes preferred. Breaking changes require compatibility analysis.
* API contracts must be documented. Avoid undocumented implicit behaviour.

---

## 13. Realtime Rules

* Laravel Reverb is the WebSocket transport.
* PostgreSQL is the source of truth. Realtime is transport only.
* Domain logic MUST NOT depend on WebSocket transport.
* Realtime events may trigger refresh/reconciliation.
* Realtime endpoints must be environment-specific configuration. Never hardcode production URLs.
* Clients must survive: lost, duplicated, delayed, out-of-order events, and reconnects.

---

## 14. Authentication

Authentication is a protected product capability. Support:
* Registration (email/password)
* Login (email/password)
* VK OAuth
* Yandex OAuth

Rules:
* Backend remains authoritative for authentication and authorization.
* Clearly separate: authentication, authorization, session/token management, user profile.
* Do not couple OAuth provider-specific logic directly to UI.
* Credentials in secure storage only — never SharedPreferences, Drift, logs, or analytics.
* Never hardcode OAuth secrets in client code.

---

## 15. Authorization

* Authentication answers: "Who are you?"
* Authorization answers: "What are you allowed to do?"
* These MUST remain separate concepts.
* Admin and Seller permissions MUST be enforced server-side.
* Never rely only on frontend route protection for authorization.

---

## 16. Security Rules

* Server-side validation is mandatory.
* Server-side authorization is mandatory.
* HTTPS everywhere — including local development.
* File uploads are untrusted input — validate MIME, size, ownership.
* Rate limiting on auth, mutations, and expensive endpoints.
* CSRF protection for web sessions.
* CORS configured per application.
* Secrets in environment variables only — never committed.
* No production credentials locally.
* No wildcard production CORS.
* No disabled TLS verification as standard workaround.
* No client-side authorization.
* No hardcoded OAuth secrets.
* No hardcoded production API endpoints.
* Anything delivered to Flutter, browser JS, or public Nuxt runtime config is public.

---

## 17. Testing Rules

### Backend
* Unit tests for domain logic.
* Feature/integration tests for API endpoints.
* Authorization tests for every protected resource.
* Authentication must have integration tests.

### Flutter
* Unit tests for Riverpod provider/state logic.
* Repository tests with mock data sources.
* Widget tests for key screens.
* Integration tests for critical flows.

### Nuxt
* Unit tests for composables.
* Component tests for key components.
* E2E tests where justified.

Do not require every feature to have every test type automatically. Document which layer is appropriate for which kind of logic.

---

## 18. Environments

Three conceptual environments:

```text
local
staging
production
```

* Never use production credentials locally.
* Never use production database access by default.
* Never hardcode environment-specific URLs into feature code.
* Use `.env.example` as the committed template.
* Never commit: `.env`, `.env.production`, OAuth secrets, API keys, private keys, credentials, production secrets.

---

## 19. Git Workflow

* `main` is the primary branch.
* Short-lived branches: `feature/*`, `fix/*`, `refactor/*`, `chore/*`, `docs/*`, `test/*`.
* Do NOT introduce `develop`, `release`, `staging` branches without an ADR.
* Use Conventional Commit-style prefixes: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, `build:`, `ci:`.
* Use Git tags for releases: `v0.1.0`, `v0.2.0`, `v1.0.0`.

---

## 20. Coding Standards

* Flutter: `dart format`, `flutter analyze` must pass.
* Backend: Laravel Pint for PHP formatting.
* Nuxt: TypeScript strict mode, ESLint.
* No dead code. No commented-out code.
* No hardcoded design tokens in feature widgets.
* No business rules in UI widgets.
* No magic strings — use constants/enums.
* Prefer explicit behavior over implicit magic.

---

## 21. Forbidden Practices

* `flutter_bloc`, `equatable`, `get_it`, `injectable` in Flutter without an approved ADR.
* Vue/Pinia in Flutter.
* Riverpod in Nuxt applications.
* GraphQL without an approved ADR.
* Microservices without an approved ADR.
* Kafka/Elasticsearch/Kubernetes without an approved ADR.
* Firebase/Firestore as primary database.
* A second backend runtime.
* Hive for local storage (use Drift).
* MySQL (use PostgreSQL).
* Global mutable state.
* Business logic in controllers.
* Business logic in UI widgets.
* Manually editing generated files.
* Silently changing architecture.
* Introducing dependencies without justification.
* Duplicating domain concepts.
* Nested Git repositories.
* Secrets in Git.

---

## 22. Documentation Rules

* Architecture documentation in `docs/` is authoritative.
* ADRs in `docs/adr/` record WHY decisions were made.
* When architectural behaviour changes, update the relevant `docs/` file.
* Do not create documentation that merely repeats other documentation.
* Documentation must be concrete and actionable.
* Do not create duplicate documents containing contradictory information.

---

## 23. AI Agent Rules

1. Read `AGENTS.md` before making architectural changes.
2. Read relevant `docs/` before implementing a feature.
3. Inspect Git status and branch before making changes.
4. Inspect existing implementation before changing it.
5. Never overwrite user changes.
6. Never silently change architecture.
7. Never commit secrets.
8. Never force-push except when explicitly authorized.
9. Never delete branches.
10. Never create repositories or nested Git repositories.
11. Never introduce a dependency without justification.
12. Never modify generated files manually.
13. Update documentation when architectural behaviour changes.
14. Run validation after changes.
15. Inspect `git diff` before reporting.
16. Report modified files and validation results.

When uncertain:

```text
inspect documentation
        ↓
inspect existing architecture
        ↓
identify boundary
        ↓
make smallest correct change
        ↓
document architectural decision if necessary
```

If the architecture itself is insufficient, stop and document the architectural question rather than silently inventing a solution.

---

## 24. Media Storage Rules

* Media upload is a **separate lifecycle** from entity sync — entity creation (Wish, shopping list, avatar) MUST NEVER block on media upload or on S3/backend availability.
* The Flutter client never holds S3 credentials and never chooses bucket or object key. It only consumes short-lived presigned PUT URLs issued by the backend (SigV4, ~10 min TTL).
* Media API is purpose-based and reusable: `avatar | wish | shopping`. Ownership and entity-existence checks are server-enforced.
* ЧтоХочу uses **one physical S3 bucket** with three logical root prefixes: `chtohochu-avatars/`, `chtohochu-wish-images/`, `chtohochu-shopping-images/` (see `config/media.php` `key_prefix`). The bucket is shared with another project's prefixes — they MUST NEVER be read, modified, or deleted. Every object key MUST start with its purpose prefix; `complete`/`delete`/cleanup MUST re-assert the prefix before any storage operation. Public-read bucket policy MUST stay scoped to `chtohochu-*` only.
* Backend whitelists content types (`image/jpeg`, `image/png`, `image/webp`) and enforces `MEDIA_MAX_UPLOAD_BYTES`. Completion is verified against S3 (object exists, type/size match) — never trust a client-claimed `remote_url`.
* Local media lives under `Documents/media/<purpose>/` in persistent storage; Drift keeps `local_path` + `remote_url` + upload status (`pending | uploading | uploaded | failed`). `local_path` is never sent to the API and never erased by pull reconcile.
* Client-side compression is mandatory before persistence: orientation fix, max 2048 px, JPEG q82 (transparency is preserved — no forced JPEG).
* Uploads are idempotent via stable `client_id`/`upload_id` per local row — retries must not create duplicate objects.
* Remote object deletion is asynchronous (queue job) and idempotent — entity deletion must not block on S3.
* See `docs/adr/ADR-015-media-storage-s3-uploads.md` for the full contract.
