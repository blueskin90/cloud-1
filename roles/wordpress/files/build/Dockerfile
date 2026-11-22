# Layers go from least to most frequently changed (cache friendly).
FROM alpine:3.24

# 1. PHP 8.4 + extensions WordPress needs. Changes rarely -> first.
#    www-data (uid/gid 82) is the conventional Alpine web user.
RUN apk add --no-cache \
        php84 php84-fpm php84-phar php84-mysqli php84-mbstring php84-openssl \
        php84-curl php84-gd php84-zip php84-dom php84-xml php84-xmlreader \
        php84-xmlwriter php84-simplexml php84-exif php84-fileinfo php84-iconv \
        php84-intl php84-tokenizer php84-ctype php84-session php84-sodium \
        php84-opcache \
    && (grep -q '^www-data:' /etc/group  || addgroup -S -g 82 www-data) \
    && (grep -q '^www-data:' /etc/passwd || adduser -S -D -H -u 82 -G www-data www-data) \
    && ln -sf /usr/bin/php84 /usr/bin/php

# 2. WordPress + wp-cli, pinned versions, verified against published checksums
#    (a corrupted or tampered download makes the build fail).
ARG WP_VERSION=7.1.5
ARG WP_SHA1=f79cd80a8f8152edd88ef9be859ae765f2ec6c36
ARG WPCLI_VERSION=2.12.0
ARG WPCLI_SHA512=be928f6b8ca1e8dfb9d2f4b75a13aa4aee0896f8a9a0a1c45cd5d2c98605e6172e6d014dda2e27f88c98befc16c040cbb2bd1bfa121510ea5cdf5f6a30fe8832
RUN wget -q -O /tmp/wordpress.tar.gz "https://wordpress.org/wordpress-${WP_VERSION}.tar.gz" \
    && echo "${WP_SHA1}  /tmp/wordpress.tar.gz" | sha1sum -c - \
    && mkdir -p /usr/src \
    && tar -xzf /tmp/wordpress.tar.gz -C /usr/src \
    && rm /tmp/wordpress.tar.gz \
    && wget -q -O /usr/local/bin/wp \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WPCLI_VERSION}/wp-cli-${WPCLI_VERSION}.phar" \
    && echo "${WPCLI_SHA512}  /usr/local/bin/wp" | sha512sum -c - \
    && chmod 755 /usr/local/bin/wp

# 3. Config files: change sometimes
COPY php-fpm.conf /etc/php84/php-fpm.conf
COPY www.conf /etc/php84/php-fpm.d/www.conf
COPY wordpress.ini /etc/php84/conf.d/zz-wordpress.ini

# 4. Entrypoint: changes most often -> last
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html
VOLUME /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
