# Public Web (Nuxt 4)

> **Status:** Authoritative architecture document for the public web application.
> Conflicts with `AGENTS.md` must be resolved via an ADR in `docs/adr/`.

## 1. Purpose

The public web application is the marketing, SEO, and shareable-content surface of ЧтоХочу.

It exists to:

* attract organic traffic from search engines;
* present marketing landing pages;
* render publicly shareable content (public wishlists, public wishes) at stable, crawlable URLs;
* provide legal pages (terms of use, privacy policy);
* route deep-link/share tokens into the correct mobile or user-web destination;
* act as the canonical entry point for the brand domain.

It is **not** an authenticated application. It does not host the user cabinet, the seller cabinet, or the admin backoffice.

## 2. Technology Stack

| Concern | Choice |
|---------|--------|
| Framework | Nuxt 4 (Vue 3, TypeScript) |
| Rendering | Server-side rendering (SSR) by default |
| Routing | File-based Nuxt routing |
| State | Minimal — no global auth store; use `useState` for ephemeral page state |
| HTTP | `$fetch` / `useFetch` / `useAsyncData` against the backend API |
| Styling | Tailwind CSS or scoped component styles (project decision) |
| Deployment | Node server (Nuxt Nitro) behind Nginx/Traefik |

## 3. Rendering Mode

SSR is mandatory for all public-facing routes.

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  ssr: true,
  runtimeConfig: {
    public: {
      apiBaseUrl: process.env.NUXT_PUBLIC_API_BASE_URL,
      userWebUrl: process.env.NUXT_PUBLIC_USER_WEB_URL,
    },
    server: {
      apiInternalBaseUrl: process.env.NUXT_SERVER_API_INTERNAL_BASE_URL,
    },
  },
});
```

### Why SSR

* Search engines receive fully rendered HTML.
* Social share crawlers (Open Graph, Twitter Cards) receive meta tags without executing JavaScript.
* First contentful paint is fast for marketing visitors.
* Stable URLs (`/w/{slug}`, `/u/{username}`) are crawlable and bookmarkable.

### Pages that must be SSR

| Route | Content |
|-------|---------|
| `/` | Landing page |
| `/about` | About the product |
| `/pricing` | Pricing/marketing |
| `/terms` | Terms of use |
| `/privacy` | Privacy policy |
| `/w/{slug}` | Public wishlist preview |
| `/u/{username}` | Public user profile |
| `/s/{token}` | Share-token resolver |
| `/blog/{slug}` | Blog article (if applicable) |

## 4. Shareable URLs

Shareable URLs are a first-class product feature.

### URL contract

| Entity | URL pattern | Resolves to |
|--------|-------------|-------------|
| Public wishlist | `/w/{slug}` | Wishlist preview page |
| Public user profile | `/u/{username}` | Public profile page |
| Share token | `/s/{token}` | Backend resolves token → redirect to app or preview |

### Rules

* Slugs are server-generated, unique, and immutable for the lifetime of the public entity.
* The backend is the source of truth for slug → entity resolution.
* The public web fetches public content via the public API endpoints (no auth required).
* If an entity is private or deleted, the page renders a 404 or a "content unavailable" state — never a login wall.
* Open Graph and Twitter Card meta tags are rendered server-side from the resolved entity.

### Example: public wishlist page

```vue
<!-- pages/w/[slug].vue -->
<script setup lang="ts">
const route = useRoute();
const slug = route.params.slug as string;

const { data: wishlist, error } = await useFetch(
  () => `/v1/public/wishlists/${slug}`,
  {
    baseURL: useRuntimeConfig().public.apiBaseUrl,
  },
);

if (error.value?.statusCode === 404) {
  throw createError({ statusCode: 404, statusMessage: 'Wishlist not found' });
}

useSeoMeta({
  title: () => wishlist.value?.title ?? 'Wishlist',
  ogTitle: () => wishlist.value?.title,
  ogImage: () => wishlist.value?.coverImageUrl,
  twitterCard: 'summary_large_image',
});
</script>
```

## 5. Boundary Rules

The public web is a **distinct application context**. It must not become an authenticated app.

### MUST NOT

* Import from `apps/client/` (Flutter), `apps/seller/`, or `apps/admin/` codebases.
* Store or manage authentication tokens.
* Render authenticated user-cabinet functionality.
* Implement seller or admin features.
* Depend on Sanctum session cookies or bearer tokens.
* Access private API endpoints.

### MUST

* Consume only public, unauthenticated API endpoints.
* Keep its own `nuxt.config.ts`, `package.json`, and dependency tree.
* Use runtime config for all environment-specific URLs.
* Treat all rendered public content as untrusted output (escape, sanitize).

## 6. Runtime Configuration

All environment-specific values flow through Nuxt runtime config. No hardcoded URLs.

| Config key | Scope | Example |
|------------|-------|---------|
| `public.apiBaseUrl` | Public (browser + server) | `https://api.chtohochu.ru` |
| `public.userWebUrl` | Public | `https://app.chtohochu.ru` |
| `server.apiInternalBaseUrl` | Server-only | `http://backend:8000` |

### Server-side fetch optimization

When fetching data during SSR, use the internal backend URL to avoid the public network round-trip:

```ts
const config = useRuntimeConfig();
const baseUrl = import.meta.server
  ? config.server.apiInternalBaseUrl
  : config.public.apiBaseUrl;

const { data } = await useFetch('/v1/public/wishlists', { baseURL: baseUrl });
```

## 7. Deep-Link / Share Token Resolution

The `/s/{token}` route resolves a share token via the backend and redirects:

* If the token targets a public wishlist → render the preview page.
* If the token requires authentication → redirect to the user web app (`userWebUrl`) with the token as a query parameter so the authenticated app can handle join/claim.
* If the token is invalid or expired → render a "link expired" page.

The public web never performs the join/claim operation. It only resolves and redirects.

## 8. Caching Strategy

| Layer | Strategy |
|-------|----------|
| Nuxt route rules | Cache marketing pages at the Nitro edge (`routeRules: { '/': { swr: 3600 } }`) |
| Public entity pages | Short SWR (e.g. 60s) with revalidation; 404 for deleted/private |
| Backend | Public endpoints may be HTTP-cached with short TTLs |
| CDN | Static assets cached aggressively; HTML cached per route rule |

Example route rules:

```ts
export default defineNuxtConfig({
  routeRules: {
    '/': { swr: 3600 },
    '/terms': { prerender: true },
    '/privacy': { prerender: true },
    '/w/**': { swr: 60 },
    '/u/**': { swr: 60 },
    '/s/**': { swr: false }, // dynamic, no cache
  },
});
```

## 9. Error Handling

* 404 pages must be SSR-rendered and SEO-friendly.
* 500 errors must render a branded error page, never a stack trace.
* API failures during SSR must fall back to a graceful "content temporarily unavailable" state, not a crash.
* Client-side hydration errors must be caught and reported, not fatal.

## 10. SEO Requirements

* Every page sets a unique `<title>` and meta description via `useSeoMeta`.
* Canonical URLs are set for all pages.
* `robots.txt` allows crawling of public content; disallows `/s/` (share tokens are ephemeral).
* `sitemap.xml` is generated from public, indexable routes.
* Structured data (JSON-LD) is emitted for public wishlists and profiles where applicable.
* All user-facing strings are localized (Russian primary).

## 11. Performance Budget

| Metric | Target |
|--------|--------|
| LCP (landing) | < 2.5s on 4G |
| TTFB | < 600ms |
| JS bundle (initial) | < 150 KB gzipped |
| Images | Lazy-loaded, responsive `srcset`, WebP/AVIF |

## 12. Deployment

* Runs as a Node process (Nitro server) inside Docker.
* Served behind Nginx/Traefik with HTTPS termination.
* Health check endpoint: `/api/health` (Nitro route) or `/health`.
* No persistent local state — stateless horizontal scaling.
