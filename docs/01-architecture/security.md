# Security Architecture

> **Status:** Authoritative security architecture document.
> All security rules are **backend-enforced**. Client-side checks are UX only and must never be the sole enforcement mechanism.
> Conflicts with `AGENTS.md` must be resolved via an ADR in `docs/adr/`.

## 1. Core Principle

> **The backend is the final authority for all security decisions.**

Every security-relevant operation — authentication, authorization, input validation, rate limiting, output filtering — is enforced on the server. The client may hide unavailable actions for UX, but this is not security.

## 2. Authentication Security

### 2.1 Credential storage

* Passwords are hashed with bcrypt or argon2id (Laravel default: bcrypt). Never MD5, SHA1, or plain text.
* Passwords MUST NOT appear in logs, error messages, analytics, or database queries.
* API tokens (Sanctum) are stored as SHA-256 hashes in the database — the plaintext token is shown only once at creation time.

### 2.2 Login

| Control | Requirement |
|---------|-------------|
| Rate limiting | Max 5 failed attempts per email per 15 minutes; max 10 per IP per 15 minutes |
| Lockout | Temporary lock after threshold; exponential backoff |
| Response | Generic "invalid credentials" — do not reveal whether email exists |
| Timing | Constant-time comparison to prevent timing attacks on user enumeration |
| 2FA | Required for admin accounts; optional for users/sellers |

### 2.3 Token security (Sanctum)

| Control | Requirement |
|---------|-------------|
| Token format | Long random string (Laravel Sanctum default, 80 chars) |
| Storage (client) | `flutter_secure_storage` (mobile), `sessionStorage`/`localStorage` (web) — never in plain files, logs, or shared preferences |
| Storage (server) | SHA-256 hash in `personal_access_tokens` table |
| Expiration | User tokens: 90 days; seller tokens: 30 days; admin tokens: 8 hours |
| Revocation | Immediate on logout, password change, or admin force-logout |
| Scope | Tokens carry abilities (`user:*`, `seller:*`, `admin:*`) — least privilege enforced |
| Rotation | No automatic rotation; user can revoke and re-issue from settings |

### 2.4 OAuth security (VK, Yandex)

| Control | Requirement |
|---------|-------------|
| State parameter | Cryptographically random, validated on callback — prevents CSRF |
| Redirect URI | Exact match only; no wildcard matching |
| Token exchange | Server-side only; client never sees the provider's access token |
| Account linking | Prevent linking an OAuth identity to an already-linked account |
| Email collision | If OAuth email matches existing account, require password verification before linking |
| Token storage | Provider tokens stored encrypted at rest; never sent to the client |

## 3. Authorization Enforcement

### 3.1 Layered authorization

Every protected API request MUST verify, in order:

1. **Authentication** — is the caller a valid, authenticated user?
2. **Ownership** — does the caller own the resource?
3. **Membership** — is the caller a member of the relevant group/list?
4. **Permission** — does the caller have the required permission for this action?
5. **Resource visibility** — is the resource visible to this caller?

### 3.2 Implementation

* Laravel policies and gates enforce authorization.
* Controllers call `$this->authorize()` or `Gate::check()` before any business logic.
* Client-supplied ownership or permission fields MUST NOT be trusted — always re-derive from the authenticated user and database state.

```php
// Example: wishlist access
public function show(Wishlist $wishlist)
{
    $this->authorize('view', $wishlist); // checks ownership/membership/visibility
    return new WishlistResource($wishlist);
}
```

### 3.3 Abilities (Sanctum token scopes)

| Context | Abilities |
|---------|-----------|
| User | `user:read`, `user:write` |
| Seller | `seller:read`, `seller:write`, `seller:products:write`, `seller:orders:write` |
| Admin | `admin:users:read`, `admin:users:write`, `admin:sellers:read`, ... |

The backend checks both the token ability AND the resource-level policy.

## 4. Rate Limiting

### 4.1 Strategy

Rate limiting is enforced by Laravel's `throttle` middleware (backed by Redis).

| Endpoint group | Limit | Window |
|----------------|-------|--------|
| Login | 5 per email, 10 per IP | 15 minutes |
| Registration | 3 per IP | 1 hour |
| Password reset request | 3 per email | 1 hour |
| OAuth callback | 10 per IP | 15 minutes |
| Authenticated API (general) | 60 per user | 1 minute |
| Write operations (mutations) | 30 per user | 1 minute |
| File uploads | 10 per user | 1 minute |
| Public API (unauthenticated) | 30 per IP | 1 minute |
| Admin API | 120 per admin | 1 minute |

### 4.2 Implementation

```php
Route::middleware(['throttle:5,15'])->group(function () {
    Route::post('/auth/login', [AuthController::class, 'login']);
});

Route::middleware(['auth:sanctum', 'throttle:60,1'])->group(function () {
    Route::get('/v1/wishlists', [WishlistController::class, 'index']);
});
```

### 4.3 Response

* `429 Too Many Requests` with `Retry-After` header.
* Response body includes rate limit info: `X-RateLimit-Limit`, `X-RateLimit-Remaining`.

## 5. Input Validation

### 5.1 Rules

* All input is validated server-side via Laravel Form Requests.
* No client-supplied data is trusted without validation.
* Validation rules are explicit and documented per endpoint.
* Unknown fields in JSON payloads are rejected (strict mode) or ignored — never silently processed.

### 5.2 Implementation

```php
class StoreWishlistRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'visibility' => ['required', 'in:personal,link,public'],
            'emoji' => ['nullable', 'string', 'max:10'],
        ];
    }

    public function authorize(): bool
    {
        return true; // policy handles resource-level auth
    }
}
```

### 5.3 SQL injection prevention

* Eloquent and query builder use parameter binding — never raw string concatenation.
* `DB::raw()` MUST NOT include user input.
* Any raw query MUST use bindings.

### 5.4 Mass assignment prevention

* Models use `$fillable` (allowlist) — never `$guarded` (denylist).
* Only explicitly allowed fields are mass-assignable.

## 6. Output Filtering

### 6.1 Principles

* API responses use Laravel API Resources to control exactly which fields are exposed.
* Never `return $model` directly — always transform through a resource.
* Sensitive fields (password_hash, tokens, internal IDs, PII) MUST NOT appear in API responses.

### 6.2 XSS prevention (web)

| Surface | Control |
|---------|---------|
| Nuxt/Vue | Vue auto-escapes `{{ }}` interpolation; never use `v-html` with untrusted data |
| Flutter web | Flutter renders text safely; avoid `HtmlElementView` with untrusted HTML |
| API responses | Sanitize any user-generated HTML before storing (e.g. wishlist descriptions, comments) |
| User content | Strip or sanitize HTML; allow only a safe subset if rich text is needed |

### 6.3 Serialization

* API Resources map domain models to JSON responses.
* Resources are the only path from internal state to API output.
* Never expose internal model attributes that are not explicitly declared in the resource.

## 7. File Upload Security

Uploaded files are **untrusted input**.

### 7.1 Validation

| Control | Requirement |
|---------|-------------|
| MIME type | Server-side detection (e.g. `finfo`/`mime_content_type`); NEVER trust client `Content-Type` |
| Extension | Allowlist only (jpg, jpeg, png, webp, avif for images) |
| File size | Max 10MB for images (configurable); reject before reading into memory |
| Dimensions | Max 4096×4096px for images; validate server-side |
| Magic bytes | Verify file signature matches claimed type |
| Filename | Server-generated random filename; never use client filename for storage |
| Count | Limit uploads per user per time window (rate limited) |

### 7.2 Storage

| Control | Requirement |
|---------|-------------|
| Location | S3-compatible object storage; never in the application server filesystem |
| Access | Private bucket; files served via signed URLs or through a CDN with token auth |
| Isolation | Files stored with random UUID names; original filename stored as metadata only |
| Scanning | Scan uploaded images for malicious content (optional: ClamAV or cloud scanning) |

### 7.3 Serving

* Images served via CDN with signed URLs (time-limited access).
* `Content-Disposition: inline` for display; `attachment` for downloads.
* `Content-Type` set from server-validated type, not from upload metadata.
* `X-Content-Type-Options: nosniff` header on all file responses.

## 8. CSRF Protection

### 8.1 API (token-based)

The mobile and web applications use **bearer token** authentication (Sanctum), not cookies. This eliminates CSRF risk for API calls because:

* The token is sent via `Authorization` header, not automatically by the browser.
* Cross-origin requests cannot attach the `Authorization` header without CORS permission.

### 8.2 Cookie-based endpoints (if any)

If any endpoint uses cookie-based auth (e.g. Sanctum cookie mode for same-origin web):

| Control | Requirement |
|---------|-------------|
| CSRF token | Laravel's `VerifyCsrfToken` middleware active |
| SameSite | Cookies set with `SameSite=Strict` or `SameSite=Lax` |
| Secure | `Secure=true` (HTTPS only) |
| HttpOnly | `HttpOnly=true` (no JS access) |

## 9. CORS Configuration

### 9.1 Rules

* Only explicitly allowed origins may make cross-origin requests.
* No wildcard (`*`) origins in production.
* Each web application (public-web, user-web, seller, admin) has its own allowed origin.

### 9.2 Configuration

```php
// config/cors.php
'paths' => ['api/*'],
'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
'allowed_origins' => [
    'https://chtohochu.ru',        // public web
    'https://app.chtohochu.ru',    // user web
    'https://seller.chtohochu.ru', // seller cabinet
    'https://admin.chtohochu.ru',  // admin (if not IP-restricted)
],
'allowed_headers' => ['Authorization', 'Content-Type', 'X-Requested-With'],
'exposed_headers' => ['X-RateLimit-Limit', 'X-RateLimit-Remaining'],
'max_age' => 3600,
'supports_credentials' => false, // bearer token auth, no cookies
```

## 10. Secrets Management

### 10.1 Principles

* Secrets MUST NOT be committed to the repository.
* Secrets MUST NOT appear in logs, error messages, or stack traces.
* Secrets are injected via environment variables at runtime.

### 10.2 Categories

| Secret | Storage |
|--------|---------|
| App key (`APP_KEY`) | Environment variable; rotated periodically |
| Database credentials | Environment variable / secret manager |
| Redis password | Environment variable |
| OAuth client secrets (VK, Yandex) | Environment variable; encrypted at rest in DB if stored |
| S3 credentials | Environment variable / IAM role |
| FCM server key | Environment variable |
| Reverb signing secret | Environment variable |
| Webhook signing secrets | Environment variable |

### 10.3 `.env` handling

* `.env` is in `.gitignore`.
* `.env.example` is committed with placeholder values only.
* Production secrets are managed via Docker secrets, cloud secret manager, or deployment pipeline secrets — never baked into images.

## 11. Audit Logging

### 11.1 What to log

All security-relevant events are logged to a persistent audit log (PostgreSQL table, not just log files).

| Event | Fields |
|-------|--------|
| Login (success) | user_id, ip, user_agent, timestamp |
| Login (failure) | email, ip, user_agent, timestamp |
| Logout | user_id, ip, timestamp |
| Token creation | user_id, abilities, ip, timestamp |
| Token revocation | user_id, token_id, ip, timestamp |
| Password change | user_id, ip, timestamp |
| OAuth link/unlink | user_id, provider, ip, timestamp |
| Admin action | actor_id, action, entity_type, entity_id, reason, ip, timestamp |
| Moderation action | actor_id, action, target_type, target_id, reason, timestamp |
| Data export | user_id, ip, timestamp |
| Data deletion | user_id, ip, timestamp |

### 11.2 Requirements

* Audit logs are append-only — no updates or deletes (enforced at DB level).
* Audit logs are retained per compliance requirements (minimum 1 year).
* PII in audit logs is minimized; IP addresses may be anonymized after a retention period.
* Admins can view audit logs but cannot modify or delete them.

## 12. Abuse Prevention

### 12.1 User-generated content

| Abuse vector | Prevention |
|--------------|------------|
| Spam wishes/lists | Rate limit creation; content-based spam detection (optional) |
| Inappropriate images | Moderation queue; report/flag system; automated scanning (optional) |
| Harassment via comments | Report system; comment rate limiting; user blocking |
| Mass invitation spam | Rate limit invitations per user per time window |
| Username squatting | Reserved names; rate limit username changes |

### 12.2 Account abuse

| Abuse vector | Prevention |
|--------------|------------|
| Mass account creation | IP-based rate limiting on registration; captcha (optional) |
| Credential stuffing | Login rate limiting; lockout; optional captcha after failures |
| Token theft | Short admin token TTL; token revocation on password change |

## 13. Webhook Verification

If the system sends or receives webhooks:

### 13.1 Outgoing webhooks (we call others)

* Include a signature header: `X-ChtoHochu-Signature: sha256={hmac}`.
* HMAC computed over the request body using a shared secret.
* Include a timestamp header to prevent replay: `X-ChtoHochu-Timestamp`.
* Recipient verifies signature and rejects if invalid or timestamp is outside tolerance (±5 minutes).

### 13.2 Incoming webhooks (others call us)

* Verify the incoming signature using the provider's documented method.
* Verify the timestamp to prevent replay attacks.
* Return `200 OK` immediately and process asynchronously via queue.
* Webhook endpoints are rate limited.
* Webhook processing jobs are idempotent (see §14).

## 14. Idempotency

### 14.1 Principle

Retryable mutations MUST be idempotent. If the same operation reaches the server twice, it MUST NOT create duplicate business effects.

### 14.2 Implementation

* Sync mutations include an `operation_id` (UUID generated client-side).
* The server stores `operation_id` with a unique constraint.
* On duplicate `operation_id`, the server returns the original result (not an error).
* This applies to: item creation, invitations, sync mutations, notification jobs, webhook processing.

```php
// Example: idempotent mutation
public function store(StoreWishRequest $request)
{
    return DB::transaction(function () use ($request) {
        $existing = SyncOperation::where('operation_id', $request->header('X-Operation-Id'))->first();
        if ($existing) {
            return $this->responseForOperation($existing);
        }

        $wish = $this->createWish->execute($request->validated());
        SyncOperation::create([
            'operation_id' => $request->header('X-Operation-Id'),
            'entity_type' => 'wish',
            'entity_id' => $wish->id,
            'status' => 'completed',
        ]);
        return new WishResource($wish);
    });
}
```

## 15. Privacy

### 15.1 Data minimization

* Collect only data necessary for the product feature.
* Do not log PII unnecessarily.
* Analytics events use pseudonymous user IDs, not emails or names.

### 15.2 Data access

* Users can access their own data via the profile/settings.
* Admins can access user data only through the admin backoffice (audited).
* No developer or system process accesses raw user data without an audited path.

### 15.3 Data retention

| Data type | Retention |
|-----------|-----------|
| Active user data | Until account deletion |
| Deleted account data | Purged within 30 days (except where legal retention requires longer) |
| Audit logs | Minimum 1 year |
| Server access logs | 90 days |
| Push notification tokens | Removed on logout or when expired |

## 16. Data Deletion (GDPR)

### 16.1 Right to erasure

Users can request account deletion. The system MUST:

1. Verify the user's identity (authenticated request or verified email confirmation).
2. Anonymize or delete personal data:
   * User profile (name, email, avatar, birthday) → deleted or anonymized.
   * User's wishlists and wishes → deleted (or anonymized if referenced by other users' content).
   * Friends relationships → deleted.
   * Shopping list memberships → removed.
   * Comments → anonymized (author set to "deleted user") or deleted.
   * Auth tokens → revoked and deleted.
   * Push notification tokens → deleted.
3. Retain only what is legally required (e.g., financial transaction records for tax compliance) — these are anonymized where possible.
4. Log the deletion to the audit trail (without retaining the user's PII in the log).
5. Complete within 30 days of request.

### 16.2 Data export (right to portability)

Users can request a data export:

1. User initiates export from settings.
2. Backend queues a job to compile the user's data (profile, wishlists, wishes, lists, comments).
3. Export is generated as JSON (and optionally CSV).
4. User receives a download link (signed URL, time-limited).
5. Export job is logged to audit.

### 16.3 Implementation

```php
class DeleteUserAccount
{
    public function execute(User $user): void
    {
        DB::transaction(function () use ($user) {
            // Revoke all tokens
            $user->tokens()->delete();

            // Delete owned content
            $user->wishlists()->delete();
            $user->wishes()->delete();
            $user->shoppingLists()->delete();

            // Remove memberships
            $user->memberships()->delete();

            // Anonymize comments
            $user->comments()->update(['user_id' => null, 'author_name' => 'deleted user']);

            // Delete friends
            $user->friendships()->delete();

            // Delete profile data
            $user->forceDelete(); // or anonymize
        });

        AuditLog::create([
            'action' => 'user.account_deleted',
            'entity_type' => 'user',
            'entity_id' => $user->id,
            'ip_address' => request()->ip(),
        ]);
    }
}
```

## 17. Transport Security

| Control | Requirement |
|---------|-------------|
| HTTPS | Mandatory for all environments (including staging) |
| HSTS | `Strict-Transport-Security: max-age=31536000; includeSubDomains` |
| TLS version | 1.2 minimum; 1.3 preferred |
| Certificate | Valid, non-expired; auto-renewed (Let's Encrypt or managed) |
| HTTP → HTTPS | All HTTP requests redirected to HTTPS |
| Internal traffic | Container-to-container may use HTTP; external-facing must be HTTPS |

## 18. Security Headers

| Header | Value |
|--------|-------|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` (or CSP `frame-ancestors`) |
| `X-XSS-Protection` | `0` (deprecated; rely on CSP) |
| `Content-Security-Policy` | Strict policy per application |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | Restrict unnecessary browser features |

## 19. Dependency Security

* Regularly run `composer audit` (PHP) and `npm audit` (JS) in CI.
* Keep dependencies updated; patch critical vulnerabilities immediately.
* No dependencies with known critical vulnerabilities deployed to production.
