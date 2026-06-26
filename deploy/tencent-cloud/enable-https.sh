#!/usr/bin/env bash
set -euo pipefail

: "${HIC_DOMAIN:?Set HIC_DOMAIN, for example headinclouds.cn}"

EMAIL="${HIC_TLS_EMAIL:-}"
FORCE_HTTPS_REDIRECT="${HIC_FORCE_HTTPS_REDIRECT:-true}"
NGINX_SITE="/etc/nginx/sites-available/head-in-clouds"
NGINX_ENABLED="/etc/nginx/sites-enabled/head-in-clouds"
read -r -a DOMAIN_LIST <<< "${HIC_DOMAIN} ${HIC_ALT_DOMAINS:-}"
PRIMARY_DOMAIN="${DOMAIN_LIST[0]}"
SERVER_NAMES="${DOMAIN_LIST[*]}"

if ! command -v certbot >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
fi

cat > "${NGINX_SITE}" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${SERVER_NAMES};

    client_max_body_size 10m;

    location /health {
        proxy_pass http://127.0.0.1:8787/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location / {
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGINX

ln -sf "${NGINX_SITE}" "${NGINX_ENABLED}"
nginx -t
systemctl reload nginx

CERTBOT_ARGS=(--nginx --non-interactive --agree-tos)
if [[ "${FORCE_HTTPS_REDIRECT}" == "true" ]]; then
  CERTBOT_ARGS+=(--redirect)
fi
for domain in "${DOMAIN_LIST[@]}"; do
  CERTBOT_ARGS+=(-d "${domain}")
done
if [[ -n "${EMAIL}" ]]; then
  CERTBOT_ARGS+=(--email "${EMAIL}")
else
  CERTBOT_ARGS+=(--register-unsafely-without-email)
fi

certbot "${CERTBOT_ARGS[@]}"
systemctl reload nginx

echo "HTTPS enabled. Verify: curl -s https://${PRIMARY_DOMAIN}/health"
if [[ "${FORCE_HTTPS_REDIRECT}" != "true" ]]; then
  echo "HTTP redirect is disabled. Verify temporary HTTP fallback: curl -s http://${PRIMARY_DOMAIN}/"
fi
