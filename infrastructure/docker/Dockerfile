# =============================================================================
# ЧтоХочу — Laravel PHP-FPM Dockerfile
# =============================================================================
# Base: PHP 8.3 FPM Alpine
# Serves Laravel via Nginx + PHP-FPM inside a single container.
# PostgreSQL is the database (NOT MySQL).
# =============================================================================

FROM php:8.3-fpm-alpine AS base

# ---------------------------------------------------------------------------
# System dependencies + PHP extension build deps
# ---------------------------------------------------------------------------
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        postgresql-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libzip-dev \
        oniguruma-dev \
        icu-dev \
    && apk add --no-cache \
        nginx \
        curl \
        git \
        postgresql-libs \
        libpng \
        libjpeg-turbo \
        freetype \
        libzip \
        icu-libs \
        libintl \
    # PHP extensions: pdo_pgsql, pgsql, redis, bcmath, gd, zip, intl, opcache
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_pgsql \
        pgsql \
        bcmath \
        gd \
        zip \
        intl \
        opcache \
        pcntl \
    && pecl install redis && docker-php-ext-enable redis \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

# ---------------------------------------------------------------------------
# Composer
# ---------------------------------------------------------------------------
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ---------------------------------------------------------------------------
# Working directory
# ---------------------------------------------------------------------------
WORKDIR /var/www/html

# ---------------------------------------------------------------------------
# Nginx config + entrypoint
# ---------------------------------------------------------------------------
COPY infrastructure/docker/nginx.conf /etc/nginx/http.d/default.conf
COPY infrastructure/docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ---------------------------------------------------------------------------
# Copy Laravel application code
# ---------------------------------------------------------------------------
COPY backend/api /var/www/html

# ---------------------------------------------------------------------------
# Install Composer dependencies
# ---------------------------------------------------------------------------
RUN composer install --no-interaction --optimize-autoloader \
    || composer update --no-interaction --optimize-autoloader

# ---------------------------------------------------------------------------
# OPcache settings (development-friendly)
# ---------------------------------------------------------------------------
RUN printf "[opcache]\nopcache.enable=1\nopcache.enable_cli=1\nopcache.memory_consumption=128\nopcache.max_accelerated_files=10000\nopcache.revalidate_freq=0\nopcache.validate_timestamps=1\n" > /usr/local/etc/php/conf.d/opcache-recommended.ini

# ---------------------------------------------------------------------------
# Permissions for storage and bootstrap/cache
# ---------------------------------------------------------------------------
RUN mkdir -p storage/logs storage/framework/cache/data storage/framework/sessions \
        storage/framework/views storage/app/public storage/app/private bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

EXPOSE 80

ENTRYPOINT ["entrypoint.sh"]
CMD ["start"]
