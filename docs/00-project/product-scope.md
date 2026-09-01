# Product Scope — ЧтоХочу

This document defines what is in scope and out of scope for the initial release of ЧтоХочу. It is the authoritative reference for feature prioritization, sprint planning, and architectural provisioning. Anything not listed here as in-scope requires an explicit product decision before implementation.

---

## 1. In Scope — Core Domains

These domains are the focus of the initial release. Each must be fully functional, tested, and shipped.

### 1.1 Users & Profiles

| Capability | Description |
|-----------|-------------|
| Registration | Email/password registration with username, email, password. |
| OAuth login | VK and Yandex OAuth via WebView. |
| Username validation | Real-time username uniqueness check with reserved-word filtering. |
| Profile editing | Avatar (camera/gallery/delete), username (async validation), display name, bio, birthday with privacy toggle. |
| Profile viewing | Authenticated users can view other users' profiles. |
| Post-auth onboarding | 3-step wizard: first wish → find friends → birthday. |
| Session management | Login, logout, logout-all-devices via Sanctum token revocation. |

### 1.2 Wishes

| Capability | Description |
|-----------|-------------|
| Create wish | Manual entry or URL paste. Fields: title, product URL, image, price, necessity level, notes. |
| Edit wish | Owner (or participant with permission) can edit all fields. |
| Delete wish | Owner (or participant with permission) can delete. |
| View wish | Full detail page with image, price, link, social actions. |
| Like wish | Any user with visibility can like/unlike a wish. |
| Comment on wish | Any user with visibility can comment. |
| Claim wish | A non-owner viewer can claim a wish (intent to gift). Claimer identity hidden from owner. |
| Fulfill wish | A claimed wish can be marked as fulfilled. |
| Inbox | Wishes can be created without a target wishlist and live in the Inbox for later assignment. |
| Move wish | A wish can be moved from the Inbox to a specific wishlist. |
| Offline support | Wishes are offline-capable — create, edit, delete work without connectivity and sync on reconnect. |

### 1.3 Wishlists

| Capability | Description |
|-----------|-------------|
| Create wishlist | Title, description, emoji icon, visibility tier (personal/link/public). |
| Edit wishlist | Owner can edit title, description, emoji, visibility. |
| Delete wishlist | Owner can delete. |
| View wishlist | Grid of wish cards with header, participant avatars, visibility badge. |
| Favorite wishlist | Users can favorite wishlists for quick access. |
| Participant management | Owner can invite participants, set permissions, remove participants. |
| Leave wishlist | Non-owner participants can leave a shared wishlist. |
| Share wishlist | Generate a share token / deep link. |
| Offline support | Wishlists are offline-capable — create, edit, delete work offline and sync on reconnect. |

### 1.4 Friends

| Capability | Description |
|-----------|-------------|
| Send friend request | By username search, contacts import, or invite link. |
| Accept / decline request | Recipient can accept or decline. |
| Cancel request | Sender can cancel a pending request. |
| Remove friend | Either party can unfriend. |
| Friend list | Paginated list with search, tabs (friends / requests). |
| Favorite friends | Mark friends as favorites for quick access. |
| View friend's wishlists | See a friend's public and shared wishlists. |
| Offline support | Friends list is cached locally; friend operations are syncable. |

### 1.5 Shopping Lists

| Capability | Description |
|-----------|-------------|
| Create shopping list | Named list with optional description. |
| Add item | Inline text entry; item appears immediately for all participants. |
| Edit item | Rename an existing item. |
| Check / uncheck item | Toggle purchased state. Tracks who checked it. |
| Delete item | Remove an item from the list. |
| Mark all purchased | Bulk-check all uncompleted items. |
| Delete list | Owner can delete the entire list. |
| Participant management | Owner can invite and remove participants. |
| Progress bar | Visual completion indicator (X of Y items purchased). |
| Offline support | Shopping lists are the reference offline-first domain — all operations work offline with sync and conflict resolution on reconnect. |
| Realtime collaboration | Multiple participants see each other's changes live via WebSocket. |

### 1.6 Sharing

| Capability | Description |
|-----------|-------------|
| Share token generation | Owner generates an opaque token for a wishlist, shopping list, or wish. |
| Deep link resolution | `chtohochu.ru/s/{token}` resolves to a preview page (web) or SharePreviewPage (app). |
| Preview page | Shows owner avatar, entity type, title, description, preview image. |
| Join flow | Eligible users can join as participants from the preview page. |
| Token revocation | Owner can revoke a share token, invalidating the link. |
| Smart link routing | Link detects platform: opens app on mobile (if installed), opens web preview otherwise. Routes to app store / play store if app not installed. |

### 1.7 Notifications & Events

| Capability | Description |
|-----------|-------------|
| In-app events feed | Paginated list of social events (friend requests, invites, new wishes, claims). |
| Read / unread state | Events have read/unread status with mark-all-read and delete-all. |
| Realtime delivery | Active clients receive notifications via WebSocket. |
| Push notifications | FCM push for friend requests, invitations, and social events. |
| Notification preferences | 11 category toggles (lists, wishes, shopping, social, reminders, system). |
| Deep linking from push | Tapping a notification navigates to the relevant screen. |
| Non-authoritative | Push is a transport, not a sync mechanism. Lost pushes must not cause data inconsistency. |

### 1.8 Web Personal Cabinet

| Capability | Description |
|-----------|-------------|
| Landing page | Public marketing site at `chtohochu.ru`. |
| Auth flows | Email/password and OAuth login via web at `lk.chtohochu.ru`. |
| Wishlist viewing | Authenticated web users can view and interact with wishlists. |
| Share preview | Web-based share token resolution for non-app users. |
| Profile cabinet | Basic profile viewing and editing via web. |

---

## 2. Future Domains — Architecturally Provisioned, Not Shipped

These domains are explicitly out of scope for the initial release but are accounted for in the architecture. The system must not block them, but must not build them prematurely.

### 2.1 Seller & Catalog

| Future Capability | Notes |
|-------------------|-------|
| Seller registration & authentication | Separate from user auth; seller cabinet at dedicated subdomain. |
| Product catalog management | CRUD for products with images, categories, pricing. |
| Product search & browse | Full-text search, category filtering, pagination. |
| Product-linked wishes | A wish can reference a catalog Product instead of a freeform URL. |

**Architectural implication:** The `Product` and `Catalog` models, seller auth flow, and seller Nuxt app (`apps/seller`) are provisioned in the monorepo but will not have functional implementations in the initial release.

### 2.2 Offers & Price Tracking

| Future Capability | Notes |
|-------------------|-------|
| Seller-published offers | Time-bound promotions tied to Products. |
| Price tracking | Monitor price changes for wish-linked products. |
| Sale notifications | Notify users when a wished item drops in price. |
| Offer matching | Match offers against wishes to surface relevant deals. |

**Architectural implication:** The `Offer` model is referenced in terminology but has no schema, API, or UI in the initial release.

### 2.3 Recommendations

| Future Capability | Notes |
|-------------------|-------|
| Wishlist-based recommendations | Suggest products based on wish history. |
| Friend-based recommendations | Surface wishlists from friends with similar tastes. |
| Trending / popular | Surface popular public wishlists. |

**Architectural implication:** No recommendation engine, ML pipeline, or analytics warehouse in the initial release. The public wishlist visibility tier is the only prerequisite.

### 2.4 Payments

| Future Capability | Notes |
|-------------------|-------|
| In-app purchase of wishes | Buy a wished item directly through the platform. |
| Group gifting | Multiple users contribute to a single gift. |
| Seller payouts | Settlement for catalog purchases. |

**Architectural implication:** No payment provider integration, no transactional financial models, no PCI-scoped infrastructure. The Claim/Fulfill model is purely social, not financial.

---

## 3. Explicit Non-Goals

These are things the product will **not** do, either in the initial release or as currently envisioned. They are listed to prevent scope creep and misaligned architectural decisions.

### 3.1 Product non-goals

| Non-goal | Rationale |
|----------|-----------|
| **Task management / to-do lists** | ЧтоХочу is about wanting and buying things, not general productivity. |
| **Calendar / scheduling** | No event scheduling, reminders by date, or calendar integration in the initial release. |
| **Messaging / chat** | No in-app 1:1 or group messaging. Social interaction happens via wishes, claims, likes, comments, and the events feed. |
| **Marketplace checkout** | The platform does not process purchases. It links to external stores. Payments are a future domain, not an initial feature. |
| **Public social feed** | No TikTok-style discovery feed. Public wishlists are discoverable, but there is no algorithmic feed. |
| **Multi-language (non-Russian)** | The initial release targets Russian-speaking users. Localization infrastructure exists, but only `ru` is supported. |
| **Desktop client** | No native desktop app. Web cabinet serves desktop users. |
| **Apple Watch / Wear OS** | No wearable companion app. |
| **Tablet-optimized layout** | The Flutter app runs on tablets but is not separately optimized for tablet form factors in the initial release. |

### 3.2 Technical non-goals

| Non-goal | Rationale |
|----------|-----------|
| **Microservices** | The backend is a modular monolith. Splitting services requires an approved ADR. |
| **GraphQL** | REST API only. GraphQL requires an approved ADR. |
| **Firebase/Firestore as primary DB** | PostgreSQL is the source of truth. Firebase is push transport only. |
| **Second backend runtime** | Laravel/PHP only. No Node.js, Go, or Python services. |
| **Elasticsearch / Kafka / Kubernetes** | Not introduced without a concrete, evidence-based requirement. |
| **Client-side business rules** | The backend is the final authority for all authorization, validation, and business logic. |
| **Realtime as source of truth** | WebSocket events are a delivery mechanism. PostgreSQL is the source of truth. |

---

## 4. Scope Summary Matrix

| Domain | Initial Release | Future | Non-goal |
|--------|:-:|:-:|:-:|
| Users & Profiles | ✅ | | |
| Wishes | ✅ | | |
| Wishlists | ✅ | | |
| Friends | ✅ | | |
| Shopping Lists | ✅ | | |
| Sharing (tokens, deep links) | ✅ | | |
| Notifications & Events | ✅ | | |
| Web Personal Cabinet | ✅ | | |
| Sellers & Catalog | | ✅ | |
| Offers & Price Tracking | | ✅ | |
| Recommendations | | ✅ | |
| Payments | | ✅ | |
| Task management | | | ✅ |
| Messaging / chat | | | ✅ |
| Calendar / scheduling | | | ✅ |
| Marketplace checkout | | | ✅ |
| Public social feed | | | ✅ |
| Multi-language (non-ru) | | | ✅ |
| Desktop native client | | | ✅ |
| Microservices | | | ✅ |
| GraphQL | | | ✅ |
