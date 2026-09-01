# Infrastructure

This directory contains deployment and infrastructure configuration for the ЧтоХочу platform.

## Structure

```
infrastructure/
├── docker/           # Dockerfiles for each service
├── docker-compose.yml # Development and production compose files
├── nginx/            # Nginx configuration
└── ...
```

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| api | PHP 8.3+FPM | Laravel API |
| web | Node 22 | Nuxt public-web (SSR) |
| seller | Node 22 | Nuxt seller (SPA) |
| admin | Node 22 | Nuxt admin (SPA) |
| postgres | PostgreSQL 16 | Primary database |
| redis | Redis 7 | Cache, queues, Reverb |
| reverb | PHP 8.3+ | WebSocket server |
| horizon | PHP 8.3+ | Queue worker |
| nginx | Nginx | Reverse proxy |

## Status

Infrastructure configuration is not yet created. See `docs/10-development/deployment.md` for the planned deployment architecture.
