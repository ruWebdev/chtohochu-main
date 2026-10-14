# ADR-016: Incoming share (ACTION_SEND) & headless WebView link preview

## Status

Accepted

## Context

The product feature "marketplace → Share → ЧтоХочу → wish creation"
requires two capabilities the client did not have:

1. Receiving `ACTION_SEND` / `text/plain` intents from the Android
   Sharesheet (marketplace apps share product URLs as text). The
   existing incoming-link pipeline (`app_links`) only delivers `VIEW`
   intents for `https://chtohochu.ru/s/{token}` deep links.

2. Extracting **dynamic** Open Graph metadata (`og:title`, `og:image`,
   `og:description`, price) on-device. Validation on a real Android
   device (Marketplace Probe) showed that direct HTTP requests to
   Wildberries/Ozon are blocked by anti-bot systems (WB Guardium →
   HTTP 498, Ozon → 403 + JS challenge), while a real WebView engine
   passes the challenge automatically and reads the SPA-rendered OG
   tags. An ordinary `Dio` fetch is therefore not a viable extractor.

Constraints from the product task: no server-side parsing, no new
form, no mandatory network for saving, offline-first preserved.

## Decision

### Incoming share plugin

- `listen_sharing_intent` is the single incoming-share plugin. It is
  an `Activity.onNewIntent`/initial-intent adapter; it does not
  overlap with `app_links` (URI `VIEW` intents) or `share_plus`
  (outgoing share).
- `MainActivity` runs `launchMode="singleTask"` so a share delivered
  while the app is running arrives via `onNewIntent` instead of
  spawning a second activity instance.
- `IncomingShareHandler` normalizes shared text → URL
  (`SharedTextParser`), deduplicates repeats (`ShareDeduper`,
  5 s window) and parks the URL in `pendingShareProvider` until the
  session reports `AppSessionReady`; then it navigates to
  `/wishes/new` with a typed `WishDraft` in `GoRouter.extra`.
- Shares received while a creation form is open are surfaced through
  `shareWhileFormOpenProvider` (Snackbar + explicit action) instead of
  silently destroying user input.

### Headless WebView extractor

- `flutter_inappwebview` `HeadlessInAppWebView` loads the shared URL
  off-screen with JS enabled and images disabled (traffic saving).
- `LinkPreviewExtractor` polls the DOM every ~1.5 s until `og:title`
  is stable across `stablePolls` polls or `maxWait` elapses — SPAs
  rewrite generic OG tags after hydration, so stability is the
  readiness signal. Anti-bot interstitial text ("Подозрительная
  активность", challenge pages) resets the stability counter.
- Price resolution prefers structured sources over page text:
  `itemprop=price` → `product:price:amount` → JSON-LD
  `Product.offers.price` → `«N ₽»` match scoped to the `h1` subtree →
  first `«N ₽»` in body. The DOM regex accepts digits with
  regular/non-breaking spaces only — `\s` would glue separate numbers
  across line breaks into a bogus price.
- One active extraction per extractor instance: a new `extract` or
  `cancel` disposes the previous WebView and invalidates the stale
  result via a generation counter.
- The extractor returns a `LinkPreview` (title/description/imageUrl/
  price/siteName); failure, timeout, CAPTCHA or missing tags yield
  `null`/empty and never block the form.

### Image handling

`og:image` is an external URL, not an uploaded wish image (ADR-015).
`RemoteImageFetcher` downloads it (bounded size/time), runs it through
`MediaImageProcessor`, stores the file under
`Documents/media/wishes/` (`MediaPaths.wishesDir`) and hands the
**local path** to the existing image field → the standard
pending-upload pipeline uploads it later. On failure the field stays
empty and manual photo selection remains available.

## Consequences

- Two new dependencies: `flutter_inappwebview` (heavy, platform
  WebView) and `listen_sharing_intent` (thin Android adapter).
- Import adds ~5–10 s of page load inside a hidden WebView; the form
  stays fully editable during extraction.
- `/s/{token}` deep links and outgoing `share_plus` flows are
  untouched — different intent actions and different plugins.
- iOS is intentionally out of scope.
