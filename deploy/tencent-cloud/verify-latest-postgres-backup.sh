#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/head_in_clouds/backups/postgres}"

if [[ ! -d "${BACKUP_DIR}" ]]; then
  echo "Missing backup directory: ${BACKUP_DIR}" >&2
  exit 1
fi

latest_dump="$(ls -1t "${BACKUP_DIR}"/head_in_clouds-*.dump 2>/dev/null | head -n 1 || true)"
if [[ -z "${latest_dump}" ]]; then
  echo "No PostgreSQL backup dump found in ${BACKUP_DIR}" >&2
  exit 1
fi

case "$(basename "${latest_dump}")" in
  head_in_clouds-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z.dump)
    ;;
  *)
    echo "Latest backup filename has unexpected format: ${latest_dump}" >&2
    exit 1
    ;;
esac

checksum_path="${latest_dump}.sha256"
if [[ ! -f "${checksum_path}" ]]; then
  echo "Missing checksum file: ${checksum_path}" >&2
  exit 1
fi

sha256sum --check "${checksum_path}" >/dev/null
pg_restore --list "${latest_dump}" >/dev/null

bytes="$(wc -c <"${latest_dump}" | tr -d '[:space:]')"
echo "Backup verification passed: ${latest_dump} (${bytes} bytes)"
