# ЧтоХочу API — production deployment

Target server: `deploy@195.226.194.165` (Debian 13, 4 vCPU / 7.8 GB / 59 GB).
Shares the host with the `anonapp` stack and a **global Traefik** instance
(network `proxy`, certresolver `letsencrypt`, entrypoint `websecure`).

Only the API is deployed here: `postgres`, `redis`, `app`, `queue`,
`scheduler`, `reverb`. Nuxt apps and the Flutter web build deploy elsewhere.

## Files

| File | Purpose |
|------|---------|
| `Dockerfile.prod` | Production image → `ghcr.io/ruwebdev/chtohochu-api:<tag>` |
| `entrypoint.prod.sh` | Runtime prepare, gated migrations, nginx+php-fpm |
| `docker-compose.prod.yml` | Server-side compose stack |
| `.env.production.example` | Template for `/srv/chtohochu/.env` |

## One-time server bootstrap

```bash
ssh deploy@195.226.194.165

sudo mkdir -p /srv/chtohochu
sudo chown deploy:deploy /srv/chtohochu

# upload compose + env
scp infrastructure/docker/docker-compose.prod.yml deploy@195.226.194.165:/srv/chtohochu/compose.yaml
scp infrastructure/docker/.env.production.example deploy@195.226.194.165:/srv/chtohochu/.env

# edit .env on the server: APP_KEY, DB_PASSWORD, REDIS_PASSWORD,
# REVERB_APP_KEY/SECRET, MAIL_*, VK_*, YANDEX_*
```

Generate `APP_KEY` locally:

```bash
cd backend/api && php artisan key:generate --show
```

DNS: `api.chtohochu.ru` must be an A-record → `195.226.194.165` **before**
the first `up`, otherwise Let's Encrypt cannot issue the certificate.

## Deploy

```bash
# on the server
cd /srv/chtohochu
docker compose pull            # pull ghcr.io/ruwebdev/chtohochu-api:$TAG
docker compose up -d           # app runs migrations via RUN_MIGRATIONS=1
docker compose ps              # all containers healthy
docker compose logs -f app     # watch startup / migrations
```

Image build (CI / GitHub Actions):

```bash
docker build -f infrastructure/docker/Dockerfile.prod \
  -t ghcr.io/ruwebdev/chtohochu-api:$(git rev-parse --short HEAD) .
docker push ghcr.io/ruwebdev/chtohochu-api:$(git rev-parse --short HEAD)
```

## Verify

```bash
curl -fsS https://api.chtohochu.ru/up              # Laravel health
curl -fsS https://api.chtohochu.ru/api/v1/health   # app health route
```

## Rollback

```bash
TAG=<previous-tag> docker compose up -d
```

Migrations are expected to be additive; destructive ones require a restore
from backup (see `docs/50-infrastructure/deployment.md` §10).

## Notes / constraints

* The host also runs the `anonapp` stack — every service has `mem_limit`.
  Do not raise limits without checking `free -m` first.
* PostgreSQL is tuned for a small VPS (`shared_buffers=128MB`), not the
  values in `deployment.md` §4.1 (those assume a dedicated DB host).
* Route caching is intentionally skipped in the entrypoint: `routes/api.php`
  contains a closure (`/api/v1/health`). If routes become closure-free,
  `php artisan route:cache` can be added there.
* Backups: daily `pg_dump` at 03:00 via deploy-user cron →
  `/srv/chtohochu/backups/chtohochu_YYYYMMDD.sql.gz`, 30-day retention.
