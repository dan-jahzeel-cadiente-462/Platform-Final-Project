# Stage 1: Base image with system dependencies and PHP extensions
FROM php:8.3-fpm-alpine AS base

# Set production environment variables
ENV APP_ENV=prod
ENV APP_DEBUG=0

# Install system dependencies for Symfony and MySQL
RUN apk add --no-cache \
    acl \
    fcgi \
    file \
    gettext \
    git \
    icu-dev \
    libzip-dev \
    mariadb-dev \
    zip \
    zlib-dev

# Install PHP extensions
RUN docker-php-ext-install \
    intl \
    pdo_mysql \
    zip

WORKDIR /var/www/html

# Stage 2: Build stage for installing Composer dependencies
FROM base AS builder

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Leverage Docker layer caching: only re-run composer install if these files change
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-progress

# Stage 3: Final production image
FROM base AS final

# Install Composer binary in the final stage to run optimization commands
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy vendors from the builder stage
COPY --from=builder /var/www/html/vendor ./vendor

# Copy application files
COPY . .

# Set production environment variables
ENV APP_ENV=prod
ENV APP_DEBUG=0

# Provide dummy environment variables for build-time console commands.
# These allow the Symfony Kernel to boot without a real database during the build.
ENV DATABASE_URL="mysql://dummy:dummy@127.0.0.1:3306/dummy"
ENV DEFAULT_URI="http://localhost"

# Run optimization and cache warmup during build
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev && \
    # Download JavaScript vendor assets managed by AssetMapper
    php bin/console importmap:install && \
    # Precompile all assets for production performance
    php bin/console asset-map:compile && \
    # Warm up cache without requiring a live database connection during build
    php bin/console cache:warmup --no-optional-warmers && \
    # Set permissions
    mkdir -p var/cache var/log assets/vendor public/assets && \
    chown -R www-data:www-data var assets/vendor public/assets && \
    chmod -R 775 var assets/vendor public/assets && \
    # Fix line endings
    sed -i 's/\r$//' entrypoint.sh && \
    chmod +x entrypoint.sh

ENTRYPOINT ["/var/www/html/entrypoint.sh"]
CMD ["php-fpm"]