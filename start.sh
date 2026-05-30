#!/bin/sh
set -e

# Run database migrations and any other entrypoint setup
/var/www/html/entrypoint.sh

# Start PHP-FPM in the background
php-fpm --daemonize --fpm-config /usr/local/etc/php-fpm.conf

echo "PHP-FPM started."

# Start Nginx in the foreground (keeps the container alive)
echo "Starting Nginx on port 8080..."
exec nginx -g "daemon off;"
