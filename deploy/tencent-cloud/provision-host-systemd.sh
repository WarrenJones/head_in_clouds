#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/opt/head_in_clouds/current}"
ENV_FILE="${ENV_FILE:-${APP_ROOT}/deploy/tencent-cloud/.env.server}"
NODE_VERSION="${NODE_VERSION:-v22.16.0}"
NODE_DIR="/opt/node-${NODE_VERSION}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl nginx ufw postgresql postgresql-contrib xz-utils

if [[ ! -x "${NODE_DIR}/bin/node" ]]; then
  curl -fsSL "https://npmmirror.com/mirrors/node/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz
  rm -rf "${NODE_DIR}"
  rm -rf "/tmp/node-${NODE_VERSION}-linux-x64"
  tar -xJf /tmp/node.tar.xz -C /tmp
  mv "/tmp/node-${NODE_VERSION}-linux-x64" "${NODE_DIR}"
fi

ln -sf "${NODE_DIR}/bin/node" /usr/local/bin/node
ln -sf "${NODE_DIR}/bin/npm" /usr/local/bin/npm
ln -sf "${NODE_DIR}/bin/npx" /usr/local/bin/npx
npm config set registry https://registry.npmmirror.com

set -a
# shellcheck disable=SC1090
. "${ENV_FILE}"
set +a

if [[ "${DATABASE_URL}" != *"127.0.0.1"* && "${DATABASE_URL}" != *"localhost"* ]]; then
  echo "DATABASE_URL must point to localhost for host-systemd deployment." >&2
  exit 1
fi

systemctl enable --now postgresql
sudo -u postgres psql -tc "select 1 from pg_roles where rolname='${POSTGRES_USER}'" | grep -q 1 \
  || sudo -u postgres psql -c "create role ${POSTGRES_USER} login password '${POSTGRES_PASSWORD}'"
sudo -u postgres psql -c "alter role ${POSTGRES_USER} with login password '${POSTGRES_PASSWORD}'"
sudo -u postgres psql -tc "select 1 from pg_database where datname='${POSTGRES_DB}'" | grep -q 1 \
  || sudo -u postgres createdb -O "${POSTGRES_USER}" "${POSTGRES_DB}"

cd "${APP_ROOT}/server"
npm ci --omit=dev
npm run db:migrate

cat >/etc/systemd/system/head-in-clouds-api.service <<EOF
[Unit]
Description=Head in the Clouds API
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
WorkingDirectory=${APP_ROOT}/server
EnvironmentFile=${ENV_FILE}
ExecStart=/usr/local/bin/npm start
Restart=always
RestartSec=5
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
EOF

DISPATCH_INTERVAL="${NOTIFICATION_DISPATCH_INTERVAL:-60s}"
cat >/etc/systemd/system/head-in-clouds-notification-dispatch.service <<EOF
[Unit]
Description=Head in the Clouds Notification Dispatch
After=network.target postgresql.service head-in-clouds-api.service
Wants=postgresql.service

[Service]
Type=oneshot
WorkingDirectory=${APP_ROOT}/server
EnvironmentFile=${ENV_FILE}
ExecStart=/usr/local/bin/npm run dispatch:notifications
User=ubuntu
Group=ubuntu
EOF

cat >/etc/systemd/system/head-in-clouds-notification-dispatch.timer <<EOF
[Unit]
Description=Run Head in the Clouds notification dispatch

[Timer]
OnBootSec=60s
OnUnitActiveSec=${DISPATCH_INTERVAL}
AccuracySec=10s
Unit=head-in-clouds-notification-dispatch.service

[Install]
WantedBy=timers.target
EOF

cp "${APP_ROOT}/deploy/tencent-cloud/nginx-head-in-clouds.conf" /etc/nginx/sites-available/head-in-clouds.conf
ln -sf /etc/nginx/sites-available/head-in-clouds.conf /etc/nginx/sites-enabled/head-in-clouds.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t

systemctl daemon-reload
systemctl enable --now head-in-clouds-api
systemctl restart head-in-clouds-api
if [[ "${HIC_NOTIFICATION_DISPATCH_ENABLED:-false}" == "true" ]]; then
  systemctl enable --now head-in-clouds-notification-dispatch.timer
else
  systemctl disable --now head-in-clouds-notification-dispatch.timer >/dev/null 2>&1 || true
fi
systemctl reload nginx

ufw allow OpenSSH
ufw allow 80/tcp
ufw --force enable

systemctl --no-pager --full status head-in-clouds-api
