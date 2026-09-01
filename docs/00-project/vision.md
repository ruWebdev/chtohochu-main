# Product Vision — ЧтоХочу

## 1. What Is ЧтоХочу

**ЧтоХочу** (Russian: "What I Want") is a social wishlist and collaborative shopping-list application. It lets people record things they want — a new phone, a book, a pair of shoes — organize those things into named wishlists, share those wishlists with friends and family, and collaborate on shared shopping lists in real time.

The product spans three surfaces:

1. **Mobile app** (Flutter) — the primary client for end users. Offline-capable, realtime-synced, push-notified.
2. **Public web** (Nuxt) — landing page, public wishlist previews, deep-link resolution, and a personal web cabinet at `lk.chtohochu.ru`.
3. **Seller cabinet** (Nuxt) — a future-facing surface where merchants manage product catalogs and offers (out of scope for the initial release, but architecturally provisioned).

The backend is a Laravel modular monolith. It is the single source of truth for all shared business state.

## 2. Core Value Proposition

> **I can tell the people who care about me what I actually want — and we can shop together without the chaos of group chats, scattered notes, and duplicated gifts.**

The three pillars:

### 2.1 Express intent

A user captures a wish in seconds — paste a product URL, snap a photo, or type a name. The wish lives in a named wishlist ("Birthday 2026", "Kitchen renovation", "Dream setup"). Wishes carry metadata: price, link, image, necessity level, notes.

### 2.2 Share with the right people

Wishlists have three visibility tiers:

| Tier | Meaning |
|------|---------|
| **Personal** | Only the owner can see it. |
| **Link** | Anyone with the share token can view. |
| **Public** | Discoverable by other users on the platform. |

Friends can be invited as **participants** on a wishlist, giving them permission to add or manage wishes alongside the owner.

### 2.3 Collaborate in real time

Shared **shopping lists** are the reference collaborative domain. Two or more people see the same list, add items, check them off, and delete them — changes propagate live via WebSocket. The system remains correct when users are offline, when events are lost or duplicated, and when clients reconnect after hours.

## 3. Target Audience

### Primary

**Russian-speaking consumers, age 16–45**, who:

- celebrate birthdays, holidays, and life events where gifts are expected;
- shop in households where multiple people contribute to a single grocery or purchase run;
- already use group chats (Telegram, WhatsApp) to coordinate gifts and shopping, and find it messy;
- want to avoid the awkwardness of being asked "what do you want?" and answering verbally.

### Secondary

- **Families** coordinating household purchases.
- **Friend groups** organizing group gifts or trip packing lists.
- **Couples** building shared wishlists for weddings, anniversaries, moving.

### Tertiary (future)

- **Sellers / merchants** who want to publish product catalogs and offers to a wishlist-native audience.

## 4. Primary Use Cases

### UC-1: Birthday wishlist

Anna creates a wishlist called "Birthday 2026". She adds 12 wishes from different online stores — a kettle, a book, a board game. She sets the wishlist to **link** visibility and sends the share link to her family group chat. Her brother opens the link, sees the wishlist, and **claims** the kettle (indicating he'll buy it). The claim is visible to other viewers so nobody else duplicates the gift. Anna sees that the kettle was claimed but not by whom — the claimer's identity is hidden from the wishlist owner.

### UC-2: Shared grocery list

Maria and her partner Alex share an apartment. Maria creates a shopping list called "Saturday groceries" and invites Alex as a participant. On Saturday morning, both are at different stores. Maria adds "milk" — it appears instantly on Alex's screen. Alex checks off "bread" that Maria added earlier — Maria sees it crossed out. They never call each other to ask "did you already get the eggs?" The list is the single source of truth.

### UC-3: Inbox capture

Dmitry sees a pair of sneakers on a website. He doesn't know which wishlist to put them in yet. He adds the wish to his **inbox** — a default unassigned bucket. Later, when he has time, he opens the inbox and moves the wish into the appropriate wishlist.

### UC-4: Friend discovery

Lena signs up. The app suggests she find friends by username search, contacts import, or by sharing her invite link. She sends a friend request to her friend Misha. Misha accepts. Now Lena can see Misha's public wishlists and Misha can see hers.

### UC-5: Event feed

Igor opens the app and sees an unread badge on the Events tab. He opens it and sees: "Misha added a new wish to 'Birthday 2026'", "Lena accepted your friend request", "You were invited to 'Trip packing list'". He taps the invite and lands on the wishlist preview page where he can join.

## 5. How ЧтоХочу Differs From Simple List Apps

Simple list apps (Apple Reminders, Google Keep, Todoist, AnyList) are excellent at personal productivity. ЧтоХочу is built for a different problem: **social coordination around wanting and buying things together**.

| Dimension | Simple list app | ЧтоХочу |
|-----------|----------------|---------|
| **Primary unit** | A task or reminder | A **wish** — a thing you want, with price, link, image, and social metadata |
| **Social model** | Maybe shared lists | First-class **friends**, **wishlists with participants**, **claims**, **likes**, **comments** |
| **Visibility** | Private or shared link | Three-tier: personal, link, public — with per-wishlist participant permissions |
| **Gift coordination** | None | **Claims** with hidden claimer identity — solves the "don't duplicate the gift" problem |
| **Realtime collaboration** | Rare, often unreliable | First-class — shared shopping lists are the reference domain, designed for offline + concurrent edits |
| **Offline** | Varies | Offline-first for wishlists, wishes, and shopping lists — mutations survive app restart and retry |
| **Deep linking** | Minimal | Unified share-token resolution — one link works for wishlists, shopping lists, and individual wishes |
| **Product metadata** | Plain text items | URL parsing, image extraction, price, necessity levels, external product links |
| **Discovery** | None | Public wishlists, friend activity feed, event notifications |

### The key insight

A simple list app asks: *"What do I need to do?"*

ЧтоХочу asks: *"What do I want, who should know, and how do we get it together?"*

That difference drives every architectural decision: the social graph, the permission model, the realtime transport, the offline sync protocol, and the share-token system all exist because the product is fundamentally **social**, not personal.

## 6. Success Criteria

The initial release succeeds when:

1. A user can create a wishlist, add wishes, and share it via link — end to end — in under 90 seconds from first launch.
2. Two users on the same shopping list can simultaneously add, edit, check, and delete items without data loss, even with intermittent connectivity.
3. A user can open a share link on the web, preview the wishlist, and (if permitted) join — without installing the app.
4. A user can work fully offline on their wishlists and shopping lists, and all mutations sync correctly when connectivity returns.
5. A user receives push notifications for friend requests, invitations, and social events, and tapping a notification deep-links into the relevant screen.
