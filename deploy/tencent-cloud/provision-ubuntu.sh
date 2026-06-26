#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root on the Ubuntu CVM." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gnupg nginx ufw docker.io docker-compose-v2

systemctl enable --now docker
systemctl enable --now nginx

ufw allow OpenSSH
ufw allow 80/tcp
ufw --force enable

mkdir -p /opt/head_in_clouds/releases /opt/head_in_clouds/current
echo "CVM base provisioning complete."
