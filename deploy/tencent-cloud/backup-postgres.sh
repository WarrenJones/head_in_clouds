#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/opt/head_in_clouds/current}"
ENV_FILE="${ENV_FILE:-${APP_ROOT}/deploy/tencent-cloud/.env.server}"
BACKUP_DIR="${BACKUP_DIR:-/opt/head_in_clouds/backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
UPLOAD_BACKUP_TO_OBJECT_STORAGE="${UPLOAD_BACKUP_TO_OBJECT_STORAGE:-false}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "${ENV_FILE}"
set +a

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required for PostgreSQL backup." >&2
  exit 1
fi

umask 077
mkdir -p "${BACKUP_DIR}"

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
backup_path="${BACKUP_DIR}/head_in_clouds-${timestamp}.dump"

pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="${backup_path}" \
  "${DATABASE_URL}"

sha256sum "${backup_path}" >"${backup_path}.sha256"
sha256sum --check "${backup_path}.sha256" >/dev/null
pg_restore --list "${backup_path}" >/dev/null

if [[ "${UPLOAD_BACKUP_TO_OBJECT_STORAGE}" == "true" ]]; then
  node "${APP_ROOT}/server/scripts/upload-backup-to-object-storage.mjs" \
    "${backup_path}" \
    "${backup_path}.sha256"
else
  echo "Backup upload skipped: UPLOAD_BACKUP_TO_OBJECT_STORAGE=false"
fi

find "${BACKUP_DIR}" \
  -type f \
  \( -name "head_in_clouds-*.dump" -o -name "head_in_clouds-*.dump.sha256" \) \
  -mtime +"${RETENTION_DAYS}" \
  -delete

echo "Backup created: ${backup_path}"
