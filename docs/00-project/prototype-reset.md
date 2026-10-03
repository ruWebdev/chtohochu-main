# Prototype Reset Record

## 1. Purpose

This document records what was inspected, what was preserved, what was discarded, and why, during the architectural reset of the ЧтоХочу prototype.

The prototype was a Flutter + Laravel application with business features (wishlists, wishes, friends, shopping lists, sharing, events, notifications, realtime, sync). The reset preserves authentication and visual/navigation knowledge while discarding the prototype's business architecture.

---

## 2. What Was Inspected

### Flutter prototype (`/home/nikolay/projects/old/chtohochu/flutter-frontend/`)

All `presentation/pages/*.dart` screens under `lib/features/` were inspected and catalogued in `docs/00-project/screen-inventory.md`. The inspection covered:

- **Auth screens:** SignInPage, SignUpPage, OAuthPage (VK/Yandex)
- **Onboarding:** OnboardingPage (pre-auth), PostAuthOnboardingPage (3-step wizard)
- **Main tabs:** WishListPage (home), PurchasesPage, FriendsPage, ProfilePage
- **Wish screens:** WishlistDetailPage, WishDetailPage, EditWishlistPage, EditWishPage, InboxWishesPage, WishlistParticipantsPage
- **Shopping list screens:** ShoppingListDetailPage, ShoppingListParticipantsPage
- **Events:** EventsPage (notification/activity feed)
- **Share:** SharePreviewPage (deep-link resolution)
- **Profile sub-screens:** ProfileEditPage, ProfileSettingsPage, ProfileNotificationsPage, AboutAppPage, TermsOfUsePage, PrivacyPolicyPage
- **Route constants** from `lib/app/router/routes.dart`

### Laravel prototype (`/var/www/chtohochu.ru/main/`)

The Laravel backend was inspected for:
- Auth controllers (AuthController, SocialAuthController)
- User model and migrations
- Auth routes (register, login, logout, me, VK/Yandex OAuth, password reset, email verification)
- Sanctum token configuration
- Spatie permission tables
- Configuration files

### Root architecture

The previous `AGENTS.md` was inspected. It prescribed:
- Riverpod 3 for state management and DI
- BLoC/GetIt as non-choices
- PostgreSQL as authoritative DB
- Drift as mobile local DB
- Reverb for realtime

The prototype implementation used BLoC + GetIt + Equatable, conflicting with the old AGENTS.md.

---

## 3. What Product Knowledge Was Preserved

The following product/UX knowledge was preserved as documentation, NOT as code:

1. **Screen inventory** (`docs/00-project/screen-inventory.md`) — every prototype screen, its purpose, navigation, states, UI elements, and product behaviour.
2. **Product vision** (`docs/00-project/vision.md`) — what the product is, value proposition, target audience, primary use cases.
3. **Domain terminology** (`docs/00-project/terminology.md`) — glossary of 18 domain terms.
4. **Product scope** (`docs/00-project/product-scope.md`) — in-scope and out-of-scope domains.
5. **UX patterns** — documented in the screen inventory:
   - SharePreviewPage as unified deep-link entry
   - Role-based permission gating
   - AppActionSheet for consistent bottom-sheet menus
   - Loading/empty/error/refresh states for every list
   - Unread badges for notifications
   - 3-step post-auth onboarding (first wish → friends → birthday)
   - Avatar upload flow (camera/gallery/delete)

---

## 4. What Implementation Was Discarded

### Flutter business implementation (removed)

- Wishlist/wish feature implementation (data, domain, presentation)
- Shopping list feature implementation
- Friends feature implementation
- Events/notifications feature implementation
- Share feature implementation
- Post-auth onboarding feature implementation
- Business profile data/domain layers
- Business Drift tables and DAOs
- Realtime service and WebSocket infrastructure
- Synchronization services
- Push notification service (FCM API)
- Business utility code
- Hive-related code (obsolete)

### Flutter state management (discarded as prototype code)

- **BLoC/Cubit** implementation (AuthBloc, all feature Blocs)
- **GetIt** dependency injection setup
- **Equatable** base classes
- All BLoC event/state classes

These were NOT migrated to Riverpod. The prototype BLoC code is disposable and will be replaced by Riverpod-based implementations in future tasks.

### Laravel business implementation (removed)

- Business controllers, models, events, listeners, notifications
- Business policies, requests, resources, services
- Business routes
- Business Vue/Inertia pages
- Business migrations (wishlists, wishes, friends, shopping lists, etc.)

### Dependencies removed from Flutter pubspec.yaml

- `flutter_bloc` — replaced by `flutter_riverpod`
- `equatable` — replaced by `freezed` (immutable models with value equality)
- `get_it` — replaced by Riverpod (DI via providers)

### Dependencies added to Flutter pubspec.yaml

- `flutter_riverpod: ^3.0.0` — state management and DI
- `riverpod_generator: ^4.0.0` (dev) — generated providers
- `riverpod_lint: ^3.0.0` (dev) — Riverpod-specific linting
- `retrofit: ^4.9.0` — typed API clients
- `retrofit_generator: ^10.0.0` (dev) — Retrofit code generation
- `freezed: ^3.0.0` (dev) — Freezed code generation
- `freezed_annotation: ^3.0.0` — Freezed annotations

---

## 5. Why Obsolete Architecture Was Removed

### BLoC + GetIt removal

The prototype used BLoC + GetIt + Equatable for state management and DI. The new architecture uses Riverpod as the single state-management and DI system because:

1. **Riverpod provides both state management and DI** — no need for a separate service locator (GetIt).
2. **Generated providers** (`riverpod_generator`) give explicit, testable, type-safe composition.
3. **No global mutable state** — Riverpod's `ProviderScope` is explicit and overridable for tests.
4. **`AsyncValue`** provides a unified loading/data/error model.
5. **Freezed** replaces Equatable for immutable models with value equality, code generation, and sealed classes.

The BLoC code was NOT mechanically migrated. It was discarded as prototype code. The auth feature will be reimplemented with Riverpod in a future task.

### Business feature removal

Business features were removed because:
1. The prototype architecture was not designed for offline-first, realtime-correct, server-authoritative operation.
2. The business logic was tightly coupled to the prototype's BLoC/data architecture.
3. Retaining business code would have preserved unsuitable architectural patterns.
4. The goal is a clean architectural baseline, not a working prototype.

### Laravel business removal

Laravel business code was removed because:
1. The business APIs were prototype-quality without proper authorization, validation, or transaction boundaries.
2. The business models were not designed for the new domain boundaries.
3. Retaining business routes would have created false API contracts.

---

## 6. What Remains Conceptually Supported

### Authentication (Flutter)

The following auth concepts remain supported and will be reimplemented with Riverpod:
- Email/password login
- Registration
- Logout
- Current-user validation
- VK OAuth
- Yandex OAuth
- Onboarding completion state
- Secure token storage
- API 401/419 force-logout behavior

### Authentication (Laravel)

The following auth functionality was retained in `backend/api/`:
- API registration/login/logout/logout-all/me
- Username availability check
- VK/Yandex social authentication
- Web login/register/logout
- Password reset
- Email verification
- Password confirmation
- Password update
- Sanctum personal access tokens
- Inertia authentication pages

### Visual/navigation skeleton (Flutter)

The following placeholder screens were retained as navigation structure:
- Splash page
- Onboarding page (minimal, auth-flow only)
- Home page (placeholder)
- Shopping/purchases page (placeholder)
- Friends page (placeholder)
- Profile page (auth-backed skeleton with logout)
- Profile settings (theme only)
- About / Terms / Privacy pages

---

## 7. Current Repository State

### Structure

```
/home/nikolay/Projects/ChtoHochu/
├── AGENTS.md                    # Engineering contract (Riverpod stack)
├── apps/
│   ├── client/                  # Flutter (prototype code, non-compiling)
│   ├── public-web/              # Nuxt 4 skeleton
│   ├── seller/                  # Nuxt 4 skeleton
│   └── admin/                   # Nuxt 4 skeleton
├── backend/
│   └── api/                     # Laravel (auth-only)
├── docs/                        # Architecture documentation
│   ├── 00-project/              # Vision, terminology, scope, screen inventory
│   ├── 01-architecture/         # Overview, monorepo, boundaries, frontend, backend, auth, security
│   ├── 10-development/          # Setup, workflow, testing, deployment, prototype-reset
│   ├── 20-backend/              # API, database, realtime, notifications, OAuth
│   ├── 30-client/               # Flutter architecture, state-management, local-storage, offline-first, ui
│   ├── 40-web/                  # Public-web, user-web, seller, admin
│   ├── 50-infrastructure/       # Local development, deployment
│   └── adr/                     # ADR-001 through ADR-013
├── infrastructure/              # (README pending)
└── packages/                    # (README pending)
```

### Flutter compilation status

The Flutter project at `apps/client/` does NOT compile because:
- The prototype auth code uses `flutter_bloc`, `get_it`, and `equatable` which were removed from `pubspec.yaml`.
- The prototype code was NOT migrated to Riverpod (intentionally — it is disposable prototype code).
- `flutter pub get` succeeds (dependencies resolve).
- `flutter analyze` reports errors in the prototype BLoC/GetIt code.

This is expected and acceptable. The auth feature will be reimplemented with Riverpod in a future task.

### Laravel status

- `composer install`: passes
- `php artisan route:list`: passes (27 auth/infrastructure routes)
- `php artisan test`: not run (requires pdo_sqlite or MySQL credentials)

### Nuxt status

- Skeleton apps created for public-web, seller, admin
- `npm install` not yet run

---

## 8. Remaining Work

### Flutter
- [ ] Reimplement auth feature with Riverpod (replacing BLoC AuthBloc)
- [ ] Replace GetIt DI with Riverpod providers
- [ ] Replace Equatable with Freezed for all models and state types
- [ ] Add Retrofit API client definitions
- [ ] Verify `flutter analyze` passes with 0 errors
- [ ] Verify `flutter test` passes

### Nuxt
- [ ] Run `npm install` for each Nuxt app
- [ ] Verify `nuxt typecheck` passes
- [ ] Verify `nuxt build` passes

### Laravel
- [ ] Set up test database (MySQL credentials or pdo_sqlite)
- [ ] Run `php artisan test`

### Infrastructure
- [ ] Create `infrastructure/README.md`
- [ ] Create `packages/README.md`
- [ ] Create root `README.md`
- [ ] Create root `.gitignore`

### Documentation
- [ ] Verify all docs use Riverpod terminology (no BLoC/GetIt/Equatable as architectural choices)
- [ ] Verify all ADRs are consistent with the Riverpod decision

---

## 9. Limitations

1. **Flutter does not compile.** The prototype BLoC code remains in `lib/` but references removed packages. This is intentional — the code is disposable and will be replaced.
2. **Laravel tests not run.** The environment lacks `pdo_sqlite` and valid MySQL credentials.
3. **Nuxt apps are skeletons only.** No `npm install` has been run.
4. **No Git repository at root.** The repository is not yet initialized as a Git repo at the monorepo root.
5. **Root README and .gitignore not yet created.**
