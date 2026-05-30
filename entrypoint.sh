#!/bin/sh
set -e

# Wait for database to be ready
echo "Waiting for database to be ready..."
# We try to connect via PDO. If it fails (even with 1045 Access Denied), 
# we keep waiting because MySQL might still be setting up the user.
until php -r "
try {
    // On Railway, we use the host and credentials provided by the MySQL service
    \$host = getenv('MYSQLHOST') ?: 'database';
    \$port = getenv('MYSQLPORT') ?: '3306';
    \$user = getenv('MYSQLUSER') ?: 'final-project';
    \$pass = getenv('MYSQLPASSWORD') ?: 'final-project-password';
    new PDO(\"mysql:host=\$host;port=\$port\", \$user, \$pass);
    exit(0);
} catch (Exception \$e) {
    exit(1);
}" > /dev/null 2>&1; do
    sleep 1
done

# Run database migrations automatically
php bin/console doctrine:database:create --if-not-exists --no-interaction
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration

# Fix permissions one last time to ensure the web server can write logs and cache
# that might have been created by root during the migrations above.
chown -R www-data:www-data var

exec "$@"