# Local Development Infrastructure — ЧтоХочу

> **Status:** Authoritative infrastructure overview for local development. See
> [`docker.md`](../10-development/docker.md), [`local-routing.md`](../10-development/local-routing.md),
> and [`local-https.md`](../10-development/local-https.md) for detailed companion
> guides.

## 1. Overview

Local development infrastructure is provided by a **Docker Compose** stack that runs
the full service topology: reverse proxy, database, cache, realtime server,
application, workers, scheduler, and a mail catcher. The stack is the canonical local
environment and mirrors production routing and TLS.

## 2. Service Topology

```text
                    ┌──────────┐
                    │  Traefik │  :80 → :443 (TLS)
                    └────┬─────┘
          ┌──────────┬───┴────┬──────────────┐
          ▼          ▼        ▼              ▼
      ┌──────┐  ┌────────┐ ┌────────┐  ┌─────────┐
      │ app  │  │ reverb │ │  mail  │  │ web app │
      │ (PHP)│  │  (WS)  │ │(Mailpit│  │ (Nuxt)  │
      └──┬───┘  └───┬────┘ └────────┘  └─────────┘
         │          │
         │     ┌────┴────┐
         │     │  redis  │  cache, queues, locks, Reverb adapter
         │     └─────────┘
         │
    ┌────┴──────┐
    │ postgres  │  authoritative database
    └───────────┘

    worker (Horizon) ──► redis
    scheduler        ──► redis (dispatches to queues)
```

| Service | Container | Role |
|---------|-----------|------|
| Traefik | `traefik` | Reverse proxy, TLS termination, Host-based routing |
| PostgreSQL | `postgres` | Authoritative database |
| Redis | `redis` | Cache, queues, locks, rate limiting, Reverb adapter |
| Laravel app | `app` | API, Inertia, Horizon dashboard |
| Queue worker | `worker` | Horizon worker processing async jobs |
| Scheduler | `scheduler` | Laravel scheduler dispatching jobs |
| Reverb | `reverb` | WebSocket server |
| Mail catcher | `mail` | Intercepts outbound SMTP |
| Web apps | `public-web`, `seller`, `admin` | Nuxt 4 applications (if containerized) |

## 3. Traefik Routing

Traefik is the single entry point. All `*.chtohochu.test` traffic flows through
Traefik, which routes by Host header to the appropriate container. HTTP on port 80 is
redirected to HTTPS on port 443. See [`local-routing.md`](../10-development/local-routing.md).

| Hostname | Target |
|----------|--------|
| `api.chtohochu.test` | `app` |
| `lk.chtohochu.test` | `app` (Inertia) |
| `chtohochu.test` | `public-web` |
| `seller.chtohochu.test` | `seller` |
| `admin.chtohochu.test` | `admin` |
| `ws.chtohochu.test` | `reverb` |
| `mail.chtohochu.test` | `mail` |

## 4. PostgreSQL

- Image: `postgres:16`.
- Data volume: `postgres-data` (persisted across restarts).
- Not published to the host by default; reachable on the internal network.
- Healthcheck: `pg_isready`.
- Connection: configured via `DB_*` environment variables in the `app` container.

## 5. Redis

- Image: `redis:7`.
- Data volume: `redis-data` (optional AOF persistence).
- Not published to the host by default.
- Healthcheck: `redis-cli ping`.
- Used by: `app` (cache, rate limiting), `worker` (queues), `reverb` (pub/sub
  adapter).

## 6. Reverb

- Runs in its own container on port 8080.
- Routed via Traefik at `wss://ws.chtohochu.test`.
- Uses Redis as the pub/sub adapter for fan-out.
- See [`realtime.md`](../20-backend/realtime.md).

## 7. Mail Catcher

- Mailpit (or equivalent) intercepts all outbound SMTP.
- SMTP endpoint: port 1025 (internal).
- Web UI: `mail.chtohochu.test` (routed via Traefik).
- `MAIL_MAILER=smtp` / `MAIL_HOST=mail` / `MAIL_PORT=1025` in the app environment.

## 8. Start / Stop / Restart

```bash
# Start the full stack
make up

# Stop (keep volumes)
make down

# Restart all services
make restart

# Restart a single service
make restart-svc=app
```

See [`docker.md`](../10-development/docker.md) §7 for the full Make command reference.

## 9. Inspect Logs

```bash
# All services
make logs

# Specific service
make logs-svc=app
make logs-svc=worker
make logs-svc=traefik
make logs-svc=reverb

# Raw docker compose
docker compose logs -f postgres
```

## 10. Shell into Containers

```bash
# App container
make shell

# Specific service
make shell-svc=worker

# Direct docker compose
docker compose exec postgres psql -U chtohochu
docker compose exec redis redis-cli
docker compose exec app bash
```

## 11. First-Time Setup

```bash
# 1. Clone
git clone git@github.com:chtohochu/chtohochu.git
cd chtohochu

# 2. Configure /etc/hosts (see local-routing.md)
make hosts
sudo tee -a /etc/hosts < <(make hosts)

# 3. Generate local TLS certs (see local-https.md)
make certs

# 4. Start the stack
make up

# 5. Run migrations and seed
make migrate
make fresh-seed
```

## 12. Verification

- [ ] `https://api.chtohochu.test/api/v1/health` returns 200.
- [ ] `https://chtohochu.test` loads the public web.
- [ ] `https://ws.chtohochu.test` accepts WebSocket upgrades.
- [ ] `https://mail.chtohochu.test` shows the mail catcher UI.
- [ ] Horizon dashboard reachable at `https://horizon.chtohochu.test`.
- [ ] `make test` passes.

## 13. Non-Goals

- This topology is for local development only. Production deployment is described in
  [`deployment.md`](./deployment.md).
- No Kubernetes, Elasticsearch, or Kafka (forbidden without an approved ADR).
- No exposure of PostgreSQL or Redis to the public network.
