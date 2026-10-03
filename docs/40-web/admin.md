# Admin / Backoffice (Nuxt 4)

> **Status:** Authoritative architecture document for the admin/backoffice application.
> Conflicts with `AGENTS.md` must be resolved via an ADR in `docs/adr/`.

## 1. Purpose

The admin/backoffice is the internal operations application for platform administrators and moderators.

It provides:

* platform administration;
* content moderation;
* user management (view, suspend, ban, reinstate);
* seller management (approval, suspension, verification);
* catalog/category oversight;
* reports and flag handling;
* audit log review;
* platform-wide configuration.

It is a **separate security boundary** from all other applications. It must not be treated as a normal user app.

## 2. Technology Stack

| Concern | Choice |
|---------|--------|
| Framework | Nuxt 4 (Vue 3, TypeScript) |
| Rendering | SPA mode (`ssr: false`) |
| Routing | File-based Nuxt routing |
| State | Pinia for client-side state |
| HTTP | `$fetch` / `useFetch` with API token interceptor |
| Auth | Laravel Sanctum API tokens with admin-scoped abilities |
| Styling | Tailwind CSS or component library (project decision) |
| Deployment | Static build served by Nginx/Traefik, restricted access |

## 3. Rendering Mode: SPA

The admin backoffice runs in **SPA mode**. No SSR.

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

* Internal tool — no SEO, no public access.
* Dashboard-style application with authenticated data.
* Static deployment simplifies infrastructure.
* All data fetched client-side after authentication.

## 4. Security Boundary

The admin backoffice is the highest-privilege application in the system. It has its own security boundary.

### Network-level restrictions

| Layer | Control |
|-------|---------|
| DNS | Admin domain not publicly advertised (e.g. `admin-internal.chtohochu.ru`) |
| Nginx/Traefik | IP allowlist for known office/VPN ranges |
| WAF | Additional rate limiting and request inspection |
| TLS | HTTPS mandatory; HSTS enabled |
| Auth | Separate auth flow; admin tokens have distinct abilities |

### Application-level restrictions

* Admin tokens are issued with `admin:*` Sanctum abilities.
* Every admin API endpoint checks `ability:admin:*` on the backend.
* Admin sessions have shorter token TTLs than user/seller tokens.
* Idle timeout: auto-logout after configurable inactivity (e.g. 15 minutes).
* No "remember me" for admin accounts.

## 5. Application Structure

```text
apps/admin/
├── nuxt.config.ts
├── package.json
├── app.vue
├── layouts/
│   ├── default.vue          # Authenticated admin layout
│   └── auth.vue             # Login layout
├── middleware/
│   ├── auth.global.ts       # Require authentication
│   ├── admin.guard.ts       # Verify admin role
│   └── idle.timeout.ts      # Auto-logout on inactivity
├── pages/
│   ├── login.vue
│   ├── index.vue            # Admin dashboard
│   ├── users/
│   │   ├── index.vue        # User list
│   │   └── [id].vue         # User detail (suspend/ban/reinstate)
│   ├── sellers/
│   │   ├── index.vue        # Seller list (pending/approved/suspended)
│   │   └── [id].vue         # Seller detail (approve/suspend/verify)
│   ├── catalog/
│   │   └── index.vue        # Platform catalog oversight
│   ├── moderation/
│   │   ├── index.vue        # Moderation queue
│   │   └── [id].vue         # Item review
│   ├── reports/
│   │   ├── index.vue        # Reports/flags queue
│   │   └── [id].vue         # Report detail
│   ├── audit/
│   │   └── index.vue        # Audit log viewer
│   └── settings/
│       └── index.vue        # Platform configuration
├── composables/
│   ├── useApi.ts            # Authenticated $fetch with admin token
│   ├── useAuth.ts           # Admin auth state
│   └── useIdleTimeout.ts    # Inactivity detection
├── stores/
│   ├── auth.ts
│   ├── users.ts
│   ├── sellers.ts
│   └── audit.ts
└── components/
    ├── ui/
    ├── users/
    ├── sellers/
    └── moderation/
```

## 6. Authentication

### Mechanism

Admin authentication uses **Laravel Sanctum API tokens** with admin-specific abilities. This is distinct from user and seller tokens.

### Token abilities

```text
admin:users:read
admin:users:write
admin:sellers:read
admin:sellers:write
admin:moderation:read
admin:moderation:write
admin:catalog:read
admin:catalog:write
admin:reports:read
admin:reports:write
admin:audit:read
admin:settings:read
admin:settings:write
```

### Flow

1. Admin navigates to `/login` (on the admin domain, behind IP allowlist).
2. Submits credentials (email + password + optional 2FA code).
3. Backend verifies admin role and 2FA, issues a short-lived Sanctum token with admin abilities.
4. Token stored in `sessionStorage` (cleared on tab close — no persistent admin tokens).
5. All API requests include `Authorization: Bearer {token}`.
6. Idle timeout middleware auto-logs out after inactivity.
7. On logout, token is revoked via API.

### 2FA requirement

Admin accounts MUST have two-factor authentication enabled. The login flow includes a 2FA code verification step. The backend enforces 2FA for all admin-ability token issuance.

### Idle timeout

```ts
// composables/useIdleTimeout.ts
export const useIdleTimeout = () => {
  const { clearToken } = useAuth();
  const TIMEOUT = 15 * 60 * 1000; // 15 minutes
  let timer: ReturnType<typeof setTimeout>;

  const reset = () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      clearToken();
      navigateTo('/login?reason=idle');
    }, TIMEOUT);
  };

  onMounted(() => {
    ['mousedown', 'keydown', 'touchstart'].forEach((event) => {
      window.addEventListener(event, reset, { passive: true });
    });
    reset();
  });
};
```

## 7. Role-Based Access

Not all admins have all abilities. The admin backoffice enforces role-based access at two levels:

### Client-side (UX only)

* Navigation items hidden based on the admin's abilities.
* Action buttons hidden if the admin lacks the write ability.
* Route middleware checks abilities and shows a 403 page if insufficient.

```ts
// middleware/admin.guard.ts
export default defineNuxtRouteMiddleware((to) => {
  const { token, abilities } = useAuth();

  if (!token.value) {
    return navigateTo('/login');
  }

  const requiredAbility = to.meta.ability as string | undefined;
  if (requiredAbility && !abilities.value.includes(requiredAbility)) {
    return navigateTo('/403');
  }
});
```

### Server-side (authoritative)

* Every admin API endpoint checks the specific ability via Sanctum's `ability` middleware.
* Client-side hiding is UX only — the backend rejects unauthorized requests regardless.

## 8. Feature Modules

### Dashboard (`/`)

* Platform metrics: total users, active sellers, pending moderation items, open reports.
* Recent activity summary.
* System health indicators (queue depth, error rate).

### Users (`/users`)

* Searchable, paginated user list.
* User detail: profile, activity, wishlists, reports against user.
* Actions: suspend, ban, reinstate (with reason, logged to audit).
* Cannot delete users from this interface — suspension/ban only (data retention/GDPR handled separately).

### Sellers (`/sellers`)

* Seller list with status filters: pending approval, active, suspended.
* Seller detail: profile, products, orders, ratings, reports.
* Actions: approve, suspend, revoke verification (with reason, logged to audit).

### Catalog (`/catalog`)

* Platform-wide category tree oversight.
* Merge/split categories.
* Manage category attributes and schemas.
* View products per category across all sellers.

### Moderation (`/moderation`)

* Queue of flagged/reported content (wishes, wishlists, product images, user avatars).
* Review interface: view content, context, reporter info.
* Actions: approve, remove, warn user (all logged to audit).
* Priority/sorting by severity and report count.

### Reports (`/reports`)

* User-submitted reports queue.
* Report detail: reporter, target, reason, evidence.
* Actions: dismiss, escalate, act (suspend/remove target).
* Status tracking: open, investigating, resolved, dismissed.

### Audit (`/audit`)

* Read-only audit log viewer.
* Filterable by: actor, action, entity type, date range.
* Every admin action appears here: user suspensions, seller approvals, moderation decisions, config changes.
* Exportable for compliance.

### Settings (`/settings`)

* Platform configuration: feature flags, rate limit thresholds, moderation rules.
* Only accessible to admins with `admin:settings:write`.
* Changes are logged to audit.

## 9. Boundary Rules

### MUST NOT

* Be treated as a normal user application — it has elevated privileges and distinct security controls.
* Contain user-facing features (wishlists, friends, shopping lists).
* Contain seller dashboard functionality (product CRUD, order fulfillment).
* Share authentication with the user web or seller cabinet.
* Be accessible without network-level restrictions (IP allowlist/VPN).
* Allow "remember me" or persistent sessions.

### MUST

* Be a standalone Nuxt application with its own `package.json` and `nuxt.config.ts`.
* Require 2FA for all admin accounts.
* Use `sessionStorage` for tokens (not `localStorage`).
* Enforce idle timeout.
* Log all admin actions to the audit trail (backend-enforced).
* Use the `/api/v1/admin/` namespace for admin-specific endpoints.
* Be deployed behind network-level access controls.

## 10. Runtime Configuration

| Config key | Scope | Example |
|------------|-------|---------|
| `public.apiBaseUrl` | Public | `https://api.chtohochu.ru` |

## 11. Audit Logging

Every destructive or state-changing admin action must be auditable.

### What is logged (backend-enforced)

| Field | Example |
|-------|---------|
| `actor_id` | Admin user ID |
| `actor_email` | admin@chtohochu.ru |
| `action` | `user.suspend` |
| `entity_type` | `user` |
| `entity_id` | 12345 |
| `reason` | "Spam activity" |
| `metadata` | `{ duration: 30 days }` |
| `ip_address` | Request IP |
| `user_agent` | Browser UA |
| `created_at` | Timestamp |

The admin UI displays this data read-only. No admin can delete or modify audit logs.

## 12. Deployment

* `nuxt build` produces static output (SPA mode).
* Served by Nginx/Traefik with:
  * IP allowlist (or VPN-only access).
  * HTTPS with HSTS.
  * Additional rate limiting.
  * No caching of authenticated responses.
* SPA fallback: all routes serve `index.html`.
* Health check: Nginx-level or static file.
* Deployed to a separate subdomain/host not linked from public-facing sites.
