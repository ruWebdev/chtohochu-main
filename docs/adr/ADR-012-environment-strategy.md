# ADR-012: Environment strategy

## Status

Accepted

## Context

ЧтоХочу needs environments for development, pre-production validation, and live user
traffic. The requirements are:

- **Local** — each developer runs the full stack on their machine for inner-loop
  development. Data is synthetic; debugging is enabled; the stack is disposable.
- **Staging** — a shared, production-like environment for integration testing, QA,
  release validation, and OAuth/external-provider testing with non-production
  credentials. Must mirror production topology and versions.
- **Production** — the live, user-facing system with real user data, restricted
  access, auditing, and production secrets.

Configuration must be environment-specific (database DSN, Redis URL, OAuth secrets,
API keys) and must never be hard-coded. Secrets must never be committed to the
repository. Production credentials must never be used in non-production environments.
The number of environments should be small enough to operate reliably but sufficient
to validate changes before they reach users.

AGENTS.md §12 mandates: secrets in environment variables only, never committed; HTTPS
everywhere; audit logging for sensitive operations. AGENTS.md §16 forbids introducing
infrastructure without a concrete requirement.

## Decision

Maintain **three environments**: local, staging, production.

Each environment is configured via environment variables. Every application and the
backend ship a committed `.env.example` template listing all required variables with
placeholder values and public/secret classification. Real `.env` files are
git-ignored and never committed.

- **Local:** Docker Compose stack (ADR-008), `APP_DEBUG=true`, synthetic seed data,
  mail catcher, dev-only OAuth clients, throwaway secrets.
- **Staging:** production-like topology and versions, `APP_ENV=staging`,
  `APP_DEBUG=false`, anonymized/synthetic data, separate OAuth clients and external
  API keys, secrets injected by the CI/CD pipeline or platform secret store.
- **Production:** `APP_ENV=production`, `APP_DEBUG=false`, real user data, secrets
  in the platform secret manager, restricted and audited access, secret rotation.

No additional environments (dev, QA, UAT) are created without an approved ADR.

## Consequences

**Positive**

- **Clear progression.** local → staging → production. Each stage validates more than
  the previous one with higher fidelity to production.
- **Staging parity.** Staging mirrors production topology and versions, so
  version-specific and integration bugs surface before production.
- **Secret hygiene.** `.env.example` templates keep configuration discoverable;
  git-ignored `.env` files and platform secret stores keep secrets out of the
  repository. Public/secret classification prevents accidental exposure of secrets
  in client bundles.
- **Credential isolation.** Each environment uses its own OAuth clients, database
  credentials, and API keys. Production credentials are never used locally or in
  staging, eliminating the risk of a local bug corrupting real data or triggering
  real OAuth flows.
- **Operational simplicity.** Three environments are few enough to keep healthy and
  monitored. More environments increase operational cost and configuration drift
  without proportional safety.

**Negative**

- **Staging is a shared resource.** Multiple developers and CI may contend for
  staging. Mitigated by coordinating destructive actions and by using
  `migrate:fresh --seed` only when staging is not in active use.
- **No dedicated QA/UAT environment.** QA and UAT use staging. If a future need
  arises for a separate UAT environment (e.g. signed-off release candidates), an ADR
  will justify adding it. Premature environments add cost and drift.
- **Local divergence.** Local uses Docker Compose and `APP_DEBUG=true`, which differs
  from production. Mitigated by using the same service versions and the same
  reverse-proxy/TLS topology (ADR-008, ADR-009, ADR-010) so that the differences are
  configuration, not topology.

## Alternatives considered

### More environments (dev, QA, UAT, staging, production)

Add dedicated dev, QA, and UAT environments between local and production.

- **Strengths:** finer-grained validation stages; each stage has a single owner.
- **Rejected because** each additional environment adds operational cost (hosting,
  monitoring, secret management, configuration drift) without proportional safety for
  a product of this size. Five environments are hard to keep parity-healthy; the
  marginal value of dev/QA/UAT beyond staging is low when staging already mirrors
  production. If the organisation grows and a dedicated UAT or release-candidate
  environment becomes justified, an ADR will add it. Premature environments are
  infrastructure without a concrete requirement (AGENTS.md §5, §16).

### Fewer environments (local, production)

Drop staging; validate directly against local and production.

- **Strengths:** minimal operational cost.
- **Rejected because** deploying directly from local to production removes the
  integration-validation stage where version-specific bugs, OAuth/external-provider
  integration issues, and migration interactions are caught. For a product with
  realtime collaboration, OAuth, queues, and a multi-app web surface, the absence of
  a production-like staging environment is an unacceptable risk. Staging is the
  cheapest reliable way to validate a release before it reaches real users. The cost
  of one staging environment is small compared to the cost of a production incident.
