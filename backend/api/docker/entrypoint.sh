#!/bin/sh
set -e

# Если передана кастомная команда (queue:work, reverb:start и т.д.) — выполняем её
if [ "$1" != "start" ]; then
    exec "$@"
fi

# Режим start: запускаем nginx + PHP-FPM с подготовкой приложения

echo "=== Подготовка storage ==="
mkdir -p storage/logs storage/framework/cache storage/framework/sessions storage/framework/views storage/app/public storage/app/private
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

echo "=== Очистка кешей ==="
php artisan optimize:clear || true

echo "=== Кеширование конфигурации ==="
php artisan config:cache || true

echo "=== Кеширование маршрутов ==="
php artisan route:cache || true

echo "=== Кеширование представлений ==="
php artisan view:cache || true

echo "=== Миграции базы данных ==="
php artisan migrate --force || true

echo "=== Создание symlink для public/storage ==="
php artisan storage:link || true

echo "=== Запуск PHP-FPM в фоне ==="
php-fpm -D

echo "=== Запуск nginx (на переднем плане) ==="
exec nginx -g 'daemon off;'
