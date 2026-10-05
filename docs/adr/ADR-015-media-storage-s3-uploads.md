# ADR-015: Media storage & S3 upload lifecycle

## Status

Accepted

## Context

ADR-014 introduced local-first wish images (`wishes.image_url` +
`wish_images` rows with `local_path`/`remote_url`). The next stage is a
production media pipeline: photos must reach object storage **without**
making wish creation depend on connectivity or S3 availability.

Hard requirements from the product task:

- offline-first is preserved: a wish with photos is created instantly in
  Drift and must survive S3/backend/network outages;
- the Flutter client **never** receives S3 credentials — only short-lived
  presigned PUT URLs issued by the backend (SigV4, ~10 min TTL);
- media storage is reusable (`avatar`, `wish`, `shopping`), not
  wish-specific;
- uploads are verifiable (backend confirms the object exists before it
  counts), retryable without duplicates, and cleanable on entity delete.

## Decision

### Buckets and namespaces

ЧтоХочу uses **one physical S3 bucket** with three logical
root prefixes. The SprintHost account exposes a single fixed bucket
(`s3-969161`) and denies `CreateBucket`; the bucket also contains
prefixes owned by another project — they must never be read, modified,
renamed, or deleted by this system.

Each `purpose` is bound server-side to a dedicated filesystem disk
(same physical bucket) and an immutable `key_prefix`:

| purpose   | root prefix                  | full object key pattern                                       |
|-----------|------------------------------|---------------------------------------------------------------|
| `avatar`  | `chtohochu-avatars/`         | `chtohochu-avatars/users/{userId}/avatar/{imageId}.{ext}`     |
| `wish`    | `chtohochu-wish-images/`     | `chtohochu-wish-images/users/{userId}/wishes/{wishId}/{imageId}.{ext}` |
| `shopping`| `chtohochu-shopping-images/` | `chtohochu-shopping-images/users/{userId}/shopping-lists/{listId}/{imageId}.{ext}` |

All three `S3_BUCKET_*` env vars MUST resolve to the same physical
bucket. Prefixes are object-key prefixes, not directories and not
buckets — every ЧтоХочу object key starts with its purpose prefix;
keys outside `chtohochu-*` are unreachable through the media API.
Object keys are unique (`{uuid}.{ext}`) — media objects are immutable
and cacheable forever; no foreign prefixes are touched.

### Access model

```
Flutter ──auth──▶ Backend ──▶ presigned PUT (SigV4, TTL 10 min) ──▶ S3
   │                                                             │
   └────────────── immutable remote_url (public-read object) ◀────┘
```

- Write access is **presigned-PUT only** — the bucket is not
  write-public.
- Read access is public-read via a bucket policy **scoped to
  `chtohochu-*` prefixes only** — foreign prefixes in the shared bucket
  stay private (immutable objects; `remote_url` is stored as the
  display reference). A CDN can be layered on top later without API
  changes.
- The client sends only `purpose`, `entity_id`, `content_type`,
  `size`, `client_id`. Bucket, object key and namespace are
  **server-generated**; the client can never pick a foreign `userId`,
  another bucket, or an arbitrary key.

### API (`/api/v1/media/uploads`)

- `POST /media/uploads` — validation (purpose, MIME whitelist
  `image/jpeg|png|webp`, `MEDIA_MAX_UPLOAD_BYTES` = 5 MB, ownership of
  the referenced wish/shopping list) → creates `media_uploads` row
  (`pending`) + returns `{upload_id, upload_url, upload_headers,
  object_key, remote_url, expires_at}`. `upload_headers` are the exact
  headers the client MUST send with PUT — `Content-Type` is always
  included (not all providers sign it; without it the object gets a
  default MIME and fails `complete`).
- `POST /media/uploads/{id}/complete` — owner check + verifies the
  object **exists** in S3 (head) with matching content type and size ≤
  limit → status `uploaded`. A mere client call never marks it uploaded.
- `DELETE /media/uploads/{id}` — owner-scoped cancel/cleanup.
- Idempotency: `(user_id, client_id)` is unique — a retry with the same
  `client_id` returns the same upload row and object key, no duplicates.

### Lifecycle

```
pending → uploading → uploaded
    ↘ transient error ↗    ↘ permanent (4xx / missing file) → failed
```

Client side (Drift v5): `wishes.image_upload_status` /
`image_upload_id` and `wish_images.upload_status` / `upload_id` persist
the state across restarts. The sync engine runs a media phase **after**
the entity push (media of an unsynced wish is skipped until its create
op lands), uploads primary then additional images, persists
`remote_url`, and emits a normal `update` outbox op carrying
`image_url` — no separate protocol.

- `uploaded` rows are never re-uploaded.
- Transport errors / 5xx keep `pending` (retried on later syncs);
  4xx / missing local file / non-whitelisted type → `failed`, no
  infinite retry.
- `local_path` is kept after upload so local rendering never regresses
  and pull reconcile cannot erase local media (`image_url: null` from
  the server does not overwrite local state).

### Local storage layout

`Documents/media/{wishes,avatars,shopping}/` replaces the ad-hoc
`Documents/wish_photos/`. A one-time sync-IO migration
(`MediaStorageMigration`, flag `media_dirs_migrated`) moves existing
files and rewrites `image_url`/`local_path` in Drift.

### Compression

Before persistence the photo goes through `MediaImageProcessor`:
correct orientation → resize to max 2048 px on the long side → JPEG
quality 82 (transparency-bearing PNG/WebP are not forcibly JPEG-ed).
HEIC camera output is normalized to JPEG. The compressed derivative is
what gets uploaded; the same file is the local render source.

### Deletion

Wish delete is never blocked on S3: the entity is deleted locally
(tombstone for the sync layer), and `DeleteMediaObjects` queue job
removes the remote objects afterwards — idempotent and retryable on
transient S3 failures. Local files are removed best-effort by the
client on delete / logout.

### Out of scope (consciously)

- shopping-images / avatar **UI** (infrastructure + API only);
- server-side image processing (resize/thumbnails);
- CDN distribution (public-read object URLs for now);
- crop/edit tooling.

## Consequences

- Wish creation stays instant and offline-capable; S3 is a later,
  retryable delivery stage.
- All media security decisions live server-side; Flutter holds zero
  storage credentials.
- `media_uploads` gives an auditable, idempotent upload ledger that
  shopping/avatar flows can reuse unchanged.
- Namespace isolation is enforced server-side twice: `key_prefix`
  is bound to `purpose` in `config/media.php` (keys can only ever be
  generated under `chtohochu-*`), and every stored-key operation
  (`complete`, `delete`, cleanup job) re-asserts the key is inside its
  purpose prefix — foreign namespaces are unreachable.
- Physical bucket names are environment configuration; moving to
  per-purpose buckets later is an `.env`-only change (prefixes stay).
