# ADR-001: Monorepo structure

## Status

Accepted

## Context

ЧтоХочу is a multi-application product. A single user-facing feature typically
touches several independently built artifacts at the same time:

- a **Flutter** client (iOS, Android, authenticated web) that consumes the API
  and the realtime channel;
- a **Nuxt** public marketing site (SSR, SEO-critical landing pages and shared
  wishlist content);
- a **Nuxt** seller cabinet (authenticated SPA for merchants managing their
  catalogs and offers);
- a **Nuxt** admin panel (authenticated SPA for platform operators);
- a **Laravel** backend that owns the API, realtime, queues, notifications and
  integrations.

These artifacts are not independent products. They share:

- **domain types and contracts** — the same `Wishlist`, `Wish`,
  `ShoppingListItem`, `Participant` and event shapes appear on the backend, in
  the Flutter DTOs and in the web clients;
- **API contracts** — the OpenAPI description of `/api/v1/` is consumed by all
  clients and produced by the backend;
- **realtime event contracts** — the `event_id` / `entity_type` / `revision`
  envelope described in AGENTS.md §23 must stay consistent across the Laravel
  broadcaster, the Flutter realtime handler and the web clients;
- **documentation** — architecture, feature specs, ADRs and development guides
  describe the system as a whole and must be co-located with the code they
  describe;
- **infrastructure** — Docker Compose files, Nginx/Traefik config, CI workflows
  and deployment scripts reference all applications together.

When a feature such as "shared shopping list item check/uncheck" is implemented,
a developer routinely needs to change the Laravel migration and action, the API
resource, the OpenAPI spec, the Flutter repository/DTO, the Flutter widget, and
possibly the web cabinet view. In a polyrepo setup each of those changes lives
in a separate repository with its own branch, pull request, review cycle and
release cadence. Coordinating a single behavioral change across five
repositories is slow and error-prone: contracts drift, a backend merge can land
before the matching client change, and reproducing a consistent local
development environment requires cloning and wiring up five repos at compatible
revisions.

The team is small and ships the whole product together. There is no independent
release of "the seller cabinet" that is not also accompanied by a backend
change. The coupling is real and intentional, so the repository boundary should
reflect it rather than fight it.

## Decision

Use a **single Git repository (monorepo)** for the entire ЧтоХочу product.

The repository is organized by concern into top-level directories:

```text
/
├── apps/                # client applications
│   ├── mobile/          # Flutter client (iOS, Android, web)
│   ├── web-public/      # Nuxt public marketing site (SSR/SEO)
│   ├── web-seller/      # Nuxt seller cabinet (SPA)
│   └── web-admin/       # Nuxt admin panel (SPA)
│
├── backend/             # Laravel modular monolith
│   ├── app/
│   ├── routes/
│   ├── database/
│   └── tests/
│
├── packages/            # shared, publishable or internal packages
│   ├── api-types/       # shared TS types generated from OpenAPI
│   ├── api-client/      # shared typed API client for web apps
│   └── eslint-config/   # shared lint/build config
│
├── infrastructure/      # Docker, Nginx/Traefik, CI, deployment
│   ├── docker/
│   └── ci/
│
├── docs/                # architecture, API, features, ADRs, dev guides
│   ├── architecture/
│   ├── api/
│   ├── features/
│   ├── decisions/
│   └── development/
│
├── AGENTS.md
└── README.md
```

Rules:

1. **One repository, one CI pipeline** (with per-app jobs that only run when the
   relevant paths change). A change to `backend/` does not rebuild Flutter.
2. **Shared packages live in `packages/`** and are consumed by the apps that
   need them via workspace links (pnpm/Turbo workspaces for TS, path
   dependencies for Dart). They are not published to an external registry unless
   a concrete reason appears.
3. **`AGENTS.md` and `docs/` live at the root** so the engineering contract and
   ADRs are visible from the repository root and apply to every app.
4. **Cross-app changes are one pull request.** A feature that spans backend +
   mobile + web-public is reviewed as a single atomic change.
5. **Branch protection and CODEOWNERS** are used to keep per-app ownership clear
   even inside the monorepo.
6. The structure in AGENTS.md §6 (`mobile/`, `backend/`, `web/`, `docs/`,
   `docker/`) is the earlier recommended layout. This ADR refines it to the
   `apps/` / `backend/` / `packages/` / `infrastructure/` / `docs/` layout to
   accommodate the three distinct Nuxt apps and shared packages. Where the two
   differ, this ADR supersedes AGENTS.md §6 per the precedence rule in §1.

## Consequences

**Positive**

- A feature spanning backend + clients is a single PR, a single review and a
  single merge. Contract drift is caught at review time, not at integration
  time.
- Shared types, the OpenAPI contract and the realtime event envelope can be
  generated once and consumed everywhere through `packages/`, so the clients
  cannot silently diverge from the backend.
- Documentation and ADRs are co-located with the code they govern; a developer
  reading `backend/app/Domain/ShoppingLists/` can find the matching feature spec
  and ADRs without leaving the repo.
- Local development environment is reproducible from one clone: `docker compose
  up` in `infrastructure/` brings up PostgreSQL, Redis, Reverb and the backend,
  and the apps can run against it.
- Atomic history: `git log -- backend/app/Domain/ShoppingLists
  apps/mobile/lib/features/shopping_lists` shows the full history of a feature
  across stack boundaries.
- CI can be path-aware: only run Flutter tests when `apps/mobile/` changes, only
  run Laravel tests when `backend/` changes.

**Negative**

- The repository is larger and clones are slower than a single-app repo. This is
  mitigated by shallow clones and partial clone (`--filter=blob:none`) when
  needed.
- CI configuration is more complex: it must be path-aware and manage
  cross-package caching (Turbo/pnpm, pub cache, Composer). This is a one-time
  setup cost.
- Access control is coarser: every contributor with write access can touch every
  app. We mitigate with CODEOWNERS and branch protection requiring review from
  the relevant app owners.
- Tooling must support workspaces (pnpm workspaces / Turborepo for TS, Melos or
  path deps for Dart). This is standard but adds a learning curve.
- A bad commit can in principle break multiple apps at once. Path-aware CI and
  per-app test suites mitigate this.

## Alternatives considered

### Polyrepo (one repository per app)

Each app (mobile, web-public, web-seller, web-admin, backend) in its own Git
repository, coordinated via published artifacts (npm packages, pub packages,
API specs).

- **Rejected because** the apps are tightly coupled by shared contracts and ship
  together. A cross-app feature would require opening PRs in five repos,
  publishing intermediate packages, and hoping the versions line up. Contract
  drift becomes a runtime problem instead of a compile/review problem. For a
  small team shipping one product, the coordination overhead outweighs the
  isolation benefits. Polyrepo is appropriate for genuinely independent
  products; ЧтоХочу is one product with multiple surfaces.

### Git submodules

Backend, each app and shared packages as separate repos, with the "main" repo
pinning them as submodules.

- **Rejected because** submodules combine the worst of both worlds: they keep
  the multi-repo coordination problem (separate histories, separate PRs, version
  pins) while adding notorious Git UX friction (detached HEAD, dirty submodule
  state, confusing clone/update commands). Cross-app changes still require
  commits in multiple repos and submodule pointer updates. They do not provide a
  true atomic view of the system at a single commit. Submodules are useful for
  vendoring third-party code; they are a poor fit for first-party tightly
  coupled code.
