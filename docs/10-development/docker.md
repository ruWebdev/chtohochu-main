# Docker Local Development — ЧтоХочу

> **Status:** Authoritative guide for the Docker-based local development environment.
> See [`local-routing.md`](./local-routing.md), [`local-https.md`](./local-https.md),
> and [`environments.md`](./environments.md) for companion topics.

## 1. Overview

The project ships a Docker Compose stack that reproduces the full local environment:
reverse proxy, database, cache, realtime server, application, workers, scheduler, and
a mail catcher. The stack is the canonical way to run the backend and web apps locally
and is the basis for the `*.chtohochu.test` routing described in
[`local-routing.md`](./local-routing.md).

Goals:

- **Reproducible.** Every developer runs the same service versions.
- **Isolated.** No native PostgreSQL/Redis/mail server conflicts with the host.
- **One command.** `make up` brings the whole stack up.
- **Production-like.** Traefik routing, TLS, and service topology mirror production.

## 2. Services

| Service | Container | Port(s) | Purpose |
|---------|-----------|---------|---------|
| Traefik | `traefik` | 80, 443 | Reverse proxy, TLS termination, routing |
| PostgreSQL | `postgres` | 5432 | Authoritative database |
| Redis | `redis` | 6379 | Cache, queues, locks, Reverb adapter |
| Laravel app | `app` | 9000 (internal) | API, Inertia, Horizon dashboard |
| Queue worker | `worker` | — | Horizon worker for async jobs |
| Scheduler | `scheduler` | — | `php artisan schedule:work` |
| Reverb | `reverb` | 8080 | WebSocket server |
| Mail catcher | `mail` | 8025 (web), 1025 (SMTP) | Intercepts outbound mail |

### 2.1 Service responsibilities

- **Traefik** is the single entry point. All `*.chtohochu.test` traffic flows through
  Traefik, which routes to the appropriate container by Host header. See
  [`local-routing.md`](./local-routing.md).
- **PostgreSQL** stores all authoritative business state. Its data volume is persisted
  across restarts.
- **Redis** is infrastructure only: cache, queue backend, rate-limit counters, locks,
  and the Reverb pub/sub adapter. Redis holds no authoritative business state.
- **Laravel app** serves the API (`/api/v1/`), Inertia pages, and the Horizon
  dashboard. It runs PHP-FPM; Traefik forwards HTTP to it.
- **Queue worker** runs Horizon and processes jobs: push notifications, email, image
  processing, broadcast dispatch.
- **Scheduler** runs the Laravel scheduler (`schedule:work`) which dispatches scheduled
  jobs and commands onto the queue.
- **Reverb** is the WebSocket server. Traefik forwards WebSocket upgrades to it.
- **Mail catcher** (e.g. Mailpit) intercepts all outbound SMTP so development mail is
  never delivered to real addresses. Its web UI is available at `mail.chtohochu.test`.

## 3. Health Checks

Each service defines a Docker healthcheck so dependent services can wait for readiness.

| Service | Healthcheck |
|---------|-------------|
| PostgreSQL | `pg_isready -U ${DB_USERNAME}` |
| Redis | `redis-cli ping` |
| Laravel app | `curl -fsS http://localhost/health` (or `php artisan db:monitor`) |
| Reverb | TCP probe on port 8080 |
| Mail catcher | HTTP probe on the web UI port |

The `app` service waits for `postgres` and `redis` to be healthy before starting
PHP-FPM. The `worker` and `scheduler` services wait for `app` to be healthy.

## 4. Startup Order

```text
postgres ─┐
          ├─► app (PHP-FPM) ─┬─► worker (Horizon)
redis ────┘                   ├─► scheduler
                              └─► reverb
traefik (independent) ────────► routes to app / reverb / mail
```

Docker Compose `depends_on` with `condition: service_healthy` enforces the order. The
`app` service runs migrations on first start (or via an entrypoint hook) before
accepting traffic.

## 5. Volumes

| Volume | Mounted in | Purpose |
|--------|-----------|---------|
| `postgres-data` | `postgres` | Persistent database files |
| `redis-data` | `redis` | AOF persistence (optional) |
| `app-storage` | `app`, `worker` | Laravel `storage/` (logs, uploads, framework cache) |
| `./../backend` | `app`, `worker`, `scheduler` | Source code (bind mount for live reload) |
| `./../apps` | web containers (if containerized) | Source code bind mount |
| `certs` | `traefik` | mkcert-generated TLS certificates |

Bind mounts of the source tree enable live reload during development without
rebuilding images.

## 6. Networks

| Network | Members | Purpose |
|---------|---------|---------|
| `chtohochu` (internal) | all app services | Service-to-service communication |
| `traefik` (external) | `traefik`, `app`, `reverb`, `mail` | Proxy-to-backend routing |

PostgreSQL and Redis are **not** published to the host by default; they are reachable
only on the internal network. If a developer needs a host port (e.g. for a GUI client),
the port can be exposed via an override file. Exposing database ports to the host is a
local convenience, not a production pattern.

## 7. Make Commands

A `Makefile` at the repository root wraps common Docker Compose operations.

| Command | Action |
|---------|--------|
| `make up` | Start the full stack in detached mode |
| `make down` | Stop and remove containers (keep volumes) |
| `make restart` | Restart all services |
| `make rebuild` | Rebuild images after dependency changes |
| `make logs` | Tail logs for all services |
| `make logs-svc=app` | Tail logs for a specific service |
| `make shell` | Shell into the `app` container |
| `make shell-svc=worker` | Shell into a specific service |
| `make migrate` | Run `php artisan migrate` in the `app` container |
| `make fresh-seed` | `migrate:fresh --seed` (destructive reset) |
| `make test` | Run `php artisan test` in the `app` container |
| `make horizon` | Open the Horizon dashboard URL |
| `make mail` | Open the mail catcher web UI |
| `make certs` | Generate local TLS certs with mkcert (see [`local-https.md`](./local-https.md)) |
| `make hosts` | Print the `/etc/hosts` entries to add (see [`local-routing.md`](./local-routing.md)) |

## 8. Common Operations

### 8.1 Start the stack

```bash
make up
make migrate          # first run only, or after pulling new migrations
make fresh-seed       # optional: reset and reseed development data
```

### 8.2 Inspect logs

```bash
make logs
make logs-svc=app
make logs-svc=worker
docker compose logs -f traefik
```

### 8.3 Shell into a container

```bash
make shell                      # app container
make shell-svc=worker           # worker container
docker compose exec postgres psql -U chtohochu
docker compose exec redis redis-cli
```

### 8.4 Rebuild after dependency changes

```bash
make rebuild
make up
```

### 8.5 Full reset

```bash
make down                        # keep volumes
# or, to wipe data:
docker compose down -v
make up
make migrate
make fresh-seed
```

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `*.chtohochu.test` does not resolve | Missing `/etc/hosts` entries | Run `make hosts` and add the output to `/etc/hosts` (see [`local-routing.md`](./local-routing.md)) |
| TLS warning in browser | mkcert CA not trusted | See [`local-https.md`](./local-https.md) |
| `app` container exits on start | PostgreSQL not ready / missing `.env` | Check `make logs-svc=postgres`; ensure `.env` exists |
| 502 from Traefik | `app` not healthy | `make logs-svc=app`; wait for healthcheck |
| WebSocket fails to connect | Reverb not running or TLS mismatch | `make logs-svc=reverb`; ensure WSS URL matches cert (see [`local-https.md`](./local-https.md)) |
| Port already in use | Host service on 80/443 | Stop host service or change Traefik ports in override |

## 10. Non-Goals

- Docker Compose is a **local development** tool. It is not the production deployment
  topology. See [`deployment.md`](../50-infrastructure/deployment.md).
- The stack does not include Kubernetes, Elasticsearch, or Kafka (forbidden without an
  approved ADR per AGENTS.md §16).
