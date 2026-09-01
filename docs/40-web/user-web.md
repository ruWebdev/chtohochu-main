# User Web (Flutter Web)

> **Status:** Authoritative architecture document for the authenticated user web application.
> Conflicts with `AGENTS.md` must be resolved via an ADR in `docs/decisions/`.

## 1. Purpose

The user web application is the **authenticated** web experience for end users of ЧтоХочу.

It provides:

* the personal wishlist cabinet;
* wish management;
* friends and social features;
* shared shopping lists;
* notifications and events feed;
* profile and settings management;
* share-token join/claim flows that require authentication.

It is the web equivalent of the Flutter mobile app's authenticated experience.

## 2. Technology Stack

The user web is built with **Flutter Web**, sharing the same codebase as the mobile app.

| Concern | Choice |
|---------|--------|
| Framework | Flutter (web target) |
| Language | Dart |
| State management | Riverpod 3 (same as mobile) |
| Routing | GoRouter (same as mobile) |
| HTTP | Dio (same as mobile) |
| Serialization | Freezed, json_serializable (same as mobile) |
| Local persistence | Drift (web backend: `sqflite_common_ffi_web` or Wasm) — see notes below |
| Auth token storage | `flutter_secure_storage` (web implementation) |
| Rendering | HTML or CanvasKit renderer (project decision, see below) |

## 3. Shared Codebase with Mobile

The user web is **not a separate codebase**. It is the Flutter mobile project compiled for the web target.

### What is shared

* `lib/app/` — router, theme, app entry
* `lib/core/` — network, database, realtime, sync, notifications, storage, errors, logging
* `lib/features/` — all feature modules (wishes, wishlists, friends, shopping lists, etc.)
* `lib/shared/` — shared UI components

### What is web-specific

* `lib/main_web.dart` — web entry point (conditional import for web-only bootstrap)
* `lib/core/config/web_config.dart` — web-specific configuration
* Conditional imports for platform-specific implementations (secure storage, local DB backend)

### Conditional import pattern

```dart
// lib/core/storage/secure_storage.dart
import 'secure_storage_stub.dart'
    if (dart.library.html) 'secure_storage_web.dart'
    if (dart.library.io) 'secure_storage_io.dart';

abstract class SecureStorage {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
}
```

## 4. Rendering Mode

Flutter web supports two renderers:

| Renderer | When to use |
|----------|-------------|
| **CanvasKit (Skia)** | Default for production. Pixel-perfect, consistent with mobile, larger initial download (~2MB Wasm). |
| **HTML** | Smaller download, uses DOM elements, less consistent rendering. Use only if initial load size is critical. |

**Recommended:** CanvasKit for production. The initial download is larger but rendering consistency with mobile is worth the tradeoff for an authenticated app where users stay longer.

```dart
// web/index.html or via FlutterRenderer API
// Configure renderer in Flutter initialization
```

## 5. Responsive Layout

The user web must adapt to desktop and tablet viewports while remaining usable on mobile-width browser windows.

### Breakpoints

| Breakpoint | Min width | Layout strategy |
|------------|-----------|-----------------|
| compact | < 600px | Single column, bottom navigation (mobile-like) |
| medium | 600–1024px | Single column with wider content, optional rail |
| expanded | ≥ 1024px | Multi-pane: navigation rail + content, master-detail for lists |

### Implementation

* Use `LayoutBuilder` and `MediaQuery` to switch between layouts.
* Prefer `NavigationRail` on expanded layouts, `NavigationBar` (bottom) on compact.
* Master-detail pattern for wishlist → wish detail on expanded layouts.
* Do not create separate widget trees for web — use responsive adaptations within shared widgets.

```dart
class AdaptiveScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return _ExpandedLayout(/* ... */);
        }
        return _CompactLayout(/* ... */);
      },
    );
  }
}
```

### Mouse and keyboard

* Add hover states for interactive elements on web.
* Support keyboard navigation (tab focus, enter to activate).
* Use `MouseRegion` and `FocusNode` for desktop-appropriate interactions.
* Add scroll-wheel support where custom scrolling is implemented.

## 6. Web-Specific Configuration

### API base URL

The web build must use a configurable API base URL. Unlike mobile (where it may be compiled in), web builds should read from a runtime-injected configuration to avoid rebuilding for each environment.

```dart
// lib/core/config/web_config.dart
class WebConfig {
  static String get apiBaseUrl =>
      _readFromWindow('API_BASE_URL') ?? 'https://api.chtohochu.ru';

  static String? _readFromWindow(String key) {
    // Read from window.__CONFIG__ injected by index.html
    // This allows deploying the same build to multiple environments
  }
}
```

### CORS

The backend API must have CORS configured to allow the user web origin. Sanctum token-based auth (bearer tokens) avoids cookie-based CSRF concerns.

| Setting | Value |
|---------|-------|
| Allowed origins | `https://app.chtohochu.ru` (per environment) |
| Credentials | Not required for bearer token auth |
| Methods | GET, POST, PUT, PATCH, DELETE |
| Headers | Authorization, Content-Type, X-Requested-With |

### WebSocket (Reverb)

* Flutter web connects to Reverb via the browser's WebSocket API.
* The Reverb URL must be configurable per environment.
* Same reconnection/reconciliation logic as mobile applies.

### Local persistence (Drift)

Drift on web requires a web-compatible database backend:

| Option | Notes |
|--------|-------|
| Wasm SQLite (`sqlite3.wasm`) | Recommended. Persistent via OPFS or IndexedDB. Full SQLite features. |
| `sqflite_common_ffi_web` | Legacy option. Uses IndexedDB-backed SQL. |

Offline-first behavior on web is **optional**. Browser persistence is less reliable than mobile. The web app may operate in a primarily online mode with Drift as a cache rather than a full offline source of truth. This decision must be documented per feature.

## 7. Authentication on Web

* Uses Laravel Sanctum bearer tokens (same as mobile).
* Token stored in `flutter_secure_storage` (web implementation uses encrypted storage backed by browser APIs).
* Login flow: email/password or OAuth (VK, Yandex) via redirect-based flow appropriate for web.
* On logout, the token is cleared from secure storage and the API token is revoked.
* The web app does not use cookie-based Sanctum sessions (avoids CSRF complexity on cross-origin web).

### OAuth on web

OAuth on web uses redirect-based flows rather than in-app WebViews:

1. User clicks "Login with VK/Yandex".
2. App redirects browser to OAuth provider authorization URL.
3. Provider redirects back to a configured callback URL (`/auth/callback`).
4. App exchanges the authorization code for a Sanctum token via the backend.

## 8. Routing on Web

GoRouter must be configured for web:

* URL-based deep linking (`/wishlists/{id}`, `/wishes/{id}`).
* Browser back/forward button support.
* URL updates on navigation (no hash routing — use path-based URLs).
* Redirect unauthenticated users to the login page with return URL.

```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/auth/sign-in', builder: (_, __) => SignInPage()),
    GoRoute(path: '/wishlists/:id', builder: (_, state) =>
      WishlistDetailPage(id: state.pathParameters['id']!)),
    // ...
  ],
  redirect: (context, state) {
    final isAuthenticated = /* read from auth provider */;
    if (!isAuthenticated && !state.matchedLocation.startsWith('/auth')) {
      return '/auth/sign-in?redirect=${state.matchedLocation}';
    }
    return null;
  },
);
```

## 9. Boundary Rules

### MUST NOT

* Import from `public-web/`, `seller/`, or `admin/` codebases (they are separate Nuxt apps).
* Contain seller dashboard or admin backoffice functionality.
* Bypass the repository layer or instantiate Dio directly in presentation.

### MUST

* Share the mobile codebase (`mobile/lib/`).
* Use the same API contract (`/api/v1/`) as mobile.
* Use the same realtime (Reverb) contract as mobile.
* Maintain the same offline/sync architecture where applicable.
* Enforce no business logic in the UI — all rules are backend-enforced.

## 10. Performance Considerations

| Concern | Mitigation |
|---------|------------|
| Initial load size | Use deferred imports for feature modules; tree-shake unused code |
| CanvasKit download | Serve Wasm with `Cross-Origin-Embedder-Policy` and `Cross-Origin-Opener-Policy` headers for SharedArrayBuffer support |
| Image loading | Use `cached_network_image` with web-compatible cache |
| Route-based code splitting | Use deferred imports per feature where feasible |
| Avoid jank | Profile with Flutter DevTools web performance view |

## 11. Deployment

* Built with `flutter build web --release`.
* Output (`build/web/`) served as static files by Nginx/Traefik.
* `index.html` must inject runtime configuration (API base URL, Reverb URL) via a `window.__CONFIG__` object or a fetched `config.json`.
* SPA fallback: all unknown routes serve `index.html` (GoRouter handles client-side routing).
* Health check: serve a static `/health` file or use the Nginx-level health check.
