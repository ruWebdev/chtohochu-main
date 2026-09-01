# ADR-004: Nuxt 4 as web framework

## Status

Accepted

## Context

ЧтоХочу requires three distinct web surfaces, each with different technical
requirements:

1. **Public marketing site** — landing pages, product explanation, public
   wishlist/share pages. This surface is **SEO-critical**, must be
   server-rendered (or statically generated) for social crawlers and search
   engines, must have fast first paint, and is mostly unauthenticated content.
2. **Seller cabinet** — an authenticated SPA where merchants manage their
   catalog, offers and orders. SEO is irrelevant; the app is behind a login,
   highly interactive, and consumes the same `/api/v1/` API and realtime
   contracts as Flutter.
3. **Admin panel** — an authenticated SPA for platform operators (moderation,
  user management, metrics). Also behind login, SEO-irrelevant, highly
  interactive, data-table-heavy.

All three surfaces share the same backend API, the same realtime event contract
and the same shared TS types (generated from OpenAPI in `packages/api-types`).
The web apps must not duplicate business rules — those stay on the backend
(AGENTS.md §35). The team is small and wants one web framework, one set of
tooling, one lint/build config and one pool of knowledge across all three
surfaces, while still being able to choose SSR for the public site and SPA for
the cabinets.

## Decision

Use **Nuxt 4** with **Vue 3** and **TypeScript** for all three web apps, each
configured for its rendering needs:

- `apps/web-public/` — **SSR** (or hybrid/SSG where pages are static) for SEO
  and fast first paint on public content.
- `apps/web-seller/` — **SPA** mode, fully client-rendered behind auth.
- `apps/web-admin/` — **SPA** mode, fully client-rendered behind auth.

Shared stack across all three (per AGENTS.md §35):

- **Vue 3** (Composition API, `<script setup>`)
- **TypeScript**
- **Vite** (Nuxt's build tool)
- **Pinia** for state management
- **Vue Router** for routing
- Shared types and API client from `packages/api-types` and `packages/api-client`
- Shared ESLint config from `packages/eslint-config`

Nuxt 4 is chosen over plain Vue + Vite specifically because the public site
needs SSR/SSG and file-based routing with layouts/middleware, and Nuxt provides
these as first-class, integrated capabilities. The seller and admin apps use
Nuxt in SPA mode (`ssr: false`) to keep a single framework and toolchain while
getting Nuxt's auto-imports, composables directory, modules ecosystem and
consistent project structure.

## Consequences

**Positive**

- **One framework, one toolchain.** All three web apps share Nuxt, Vite, Pinia,
  Vue Router, ESLint config and TS types. Developers move freely between the
  public site, seller cabinet and admin panel.
- **SSR where it matters, SPA where it doesn't.** Nuxt's rendering modes let
  each app be configured appropriately without switching frameworks. The public
  site gets SEO and fast first paint; the cabinets get a lightweight SPA with
  no SSR overhead.
- **Shared contracts.** All three apps consume the same `packages/api-types`
  (generated from OpenAPI) and `packages/api-client`, so they cannot silently
  diverge from the backend API or the realtime event envelope.
- **Business rules stay on the backend.** The web apps are view + orchestration
  layers over the same API Flutter uses, satisfying §35. No second
  implementation of business logic.
- **Vue 3 + Pinia is a good fit** for interactive authenticated SPAs: reactive,
  composable, low boilerplate. Pinia is the official, typed state-management
  solution for Vue.
- **Nuxt 4 module ecosystem** gives auth helpers, image optimization, sitemap,
  robots and other capabilities needed for the public site without hand-rolling.

**Negative**

- **Nuxt for SPA-only apps is slightly heavier** than plain Vue + Vite. The
  seller and admin apps carry Nuxt's conventions and module system even though
  they do not use SSR. This is an acceptable trade-off for toolchain
  uniformity and developer mobility across the three apps.
- **Vue/TS is a separate language from Dart.** The Flutter client does not
  share code directly with the web apps; sharing happens via generated OpenAPI
  types. This is already the plan and is fine.
- **Pinia is not Riverpod.** The state-management patterns differ between
  Flutter and web. This is expected: the platforms have different idioms, and
  business rules live on the backend anyway, so the clients only manage
  view/orchestration state.

## Alternatives considered

### React / Next.js

React with Next.js for the public site (SSR/SSG) and React + Vite (or Next in
SPA mode) for the seller and admin apps.

- **Strengths:** largest ecosystem; huge hiring pool; App Router for SSR;
  excellent for SEO on the public site.
- **Rejected because** it introduces a second UI paradigm (React) alongside
  Vue. AGENTS.md §35 contracts Vue 3 + Pinia + Vue Router for the web cabinet.
  Choosing React would supersede that contract and require an ADR justifying
  the switch; no such justification exists given Vue 3 + Nuxt 4 fully satisfies
  the SSR/SPA requirements. React's ecosystem size is not a decisive advantage
  for three apps whose backend interaction is a typed API client. The
  consistency of one web framework (Nuxt/Vue) across all three surfaces
  outweighs React's ecosystem margin.

### Plain Vue 3 + Vite (no Nuxt)

Vue 3 + Vite + Vue Router + Pinia for all three apps, hand-rolling SSR for the
public site.

- **Strengths:** lighter than Nuxt for the SPA apps; no Nuxt conventions to
  learn; full control.
- **Rejected because** hand-rolling SSR for the public site is exactly the
  problem Nuxt solves. SSR with data fetching, hydration, meta tags, sitemaps
  and SEO is non-trivial to build and maintain from scratch on plain Vue.
  Nuxt provides this as an integrated, documented first-party capability. For
  the SPA-only seller and admin apps, Nuxt's overhead is small and the benefit
  of one shared framework and project structure across all three apps is
  significant. Plain Vue + Vite would mean two different project structures
  (one with hand-rolled SSR for public, two without for cabinets), increasing
  cognitive load for a small team.

### Laravel Inertia

Use Laravel Inertia to render Vue components server-side through Laravel,
avoiding a separate Node/web runtime for the public site and cabinets.

- **Strengths:** keeps everything in Laravel; no separate web build/deploy for
  SSR; tight coupling of routing and data with Laravel controllers; great for
  admin/internal tools.
- **Rejected because** Inertia couples the web frontend tightly to Laravel's
  request/response cycle, which is a poor fit for the seller cabinet and admin
  panel, which are highly interactive realtime SPAs that consume the API and
  the WebSocket channel like Flutter does. Inertia's model is
  page-by-page server-driven navigation, not a long-lived SPA with realtime
  subscriptions. It also makes the public site's SSR depend on the Laravel
  runtime, which complicates scaling and CDN caching of public content. We
  want the web apps to be independent clients of the API (per §35: "Web may
  consume the same API and realtime contracts as Flutter"), not
  controller-rendered Inertia pages. Inertia is a good choice for
  Laravel-admin-heavy internal tools; it is not the right fit for a
  realtime-consuming seller cabinet and a SEO-optimized public site that
  benefits from being a standalone Nuxt app.
