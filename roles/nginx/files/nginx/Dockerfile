# Layers go from least to most frequently changed (cache friendly).
FROM alpine:3.24

# 1. nginx + openssl (for the self-signed fallback certificate)
RUN apk add --no-cache nginx openssl \
    && mkdir -p /etc/nginx/selfsigned /etc/nginx/tls /var/www/acme

# 2. Global config (site config is mounted from the host by Ansible)
COPY nginx.conf /etc/nginx/nginx.conf

# 3. Entrypoint
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
