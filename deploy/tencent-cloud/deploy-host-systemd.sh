#!/usr/bin/env bash
set -euo pipefail

: "${SSH_HOST:?Set SSH_HOST, for example ubuntu@101.43.4.247}"
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

ssh -i "${SSH_KEY}" -o IdentitiesOnly=yes "${SSH_HOST}" "${REMOTE_SUDO} bash ${REMOTE_DIR}/deploy/tencent-cloud/provision-host-systemd.sh"
ssh -i "${SSH_KEY}" -o IdentitiesOnly=yes "${SSH_HOST}" \
  "bash -lc 'set -a && source ${REMOTE_DIR}/deploy/tencent-cloud/.env.server && set +a && npm run check:deploy --prefix ${REMOTE_DIR}/server -- --profile=production'"

echo "Host systemd deploy command finished. Verify: curl -s https://api.headinclouds.cn/health"
