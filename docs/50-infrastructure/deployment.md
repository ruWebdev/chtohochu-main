# Deployment Guide

> **Status:** Authoritative deployment guide for all environments.
> Covers Docker-based deployment, reverse proxy, database, Redis, Reverb, Horizon, health checks, and rollback.

## 1. Architecture Overview

```text
                    ┌──────────────────────────┐
                    │       Nginx / Traefik     │
                    │   (HTTPS, reverse proxy)  │
                    └─────────────┬────────────┘
                                  │
          ┌───────────┬───────────┼───────────┬──────────────┐
          │           │           │           │              │
     ┌────▼────┐ ┌────▼────┐ ┌────▼────┐ ┌────▼─────┐ ┌──────▼──────┐
     │ Public  │ │  User   │ │ Seller  │ │  Admin   │ │   Backend   │
     │  Web    │ │  Web    │ │ Cabinet │ │ Backoffice│ │  (Laravel)  │
     │ (Nuxt)  │ │ (Flutter│ │ (Nuxt)  │ │ (Nuxt)   │ │ API+Horizon │
     │  SSR    │ │  web)   │ │  SPA    │ │   SPA    │ │ +Reverb     │
     └─────────┘ └─────────┘ └─────────┘ └──────────┘ └──────┬──────┘
                                                              │
                                              ┌───────────────┼───────────────┐
                                              │               │               │
                                         ┌────▼────┐   ┌─────▼────┐   ┌─────▼─────┐
                                         │PostgreSQL│   │  Redis   │   │    S3     │
                                         │         │   │          │   │ (storage) │
                                         └─────────┘   └──────────┘   └───────────┘
```

## 2. Docker-Based Deployment

### 2.1 Container images

Each application is packaged as a Docker image.

| Service | Image | Base |
|---------|-------|------|
| Backend | `chtohochu/backend:{tag}` | `php:8.4-fpm-alpine` + Nginx (or Octane) |
| Public web | `chtohochu/public-web:{tag}` | `node:22-alpine` (Nitro server) |
| Seller | `chtohochu/seller:{tag}` | Static files (Nginx) |
| Admin | `chtohochu/admin:{tag}` | Static files (Nginx) |
| User web | `chtohochu/user-web:{tag}` | Static files (Nginx) |

### 2.2 Docker Compose (production)

```yaml
# infrastructure/docker/docker-compose.prod.yml
services:
  backend:
    image: chtohochu/backend:${TAG}
    restart: unless-stopped
    environment:
      APP_ENV: production
      APP_KEY: ${APP_KEY}
      DB_HOST: postgres
      DB_DATABASE: ${DB_DATABASE}
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: redis
      REDIS_PASSWORD: ${REDIS_PASSWORD}
      REVERB_APP_ID: ${REVERB_APP_ID}
      REVERB_APP_KEY: ${REVERB_APP_KEY}
      REVERB_APP_SECRET: ${REVERB_APP_SECRET}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 1G

  horizon:
    image: chtohochu/backend:${TAG}
    restart: unless-stopped
    command: php artisan horizon
    environment:
      # same as backend
    depends_on:
      - postgres
      - redis

  reverb:
    image: chtohochu/backend:${TAG}
    restart: unless-stopped
    command: php artisan reverb:start --host=0.0.0.0 --port=8080
    environment:
      # same as backend
    depends_on:
      - redis

  scheduler:
    image: chtohochu/backend:${TAG}
    restart: unless-stopped
    command: php artisan schedule:work
    environment:
      # same as backend
    depends_on:
      - postgres
      - redis

  public-web:
    image: chtohochu/public-web:${TAG}
    restart: unless-stopped
    environment:
      NUXT_PUBLIC_API_BASE_URL: https://api.chtohochu.ru/api/v1
      NUXT_PUBLIC_USER_WEB_URL: https://app.chtohochu.ru
      NUXT_SERVER_API_INTERNAL_BASE_URL: http://backend:8000/api/v1
    depends_on:
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  seller:
    image: chtohochu/seller:${TAG}
    restart: unless-stopped

  admin:
    image: chtohochu/admin:${TAG}
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_DATABASE}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:
```

### 2.3 Image build

```dockerfile
# backend/api/Dockerfile
FROM php:8.4-fpm-alpine AS base

RUN apk add --no-cache \
    postgresql-dev libzip-dev libpng-dev libjpeg-turbo-dev freetype-dev \
    && docker-php-ext-configure pgsql --with-pgsql=/usr/local/include \
    && docker-php-ext-install pdo pdo_pgsql pgsql zip gd bcmath opcache

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction

COPY . .
RUN php artisan optimize && php artisan config:cache && php artisan route:cache

# Health check
RUN apk add --no-cache curl
HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:8000/api/health || exit 1

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
```

## 3. Nginx / Traefik Configuration

### 3.1 Nginx (reverse proxy)

```nginx
# /etc/nginx/sites-available/chtohochu.conf

# Upstreams
upstream backend {
    server backend:8000;
}
upstream public_web {
    server public-web:3000;
}
upstream reverb {
    server reverb:8080;
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name chtohochu.ru www.chtohochu.ru api.chtohochu.ru app.chtohochu.ru
               seller.chtohochu.ru admin.chtohochu.ru;
    return 301 https://$host$request_uri;
}

# Main site (public web)
server {
    listen 443 ssl http2;
    server_name chtohochu.ru www.chtohochu.ru;

    ssl_certificate /etc/letsencrypt/live/chtohochu.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chtohochu.ru/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://public_web;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# API
server {
    listen 443 ssl http2;
    server_name api.chtohochu.ru;

    ssl_certificate /etc/letsencrypt/live/api.chtohochu.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.chtohochu.ru/privkey.pem;

    client_max_body_size 10M;

    # API
    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket (Reverb)
    location /app/ {
        proxy_pass http://reverb;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }

    # Health check
    location /health {
        proxy_pass http://backend/api/health;
    }
}

# User web (Flutter) — static files
server {
    listen 443 ssl http2;
    server_name app.chtohochu.ru;

    ssl_certificate /etc/letsencrypt/live/app.chtohochu.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.chtohochu.ru/privkey.pem;

    root /var/www/user-web;
    index index.html;

    # SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # COOP/COEP headers for Flutter CanvasKit SharedArrayBuffer
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
}

# Seller cabinet — static files
server {
    listen 443 ssl http2;
    server_name seller.chtohochu.ru;

    ssl_certificate /etc/letsencrypt/live/seller.chtohochu.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/seller.chtohochu.ru/privkey.pem;

    root /var/www/seller;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}

# Admin backoffice — static files + IP restriction
server {
    listen 443 ssl http2;
    server_name admin.chtohochu.ru;

    ssl_certificate /etc/letsencrypt/live/admin.chtohochu.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.chtohochu.ru/privkey.pem;

    # IP allowlist
    allow 10.0.0.0/8;       # VPN/internal
    allow 203.0.113.0/24;   # office IP range
    deny all;

    root /var/www/admin;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 3.2 Traefik (alternative)

```yaml
# infrastructure/docker/traefik.yml
traefik:
  image: traefik:v3
  command:
    - --providers.docker=true
    - --providers.docker.exposedbydefault=false
    - --entrypoints.web.address=:80
    - --entrypoints.websecure.address=:443
    - --certificatesresolvers.le.acme.tlschallenge=true
    - --certificatesresolvers.le.acme.email=dev@chtohochu.ru
    - --certificatesresolvers.le.acme.storage=/letsencrypt/acme.json
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - letsencrypt:/letsencrypt
```

Traefik labels on backend service:

```yaml
backend:
  labels:
    - traefik.enable=true
    - traefik.http.routers.api.rule=Host(`api.chtohochu.ru`)
    - traefik.http.routers.api.tls.certresolver=le
    - traefik.http.routers.api.middlewares=rate-limit@docker
    - traefik.http.services.api.loadbalancer.server.port=8000
```

## 4. PostgreSQL Setup

### 4.1 Production configuration

```sql
-- postgresql.conf key settings
shared_buffers = 2GB              # 25% of RAM
effective_cache_size = 6GB        # 75% of RAM
maintenance_work_mem = 512MB
work_mem = 16MB
max_connections = 200
checkpoint_completion_target = 0.9
wal_buffers = 16MB
random_page_cost = 1.1            # SSD
effective_io_concurrency = 200    # SSD
```

### 4.2 Database creation

```sql
CREATE DATABASE chtohochu;
CREATE USER chtohochu_app WITH PASSWORD 'strong-random-password';
GRANT ALL PRIVILEGES ON DATABASE chtohochu TO chtohochu_app;

-- Read-only user for analytics (optional)
CREATE USER chtohochu_ro WITH PASSWORD 'strong-random-password';
GRANT CONNECT ON DATABASE chtohochu TO chtohochu_ro;
```

### 4.3 Backup

| Type | Schedule | Retention |
|------|----------|-----------|
| Full `pg_dump` | Daily at 02:00 | 30 days |
| WAL archiving | Continuous | 7 days (PITR) |
| Base backup (pg_basebackup) | Weekly | 4 weeks |

```bash
# Daily backup script
pg_dump -U chtohochu_app -h localhost chtohochu | gzip > /backups/chtohochu_$(date +%Y%m%d).sql.gz
```

### 4.4 Connection pooling (PgBouncer)

For high-traffic deployments, use PgBouncer:

```ini
# pgbouncer.ini
[databases]
chtohochu = host=postgres dbname=chtohochu

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
```

## 5. Redis Setup

### 5.1 Configuration

```conf
# redis.conf
requirepass strong-random-password
maxmemory 1gb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
```

### 5.2 Usage

| Purpose | DB index |
|---------|----------|
| Queue (Horizon) | 0 |
| Cache | 1 |
| Reverb | 2 |
| Rate limiting | 3 |

### 5.3 Persistence

Redis is used for non-authoritative data. If Redis loses data:

* Queues: jobs may be lost — ensure critical jobs are idempotent and re-queueable.
* Cache: cache rebuilds from PostgreSQL.
* Reverb: clients reconnect and re-subscribe.
* Rate limits: reset — acceptable.

## 6. Reverb WebSocket Server

### 6.1 Configuration

```env
REVERB_HOST=0.0.0.0
REVERB_PORT=8080
REVERB_SCHEME=https
REVERB_APP_ID=chtohochu-prod
REVERB_APP_KEY=${REVERB_APP_KEY}
REVERB_APP_SECRET=${REVERB_APP_SECRET}
REVERB_ALLOWED_ORIGINS=https://app.chtohochu.ru,https://chtohochu.ru
```

### 6.2 Scaling

* Reverb supports horizontal scaling via Redis pub/sub.
* Multiple Reverb instances share connection state through Redis.
* Nginx/Traefik load-balances WebSocket connections across instances.

### 6.3 Process management

Reverb runs as a long-lived process managed by the container's process manager (supervisord or Docker restart policy):

```ini
# supervisord.conf (if using supervisord inside container)
[program:reverb]
command=php /var/www/artisan reverb:start --host=0.0.0.0 --port=8080
autostart=true
autorestart=true
numprocs=1
```

## 7. Horizon Queue Worker

### 7.1 Configuration

```php
// config/horizon.php
'environments' => [
    'production' => [
        'supervisor-default' => [
            'connection' => 'redis',
            'queue' => ['default', 'notifications', 'images', 'integrations'],
            'balance' => 'auto',
            'minProcesses' => 2,
            'maxProcesses' => 10,
            'tries' => 3,
            'backoff' => [10, 30, 60],
            'timeout' => 120,
            'nice' => 0,
        ],
    ],
    'staging' => [
        'supervisor-default' => [
            'minProcesses' => 1,
            'maxProcesses' => 3,
        ],
    ],
],
```

### 7.2 Queue priorities

| Queue | Purpose | Priority |
|-------|---------|----------|
| `notifications` | Push notifications, emails | High |
| `default` | General jobs | Normal |
| `images` | Image processing/resizing | Normal |
| `integrations` | External API calls | Low |

### 7.3 Deployment

Horizon is deployed as a separate container/process:

```bash
php artisan horizon:terminate  # graceful stop (finishes current jobs)
# Supervisor/Docker restarts the process with new code
```

On deployment, run `horizon:terminate` — the process manager restarts Horizon with the new code. In-flight jobs finish; queued jobs are picked up by the new instance.

## 8. Environment Configuration

### 8.1 Per-environment variables

| Variable | dev | staging | production |
|----------|-----|---------|------------|
| `APP_ENV` | local | staging | production |
| `APP_DEBUG` | true | false | false |
| `APP_URL` | http://localhost:8000 | https://api.staging.chtohochu.ru | https://api.chtohochu.ru |
| `DB_HOST` | localhost | postgres (container) | postgres (managed) |
| `REDIS_PASSWORD` | (none) | strong password | strong password |
| `QUEUE_CONNECTION` | redis | redis | redis |
| `FILESYSTEM_DISK` | local | s3 | s3 |
| `MAIL_MAILER` | log | smtp (test) | smtp (production) |
| `SENTRY_LARAVEL_DSN` | (disabled) | staging DSN | production DSN |

### 8.2 Secret injection

Secrets are injected via:

| Environment | Method |
|-------------|--------|
| dev | `.env` file (gitignored) |
| staging | Docker Compose env file / CI secrets |
| production | Docker secrets / cloud secret manager / CI deployment secrets |

Never bake secrets into Docker images. Use environment variables at runtime.

## 9. Health Checks

### 9.1 Backend health endpoint

```php
// routes/api.php
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'database' => DB::connection()->getPdo() ? 'connected' : 'disconnected',
        'redis' => Redis::ping() ? 'connected' : 'disconnected',
        'queue' => app('queue')->isDownForMaintenance() ? 'maintenance' : 'active',
        'timestamp' => now()->toISOString(),
    ]);
});
```

### 9.2 Health check matrix

| Service | Endpoint | Expected |
|---------|----------|----------|
| Backend API | `GET /api/health` | 200 + `{"status":"ok"}` |
| Public web | `GET /api/health` (Nitro) | 200 |
| Seller | Nginx static `/index.html` | 200 |
| Admin | Nginx static `/index.html` | 200 |
| User web | Nginx static `/index.html` | 200 |
| PostgreSQL | `pg_isready` | success |
| Redis | `redis-cli ping` | `PONG` |
| Reverb | WebSocket handshake | 101 Switching Protocols |
| Horizon | `GET /horizon/api/stats` | 200 + stats JSON |

### 9.3 Docker health checks

Each service defines a `healthcheck` in `docker-compose`. Docker marks unhealthy containers and orchestrators (if used) restart them.

### 9.4 External monitoring

* Uptime monitoring (e.g. UptimeRobot, Better Stack) pings health endpoints every 60s.
* Alerting on 3 consecutive failures.
* Sentry for error tracking (backend + web apps).
* Horizon dashboard for queue health.

## 10. Rollback Strategy

### 10.1 Backend rollback

```text
1. Identify the previous stable image tag
2. Deploy previous image: docker compose up -d backend (with old tag)
3. If migrations ran, assess backward compatibility:
   a. If migrations are backward-compatible: no action needed
   b. If migrations are destructive: restore database from backup (PITR)
4. Run horizon:terminate to restart queue workers with old code
5. Verify health checks pass
6. Verify critical API endpoints respond correctly
```

### 10.2 Web app rollback

```text
1. Deploy previous static build / image
2. Invalidate CDN cache
3. Verify pages load
```

### 10.3 Database rollback

| Scenario | Action |
|----------|--------|
| Backward-compatible migration | No rollback needed — old code works with new schema |
| Additive migration (new column/table) | No rollback needed |
| Destructive migration (dropped column) | Restore from backup (PITR to before migration) |
| Failed migration (partial) | `php artisan migrate:rollback` to revert the batch |

### 10.4 Rollback decision matrix

| Symptom | First action | Escalation |
|---------|-------------|------------|
| Health check fails after deploy | Wait 60s (startup time), recheck | Rollback if still failing after 2 min |
| Elevated error rate (>5%) | Check Sentry for new errors | Rollback if caused by new code |
| Database migration failure | `migrate:rollback` | Restore from backup if rollback fails |
| Queue backlog growing | Check Horizon dashboard | Scale workers or rollback |
| WebSocket connections dropping | Check Reverb logs | Restart Reverb or rollback |

### 10.5 Blue/green deployment (recommended for production)

```text
1. Deploy new version to "green" environment (parallel to "blue")
2. Run health checks against green
3. If healthy: switch traffic from blue → green (Nginx upstream change or Traefik label)
4. Monitor for 10 minutes
5. If issues: switch traffic back to blue (instant rollback)
6. If stable: decommission blue (or keep as next rollback target)
```

## 11. Deployment Checklist

Pre-deployment:
- [ ] All CI checks pass on the release tag
- [ ] Migrations tested on staging
- [ ] Release notes / changelog prepared
- [ ] Database backup taken
- [ ] Maintenance window announced (if needed)

During deployment:
- [ ] Pull new images
- [ ] Run migrations (`php artisan migrate --force`)
- [ ] Restart Horizon (`php artisan horizon:terminate`)
- [ ] Restart Reverb
- [ ] Clear and warm cache (`php artisan optimize`)
- [ ] Verify health checks pass
- [ ] Verify critical user flows (login, create wishlist, share)

Post-deployment:
- [ ] Monitor error rate for 30 minutes
- [ ] Monitor queue depth
- [ ] Monitor WebSocket connection count
- [ ] Confirm Sentry shows no new error spikes
- [ ] Tag the release in Git (`git tag v1.2.3`)
