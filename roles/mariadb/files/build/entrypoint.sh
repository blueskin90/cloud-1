#!/bin/sh
# Initialise the database on first start only, then hand over to mariadbd.
set -eu

DATADIR=/var/lib/mysql

# Secrets are mounted by Docker Compose as files (never as env vars, which
# would be visible with "docker inspect").
read_secret() { cat "/run/secrets/$1"; }

# Escape a value for use inside a single-quoted SQL string.
sql_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"; }

: "${MARIADB_DATABASE:?MARIADB_DATABASE is not set}"
: "${MARIADB_USER:?MARIADB_USER is not set}"

# The volume may be fresh (empty) or come from a previous run.
chown -R mysql:mysql "$DATADIR"

# "mysql" system database present = already initialised (e.g. after a reboot
# or container re-creation). Data in the volume is kept as is.
if [ ! -d "$DATADIR/mysql" ]; then
    echo "[entrypoint] First start: initialising database"

    mariadb-install-db --user=mysql --datadir="$DATADIR" \
        --skip-test-db --auth-root-authentication-method=normal >/dev/null

    root_pw=$(sql_escape "$(read_secret db_root_password)")
    user_pw=$(sql_escape "$(read_secret db_password)")

    # --bootstrap runs SQL without networking and without grant checks.
    mariadbd --user=mysql --datadir="$DATADIR" --bootstrap <<SQL
FLUSH PRIVILEGES;
-- root: password only, through the local socket only. The installer also
-- creates root@127.0.0.1, root@::1 and root@<hostname> WITHOUT a password.
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_pw}';
DROP USER IF EXISTS 'root'@'127.0.0.1';
DROP USER IF EXISTS 'root'@'::1';
DROP USER IF EXISTS 'root'@'$(hostname)';
DROP USER IF EXISTS 'root'@'%';
-- remove anonymous users
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'$(hostname)';
-- application database + user, limited to that database
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${user_pw}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
    echo "[entrypoint] Initialisation done"
fi

# exec: mariadbd replaces this shell as PID 1, so it receives SIGTERM from
# "docker stop" directly and shuts down cleanly (1 container = 1 process).
exec mariadbd --user=mysql --datadir="$DATADIR"
