# ADR-011: Multi-application web architecture

## Status

Accepted

## Context

ЧтоХочу has three distinct web surfaces with different requirements (AGENTS.md §5):

- **public-web** — marketing, SEO, public content, and the authenticated user cabinet.
  Requires SSR for SEO and crawlable URLs. Uses Sanctum cookie auth for the cabinet.
- **seller** — seller cabinet (catalog, offers, orders). An authenticated dashboard
  behind a login; no SEO requirement. Uses Sanctum token auth.
- **admin** — admin/backoffice (user management, moderation, system monitoring). An
  internal, authenticated dashboard with Spatie role-based permissions. Uses Sanctum
  token auth.

These surfaces differ in rendering mode (SSR vs SPA), auth model (cookie vs token),
audience (public vs seller vs admin), security posture (public vs internal-only), and
deployment lifecycle. AGENTS.md §5 mandates hard boundaries: `public-web` MUST NOT
import from `seller` or `admin`; `seller` MUST NOT contain admin functionality;
`admin` MUST NOT be treated as a normal user application.

The web stack is Nuxt 4 / Vue 3 / TypeScript (AGENTS.md §9). The choice is how to
structure the three surfaces: one app with route guards, separate apps, or
micro-frontends.

## Decision

Implement the three surfaces as **separate Nuxt 4 applications**: `apps/public-web`,
`apps/seller`, `apps/admin`.

Each app has its own `package.json`, build, deployment, runtime config, design
system, and hostname (see ADR-009). They share TypeScript types and utilities via
`packages/` and communicate with the backend exclusively via the REST API and
WebSocket. No app imports another app's source code.

- `public-web`: `ssr: true` (SSR for SEO).
- `seller`: `ssr: false` (SPA dashboard).
- `admin`: `ssr: false` (SPA dashboard).

## Consequences

**Positive**

- **Hard boundaries by construction.** Separate apps cannot import each other's
  source code. The AGENTS.md §5 boundary rules are enforced at the filesystem level,
  not just by code review.
- **Right rendering mode per surface.** `public-web` gets SSR for SEO; `seller` and
  `admin` get SPA simplicity without SSR-side auth complexity.
- **Right auth model per surface.** `public-web` uses Sanctum cookie sessions for the
  cabinet; `seller` and `admin` use Sanctum tokens. The auth models do not leak
  across surfaces.
- **Independent deployment.** Each app deploys on its own schedule. A seller cabinet
  release does not require redeploying the marketing site.
- **Independent design system.** Each app has its own UI; Flutter UI patterns are not
  forced onto web (AGENTS.md §9).
- **Security isolation.** `admin` is internal-only and can be network-restricted
  independently of the public site.

**Negative**

- **Code duplication.** Shared UI primitives (buttons, inputs) may be duplicated
  across apps. Mitigated by sharing non-business utilities in `packages/` and
  accepting that each app owns its design system. Business logic is not duplicated
  because it lives in the backend.
- **Three builds to maintain.** Dependency updates and build configuration must be
  applied to each app. This is the cost of independence and is acceptable.
- **No shared runtime state.** State cannot be shared across apps at runtime; they
  communicate through the backend. This is a feature, not a bug — it enforces the
  API-as-contract boundary.

## Alternatives considered

### Single app with route guards

One Nuxt app with route guards separating public, seller, and admin sections.

- **Strengths:** one build, one deployment, shared UI primitives.
- **Rejected because** it violates the AGENTS.md §5 boundary rules in spirit and in
  practice: a single app inevitably shares state, components, and auth context across
  sections, making it easy for seller/admin code to leak into the public bundle and
  for the public SSR app to carry admin auth complexity. It forces a single rendering
  mode (or per-route mode juggling), a single auth model, and a single deployment
  lifecycle onto three surfaces with genuinely different requirements. The security
  posture also suffers: admin code is served by the same app as the public site,
  making network-level isolation impossible. The boundary enforcement that separate
  apps give for free is lost.

### Micro-frontends

Compose the three surfaces from independently deployed micro-frontends at runtime
(e.g. Module Federation).

- **Strengths:** independent deployment with a single shell; runtime composition.
- **Rejected because** it introduces significant operational and build complexity
  (shared dependency negotiation, runtime version compatibility, a shell app, CDN
  coordination) disproportionate to a three-surface product. Micro-frontends solve
  organisational scaling (many teams, many fronts); ЧтоХочу has a small number of
  surfaces and does not need runtime composition. Separate Nuxt apps give the same
  deployment independence with far less complexity and no runtime coupling. AGENTS.md
  §5 and §16 favour hard boundaries and explicit dependencies; micro-frontends add
  implicit runtime coupling that works against that.
