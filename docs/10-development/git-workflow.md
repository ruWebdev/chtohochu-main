# Development Workflow

> **Status:** Authoritative guide for the development workflow.
> Covers Git workflow, code review, CI/CD, deployment, feature flags, and environment management.

## 1. Git Workflow

### 1.1 Branch model

The project uses a trunk-based development model with short-lived feature branches.

| Branch | Purpose | Lifetime |
|--------|---------|----------|
| `main` | Production-ready code; always deployable | Permanent |
| `develop` | Integration branch for the next release (optional, if release cadence warrants it) | Permanent |
| `feature/{ticket}-{slug}` | New feature development | Short (days) |
| `fix/{ticket}-{slug}` | Bug fix | Short (days) |
| `hotfix/{ticket}-{slug}` | Urgent production fix | Short (hours) |
| `chore/{slug}` | Non-functional changes (deps, config, docs) | Short |

### 1.2 Branch naming conventions

```text
feature/CX-123-wishlist-sharing
fix/CX-456-login-redirect-loop
hotfix/CX-789-payment-double-charge
chore/update-flutter-deps
```

* `{ticket}` is the Linear/Jira ticket ID (e.g. `CX-123`).
* `{slug}` is a short kebab-case description.
* Branch names are lowercase.

### 1.3 Commit conventions

The project uses **Conventional Commits** for structured, machine-parseable history.

#### Format

```text
<type>(<scope>): <subject>

<optional body>

<optional footer>
```

#### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `chore` | Build, deps, config, tooling |
| `ci` | CI/CD changes |
| `revert` | Reverting a previous commit |

#### Scopes

| Scope | Description |
|-------|-------------|
| `mobile` | Flutter client |
| `backend` | Laravel API |
| `public-web` | Public Nuxt site |
| `seller` | Seller cabinet |
| `admin` | Admin backoffice |
| `db` | Database/migrations |
| `api` | API contract changes |
| `docs` | Documentation |
| `docker` | Docker/infrastructure |

#### Examples

```text
feat(mobile): add wishlist share sheet with QR code

fix(backend): prevent duplicate wish creation on sync retry

docs(api): document wishlist visibility endpoint

chore(docker): add MinIO service to docker-compose

test(mobile): add repository tests for offline wish sync
```

#### Rules

* Subject line: imperative mood, lowercase, no period, max 72 characters.
* Body: explain *why*, not *what* (the diff shows what). Wrap at 72 characters.
* Footer: reference tickets (`Closes CX-123`, `Refs CX-456`) and breaking changes (`BREAKING CHANGE: ...`).
* One logical change per commit — do not mix unrelated changes.

### 1.4 Pull requests

* One PR per feature/fix — small and reviewable.
* PR title follows the commit convention format.
* PR description includes:
  * Summary of changes.
  * Related ticket (`Closes #123`).
  * Breaking changes (if any).
  * Migration notes (if any).
  * Testing notes (how to verify).
  * Screenshots (for UI changes).

## 2. Code Review Process

### 2.1 Requirements

| Requirement | Threshold |
|-------------|----------|
| Minimum approvals | 1 (from a non-author) |
| CI status | All checks must pass |
| Conflicts | Must be resolved before merge |
| Test coverage | New/changed critical behavior must have tests |
| AGENTS.md compliance | Reviewer verifies architectural compliance |

### 2.2 Review checklist

Reviewers MUST check:

- [ ] Architecture follows `AGENTS.md` (layers, boundaries, DI).
- [ ] Business logic is in the correct layer (not in controllers/views/widgets).
- [ ] Authorization is server-side enforced.
- [ ] No client-supplied ownership/permission is trusted.
- [ ] API changes are additive (or breaking change is approved).
- [ ] Migrations exist for schema changes.
- [ ] Offline/sync behavior is defined where needed.
- [ ] Realtime behavior is defined where needed.
- [ ] Error handling is appropriate (no raw exceptions to UI).
- [ ] Localization: no hardcoded user-facing strings.
- [ ] Tests cover critical behavior.
- [ ] Generated code is regenerated (not manually edited).
- [ ] No unrelated refactoring.
- [ ] No secrets in code or commits.

### 2.3 Review etiquette

* Review the code, not the person.
* Be specific — reference line numbers.
* Distinguish between blocking comments and suggestions.
* Approve only when the code is ready to merge.
* Use "nitpick:" prefix for non-blocking style preferences.

### 2.4 Merge strategy

* **Squash and merge** for feature/fix branches (clean history, one commit per PR).
* **Rebase and merge** for multi-commit PRs that should preserve commit structure (rare).
* No merge commits into `main` (keep history linear).

## 3. CI/CD Pipeline

### 3.1 Overview

CI/CD is powered by GitHub Actions. Pipelines run on every push and pull request.

### 3.2 Pipeline stages

```text
Push / PR
  ↓
[1] Lint & Static Analysis
  ↓
[2] Tests
  ↓
[3] Build
  ↓
[4] Security Scan
  ↓
[5] Deploy (main branch only)
```

### 3.3 Backend pipeline (Laravel)

| Stage | Commands |
|-------|----------|
| Setup | `composer install`, copy `.env`, generate key |
| Static analysis | `php artisan lint` (or PHPStan/Pint) |
| Migration check | `php artisan migrate --pretend` (verify migrations run) |
| Tests | `php artisan test --parallel` |
| Coverage | Generate coverage report (minimum threshold: 70% for critical paths) |
| Security | `composer audit` |

### 3.4 Mobile pipeline (Flutter)

| Stage | Commands |
|-------|----------|
| Setup | `flutter pub get` |
| Code generation | `dart run build_runner build --delete-conflicting-outputs` |
| Static analysis | `flutter analyze` |
| Tests | `flutter test` |
| Build (Android) | `flutter build apk --release` |
| Build (iOS) | `flutter build ios --release --no-codesign` (macOS runner) |
| Build (Web) | `flutter build web --release` |

### 3.5 Web pipeline (Nuxt apps)

| Stage | Commands |
|-------|----------|
| Setup | `npm ci` |
| Lint | `npm run lint` |
| Type check | `npm run typecheck` (vue-tsc) |
| Tests | `npm run test` (Vitest) |
| Build | `npm run build` |

### 3.6 Security scan

| Tool | Scope |
|------|-------|
| `composer audit` | PHP dependencies |
| `npm audit` | JS dependencies |
| Trivy / Grype | Docker image vulnerability scan |
| CodeQL | GitHub code security analysis |

## 4. Deployment Process

### 4.1 Environments

| Environment | Branch | Purpose | URL pattern |
|-------------|--------|---------|-------------|
| `dev` | `develop` (or `main`) | Developer integration testing | `dev.chtohochu.ru` |
| `staging` | `release/*` or tagged | Pre-production testing, QA | `staging.chtohochu.ru` |
| `production` | tagged release | Live | `chtohochu.ru` |

### 4.2 Deployment trigger

* **dev:** Automatic on push to `develop`/`main`.
* **staging:** Automatic on tag `v*.*.*-rc.*` or manual trigger.
* **production:** Manual trigger after staging sign-off. Tagged release (`v*.*.*`).

### 4.3 Deployment steps (backend)

```text
1. Pull Docker image (tagged with git SHA)
2. Run database migrations (php artisan migrate --force)
3. Clear and warm cache (php artisan optimize)
4. Restart queue workers (php artisan horizon:terminate → supervisor restarts)
5. Restart Reverb server (zero-downtime via process manager)
6. Health check verification
7. Switch traffic to new container (if blue/green)
```

### 4.4 Deployment steps (web apps)

```text
1. Build static assets (npm run build)
2. Upload to CDN / copy to server
3. Invalidate CDN cache
4. Health check verification
```

### 4.5 Deployment steps (mobile)

```text
1. Bump version number (pubspec.yaml + build.gradle)
2. Build signed AAB/IPA in CI (Android: upload keystore via key.properties — see ADR-013)
3. Upload to Google Play Console (internal track → production)
4. Upload to App Store Connect (TestFlight → App Store)
5. Submit for store review
```

Android release bundles are signed with the upload keystore
(`apps/client/android/app/chtohochu-upload.jks`, alias `chtohochu`) configured
through `apps/client/android/key.properties`. Google Play App Signing re-signs
delivered APKs with its own key; the upload key only authenticates uploaded
bundles. The keystore and `key.properties` are git-ignored and must be provided
to CI via secrets. See ADR-013 for the full signing scheme.

### 4.6 Zero-downtime deployments

* Backend: blue/green deployment with health-check-gated traffic switch.
* Web: CDN-backed static assets; atomic directory swap or CDN invalidation.
* Database: migrations must be backward-compatible (see §6).

## 5. Feature Flags

### 5.1 Purpose

Feature flags allow deploying code with incomplete features hidden behind a toggle, enabling:

* trunk-based development without long-lived branches;
* gradual rollout to subsets of users;
* instant rollback (disable flag) without redeployment;
* A/B testing.

### 5.2 Implementation

Feature flags are stored in the backend (database table or config) and exposed via the API.

| Flag type | Storage | Example |
|-----------|---------|---------|
| Global on/off | Database `feature_flags` table | `new_share_flow` |
| Per-user rollout | Database with user/cohort targeting | `beta_offline_sync` |
| Percentage rollout | Database with hash-based assignment | `new_wishlist_ui` |

### 5.3 API exposure

```http
GET /api/v1/features
```

```json
{
  "features": {
    "new_share_flow": true,
    "beta_offline_sync": false
  }
}
```

The client reads flags on app launch and refreshes periodically. Flags affect UI presentation only — backend endpoints behind a flag reject requests if the flag is off (defense in depth).

### 5.4 Rules

* Every flag has an owner and an expiry date — flags are not permanent.
* Flags are cleaned up after the feature is fully rolled out.
* Flag names are kebab-case, prefixed with the feature area: `wishlist-new-ui`, `sync-beta`.
* No flag-dependent business logic in the database layer.

## 6. Environment Management

### 6.1 Environment parity

Environments should be as similar as possible. Differences are limited to:

| Aspect | dev | staging | production |
|--------|-----|---------|------------|
| Data | Seeded fake data | Anonymized prod copy or fresh seed | Real data |
| Debug | `APP_DEBUG=true` | `APP_DEBUG=false` | `APP_DEBUG=false` |
| Mail | `MAIL_MAILER=log` | Real SMTP (test addresses) | Real SMTP |
| Payments | Mock/sandbox | Sandbox/test mode | Live |
| Rate limits | Relaxed | Production-like | Production |
| Error reporting | Verbose | Sentry (staging project) | Sentry (production project) |

### 6.2 Secrets per environment

* Each environment has its own set of secrets.
* Secrets are never shared between environments.
* Production secrets are managed via the deployment platform's secret manager (GitHub Actions secrets, cloud secret manager, or Vault).
* No production secret is accessible to developers directly.

### 6.3 Database migrations

* Migrations MUST be backward-compatible — the old code version must work against the new schema until the new code is fully deployed.
* Destructive migrations (column drops, type changes) are split across two releases:
  1. Release A: add new column, dual-write, backfill.
  2. Release B: remove old column (after confirming no code references it).
* Never run destructive migrations during a deployment without the backward-compatible step.

### 6.4 Configuration management

| Config type | Mechanism |
|-------------|-----------|
| Environment variables | `.env` per environment; injected via Docker/deployment |
| Feature flags | Database `feature_flags` table |
| Application config | Laravel `config/*.php` with env-driven defaults |
| Web app config | Nuxt runtime config / Flutter `--dart-define` |
