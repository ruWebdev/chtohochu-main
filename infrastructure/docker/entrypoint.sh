#!/bin/sh
# =============================================================================
# ЧтоХочу — Laravel container entrypoint
# =============================================================================
# Handles two modes:
#   1. "start" (default) — prepare app, run migrations, start PHP-FPM + Nginx
#   2. Any other command — exec it directly (queue:work, reverb:start, etc.)
# =============================================================================

set -e

# If a custom command is passed (queue:work, reverb:start, schedule:run, etc.),
# execute it directly without starting the web server.
if [ "$1" != "start" ]; then
    exec "$@"
fi

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

echo "=== Clearing caches ==="
php artisan optimize:clear || true

echo "=== Running database migrations ==="
php artisan migrate --force || true

echo "=== Starting PHP-FPM (background) ==="
php-fpm -D

echo "=== Starting Nginx (foreground) ==="
# Graceful shutdown: forward signals to nginx
trap 'nginx -s quit; wait' TERM INT
exec nginx -g 'daemon off;'
