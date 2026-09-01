# ADR-009: Traefik for local routing

## Status

Accepted

## Context

ЧтоХочу has multiple local web surfaces that must each be reachable on their own
hostname with HTTPS (see ADR-010 for why HTTPS is required locally):

- `api.chtohochu.test` — Laravel API.
- `lk.chtohochu.test` — public-web authenticated cabinet (Inertia).
- `chtohochu.test` — public-web marketing/SEO.
- `seller.chtohochu.test` — seller cabinet.
- `admin.chtohochu.test` — admin backoffice.
- `ws.chtohochu.test` — Reverb WebSocket.
- `mail.chtohochu.test` — mail catcher UI.

Using `localhost:PORT` for each app is insufficient because:

- **Cookies are scoped to the host.** Sanctum stateful domains and CSRF tokens need
  proper domain scoping; sharing `localhost` across apps causes cookie leakage.
- **OAuth redirect URIs** must be stable, HTTPS URLs, not ports.
- **WebSocket mixed-content** rules require the page and the socket to share a scheme;
  per-app ports do not solve this cleanly.
- **The routing topology should mirror production** so edge cases surface locally.

The local environment needs a reverse proxy that can route by Host header, terminate
TLS, handle WebSocket upgrades, and be configured declaratively (via Docker labels
or a file) rather than via hand-edited config that drifts.

## Decision

Use **Traefik** as the local reverse proxy.

Traefik is configured declaratively. In the Docker Compose stack, each container is
labelled with its routing rules; Traefik discovers services via the Docker provider
and routes by Host header. TLS is terminated using mkcert-generated certificates
(ADR-010). HTTP on port 80 is redirected to HTTPS on port 443. WebSocket upgrades are
handled automatically.

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`api.chtohochu.test`)"
  - "traefik.http.routers.app.entrypoints=websecure"
  - "traefik.http.routers.app.tls=true"
```

## Consequences

**Positive**

- **Declarative, label-driven routing.** Adding a service means adding labels to its
  container — no central config file to hand-edit and drift. This fits the Docker
  Compose workflow.
- **Automatic WebSocket support.** Traefik handles `Upgrade: websocket` without
  special middleware, so Reverb routing requires no extra configuration.
- **Automatic TLS.** With mkcert certificates in the default TLS store, every
  `*.chtohochu.test` host is served over HTTPS without per-host cert configuration.
- **Production-like topology.** A single reverse proxy in front of all services
  mirrors production, so cookie scoping, OAuth redirects, and mixed-content rules
  behave locally as they do in production.
- **Dashboard.** Traefik's built-in dashboard (dev-only) helps debug routing.

**Negative**

- **One more service to learn.** Developers unfamiliar with Traefik must understand
  label-based routing. Mitigated by the `Makefile` and the local-routing doc, which
  hide the common cases behind `make` commands.
- **Label complexity for non-trivial rules.** Path stripping and middleware chains
  (e.g. for Horizon/Telescope) are more verbose in labels than in a config file.
  Mitigated by using Traefik's file provider for dynamic config where labels become
  unwieldy.

## Alternatives considered

### Nginx

The canonical reverse proxy; mature; ubiquitous.

- **Strengths:** extremely mature; well-understood; excellent performance; the
  production default for many deployments.
- **Rejected because** for *local* development, Nginx requires hand-edited config
  files that do not auto-discover containers. Adding a service means editing the
  Nginx config and reloading, which drifts from the Docker Compose workflow and is
  error-prone. Traefik's label-based, auto-discovering model is a better fit for a
  Docker Compose local environment where services are added and removed frequently.
  Nginx remains a valid production choice (AGENTS.md §4 lists "Nginx or Traefik");
  this ADR is specifically about the *local* reverse proxy, where the developer
  experience favours Traefik.

### Caddy

Modern reverse proxy with automatic HTTPS.

- **Strengths:** very simple config; automatic HTTPS via Let's Encrypt; good
  WebSocket support.
- **Rejected because** its automatic HTTPS is designed for public domains (Let's
  Encrypt), not local `.test` domains with a private CA. For local development with
  mkcert, Caddy's automatic HTTPS is not an advantage and its local-CA integration is
  less straightforward than Traefik's explicit TLS store. Caddy's Docker provider and
  label-based discovery are less mature than Traefik's. Caddy is an excellent choice
  for public-facing deployments; for the local Docker Compose stack, Traefik's
  label-driven, Docker-native routing is a better fit.
