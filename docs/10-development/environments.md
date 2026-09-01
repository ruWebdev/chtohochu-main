# Environment Strategy — ЧтоХочу

> **Status:** Authoritative. Defines the environments used for development, staging,
> and production, and the rules for managing configuration and secrets.

## 1. Environments

The project maintains three environments:

| Environment | Purpose | Data | Access |
|-------------|---------|------|--------|
| **local** | Developer machine; full stack via Docker | Synthetic seed data | Developer only |
| **staging** | Pre-production integration; mirrors production config | Anonymized or synthetic data | Team + QA |
| **production** | Live user-facing system | Real user data | Restricted; audited |

No additional environments (dev, QA, UAT) are created without an approved ADR. Three
environments balance correctness against operational cost.

## 2. Environment Variables

### 2.1 Principles

1. **Configuration via environment variables.** All environment-specific values
   (database DSN, Redis URL, OAuth secrets, API keys) are read from the environment,
   never hard-coded.
2. **`.env.example` is the template.** Every application and the backend ship a
   `.env.example` that lists all required variables with placeholder values. The
   example is committed; real `.env` files are not.
3. **`.env` is git-ignored.** The real `.env` file is never committed. The
   `.gitignore` in each app and the backend excludes `.env`.
4. **Secrets are never logged.** Application code and logging configuration must not
   emit secret values (passwords, tokens, API keys) to logs, error messages, or
   telemetry.
5. **Runtime config for Nuxt.** Nuxt apps use `runtimeConfig` populated from
   environment variables (`NUXT_PUBLIC_*`, `NUXT_SERVER_*`).

### 2.2 Backend variables

| Variable | Public / Secret | Notes |
|----------|-----------------|-------|
| `APP_ENV` | Public | `local`, `staging`, `production` |
| `APP_DEBUG` | Public | `true` locally, `false` in staging/production |
| `APP_URL` | Public | Environment base URL |
| `APP_KEY` | Secret | Laravel encryption key |
| `DB_HOST`, `DB_PORT`, `DB_DATABASE` | Public | Connection details |
| `DB_USERNAME`, `DB_PASSWORD` | Secret | Database credentials |
| `REDIS_HOST`, `REDIS_PORT` | Public | Cache/queue connection |
| `REDIS_PASSWORD` | Secret | If configured |
| `REVERB_APP_ID`, `REVERB_APP_KEY` | Public | WebSocket app identifier |
| `REVERB_APP_SECRET` | Secret | WebSocket signing secret |
| `VK_OAUTH_CLIENT_ID` | Public | OAuth provider client ID |
| `VK_OAUTH_CLIENT_SECRET` | Secret | OAuth provider secret |
| `YANDEX_OAUTH_CLIENT_ID` | Public | OAuth provider client ID |
| `YANDEX_OAUTH_CLIENT_SECRET` | Secret | OAuth provider secret |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Secret | S3-compatible storage |
| `FCM_SERVER_KEY` | Secret | Firebase push transport |
| `MAIL_*` | Secret (if SMTP) | Mail transport credentials |

### 2.3 Web app variables

| Variable | Public / Secret | Notes |
|----------|-----------------|-------|
| `NUXT_PUBLIC_API_BASE_URL` | Public | API base URL for client-side calls |
| `NUXT_PUBLIC_USER_WEB_URL` | Public | Cross-app link target |
| `NUXT_SERVER_API_INTERNAL_BASE_URL` | Public (server-only) | API base URL for SSR calls |

## 3. Secrets Management

### 3.1 Local

- Secrets live in `.env` files on the developer machine.
- `.env` is git-ignored and never committed.
- Local secrets (e.g. `REVERB_APP_SECRET`) are throwaway values for development only.
- OAuth provider credentials for local use are obtained from a dedicated dev app in
  the provider dashboard, not from the production OAuth app.

### 3.2 Staging

- Secrets are injected by the CI/CD pipeline or the hosting platform's secret store
  (e.g. GitHub Actions secrets, cloud secret manager).
- `.env` files are not stored in the repository.
- Staging uses its own OAuth client IDs and secrets, separate from production.

### 3.3 Production

- Secrets are stored in the platform's secret manager (cloud secret store, sealed
  secrets, or equivalent) and injected at deploy time.
- Access to production secrets is restricted and audited.
- Secret rotation is performed on a schedule and after any suspected exposure.

## 4. Rules

1. **Never commit `.env`.** The `.gitignore` excludes `.env`, `.env.local`, and
   `.env.*.local`. A pre-commit hook or CI check should fail if a secret is detected.
2. **Never use production credentials locally.** Local development uses synthetic
   data, local database users, and dev-only OAuth clients. Connecting a local
   environment to production databases or production OAuth apps is forbidden.
3. **Never log secrets.** Logging configuration must redact known secret keys. Error
   handlers must not dump the full environment.
4. **`.env.example` stays in sync.** When a new environment variable is introduced,
   `.env.example` is updated in the same PR. A stale `.env.example` is a bug.
5. **Public vs secret is explicit.** Variables are classified as public or secret in
   this document and in `.env.example`. Public variables may appear in client bundles;
   secret variables must never be exposed to the client.

## 5. Environment Parity

Staging mirrors production as closely as possible:

- Same service topology (Traefik/Nginx, PostgreSQL, Redis, Reverb, workers).
- Same major versions of PostgreSQL, Redis, PHP, Node.
- Same feature flags (or a staging subset).
- Same queue and scheduler configuration.

The only intentional differences:

- `APP_ENV=staging`, `APP_DEBUG=false`.
- Synthetic or anonymized data.
- Separate OAuth clients and separate external API keys.
- Reduced resource sizing (acceptable; not a correctness concern).

Local differs more substantially (Docker Compose, `APP_DEBUG=true`, mail catcher,
seed data) but uses the same service versions to catch version-specific issues early.

## 6. Non-Goals

- No more than three environments without an approved ADR.
- No `.env` files in the repository.
- No production data in non-production environments.
- No shared credentials across environments.
