# Authorization Model

> **Authority:** This document defines the authorization model for ЧтоХочу. It is normative
> for backend, mobile, and web. The backend is the final authorization authority; client-side
> checks are UX affordances only and are never security boundaries.

## 1. Principles

1. **Server authority.** Every protected operation is authorized on the server, on every
   request, using fresh state from PostgreSQL. The client is never trusted.
2. **Capability-based, role-mediated.** Authorization is expressed in terms of capabilities
   (permissions), not role names. Roles are bundles of capabilities; checks test capabilities.
3. **Roles are not mutually exclusive.** A user may hold `User` and `Seller` simultaneously.
   Authorization code must never assume a single role per user.
4. **Defense in depth.** Authentication, ownership, membership, permission, and visibility
   are each verified independently. Failing one must fail the operation.
5. **Explicit over magic.** Policies and gates are named and registered; no ad-hoc
   `if ($user->role === 'admin')` checks in controllers or views.

## 2. Roles

The system defines four roles. Roles are stored as Spatie `roles` rows with the `web` guard
name (the same guard used for both session and Sanctum authentication, since both resolve to
the `users` provider).

| Role | Purpose | Granted to |
|------|---------|------------|
| `User` | Baseline capabilities for any authenticated account. | Every registered account, automatically at registration. |
| `Seller` | Commercial capabilities: manage shop profile, list products, fulfill orders. | Any `User` who activates seller status. A seller is still a `User`. |
| `Moderator` | Content moderation: hide/review wishes, lists, comments, user-generated media. | Staff accounts. Does not imply `Admin`. |
| `Admin` | Full platform administration: user management, role assignment, system config. | Staff accounts with elevated trust. |

### 2.1 Non-exclusivity

A user can be a `User` **and** a `Seller`. A `Moderator` is typically also a `User`. An
`Admin` typically also holds `User`. Authorization code must use capability checks
(`$user->can('...')`), not role equality (`$user->hasRole('Admin')`), except where the
operation is definitionally role-scoped (e.g. "assign role X" requires `Admin`).

### 2.2 Role assignment

- `User` is assigned in `RegisterUserAction` at registration, inside the same transaction
  that creates the user. A user without the `User` role is an invalid state and must be
  treated as a bug.
- `Seller` is self-assigned via a future "become a seller" flow, gated by eligibility checks
  (verified email, accepted seller terms). The assignment is logged.
- `Moderator` and `Admin` are assigned only by an existing `Admin`, via an admin endpoint
  that itself requires the `assign-roles` capability. Assignment is audited.

### 2.3 Role removal

Removing the `User` role from an account is not permitted; it would leave the account in an
invalid state. To disable an account, use account suspension (a separate flag), not role
removal. Removing `Admin`/`Moderator` is reversible and audited.

## 3. Capabilities (Permissions)

Capabilities are fine-grained, verb-noun strings stored in the Spatie `permissions` table.
They are the unit of authorization. Roles map to capabilities through the
`role_has_permissions` pivot.

### 3.1 Naming convention

`<verb>-<noun>`, lowercase, hyphen-separated.

Examples:

| Capability | Meaning |
|------------|---------|
| `wishes.create` | Create a wish owned by the user |
| `wishes.update.own` | Update a wish owned by the user |
| `wishes.delete.own` | Delete a wish owned by the user |
| `wishlists.share` | Share a wishlist the user owns |
| `shopping-lists.invite` | Invite a participant to a shared shopping list |
| `shopping-lists.remove-participant` | Remove a participant from a shared shopping list |
| `seller.shop.manage` | Manage the seller's own shop profile |
| `seller.products.publish` | Publish a product listing |
| `moderation.content.hide` | Hide user-generated content |
| `moderation.content.review` | Review reported content |
| `admin.users.assign-roles` | Assign roles to a user |
| `admin.users.suspend` | Suspend a user account |

> The exact capability catalog is defined in the role/permission seeders and is the
> authoritative list. The examples above illustrate the naming scheme and granularity.

### 3.2 Ownership-relative capabilities

Many capabilities are scoped by ownership (`*.own`) or membership (`*.member`). These are
enforced by Laravel policies, not by Spatie alone, because Spatie checks only the capability
boolean. The policy combines the capability with a resource ownership/membership test:

```php
// Gate::define('update', [WishlistPolicy::class, 'update'])
public function update(User $user, Wishlist $wishlist): bool
{
    return $user->can('wishlists.update.own') && $user->id === $wishlist->user_id;
}
```

## 4. Spatie Permission Package

The project uses `spatie/laravel-permission` for role and permission storage and lookup.

### 4.1 Schema

The package's standard schema is used, with UUID primary keys on `roles`, `permissions`, and
the morph pivots (`model_has_roles`, `model_has_permissions`, `role_has_permissions`). The
`User` model uses the `HasRoles` trait. Teams support is disabled (`config/permission.teams`
is false); authorization is global, not tenant-scoped.

### 4.2 Guard

All roles and permissions are registered against the `web` guard name. Because both the
`web` (session) and `sanctum` guards resolve to the same `users` provider, the same
role/permission set applies to both API and web clients. Do not create parallel sets of
permissions for the `sanctum` guard.

### 4.3 Caching

Spatie caches role/permission assignments in the application cache (Redis). The cache is
keyed by the package's configured key and is invalidated on assignment changes via the
package's built-in cache-reset hooks. Application code that mutates roles/permissions
directly (e.g. via `DB::table`) must call `app('cache')->forget(config('permission.cache.key'))`
afterwards; prefer the `HasRoles` trait methods (`assignRole`, `removeRole`, `givePermissionTo`)
which handle this automatically.

### 4.4 Seeding

Roles, capabilities, and role→capability mappings are seeded by a database seeder and are
idempotent. The seeder is the source of truth for the catalog. Adding a capability requires:
1) adding it to the seeder, 2) mapping it to the appropriate role(s), 3) writing a policy
method that consumes it, 4) adding a test.

## 5. Server-Enforced Rules

### 5.1 The five checks

Every protected operation MUST verify, as applicable:

1. **Authentication** — the requester is an authenticated user.
2. **Ownership** — the requester owns the resource (for `*.own` capabilities).
3. **Membership** — the requester is a member of the resource (for shared lists, wishlists
   with participants).
4. **Permission** — the requester has the required capability, via role or direct grant.
5. **Visibility** — the resource is visible to the requester (public, shared, friends-only,
   private).

Failing any applicable check MUST fail the operation with `403 Forbidden` (or `404` when
visibility failure should not reveal existence — see [`../03-api/errors.md`](../03-api/errors.md)).

### 5.2 Enforcement points

- **Controllers** call `$this->authorize('action', $model)` or `Gate::authorize(...)` before
  mutating state. Controllers are thin (per AGENTS.md §16); authorization is one of the few
  things they do directly.
- **Form requests** may use `authorize()` for simple checks, but resource-scoped checks that
  need the route-model-bound entity belong in the controller/policy.
- **Policies** contain the ownership/membership/permission composition.
- **Database constraints** enforce invariants that cannot be bypassed by application bugs
  (e.g. unique memberships, check constraints on visibility enums). See
  [`../04-database/architecture.md`](../04-database/architecture.md).

### 5.3 What the server never trusts

- Client-supplied `user_id`, `owner_id`, `role`, `permissions`, `is_admin` fields.
- Client-supplied membership or participant lists used to authorize the same request.
- Client-supplied `visibility` that would broaden access beyond what the user may set.

These fields may be present in request bodies for convenience but are always overwritten or
ignored for authorization purposes.

## 6. Client-Side Checks Are UX-Only

The Flutter and Vue clients receive `roles` and `permissions` in the `/auth/me` response and
may use them to:

- hide or disable actions the user cannot perform;
- route the user away from screens they cannot access;
- show role-specific UI (seller dashboard, moderator queue).

These checks are **UX affordances**. They are not security. A user who manipulates the client
to send a request they "shouldn't" be able to send must be stopped by the server, not by the
UI. Concretely:

- Never rely on hiding a button to prevent the underlying API call.
- Never let the client decide final authorization for a mutation.
- Never ship a capability in a client-only bundle that the server doesn't also enforce.

## 7. Authorization and Realtime

Realtime events (Reverb) carry an `actor_id` and are delivered to authorized subscribers.
Authorization for realtime channels is enforced by Laravel's broadcast authorization route,
which runs the same gates/policies as REST. A client subscribed to a channel it later loses
access to must be disconnected by the server; the client must also tolerate being dropped.

See [`../05-realtime/`](../05-realtime/) for the realtime authorization contract.

## 8. Audit

Role assignments, role removals, capability grants, and suspensions are written to an audit
log with: actor, target, before/after, timestamp, request IP. Moderator/Admin actions are
always auditable. The audit log is append-only and stored in PostgreSQL.

## 9. Testing Requirements

Per AGENTS.md §40, authorization is tested at three levels:

1. **Policy tests** — each policy method, for owners/members/strangers/admins, expects
   `true`/`false` respectively.
2. **API tests** — each protected endpoint, for authenticated-but-unauthorized users,
   expects `403` (or `404` for hidden resources).
3. **Database constraint tests** — invariants that the DB enforces (e.g. unique membership)
   are tested by attempting the invalid insert and expecting a constraint violation.

Role non-exclusivity must be tested: a user with both `User` and `Seller` must be able to
perform both sets of capabilities.

## 10. Non-Goals

- No attribute-based access control (ABAC) engine. Capabilities + ownership/membership
  composition in policies is sufficient.
- No per-tenant roles (teams support is off).
- No client-side enforcement as security.
- No dynamic role creation at runtime. Roles are fixed to the four defined in §2; only
  capabilities may be extended, and only via seeder + ADR.
