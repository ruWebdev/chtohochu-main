#!/bin/sh
# =============================================================================
# ЧтоХочу — Laravel container entrypoint
# =============================================================================
# Handles two modes:
#   1. "start" (default) — prepare app, run migrations, start PHP-FPM + Nginx
#   2. Any other command — prepare app, then exec it directly
# =============================================================================

set -e

# Prepare application (shared between all modes)
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

    echo "=== Checking vendor/ ==="
    if [ ! -d vendor ]; then
        echo "vendor/ not found, running composer install..."
        composer install --no-interaction --optimize-autoloader \
            || composer update --no-interaction --optimize-autoloader
    fi

    echo "=== Creating storage symlink ==="
    php artisan storage:link || true

    echo "=== Clearing caches ==="
    php artisan optimize:clear || true

    echo "=== Generating APP_KEY if missing ==="
    php artisan key:generate --force || true

    echo "=== Running database migrations ==="
    php artisan migrate --force || true
}

# If a custom command is passed (queue:work, reverb:start, schedule:run, etc.),
# prepare the app first, then execute the command.
if [ "$1" != "start" ]; then
    prepare_app
    exec "$@"
fi

# Default mode: prepare app and start web server
prepare_app

echo "=== Starting PHP-FPM (background) ==="
php-fpm -D

echo "=== Starting Nginx (foreground) ==="
# Graceful shutdown: forward signals to nginx
trap 'nginx -s quit; wait' TERM INT
exec nginx -g 'daemon off;'
