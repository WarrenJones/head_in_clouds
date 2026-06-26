#!/usr/bin/env bash
set -euo pipefail

: "${SSH_HOST:?Set SSH_HOST, for example root@101.43.4.247}"
: "${SSH_KEY:?Set SSH_KEY to the local private key path}"

REMOTE_DIR="${REMOTE_DIR:-/opt/head_in_clouds/current}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_SUDO="${REMOTE_SUDO:-sudo}"

ssh -i "${SSH_KEY}" -o IdentitiesOnly=yes "${SSH_HOST}" "${REMOTE_SUDO} mkdir -p ${REMOTE_DIR} && ${REMOTE_SUDO} chown -R \$(id -u):\$(id -g) ${REMOTE_DIR}"
rsync -az --delete \
  --exclude 'ios/DerivedData' \
  --exclude 'ios/.build' \
  --exclude 'server/.local' \
  --exclude 'server/node_modules' \
  --exclude 'deploy/tencent-cloud/.env.server' \
  -e "ssh -i ${SSH_KEY} -o IdentitiesOnly=yes" \
  "${PROJECT_ROOT}/" "${SSH_HOST}:${REMOTE_DIR}/"

ssh -i "${SSH_KEY}" -o IdentitiesOnly=yes "${SSH_HOST}" "set -euo pipefail
cd ${REMOTE_DIR}/deploy/tencent-cloud
if [[ ! -f .env.server ]]; then
  cp .env.server.example .env.server
  echo 'Created .env.server from template. Fill secrets and DATABASE_URL on the server, then rerun deploy.' >&2
  exit 2
fi
if grep -q 'REPLACE_ME' .env.server; then
  echo '.env.server still contains REPLACE_ME placeholders.' >&2
  exit 2
fi
${REMOTE_SUDO} cp nginx-head-in-clouds.conf /etc/nginx/sites-available/head-in-clouds.conf
${REMOTE_SUDO} ln -sf /etc/nginx/sites-available/head-in-clouds.conf /etc/nginx/sites-enabled/head-in-clouds.conf
${REMOTE_SUDO} rm -f /etc/nginx/sites-enabled/default
${REMOTE_SUDO} nginx -t
${REMOTE_SUDO} systemctl reload nginx
${REMOTE_SUDO} docker compose build
${REMOTE_SUDO} docker compose up -d postgres
for i in \$(seq 1 30); do
  if ${REMOTE_SUDO} docker compose exec -T postgres pg_isready -U hic_app -d head_in_clouds >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
${REMOTE_SUDO} docker compose run --rm head-in-clouds-api npm run db:migrate
${REMOTE_SUDO} docker compose up -d
${REMOTE_SUDO} docker compose ps
"

echo "Deploy command finished. Verify: curl -s https://api.headinclouds.cn/health"
