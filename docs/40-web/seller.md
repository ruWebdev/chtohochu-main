# Seller Cabinet (Nuxt 4)

> **Status:** Authoritative architecture document for the seller cabinet application.
> Conflicts with `AGENTS.md` must be resolved via an ADR in `docs/adr/`.

## 1. Purpose

The seller cabinet is the web application for sellers (merchants) who list products, manage catalogs, fulfill orders, and track analytics on ЧтоХочу.

It provides:

* seller dashboard with key metrics;
* product and catalog management (CRUD);
* offer management (pricing, availability, promotions);
* order management (view, process, fulfill, cancel);
* analytics and reporting (sales, views, conversions);
* billing and payout management;
* seller profile and settings.

It is a **distinct application context** from the user web, public web, and admin backoffice.

## 2. Technology Stack

| Concern | Choice |
|---------|--------|
| Framework | Nuxt 4 (Vue 3, TypeScript) |
| Rendering | SPA mode (`ssr: false`) |
| Routing | File-based Nuxt routing |
| State | Pinia for client-side state |
| HTTP | `$fetch` / `useFetch` with API token interceptor |
| Auth | Laravel Sanctum API tokens (bearer tokens) |
| Styling | Tailwind CSS or component library (project decision) |
| Deployment | Static build served by Nginx/Traefik |

## 3. Rendering Mode: SPA

The seller cabinet runs in **SPA mode**. There is no server-side rendering.

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  ssr: false,
  runtimeConfig: {
    public: {
      apiBaseUrl: process.env.NUXT_PUBLIC_API_BASE_URL,
    },
  },
});
```

### Why SPA

* The seller cabinet is an authenticated, dashboard-style application — SEO is irrelevant.
* No public/crawlable content.
* SPA mode simplifies deployment (static files, no Node server required).
* Faster development iteration for dashboard UIs.
* All data is fetched client-side after authentication.

## 4. Application Structure

```text
apps/seller/
├── nuxt.config.ts
├── package.json
├── app.vue
├── layouts/
│   ├── default.vue          # Authenticated layout with sidebar
│   └── auth.vue             # Unauthenticated layout (login)
├── middleware/
│   ├── auth.global.ts       # Redirect to login if unauthenticated
│   └── seller.guard.ts      # Verify seller role/permissions
├── pages/
│   ├── login.vue
│   ├── index.vue            # Dashboard
│   ├── products/
│   │   ├── index.vue        # Product list
│   │   ├── create.vue       # New product
│   │   └── [id]/
│   │       ├── index.vue    # Product detail/edit
│   │       └── offers.vue   # Offers for product
│   ├── catalog/
│   │   └── index.vue        # Category/catalog management
│   ├── offers/
│   │   ├── index.vue
│   │   └── [id].vue
│   ├── orders/
│   │   ├── index.vue        # Order list
│   │   └── [id].vue         # Order detail
│   ├── analytics/
│   │   └── index.vue
│   ├── billing/
│   │   ├── index.vue        # Overview
│   │   ├── payouts.vue
│   │   └── invoices.vue
│   └── settings/
│       └── index.vue
├── composables/
│   ├── useApi.ts            # Authenticated $fetch wrapper
│   ├── useAuth.ts           # Auth state management
│   └── useSeller.ts         # Seller context
├── stores/
│   ├── auth.ts              # Pinia auth store
│   ├── products.ts
│   ├── orders.ts
│   └── analytics.ts
└── components/
    ├── ui/                  # Shared UI components
    ├── products/
    ├── orders/
    └── charts/
```

## 5. Authentication

### Mechanism

The seller cabinet authenticates via **Laravel Sanctum API tokens** (bearer tokens), not cookie-based sessions.

### Flow

1. Seller navigates to `/login`.
2. Submits email + password (or OAuth if seller supports it).
3. Backend issues a Sanctum API token with seller-scoped abilities.
4. Token stored in `localStorage` (or `sessionStorage` for ephemeral sessions).
5. All API requests include `Authorization: Bearer {token}` header.
6. On logout, token is revoked via API and cleared from storage.

### Token storage

```ts
// composables/useAuth.ts
const TOKEN_KEY = 'seller_api_token';

export const useAuth = () => {
  const token = useState<string | null>('auth_token', () => null);

  const setToken = (t: string) => {
    token.value = t;
    localStorage.setItem(TOKEN_KEY, t);
  };

  const clearToken = () => {
    token.value = null;
    localStorage.removeItem(TOKEN_KEY);
  };

  const initFromStorage = () => {
    const stored = localStorage.getItem(TOKEN_KEY);
    if (stored) token.value = stored;
  };

  return { token, setToken, clearToken, initFromStorage };
};
```

### Authenticated API client

```ts
// composables/useApi.ts
export const useApi = () => {
  const { token } = useAuth();
  const config = useRuntimeConfig();

  return $fetch.create({
    baseURL: config.public.apiBaseUrl,
    headers: {
      Authorization: token.value ? `Bearer ${token.value}` : '',
    },
    onResponseError({ response }) {
      if (response.status === 401) {
        navigateTo('/login');
      }
    },
  });
};
```

### Auth middleware

```ts
// middleware/auth.global.ts
export default defineNuxtRouteMiddleware((to) => {
  const { token, initFromStorage } = useAuth();
  initFromStorage();

  const isAuthRoute = to.path === '/login';

  if (!token.value && !isAuthRoute) {
    return navigateTo('/login');
  }

  if (token.value && isAuthRoute) {
    return navigateTo('/');
  }
});
```

## 6. Feature Modules

### Dashboard (`/`)

* Key metrics: total products, active offers, pending orders, revenue (period).
* Recent orders list.
* Low-stock or inactive product alerts.
* Quick actions: add product, view orders.

### Products (`/products`)

* Paginated, searchable, filterable product list.
* Create/edit product with: name, description, images, category, attributes.
* Image upload with validation (see security doc).
* Bulk actions: activate/deactivate, delete.
* Product status: draft, active, inactive.

### Catalog (`/catalog`)

* Category tree management.
* Category assignment for products.
* Attribute/schema management per category.

### Offers (`/offers`)

* Create offers tied to products.
* Manage pricing, discount, availability windows.
* Promotional offers with start/end dates.
* Offer status tracking.

### Orders (`/orders`)

* Order list with filters: status, date range, customer.
* Order detail: items, customer info, shipping, payment status.
* Actions: confirm, ship, mark fulfilled, cancel (with reason).
* Order status workflow enforced by backend.

### Analytics (`/analytics`)

* Sales over time (charts).
* Product view / conversion metrics.
* Revenue breakdown by product/category.
* Date range selection.
* Export to CSV (client-side generation from API data).

### Billing (`/billing`)

* Payout schedule and history.
* Invoice list and download.
* Commission/fee breakdown.
* Payment method management.
* All financial calculations are backend-authoritative — the cabinet only displays.

### Settings (`/settings`)

* Seller profile (name, logo, description).
* Contact information.
* Notification preferences.
* API token management (view/revoke tokens).
* Store policies.

## 7. Boundary Rules

### MUST NOT

* Contain admin functionality (user management, platform moderation, seller approval, audit logs).
* Import from `apps/public-web/`, `apps/admin/`, or `apps/client/` (Flutter) codebases.
* Perform authorization decisions client-side — all enforcement is backend.
* Trust client-side role checks as security.
* Access user-facing features (wishlists, friends, shopping lists) — those belong to the user web.

### MUST

* Be a standalone Nuxt application with its own `package.json` and `nuxt.config.ts`.
* Authenticate via Sanctum API tokens.
* Use the `/api/v1/seller/` namespace for seller-specific endpoints.
* Handle 401/403 responses gracefully (redirect to login or show permission error).
* Validate all forms client-side for UX, but rely on backend validation for correctness.

## 8. Runtime Configuration

| Config key | Scope | Example |
|------------|-------|---------|
| `public.apiBaseUrl` | Public | `https://api.chtohochu.ru` |

No server-side runtime config is needed (SPA mode, no SSR).

## 9. Error Handling

| Scenario | Behavior |
|----------|----------|
| 401 Unauthorized | Clear token, redirect to `/login` |
| 403 Forbidden | Show "insufficient permissions" message; do not redirect to login |
| 404 Not found | Show not-found state within the layout |
| 422 Validation error | Display field-level errors on forms |
| 429 Rate limited | Show "too many requests, try again later" |
| 500 Server error | Show generic error with retry option |
| Network failure | Show offline banner with retry |

## 10. Deployment

* `nuxt build` produces static output (SPA mode).
* Served as static files by Nginx/Traefik.
* SPA fallback: all routes serve `index.html` (client-side routing).
* Environment configuration via build-time env vars or runtime `window.__CONFIG__`.
* Health check: static file or Nginx-level check.
* No persistent server-side state — fully stateless, horizontally scalable.
