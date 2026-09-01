# ADR-003: Flutter as client

## Status

Accepted

## Context

ЧтоХочу needs a client that covers:

- **iOS** — first-class native-feeling mobile experience;
- **Android** — first-class native-feeling mobile experience;
- **Authenticated web** — an authenticated web client for users who are not on
  the seller or admin cabinets (e.g. viewing/editing their own wishlists and
  shared shopping lists from a browser).

The client is not a thin view layer. It is **offline-first** for several domains
(wishlists, wishes, shared shopping lists, shopping items, friends — AGENTS.md
§24), which means it must host a local relational database (Drift), a
synchronization protocol with stable `operation_id`s, retry-safe mutations,
conflict reconciliation and optimistic updates that are locally persisted
(§27–§31). It must also consume a realtime WebSocket channel and survive lost,
duplicate, delayed and out-of-order events (§21, §23).

The product is social and collaborative: shared shopping lists where two users
edit the same list simultaneously are the reference domain (§32). The UI must
remain responsive and correct during offline mode, simultaneous changes,
retries, reconnect and app restart.

The team is small and cannot afford to maintain three separate codebases (iOS,
Android, web) with three separate implementations of the sync engine, the
realtime handler, the local database and the repository layer. The offline-first
and realtime logic is the hard part; duplicating it across platforms would
double the bug surface and halve the velocity.

## Decision

Use **Flutter** (Dart) as the single client framework for iOS, Android and the
authenticated web, with the following stack as prescribed in AGENTS.md §3 and
§7–§11:

- **Riverpod** (`flutter_riverpod` 3.0) as the state-management and
  dependency-injection system (§8). `Notifier` / `AsyncNotifier` /
  `StreamNotifier` for state; `riverpod_generator` for generated providers.
  Riverpod is the only DI mechanism — no global service locator.
- **Drift** as the local relational persistence layer for offline-capable data
  (§25, §26). UI observes Drift through repositories; the network synchronizes
  that state.
- **GoRouter** for declarative routing.
- **Dio + Retrofit** as the HTTP client stack, centralized so feature code
  never instantiates Dio directly (§11). Raw Dio exceptions must never reach
  presentation. Retrofit generates type-safe API clients from annotations.
- **Freezed** + **json_serializable** for immutable models and DTOs with
  generated equality, copy-with and JSON serialization.
- **Firebase Cloud Messaging** for push (transport only, not synchronization —
  §33).
- **flutter_secure_storage** for credentials (§13).
- **Material 3** with a centralized theme (§36).

Architecture is **feature-first** with `data` / `domain` (optional) /
`presentation` layers inside each feature (§7, §8). The domain layer is
conditional, not mandatory.

## Consequences

**Positive**

- **One implementation of the hard parts.** The offline sync engine, the Drift
  schema, the realtime reconciliation logic and the repository layer are written
  once and shared across iOS, Android and web. This is the decisive benefit:
  the collaborative shopping list correctness requirements (§32) are hard
  enough to implement once; implementing them three times is infeasible for a
  small team.
- **Single language and single toolchain.** Dart across all platforms means one
  set of testing tools, one analyzer/lint config, one CI job for client tests.
- **Strong UI consistency.** Flutter's widget tree and Material 3 give a
  consistent look and feel across iOS and Android, and a usable authenticated
  web experience, from one codebase.
- **Riverpod fits the architecture.** Riverpod provides explicit, testable
  state transitions via `Notifier` / `AsyncNotifier`. Riverpod providers also
  handle dependency injection without a separate service locator. This aligns
  with the "explicit behavior over magic" principle (§5).
- **Drift gives a real local database.** Offline-first requires a relational
  local store with transactions, migrations and queries — not just a key-value
  cache. Drift provides this with generated type-safe code.
- **Freezed + json_serializable** make immutable models and DTOs ergonomic and
  correct, supporting the "persistent state is immutable from the UI's point of
  view" principle (§5).

**Negative**

- **Web is not native DOM.** Flutter web renders to a canvas; it is heavier and
  less SEO-friendly than a real HTML framework. This is acceptable because the
  authenticated web client is an app, not a marketing surface — SEO-critical
  public pages are handled by the Nuxt public site (ADR-004). The Flutter web
  client is for logged-in users interacting with their data.
- **App size on mobile.** Flutter carries its own rendering engine, so the
  binary is larger than a pure native app. This is a known, acceptable
  trade-off.
- **Dart is not JS/TS.** Sharing types with the web apps requires code
  generation from OpenAPI rather than sharing a TS package directly. This is
  already the plan: `packages/api-types` serves the TS web apps, and the Flutter
  client generates Dart models from the same OpenAPI spec.
- **Plugin/platform-channel risk.** Some platform-specific features require
  plugins or platform channels. For this product's domain (lists, items,
  realtime, push, secure storage, local DB) the standard plugins cover the
  needs.

## Alternatives considered

### React Native

Cross-platform iOS/Android (and via web targets) using JS/TS, sharing a
language with the web apps.

- **Strengths:** shares JS/TS with Nuxt web apps; large ecosystem; can share
  some types and logic with web.
- **Rejected because** the offline-first story is weaker. React Native's local
  persistence options (WatermelonDB, MMKV, SQLite via op-sqlite) are capable
  but less integrated and less ergonomic than Drift's type-safe generated
  relational layer. The realtime + sync + conflict reconciliation logic would
  be implemented in JS, which is fine, but the overall offline-first
  developer experience and type safety of the Drift + Riverpod + Freezed
  combination is stronger and more cohesive for this product's hard
  requirements. React Native also does not provide a first-class web target
  comparable to Flutter web for an authenticated app; the web story is
  fragmented (react-native-web, Expo web).

### Native iOS (Swift) + native Android (Kotlin)

Two separate native codebases, plus a separate web client.

- **Strengths:** best possible native UX and platform integration; smallest
  binaries; direct access to all platform APIs.
- **Rejected because** it requires implementing the offline sync engine, Drift
  equivalent, realtime handler and repository layer twice (Swift + Kotlin), plus
  a third time for web. For a small team building a collaborative offline-first
  app, this triples the hard-logic implementation and the bug surface. The
  marginal UX benefit of fully native UI does not justify the cost for a
  wishlist/shopping-list product whose UI is standard list/form UI, not a
  high-performance game or media app.

### Kotlin Multiplatform (KMP)

Share business logic (sync, repositories, networking) between iOS and Android
via Kotlin, with native UI per platform (Compose on Android, SwiftUI on iOS).

- **Strengths:** shares the hard logic across mobile platforms while keeping
  native UI; strong typing; modern.
- **Rejected because** it does not cover the authenticated web client — a
  separate web implementation would still be needed, duplicating the sync
  engine a third time (or via Kotlin/Wasm, which is still immature for this
  use case). The KMP + Compose Multiplatform story for web is not mature
  enough to rely on. Additionally, the team would maintain two UI codebases
  (Compose + SwiftUI) for mobile, which is more than Flutter's one. KMP is an
  excellent choice when native UI parity is the top priority and web is out of
  scope; here web-in-scope and one-implementation-of-the-hard-parts are the
  priorities, which favors Flutter.
