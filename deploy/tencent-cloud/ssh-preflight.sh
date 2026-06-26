#!/usr/bin/env bash
set -euo pipefail

: "${SSH_KEY:?Set SSH_KEY to the local private key path}"
SSH_HOST_IP="${SSH_HOST_IP:-101.43.4.247}"
USERS="${SSH_USERS:-root ubuntu lighthouse tencent}"

echo "Testing SSH key: ${SSH_KEY}"
echo "Testing host: ${SSH_HOST_IP}"

for user in ${USERS}; do
  echo "==> Trying ${user}@${SSH_HOST_IP}"
  if ssh -i "${SSH_KEY}" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    "${user}@${SSH_HOST_IP}" "whoami && uname -a"; then
    echo "SSH_OK_USER=${user}"
    exit 0
  fi
done

echo "No tested user accepted this SSH key." >&2
echo "Public key to bind in Tencent Cloud console:" >&2
ssh-keygen -y -f "${SSH_KEY}" >&2
exit 1
