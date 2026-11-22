#!/bin/sh
# Pick the TLS certificate (Let's Encrypt if present, self-signed otherwise),
# then hand over to nginx.
set -eu

: "${SITE_DOMAIN:?}" "${PMA_DOMAIN:?}"

LE=/etc/letsencrypt/live/$SITE_DOMAIN
SS=/etc/nginx/selfsigned
TLS=/etc/nginx/tls

# 1. Self-signed fallback: (re)generated when missing or when the domain changed
if [ "$(cat "$SS/domain" 2>/dev/null)" != "$SITE_DOMAIN" ]; then
    echo "[entrypoint] Generating self-signed certificate for $SITE_DOMAIN"
    openssl req -x509 -nodes -days 825 \
        -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout "$SS/privkey.pem" -out "$SS/fullchain.pem" \
        -subj "/CN=$SITE_DOMAIN" \
        -addext "subjectAltName=DNS:$SITE_DOMAIN,DNS:$PMA_DOMAIN" 2>/dev/null
    chmod 600 "$SS/privkey.pem"
    echo "$SITE_DOMAIN" > "$SS/domain"
fi

# 2. The site config always uses /etc/nginx/tls/*: point it at the right files.
#    HSTS ("HTTPS only from now on") is only sent with a real certificate,
#    otherwise browsers would refuse to let you past the self-signed warning.
if [ -f "$LE/fullchain.pem" ]; then
    echo "[entrypoint] Using Let's Encrypt certificate"
    ln -sf "$LE/fullchain.pem" "$TLS/fullchain.pem"
    ln -sf "$LE/privkey.pem" "$TLS/privkey.pem"
    echo 'add_header Strict-Transport-Security "max-age=31536000" always;' > "$TLS/hsts.conf"
else
    echo "[entrypoint] Using self-signed certificate"
    ln -sf "$SS/fullchain.pem" "$TLS/fullchain.pem"
    ln -sf "$SS/privkey.pem" "$TLS/privkey.pem"
    : > "$TLS/hsts.conf"
fi

nginx -t -q
echo "[entrypoint] Starting nginx"
# exec: nginx master becomes PID 1 and receives "docker stop" signals directly
exec nginx -g 'daemon off;'
