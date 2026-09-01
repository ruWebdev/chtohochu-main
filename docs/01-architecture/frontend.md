# Frontend Architecture — ЧтоХочу

This document covers the frontend architecture across both ecosystems: the Flutter mobile client and the Nuxt 4 web applications. Each has its own patterns, conventions, and layering rules.

---

## Part A: Flutter Client (`apps/client`)

### 1. Architecture Style

Flutter uses **feature-first architecture**. Each feature is a self-contained module with its own data, domain (optional), and presentation layers. Cross-feature infrastructure lives in `core/`. Shared UI components live in `shared/ui/`.

```
mobile/lib/

├── app/                           # App shell
│   ├── app.dart                   # MaterialApp configuration
│   ├── di/                        # Dependency injection (Riverpod)
│   ├── router/                    # GoRouter configuration, routes, shell
│   └── theme/                     # Material 3 theme: colors, typography, spacing
│
├── core/                          # Cross-feature infrastructure
│   ├── config/                    # Environment configuration (EnvConfig)
│   ├── constants/                 # API constants, storage keys
│   ├── database/                  # Drift database, tables, DAOs
│   ├── network/                   # Dio API client, interceptors
│   ├── services/                  # Secure storage, OAuth, app storage
│   └── errors/                    # Failures, exceptions
│
├── shared/                        # Shared UI components (no business logic)
│   └── ui/
│       ├── buttons/               # AppButton, AppBarIconButton
│       ├── cards/                 # AppCard
│       ├── display/               # AppAvatar, AppEmptyState, AppErrorState
│       ├── feedback/              # AppSnackBar
│       ├── inputs/                # AppSearchHeader, AppTextField
│       ├── navigation/            # AppBottomNavBar, CenterActionButton
│       └── sheets/                # AppActionSheet, FormSheet
│
├── features/                      # Feature modules
│   └── <feature>/
│       ├── data/                  # Data layer
│       │   ├── datasources/       # Remote + local data sources
│       │   ├── models/            # DTOs (Freezed + json_serializable)
│       │   └── repositories/      # Repository implementations
│       ├── domain/                # Domain layer (optional)
│       │   ├── entities/          # Domain entities
│       │   ├── repositories/      # Repository interfaces
│       │   └── usecases/          # Use cases (only when complex)
│       └── presentation/          # Presentation layer
│           ├── notifiers/         # Riverpod Notifiers
│           ├── pages/             # Full-screen pages
│           └── widgets/           # Feature-specific widgets
│
└── main.dart                      # Entry point
```

### 2. Layers

#### 2.1 Presentation layer

Contains: pages, widgets, Riverpod Notifiers, presentation state.

**Rules:**
- Pages and widgets contain only presentation logic.
- Presentation MUST NOT directly access Dio, Drift, secure storage, Firebase, or platform APIs.
- All data access flows through the repository via the state manager.

**Pattern (Riverpod 3):**
```
View (Page/Widget)
  ↓ watches
Notifier / AsyncNotifier / StreamNotifier
  ↓ calls
Repository
  ↓
Data sources (remote/local)
```

> **Note:** The prototype used BLoC + GetIt — this is disposable prototype code, not the target architecture. Riverpod 3 is the mandated state management and DI system (per AGENTS.md). See `docs/decisions/` for the ADR.

#### 2.2 Data layer

Contains: repositories, remote data sources, local data sources, DTOs, mappers.

**Rules:**
- Repositories are the application data boundary — presentation never bypasses them.
- Remote data sources wrap Dio/Retrofit API calls.
- Local data sources wrap Drift database operations.
- DTOs are Freezed classes with `json_serializable` for JSON (de)serialization.
- Mappers convert between DTOs and domain entities (or directly to presentation models for simple features).

**Data flow:**
```
Notifier
  ↓
Repository
  ↓
┌─────────────┬──────────────┐
│ Remote      │ Local        │
│ DataSource  │ DataSource   │
│ (Dio)       │ (Drift)      │
└─────────────┴──────────────┘
```

#### 2.3 Domain layer (optional)

The domain layer is **conditional**, not mandatory.

**Use it when:**
- Business rules are complex.
- Logic is reused by multiple presentation flows.
- Multiple repositories must be orchestrated.
- Domain invariants require dedicated modeling.

**Do NOT use it when:**
- The feature is simple CRUD.
- A single repository serves a single presentation flow.
- Creating a UseCase would just delegate to a single repository method.

For simple features (most features):
```
View → Notifier → Repository → Data sources
```

For complex features (e.g., sync, collaborative editing):
```
View → Notifier → UseCase → Repositories → Data sources
```

### 3. State Management

#### 3.1 Riverpod 3

Riverpod 3 is the mandated state management and DI system (per AGENTS.md). The prototype used BLoC + GetIt — this is disposable prototype code, not the target architecture.

- Use `Notifier`, `AsyncNotifier`, `StreamNotifier`.
- Use `riverpod_generator` for generated providers.
- Do NOT use legacy `StateProvider`, `StateNotifierProvider`, or `ChangeNotifierProvider`.
- States are immutable Freezed classes.
- Riverpod is the **only** DI mechanism — no global service locator.

#### 3.2 Dependency injection

Riverpod providers declare all dependencies. The dependency flow:
```
ApiClient → RemoteDataSource → Repository → UseCase (if needed) → Notifier → View
```

### 4. Navigation

**GoRouter** handles all declarative routing.

```
app/router/
├── app_router.dart     # Router configuration
├── routes.dart         # Route constants (paths + names)
├── router.dart         # Router export
└── shell_page.dart     # Bottom nav shell (StatefulShellRoute)
```

**Key routes** (from screen inventory):

| Route name | Path | Screen |
|-----------|------|--------|
| splash | `/splash` | SplashPage |
| onboarding | `/onboarding` | OnboardingPage |
| signIn | `/auth/sign-in` | SignInPage |
| home | `/` | WishListPage |
| purchases | `/purchases` | PurchasesPage |
| friends | `/friends` | FriendsPage |
| profile | `/profile` | ProfilePage |
| wishlistDetail | `/wishlist` | WishlistDetailPage |
| wishDetail | `/wish` | WishDetailPage |
| shoppingListDetail | `/shopping-list` | ShoppingListDetailPage |
| sharePreview | `/s` | SharePreviewPage |

**Deep linking:** Share tokens (`/s/{token}`) and push notification payloads resolve through GoRouter's redirect logic to the appropriate detail page.

### 5. Networking

**Dio** is the HTTP client. **Retrofit** generates typed API interfaces from annotations.

```
core/network/
├── api_client.dart       # Dio instance configuration, interceptors
└── network.dart          # Barrel export
```

**Rules:**
- Feature code MUST NOT instantiate Dio directly.
- All HTTP access flows through: `Notifier → Repository → RemoteDataSource → ApiClient → Dio`.
- Raw Dio exceptions MUST NOT reach presentation. Translate them into application-level `Failure` objects (`core/errors/failures.dart`).
- Interceptors handle: auth token injection, token refresh, error mapping, request logging.

**Retrofit example pattern:**
```dart
@RestApi(baseUrl: '/api/v1')
abstract class AuthApi {
  @POST('/auth/login')
  Future<AuthTokenDto> login(@Body() LoginRequestDto request);

  @GET('/auth/me')
  Future<UserDto> me(@Header('Authorization') String token);
}
```

### 6. Local Persistence (Drift)

Drift is the mobile relational persistence layer — the local source of truth for offline-capable domains.

```
core/database/
├── app_database.dart       # Database definition
├── app_database.g.dart     # Generated code (DO NOT EDIT)
└── (tables, daos, migrations will be added here)
```

**Rules:**
- Feature code accesses Drift through local data sources, never directly.
- UI MUST NOT access `AppDatabase` directly.
- Generated Drift code (`*.g.dart`) MUST NOT be edited manually.
- Every schema change requires updating the table definition and regenerating.

**Offline data flow:**
```
UI → Riverpod → Repository → Drift (local)
                              ↕
                        Sync Worker → API (remote)
```

The UI observes local persisted state. The network syncs that state. This prevents "online UI state" and "offline UI state" from becoming competing sources of truth.

### 7. Code Generation

The Flutter client relies heavily on code generation:

| Tool | Generates | Files |
|------|-----------|-------|
| `build_runner` | Orchestration | — |
| `freezed` | Immutable data classes, copyWith, equality, union types | `*.freezed.dart` |
| `json_serializable` | JSON (de)serialization | `*.g.dart` |
| `drift_dev` | Database queries, table companions | `*.g.dart` |
| `retrofit_generator` | Typed API client implementations | `*.g.dart` |

**Rules:**
- Generated files (`*.g.dart`, `*.freezed.dart`) MUST NOT be edited manually.
- After changing a source file, run: `dart run build_runner build --delete-conflicting-outputs`.
- Generated files are committed to the repository (not gitignored) to avoid CI build overhead.

### 8. Theming

Flutter uses **Material 3** with a centralized design system:

```
app/theme/
├── app_theme.dart        # ThemeData configuration
├── app_colors.dart       # Color palette (light + dark)
├── app_typography.dart   # Named text styles
├── app_spacing.dart      # Spacing constants, radii, dimensions
├── theme_colors.dart     # Semantic color aliases
└── theme.dart            # Barrel export
```

**Rules:**
- Do not hardcode colors, font sizes, spacing, or radii in widgets.
- Use named semantic styles (e.g. `AppTypography.headlineLarge`) not arbitrary `TextStyle` constructors.
- Do not chain `copyWith()` as a replacement for a missing semantic style — add the style to the theme.

### 9. Localization

All user-facing strings MUST be localized. The initial release supports `ru` (Russian).

- Use Flutter's built-in `flutter_localizations` with `AppLocalizations`.
- Do not hardcode user-facing strings in widgets.
- String keys follow the convention: `feature.context.message` (e.g. `auth.signIn.title`).

---

## Part B: Nuxt Web Applications

### 10. Architecture Style

The three Nuxt apps (`public-web`, `seller`, `admin`) share a common structure based on **Nuxt 4** with **Vue 3** and **TypeScript**.

```
apps/<app>/
├── app/
│   ├── pages/              # File-based routing (Vue Router)
│   ├── components/         # Vue components (auto-imported)
│   └── composables/        # Vue composables (auto-imported)
├── server/                 # Nitro server routes + middleware
├── public/                 # Static assets
├── nuxt.config.ts          # Nuxt configuration
├── package.json            # Dependencies
└── tsconfig.json           # TypeScript config
```

### 11. Rendering Strategies

| App | Mode | Rationale |
|-----|------|-----------|
| `public-web` | **SSR** (`ssr: true`) | Landing page needs SEO; cabinet needs fast first paint |
| `seller` | **SPA** (`ssr: false`) | Internal tool, no SEO, simpler deployment |
| `admin` | **SPA** (`ssr: false`) | Internal tool, no SEO, simpler deployment |

### 12. State Management

**Pinia** is the state management library for all Nuxt apps (per AGENTS.md).

```typescript
// app/composables/useAuthStore.ts (or stores/auth.ts)
import { defineStore } from 'pinia';

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null);
  const isAuthenticated = computed(() => user.value !== null);

  async function fetchUser() {
    const data = await $fetch('/api/v1/auth/me');
    user.value = data;
  }

  return { user, isAuthenticated, fetchUser };
});
```

**Rules:**
- Pinia stores hold shared state (auth, user, UI state).
- Component-local state uses Vue's `ref()`/`reactive()`.
- Do not duplicate server state in Pinia — use `useAsyncData` / `useFetch` for SSR-compatible data fetching.

### 13. Composables

Composables are the Nuxt equivalent of hooks — reusable logic functions used across components.

```
app/composables/
├── useApi.ts              # Typed API client wrapper
├── useAuth.ts             # Auth state + actions
└── useShareToken.ts       # Share token resolution logic
```

**Rules:**
- Composables are auto-imported by Nuxt — no manual import needed.
- Composables that access the API should use the shared `@chtohochu/api-client` package (when available) or a centralized `$fetch` wrapper.
- Composables must be framework-agnostic within Vue — no direct DOM manipulation.

### 14. Data Fetching

Nuxt provides built-in data fetching composables that integrate with SSR:

```typescript
// SSR-compatible data fetching (public-web)
const { data: wishlist, error } = await useFetch(
  `/api/v1/wishlists/${token}`,
  {
    baseURL: useRuntimeConfig().public.apiBase,
  }
);
```

**Rules:**
- Use `useFetch` for simple GET requests in pages/components.
- Use `useAsyncData` when you need custom logic or multiple data sources.
- For mutations (POST/PUT/DELETE), use `$fetch` directly (no SSR caching needed).
- Always pass `baseURL` from `useRuntimeConfig().public.apiBase` — never hardcode API URLs.

### 15. API Communication

All Nuxt apps communicate with the backend via HTTP:

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || 'http://localhost:8000/api',
    },
  },
});
```

**Auth patterns:**

| App | Auth mechanism |
|-----|---------------|
| `public-web` (cabinet) | Cookie-based (Sanctum web guard) via Inertia or `$fetch` with `credentials: 'include'` |
| `public-web` (landing) | No auth (public content) |
| `seller` | Token-based (Sanctum) via `Authorization: Bearer` header |
| `admin` | Token-based (Sanctum) + Spatie role check |

### 16. Inertia.js (public-web cabinet)

The personal cabinet at `lk.chtohochu.ru` uses **Inertia.js** for a hybrid SSR/SPA experience:

```
Browser → lk.chtohochu.ru → Laravel (web routes)
  │
  ├── Laravel renders Inertia page props (server-side)
  │     ↓
  ├── Nuxt/Vue renders the page (client-side hydration)
  │     ↓
  └── Subsequent navigations are SPA (no full page reload)
       ↓
       Inertia visits → Laravel returns JSON props → Vue updates
```

**Rules:**
- Inertia pages receive data as props from Laravel — no separate API call needed for initial render.
- Client-side navigation uses Inertia's `router.visit()` or `<Link>` component.
- Form submissions use Inertia's `useForm()` for automatic error handling and state management.

### 17. Component Conventions

```
app/components/
├── layout/               # Layout components (header, footer, nav)
├── ui/                   # Generic UI components (buttons, inputs, cards)
└── <feature>/            # Feature-specific components
```

**Rules:**
- Components are auto-imported by Nuxt based on directory structure.
- Generic UI components go in `components/ui/`.
- Feature-specific components go in `components/<feature>/`.
- Components must not contain business logic — they receive props and emit events.
- Use `defineProps` and `defineEmits` with TypeScript for type safety.

### 18. TypeScript

All Nuxt apps use TypeScript. The `tsconfig.json` extends Nuxt's generated config:

```json
{
  "extends": "./.nuxt/tsconfig.json"
}
```

**Rules:**
- All composables, components, and pages must be typed.
- API response types should come from `@chtohochu/api-types` (when available) or be defined locally in `types/`.
- Avoid `any` — use `unknown` and narrow with type guards when the shape is uncertain.
- Enable strict mode in development.

### 19. Realtime (Web)

The public-web cabinet may consume Reverb WebSocket events for live notifications:

```typescript
// app/composables/useRealtime.ts
import { ref, onUnmounted } from 'vue';

export function useRealtime() {
  const ws = ref<WebSocket | null>(null);

  function connect(channel: string) {
    const wsUrl = `wss://app.chtohochu.ru/app/${useRuntimeConfig().public.reverbKey}`;
    ws.value = new WebSocket(wsUrl);
    // ... subscribe to channel, handle events
  }

  onUnmounted(() => ws.value?.close());
  return { connect };
}
```

> **Note:** Collaborative editing (shared shopping lists) is a Flutter-only domain. Web consumes realtime for notifications, not for collaborative state management.
