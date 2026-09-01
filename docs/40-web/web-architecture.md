# Web Architecture Overview — ЧтоХочу

> **Status:** Authoritative web architecture document covering all Nuxt 4
> applications. See the per-app docs ([`public-web.md`](./public-web.md),
> [`seller.md`](./seller.md), [`admin.md`](./admin.md), [`user-web.md`](./user-web.md))
> and [`ADR-011-multi-app-web.md`](../adr/ADR-011-multi-app-web.md).

## 1. Overview

The ЧтоХочу web surface is composed of **independent Nuxt 4 applications**, each with
its own runtime, build, deployment, and design system. They share contracts through
`packages/` and communicate with the backend exclusively via the REST API and
WebSocket (see [`api-boundary.md`](../01-architecture/api-boundary.md)).

| Application | Rendering | Auth | Purpose |
|-------------|----------|------|---------|
| `apps/public-web` | SSR | Sanctum cookie / none | Marketing, SEO, public pages, user cabinet |
| `apps/seller` | SPA (`ssr: false`) | Sanctum tokens | Seller cabinet |
| `apps/admin` | SPA (`ssr: false`) | Sanctum tokens | Admin backoffice |

## 2. Technology Stack

All web apps share the same stack:

| Concern | Choice |
|---------|--------|
| Framework | Nuxt 4 |
| UI framework | Vue 3 (Composition API, `<script setup lang="ts">`) |
| Language | TypeScript (strict mode) |
| Routing | File-based Nuxt routing / Vue Router |
| State | Composables + `useState`; no Pinia/Riverpod (AGENTS.md §9, §16) |
| HTTP | `$fetch`, `useFetch`, `useAsyncData` against the backend API |
| Styling | Per-app design system (Tailwind CSS or scoped styles — project decision) |
| Runtime config | `runtimeConfig` populated from environment variables |

## 3. SSR vs SPA

Rendering mode is chosen per application based on requirements:

### 3.1 public-web — SSR

SSR is mandatory for public-facing routes. SEO, social share crawlers, and first
contentful paint require server-rendered HTML.

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  ssr: true,
});
```

### 3.2 seller and admin — SPA

The seller and admin apps are authenticated dashboards behind a login. They do not
need SEO or crawlable URLs, so they run in SPA mode (`ssr: false`) for simplicity and
to avoid SSR-side auth complexity.

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  ssr: false,
});
```

## 4. Composables and State Management

Reusable logic lives in **composables** (`composables/*.ts`). State management uses
Nuxt's `useState` for ephemeral shared state. There is no Pinia and no Riverpod in web
apps (AGENTS.md §9, §16). Introducing Pinia or another state library requires an
approved ADR.

```ts
// composables/useAuth.ts
export const useAuth = () => {
  const user = useState<User | null>('auth-user', () => null);
  const isAuthenticated = computed(() => user.value !== null);
  return { user, isAuthenticated };
};
```

## 5. API Communication

All API access uses `$fetch`, `useFetch`, and `useAsyncData` against the backend API.
The base URL comes from runtime config:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  runtimeConfig: {
    public: {
      apiBaseUrl: process.env.NUXT_PUBLIC_API_BASE_URL,
    },
    server: {
      apiInternalBaseUrl: process.env.NUXT_SERVER_API_INTERNAL_BASE_URL,
    },
  },
});
```

```ts
const { public: { apiBaseUrl } } = useRuntimeConfig();
const { data } = await useFetch(`${apiBaseUrl}/wishlists/${id}`);
```

Rules:

- No app imports another app's source code (AGENTS.md §5).
- Shared TypeScript types and utilities live in `packages/`.
- The API contract is defined by the backend; web apps consume it.
- No direct database access from any web app.

## 6. Independent Runtime Boundaries

Each Nuxt app is an independent runtime:

- **Separate `package.json`.** No path aliases to sibling apps.
- **Separate build and deployment.** No build-time coupling between apps.
- **Separate design system.** Do not force Flutter UI patterns onto web (AGENTS.md §9).
- **Separate runtime config.** Each app has its own environment variables.
- **Separate domain.** Each app is served on its own hostname
  (see [`local-routing.md`](../10-development/local-routing.md)).

Boundary enforcement is described in
[`application-boundaries.md`](../01-architecture/application-boundaries.md) §8.

## 7. Shared Code

Shared TypeScript code lives in `packages/`:

| Package | Consumers |
|---------|-----------|
| `@chtohochu/api-types` | public-web, seller, admin |
| `@chtohochu/api-client` | public-web, seller, admin |
| `@chtohochu/shared-utils` | public-web, seller, admin |
| `@chtohochu/shared-constants` | public-web, seller, admin |

Flutter does not consume `packages/` (different language). Shared code in `packages/`
contains types and utilities, never business logic.

## 8. Realtime on Web

Web apps MAY consume realtime events over Reverb for live notifications and presence.
Collaborative editing is a Flutter concern; the web apps use realtime for
notifications and lightweight live updates, not for offline-capable collaborative
editing. See [`realtime.md`](../20-backend/realtime.md).

## 9. Non-Goals

- No Riverpod in Nuxt (AGENTS.md §16).
- No Pinia without an approved ADR.
- No cross-app source imports.
- No business logic in web apps; business rules live in the backend.
- No single mega-app with route guards instead of separate apps (see
  [`ADR-011-multi-app-web.md`](../adr/ADR-011-multi-app-web.md)).
