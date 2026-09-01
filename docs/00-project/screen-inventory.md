# Flutter Screen Inventory (Prototype Reference)

> **Source:** Extracted from the prototype backup at `/home/nikolay/projects/old/chtohochu/flutter-frontend/`.
> This document records the UX/product knowledge embedded in the prototype screens.
> The screen implementations themselves are NOT authoritative.

## Route Constants

| Route | Path | Screen |
|-------|------|--------|
| splash | `/splash` | SplashPage |
| onboarding | `/onboarding` | OnboardingPage |
| postAuthOnboarding | `/post-auth-onboarding` | PostAuthOnboardingPage |
| signIn | `/auth/sign-in` | SignInPage |
| signUp | `/auth/sign-up` | SignUpPage |
| authVk | `/auth/vk` | OAuthPage (VK) |
| authYandex | `/auth/yandex` | OAuthPage (Yandex) |
| home | `/` | WishListPage |
| purchases | `/purchases` | PurchasesPage |
| friends | `/friends` | FriendsPage |
| profile | `/profile` | ProfilePage |
| wishlistDetail | `/wishlist` | WishlistDetailPage |
| wishDetail | `/wish` | WishDetailPage |
| editWishlist | `/wishlist/edit` | EditWishlistPage |
| editWish | `/wish/edit` | EditWishPage |
| inboxWishes | `/inbox` | InboxWishesPage |
| profileEdit | `/profile/edit` | ProfileEditPage |
| profileSettings | `/profile/settings` | ProfileSettingsPage |
| profileNotifications | `/profile/notifications` | ProfileNotificationsPage |
| aboutApp | `/about` | AboutAppPage |
| termsOfUse | `/terms` | TermsOfUsePage |
| privacyPolicy | `/privacy` | PrivacyPolicyPage |
| events | `/events` | EventsPage |
| addFriend | `/friends/add` | AddFriendPage |
| friendHub | `/friends/hub` | FriendHubPage |
| sharePreview | `/s` | SharePreviewPage |
| shoppingListDetail | `/shopping-list` | ShoppingListDetailPage |

## Auth Screens

### SignInPage
- **Purpose:** Email + password sign-in
- **Navigation:** signUp, VK OAuth, Yandex OAuth
- **States:** loading, error
- **UI:** Auth header, email/password fields with visibility toggle, OAuth buttons, primary CTA

### SignUpPage
- **Purpose:** New user registration
- **Navigation:** signIn
- **States:** loading, error
- **UI:** Username, email, password, confirm password fields, primary CTA

### OAuthPage
- **Purpose:** OAuth WebView login for VK/Yandex
- **Navigation:** home on success, pop on cancel
- **States:** WebView loading, OAuth error, authenticated
- **UI:** AppBar with close, WebViewWidget, loading indicator, error card with retry

## Onboarding

### OnboardingPage (pre-auth)
- **Purpose:** First-launch marketing onboarding
- **Navigation:** signIn on complete/skip
- **States:** currentPage, isLastPage
- **UI:** PageView with 3 slides, dot indicator, skip/next buttons

### PostAuthOnboardingPage (3-step wizard)
- **Purpose:** Post-registration guided setup
- **Navigation:** home on complete
- **Steps:**
  1. **Step 1 — First Wish:** Parse product URL or manual entry, image picker, price field
  2. **Step 2 — Find Friends:** Username search, contacts import, invite links
  3. **Step 3 — Birthday:** Day/month/year picker with privacy toggle

## Main Tabs

### WishListPage (Home)
- **Purpose:** Main home tab — wishlist browsing hub
- **Navigation:** wishlistDetail, wishDetail, profile, events, inboxWishes
- **States:** loading, success, refreshing, search, filters
- **UI:** Search header, filter chips, featured lists, wishlist list, inbox count badge, FAB with create sheets
- **Product behaviour:** Browse, filter, favorite, search, create wishlists and wishes

### PurchasesPage
- **Purpose:** Shopping lists hub
- **Navigation:** shoppingListDetail
- **States:** loading, failure, empty (my/shared), tabs
- **UI:** Header, SliverList of ShoppingListTile, FAB opens create bottom sheet

### FriendsPage
- **Purpose:** Friends list and request management
- **Navigation:** addFriend, friendWishlists, friend options menu
- **States:** loading, failure, empty friends, empty requests, search, tabs (friends/requests)
- **UI:** Search header, tabs, FriendCard/FriendRequestCard lists, AppEmptyState, AppActionSheet
- **Product behaviour:** Search, view, favorite, accept/decline/cancel requests, remove friends

### ProfilePage
- **Purpose:** Main profile/account hub
- **Navigation:** profileEdit, profileNotifications, profileSettings, aboutApp, share, logout
- **States:** authenticated, loading, WebSocket status
- **UI:** Profile avatar, name/username, action buttons, stats row (wishes total/fulfilled/friends), menu cards, logout button, version

## Wish Feature Screens

### WishlistDetailPage
- **Purpose:** Single wishlist with its wishes
- **Navigation:** editWishlist, wishlistParticipants, wishDetail, share sheet
- **States:** loading, deleted, left, error, empty wishes, role-based permissions
- **UI:** Top bar, header with participant avatars, visibility badge, SliverGrid of wish cards, menu/delete bottom sheets
- **Product behaviour:** View wishes, add new, edit list (owner), manage participants, leave, delete, favorite, share

### WishDetailPage
- **Purpose:** Full wish details and social actions
- **Navigation:** editWish, external link, share
- **States:** loading, not found, processing, deleted, claimed, error, isLiked, likesCount, comments
- **UI:** Header with back/share/menu, content (image, name, price, link, like, claim, fulfill, comments)
- **Product behaviour:** View, like, comment, claim, mark fulfilled, edit/delete (owner), share, open product link

### EditWishlistPage
- **Purpose:** Create or edit a wishlist
- **States:** loading, loaded, saved, failure, saving
- **UI:** Emoji grid, name/description fields, visibility radio (personal/link/public)

### EditWishPage
- **Purpose:** Create or edit a wish
- **States:** loading, loaded, saved, failure, saving
- **UI:** Collapsible sections (Main, Photo, Details, Notes), necessity chips, image picker, price field

### InboxWishesPage
- **Purpose:** Quick-capture inbox of unassigned wishes
- **Navigation:** wishDetail, move bottom sheet
- **States:** loading, empty, moved, failure
- **UI:** Header with count, wish cards, move button, bottom sheet to choose wishlist

### WishlistParticipantsPage
- **Purpose:** Manage wishlist participants
- **States:** loading, removed, failure, empty
- **UI:** Participant list with avatars/roles, owner-only remove button, confirm sheet

## Shopping List Screens

### ShoppingListDetailPage
- **Purpose:** Items inside one shopping list
- **Navigation:** shoppingListParticipants
- **States:** loading, empty, add-item input, completed/uncompleted sections
- **UI:** Header with back/participants/menu, progress bar, checklist ListView, add-item field, action sheets
- **Product behaviour:** Add, toggle, delete items; mark all purchased; delete list; manage participants

### ShoppingListParticipantsPage
- **Purpose:** Manage shopping-list participants
- **States:** loading, empty, isOwner
- **UI:** Participant ListTiles with avatars/role, remove confirm sheet

## Events

### EventsPage
- **Purpose:** In-app notification/activity feed
- **Navigation:** wishlistDetail (for invite/new wish events), friends (for friend events)
- **States:** loading, error, loaded (empty/read/unread), deleteAll sheet
- **UI:** Header with mark-all-read and delete-all, notification list with type icons, unread badges

## Share

### SharePreviewPage
- **Purpose:** Deep-link entry point — resolve share token
- **Navigation:** wishlistDetail, shoppingListDetail, wishDetail, or home
- **States:** loading, error, joining, canJoin, isMember
- **UI:** Owner avatar, entity-type chip, title/description, preview image, join/open CTA

## Profile Sub-screens

### ProfileEditPage
- **Purpose:** Edit user profile
- **States:** saving, checkingUsername, usernameError
- **UI:** Avatar section (camera/gallery/delete), username with async validation, email (disabled), name, bio, birthday picker

### ProfileSettingsPage
- **Purpose:** App-level settings
- **States:** themeMode, autoSync, cacheImages
- **UI:** Theme menu, auto-sync and image-cache switches, clear-cache action

### ProfileNotificationsPage
- **Purpose:** Push notification preferences
- **UI:** Master push switch, 11 category toggles (lists, wishes, shopping, social, reminders, system)

### AboutAppPage
- **Purpose:** About/version/legal hub
- **Navigation:** termsOfUse, privacyPolicy, mailto support
- **UI:** App icon, name, version, carded menu, footer

### TermsOfUsePage / PrivacyPolicyPage
- **Purpose:** Static legal content
- **UI:** AppBar, scrollable text with sections

## Key UX Patterns to Preserve

1. **SharePreviewPage** — unified deep-link/invite resolution for wishlists, shopping lists, and wishes
2. **Role-based permission gating** — `canManageList`, `canAddWishes`, `canManageParticipants` pattern
3. **AppActionSheet** — consistent bottom-sheet menus across all screens
4. **Loading/empty/error/refresh states** — every list screen supports all four
5. **Unread badges** — notification counts on events and inbox
6. **Post-auth onboarding** — 3-step wizard (first wish → friends → birthday)
7. **Avatar upload flow** — AppActionSheet + camera/gallery/delete pattern
