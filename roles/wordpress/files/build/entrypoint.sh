#!/bin/sh
# Install/configure WordPress if needed, then hand over to php-fpm.
# Every step checks first, so restarts are safe (idempotent).
set -eu

WEBROOT=/var/www/html

: "${WP_URL:?}" "${WP_TITLE:?}" "${WP_ADMIN_USER:?}" "${WP_ADMIN_EMAIL:?}"
: "${WORDPRESS_DB_HOST:?}" "${WORDPRESS_DB_NAME:?}" "${WORDPRESS_DB_USER:?}"

# Secrets come from files mounted by Docker Compose (not visible in "docker inspect")
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)

# wp-cli runs as root here (hence --allow-root); ownership is fixed below.
wp() { /usr/local/bin/wp --allow-root --path="$WEBROOT" "$@"; }

# 1. WordPress files: copy into the (persistent) volume on first start only
if [ ! -f "$WEBROOT/wp-includes/version.php" ]; then
    echo "[entrypoint] Copying WordPress files into the volume"
    cp -a /usr/src/wordpress/. "$WEBROOT/"
fi

# 2. Wait for the database (it may still be starting after a reboot)
echo "[entrypoint] Waiting for database at ${WORDPRESS_DB_HOST}"
tries=0
until DB_PASSWORD="$DB_PASSWORD" php -r '
    mysqli_report(MYSQLI_REPORT_OFF);
    exit(@mysqli_connect(getenv("WORDPRESS_DB_HOST"), getenv("WORDPRESS_DB_USER"),
                         getenv("DB_PASSWORD"), getenv("WORDPRESS_DB_NAME")) ? 0 : 1);'
do
    tries=$((tries + 1))
    [ "$tries" -ge 60 ] && { echo "[entrypoint] Database unreachable, giving up" >&2; exit 1; }
    sleep 2
done

# 3. wp-config.php: created once (this also generates the unique security salts)
if [ ! -f "$WEBROOT/wp-config.php" ]; then
    echo "[entrypoint] Creating wp-config.php"
    wp config create --skip-check --dbpass=placeholder \
        --dbhost="$WORDPRESS_DB_HOST" --dbname="$WORDPRESS_DB_NAME" \
        --dbuser="$WORDPRESS_DB_USER"
fi
# Settings are re-applied on every start: a new domain or a password changed
# in the vault reaches wp-config.php on the next deploy.
wp config set DB_HOST "$WORDPRESS_DB_HOST" --quiet
wp config set DB_NAME "$WORDPRESS_DB_NAME" --quiet
wp config set DB_USER "$WORDPRESS_DB_USER" --quiet
# The password goes through PHP's var_export(), which produces a correctly
# escaped PHP string literal. (wp-cli's own escaping breaks passwords that
# contain a double quote: it writes \" which PHP keeps as two characters.)
DB_PASSWORD_PHP=$(php -r 'echo var_export(rtrim(file_get_contents("/run/secrets/db_password"), "\r\n"), true);')
wp config set DB_PASSWORD "$DB_PASSWORD_PHP" --raw --quiet
wp config set WP_HOME "$WP_URL" --quiet
wp config set WP_SITEURL "$WP_URL" --quiet

# 4. Site installation (tables, admin user): once
if ! wp core is-installed 2>/dev/null; then
    echo "[entrypoint] Installing WordPress"
    wp core install --skip-email \
        --url="$WP_URL" --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL"
fi

# 5. Ownership: php-fpm workers run as www-data (needed for media uploads).
#    Only touch files that need it -> fast on later starts.
find "$WEBROOT" ! -user www-data -exec chown www-data:www-data {} +
# wp-config.php holds the DB password: not world-readable (nginx can't read it)
chmod 640 "$WEBROOT/wp-config.php"

echo "[entrypoint] Starting php-fpm"
# exec: php-fpm becomes PID 1 and receives "docker stop" signals directly
exec php-fpm84 -F
