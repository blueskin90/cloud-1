# Layers go from least to most frequently changed (cache friendly).
FROM alpine:3.24

# 1. PHP 8.3: phpMyAdmin 5.2.x supports PHP < 8.4 only.
RUN apk add --no-cache \
        php83 php83-fpm php83-mysqli php83-mbstring php83-session php83-sodium \
        php83-openssl php83-ctype php83-iconv php83-xml php83-dom php83-simplexml \
        php83-xmlwriter php83-zip php83-gd php83-opcache \
    && (grep -q '^www-data:' /etc/group  || addgroup -S -g 82 www-data) \
    && (grep -q '^www-data:' /etc/passwd || adduser -S -D -H -u 82 -G www-data www-data)

# 2. phpMyAdmin, pinned version, verified against the published checksum.
#    "english" build = no extra translations -> smaller.
ARG PMA_VERSION=5.2.3
ARG PMA_SHA256=03de2640bb25c9a6f96bc94eae316080b5fd5bd58d769e1318ba9dd94c83364c
RUN wget -q -O /tmp/pma.tar.gz \
        "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-english.tar.gz" \
    && echo "${PMA_SHA256}  /tmp/pma.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/phpmyadmin \
    && tar -xzf /tmp/pma.tar.gz -C /usr/src/phpmyadmin --strip-components=1 \
    && rm -rf /tmp/pma.tar.gz /usr/src/phpmyadmin/setup /usr/src/phpmyadmin/examples

# 3. Config files: change sometimes
COPY php-fpm.conf /etc/php83/php-fpm.conf
COPY www.conf /etc/php83/php-fpm.d/www.conf
COPY phpmyadmin.ini /etc/php83/conf.d/zz-phpmyadmin.ini

# 4. Entrypoint: changes most often -> last
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

VOLUME /var/www/phpmyadmin
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
