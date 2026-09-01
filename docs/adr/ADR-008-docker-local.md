# ADR-008: Docker for local infrastructure

## Status

Accepted

## Context

ЧтоХочу has a non-trivial service topology: PostgreSQL, Redis, a Laravel application,
queue workers, a scheduler, a WebSocket server (Reverb), a reverse proxy, and a mail
catcher (AGENTS.md §4). Developers need to run this stack locally to develop and test
the full system, including realtime, queues, OAuth, and HTTPS-dependent features.

The requirements for the local environment are:

- **Reproducible.** Every developer runs the same service versions and the same
  topology. "Works on my machine" is not acceptable for a multi-service system.
- **Isolated.** The local stack must not conflict with host-installed PostgreSQL,
  Redis, or web servers, and must not require the developer to install and configure
  each service natively.
- **Production-like.** The local topology should mirror production (reverse proxy,
  TLS, service separation) so that edge cases (cookies, OAuth redirects, WebSocket
  mixed-content, service workers) surface locally, not in staging.
- **One command.** Bringing the stack up and down should be a single command, not a
  runbook.

The backend is a modular monolith (§4); the local environment should not introduce
microservices or orchestration complexity disproportionate to the product.

## Decision

Use **Docker Compose** with **Traefik** as the local development infrastructure.

Docker Compose defines the full service topology in a versioned `docker-compose.yml`.
Each service runs in a container with a pinned image version. Traefik is the reverse
proxy that routes `*.chtohochu.test` domains to the appropriate container and
terminates TLS (see ADR-009 and ADR-010). Source trees are bind-mounted into the
application containers for live reload.

A `Makefile` wraps common operations (`make up`, `make down`, `make logs`, `make
shell`, `make migrate`, `make test`) so the developer experience is a single command
per action.

## Consequences

**Positive**

- **Reproducible.** Pinned image versions and a versioned compose file guarantee
  every developer runs the same stack. Onboarding is `git clone && make up`.
- **Isolated.** No host-installed PostgreSQL, Redis, or web server required. The
  stack does not conflict with the host environment.
- **Production-like.** Traefik routing and TLS mirror production, so HTTPS-dependent
  features (OAuth, secure cookies, WebSockets, service workers) work locally exactly
  as they do in production.
- **One command.** `make up` brings the full stack up; `make down` tears it down.
- **Disposable.** `docker compose down -v` resets all state for a clean start;
  `make fresh-seed` reseeds the database.

**Negative**

- **Resource overhead.** Docker on a laptop consumes CPU and memory. Developers on
  low-resource machines may feel the overhead. Mitigated by allowing infrastructure-
  only mode (`docker compose -f docker-compose.infra.yml up`) for developers who run
  applications natively.
- **Docker Desktop / engine dependency.** Developers must have Docker installed and
  configured. This is a one-time setup cost documented in the setup guide.
- **Bind-mount performance on some platforms.** File-system bind mounts can be slow
  on macOS/Windows. Mitigated by using named volumes for framework caches where
  performance matters and by documenting the trade-off.

## Alternatives considered

### Native services

Install PostgreSQL, Redis, PHP, Node, and a mail catcher directly on the host.

- **Strengths:** lowest resource overhead; no container layer.
- **Rejected because** it is not reproducible (host versions differ, configurations
  drift), it conflicts with host-installed software, it requires per-developer
  configuration runbooks for each service, and it cannot easily reproduce the
  reverse-proxy + TLS topology that production uses. HTTPS-dependent features
  (OAuth, secure cookies, WebSockets, service workers) would behave differently
  locally than in production, hiding bugs until staging. The operational and
  reproducibility cost outweighs the resource savings for a multi-service system.

### Vagrant

A virtual machine managed by Vagrant, provisioned with the same services.

- **Strengths:** reproducible; full VM isolation; works on any host OS.
- **Rejected because** a full VM is heavier than Docker containers for the same
  service set, startup is slower, and the developer experience (file syncing, port
  forwarding, networking) is more cumbersome than Docker bind mounts and Traefik
  routing. Docker Compose with Traefik gives the same reproducibility with lower
  overhead and a better inner-loop experience. Vagrant is a reasonable choice for
  teams that cannot use Docker, but Docker is available and preferred here.
