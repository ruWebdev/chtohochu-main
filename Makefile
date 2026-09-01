# =============================================================================
# ЧтоХочу — Makefile
# =============================================================================
# Convenience commands for local development with Docker.
# All Docker Compose commands target infrastructure/docker/docker-compose.yml.
# =============================================================================

COMPOSE      := docker compose
COMPOSE_FILE := infrastructure/docker/docker-compose.yml
COMPOSE_CMD  := $(COMPOSE) -f $(COMPOSE_FILE) --env-file infrastructure/docker/.env
APP_SERVICE  := app
PHP          := $(COMPOSE_CMD) exec $(APP_SERVICE) php
ARTISAN      := $(PHP) artisan

.PHONY: up down restart logs ps shell migrate seed fresh test reverb build certs help

# ---------------------------------------------------------------------------
# Docker lifecycle
# ---------------------------------------------------------------------------
up: ## Start all Docker services (build if needed)
	$(COMPOSE_CMD) up -d --build

down: ## Stop all Docker services
	$(COMPOSE_CMD) down

restart: ## Restart all Docker services
	$(COMPOSE_CMD) restart

logs: ## Tail logs for all services (Ctrl-C to exit)
	$(COMPOSE_CMD) logs -f --tail=100

ps: ## Show container status
	$(COMPOSE_CMD) ps

build: ## Build (or rebuild) all images
	$(COMPOSE_CMD) build

# ---------------------------------------------------------------------------
# Laravel commands
# ---------------------------------------------------------------------------
shell: ## Shell into the Laravel container
	$(COMPOSE_CMD) exec $(APP_SERVICE) sh

migrate: ## Run database migrations
	$(ARTISAN) migrate --force

seed: ## Run database seeders
	$(ARTISAN) db:seed

fresh: ## migrate:fresh --seed (wipes and re-seeds database)
	$(ARTISAN) migrate:fresh --seed --force

test: ## Run the Laravel test suite
	$(ARTISAN) test

# ---------------------------------------------------------------------------
# Reverb (local, outside Docker)
# ---------------------------------------------------------------------------
reverb: ## Start Reverb WebSocket server locally (outside Docker)
	cd backend/api && php artisan reverb:start --host=127.0.0.1 --port=8080

# ---------------------------------------------------------------------------
# Local HTTPS certificates (mkcert)
# ---------------------------------------------------------------------------
certs: ## Generate local TLS certificates with mkcert (requires mkcert installed)
	@command -v mkcert >/dev/null 2>&1 || { \
		echo "ERROR: mkcert is not installed."; \
		echo "  macOS:  brew install mkcert"; \
		echo "  Linux:  see https://github.com/FiloSottile/mkcert#installation"; \
		exit 1; \
	}
	@mkdir -p infrastructure/docker/traefik/certs
	mkcert -install
	mkcert -cert-file infrastructure/docker/traefik/certs/chtohochu.test.pem \
	       -key-file  infrastructure/docker/traefik/certs/chtohochu.test-key.pem \
	       "*.chtohochu.test" chtohochu.test
	@echo ""
	@echo "Certificates generated in infrastructure/docker/traefik/certs/"
	@echo "Restart Traefik: make restart"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
