# Local Routing with Traefik — ЧтоХочу

> **Status:** Authoritative guide for local domain routing. See
> [`docker.md`](./docker.md) and [`local-https.md`](./local-https.md) for companion
> topics.

## 1. Overview

Local development uses **Traefik** as the reverse proxy. All applications and backend
services are reached through `*.chtohochu.test` domains that Traefik routes to the
appropriate container by Host header. This mirrors production routing and lets each
app run on its own hostname with HTTPS from the start.

Benefits over per-app `localhost:PORT` access:

- Each app gets a stable, memorable hostname.
- Cookies are scoped to the right domain (no cross-app cookie leakage).
- HTTPS works locally (required for secure cookies, OAuth, WebSockets, service
  workers — see [`local-https.md`](./local-https.md)).
- The routing topology matches production, so edge cases surface locally.

## 2. Local Domains

| Hostname | Routes to | Purpose |
|----------|-----------|---------|
| `api.chtohochu.test` | `app` (Laravel) | REST API + Inertia |
| `lk.chtohochu.test` | `app` (Laravel, Inertia) | Public-web authenticated cabinet |
| `chtohochu.test` | `public-web` (Nuxt SSR) | Marketing, SEO, public pages |
| `seller.chtohochu.test` | `seller` (Nuxt SPA) | Seller cabinet |
| `admin.chtohochu.test` | `admin` (Nuxt SPA) | Admin backoffice |
| `ws.chtohochu.test` | `reverb` | WebSocket (WSS) |
| `mail.chtohochu.test` | `mail` (Mailpit) | Mail catcher web UI |
| `horizon.chtohochu.test` | `app` (`/horizon`) | Horizon dashboard (dev only) |
| `telescope.chtohochu.test` | `app` (`/telescope`) | Telescope dashboard (dev only) |

## 3. `/etc/hosts` Configuration

The `.test` TLD is reserved for testing and is not routed by public DNS. Each
developer must add the local domains to `/etc/hosts`:

```bash
sudo tee -a /etc/hosts <<'EOF'
127.0.0.1 chtohochu.test
127.0.0.1 api.chtohochu.test
127.0.0.1 lk.chtohochu.test
127.0.0.1 seller.chtohochu.test
127.0.0.1 admin.chtohochu.test
127.0.0.1 ws.chtohochu.test
127.0.0.1 mail.chtohochu.test
127.0.0.1 horizon.chtohochu.test
127.0.0.1 telescope.chtohochu.test
EOF
```

Run `make hosts` to print the exact block to append. After editing `/etc/hosts`, no
restart is required; resolution is immediate.

> **Alternative:** `dnsmasq` can wildcard-resolve `*.chtohochu.test` to 127.0.0.1 so
> new subdomains do not require editing `/etc/hosts`. This is optional and not
> required for the standard setup.

## 4. Traefik Routing Rules

Traefik routes by Host header (and, for WebSockets, by upgrade headers). Each
container is labelled in `docker-compose.yml` with Traefik rules.

### 4.1 HTTP routers

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`api.chtohochu.test`) || Host(`lk.chtohochu.test`)"
  - "traefik.http.routers.app.entrypoints=websecure"
  - "traefik.http.routers.app.tls=true"
  - "traefik.http.services.app.loadbalancer.server.port=9000"
```

### 4.2 WebSocket router

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.reverb.rule=Host(`ws.chtohochu.test`)"
  - "traefik.http.routers.reverb.entrypoints=websecure"
  - "traefik.http.routers.reverb.tls=true"
  - "traefik.http.routers.reverb.service=reverb"
  - "traefik.http.services.reverb.loadbalancer.server.port=8080"
```

Traefik handles WebSocket upgrades automatically; no special middleware is required
beyond the TLS entrypoint.

### 4.3 Path-based routing (Horizon / Telescope)

Horizon and Telescope are path prefixes on the `app` container. They are routed either
by a dedicated host (`horizon.chtohochu.test`) or by a path rule on
`api.chtohochu.test`:

```yaml
- "traefik.http.routers.horizon.rule=Host(`horizon.chtohochu.test`)"
- "traefik.http.routers.horizon.middlewares=horizon-stripprefix"
- "traefik.http.middlewares.horizon-stripprefix.stripprefix.prefixes=/horizon"
```

These dashboards are dev-only and must not be exposed in production.

## 5. Entrypoints

Traefik listens on two entrypoints:

| Entrypoint | Port | Protocol | Purpose |
|------------|------|----------|---------|
| `web` | 80 | HTTP | Redirects to `websecure` |
| `websecure` | 443 | HTTPS | All application traffic, including WSS |

All HTTP traffic on port 80 is redirected to HTTPS on port 443. There is no
plaintext-only application traffic. This forces clients to use HTTPS locally, matching
production and satisfying the requirements in [`local-https.md`](./local-https.md).

## 6. WebSocket Support

WebSocket connections use the `wss://` scheme and are routed to the Reverb container
via `ws.chtohochu.test`. Traefik terminates TLS and forwards the upgraded connection.

Client connection URLs:

```
wss://ws.chtohochu.test/app/<REVERB_APP_KEY>
```

Traefik automatically handles the `Upgrade: websocket` and `Connection: Upgrade`
headers. No sticky-session middleware is required for a single Reverb instance; for
multiple instances, the Redis pub/sub adapter (see
[`realtime.md`](../20-backend/realtime.md)) fans out broadcasts.

## 7. Verifying Routing

```bash
# DNS resolution
ping api.chtohochu.test

# HTTP (should redirect to HTTPS)
curl -I http://chtohochu.test

# HTTPS
curl -I https://api.chtohochu.test/api/v1/health

# WebSocket
curl -I https://ws.chtohochu.test
```

If a host does not resolve, check `/etc/hosts`. If Traefik returns 404, check the
container labels and that the target container is healthy (`make logs-svc=traefik`).

## 8. Non-Goals

- No wildcard DNS via a public resolver. `.test` is local only.
- No exposure of PostgreSQL or Redis through Traefik; they are internal-only.
- No production routing configuration; this is local development only. Production
  routing is described in [`deployment.md`](../50-infrastructure/deployment.md).
