# ADR-014: Local storage model for wish images

## Status

Accepted

## Context

Quick-capture (`AddWishSheet`) allows attaching multiple photos to a wish
(camera + gallery). The `wishes.image_url` column holds a single reference:
either a remote `http(s)` URL or a local file path under
`Documents/wish_photos/`.

Requirements for the local model:

- one **primary** image + N **additional** images per wish;
- deterministic ordering;
- atomic creation with the wish;
- cascading cleanup when the wish is deleted;
- survival across sheet close, navigation, app restarts, and sync;
- local paths must never be sent to the API as `image_url`
  (backend validation expects a URL);
- the model must be ready for a future image-upload stage (S3/CDN) without
  restructuring — no JSON arrays inside `wishes`, no temporary UI state.

## Decision

Keep `wishes.image_url` as the **primary image** reference (unchanged
semantics for API payload, `WishCard`, and sync reconcile).

Add a child table `wish_images` (Drift schema v4) for **additional** images:

```
wish_images
  id          (uuid, PK)
  owner_id    (user scope, composite unique with id)
  wish_id     (parent wish; cascade enforced in code — see below)
  local_path  (NULL — local file path; may be cleared after upload)
  remote_url  (NULL — filled by the future upload stage)
  sort_order  (int — order among additional images, 1..N)
  created_at
```

Rules:

- `Wish 1 ─── N WishImage`; primary lives in `wishes.image_url`,
  `wish_images` holds only additional images.
- On create, the first selected photo becomes `image_url` (primary);
  the rest get `sort_order 1, 2, ...` in selection order, inside the same
  Drift transaction as the wish row and its outbox entry.
- `WishImage.remoteUrl` is reserved: a future upload worker fills it,
  giving a natural `local-only → uploaded` progression without schema
  changes. Until then every row is local-only.
- `AppImage` renders local paths vs remote URLs by prefix (`http(s)` →
  network, otherwise file); `Wish.isRemoteImageRef` decides what may go
  into the API payload.
- Outbox payload sends `image_url` only when it is a remote reference;
  `wish_images` rows are never serialized into the wish payload.
- Pull reconcile never erases local references when the server returns
  `image_url: null`, and never touches `wish_images` (server does not know
  about them yet).
- Deletion: no SQL-level FK; the cascade lives in the repository and the
  sync engine (unsynced create → rows go with the wish; tombstone → rows
  survive until the server DELETE is confirmed; remote-delete reconcile →
  rows and local files are removed). Local image files are removed
  best-effort by the repository/session layer.

## Consequences

- Multiple photos persist offline-first without any API/backend change.
- `wish_images` is invisible to the current server contract; a future
  upload stage can backfill `remote_url` and add image-level outbox
  operations without migrating data out of JSON or UI state.
- `wishes.image_url` continues to mean "primary display image" for cards
  and the existing API — no breaking change to `WishCard` or sync.
