#!/bin/sh
# =============================================================================
# ЧтоХочу — Laravel production entrypoint
# =============================================================================
# Modes:
#   "start" (default) — prepare app, optionally migrate, start PHP-FPM + Nginx
#   any other command — prepare app, then exec it (queue:work, reverb:start, ...)
#
# Differences from the dev entrypoint:
#   * APP_KEY must come from the environment — it is NEVER generated here.
#   * Migrations run only when RUN_MIGRATIONS=1 (set on the `app` service only).
#   * Config/event/view caches are warmed. Route cache is skipped: routes
#     contain closures (e.g. /api/v1/health) which break route:cache.
# =============================================================================

set -e

cd /var/www/html

if [ -z "$APP_KEY" ]; then
    echo "ERROR: APP_KEY is not set. Generate one with:" >&2
    echo "  php artisan key:generate --show" >&2
    exit 1
fi

prepare_app() {
    echo "=== Preparing storage directories ==="
    mkdir -p \
        storage/logs \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/app/public \
        storage/app/private
    chown -R www-data:www-data storage bootstrap/cache
    chmod -R 775 storage bootstrap/cache

    echo "=== Creating storage symlink ==="
    php artisan storage:link || true

    echo "=== Rebuilding framework caches ==="
    php artisan config:cache
    php artisan event:cache || true
    php artisan view:cache || true

    if [ "$RUN_MIGRATIONS" = "1" ]; then
        echo "=== Running database migrations ==="
        php artisan migrate --force
    fi
}

if [ "$1" != "start" ]; then
    prepare_app
    exec "$@"
fi

prepare_app

echo "=== Starting PHP-FPM (background) ==="
php-fpm -D

echo "=== Starting Nginx (foreground) ==="
trap 'nginx -s quit; wait' TERM INT
exec nginx -g 'daemon off;'
