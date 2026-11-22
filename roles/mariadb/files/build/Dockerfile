# Layers are ordered from least to most frequently changed, so editing the
# config or the entrypoint does not re-run the (slow) package install.
FROM alpine:3.24

# 1. System packages: change rarely -> first, cached.
#    Alpine's package also ships test binaries, an embedded server and offline
#    repair/benchmark tools (~150 MB) a container never uses. They are removed
#    in the SAME layer: deleting them in a later layer would not shrink the image.
RUN apk add --no-cache mariadb mariadb-client \
    && rm -f /usr/bin/mariadb-embedded /usr/bin/test-connect-t \
             /usr/bin/mariadb-ldb /usr/bin/sst_dump \
             /usr/bin/aria_* /usr/bin/myisam* /usr/bin/mariadb-slap \
             /usr/bin/mariadb-binlog /usr/bin/mariadb-import /usr/bin/mariadb-show \
             /usr/bin/mariadb-waitpid /usr/bin/resolve_stack_dump \
             /usr/bin/mariadb-plugin /usr/bin/mariadb-conv /usr/bin/innochecksum \
             /usr/bin/replace /usr/bin/mariadb-migrate-config-file \
    && mkdir -p /run/mysqld \
    && chown mysql:mysql /run/mysqld

# 2. Server config: changes sometimes
COPY mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf

# 3. Entrypoint: changes most often -> last
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 3306
VOLUME /var/lib/mysql
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
