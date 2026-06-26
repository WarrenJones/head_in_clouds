#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/head_in_clouds/ios/HeadInClouds.xcodeproj"
DERIVED_DATA_PATH="${ROOT_DIR}/head_in_clouds/ios/DerivedData"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/HeadInClouds.app"

SIMULATOR_ID="${SIMULATOR_ID:-430D7F48-C297-4DB8-B6DE-5C60E17F6D9F}"
SMOKE_RUN_ID="${SMOKE_RUN_ID:-ios-simulator-staging-smoke-$(date +%Y%m%d-%H%M%S)}"
SSH_HOST="${SSH_HOST:-ubuntu@101.43.4.247}"
SSH_KEY="${SSH_KEY:-/Users/zhongwowen.3/.ssh/head-in-clouds-tencent.pem}"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/opt/head_in_clouds/current}"
EXPECTED_EVENTS="${EXPECTED_EVENTS:-app_first_launched,onboarding_step_viewed}"
EVENT_TUNNEL_PORT="${EVENT_TUNNEL_PORT:-18787}"
HEAD_IN_CLOUDS_API_BASE_URL="${HEAD_IN_CLOUDS_API_BASE_URL:-http://127.0.0.1:${EVENT_TUNNEL_PORT}}"
HEAD_IN_CLOUDS_EVENTS_URL="${HEAD_IN_CLOUDS_EVENTS_URL:-${HEAD_IN_CLOUDS_API_BASE_URL}/events}"
HEAD_IN_CLOUDS_SHARE_BASE_URL="${HEAD_IN_CLOUDS_SHARE_BASE_URL:-https://headinclouds.cn}"
TUNNEL_PID=""
LAST_OUTPUT=""

cleanup() {
  if [[ -n "${TUNNEL_PID}" ]]; then
    kill "${TUNNEL_PID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${LAST_OUTPUT}" ]]; then
    rm -f "${LAST_OUTPUT}"
  fi
}
trap cleanup EXIT

cd "${ROOT_DIR}"

ssh -i "${SSH_KEY}" -o IdentitiesOnly=yes -N \
  -L "${EVENT_TUNNEL_PORT}:127.0.0.1:8787" \
  "${SSH_HOST}" &
TUNNEL_PID="$!"

TUNNEL_READY=false
for attempt in {1..20}; do
  if curl -fsS "${HEAD_IN_CLOUDS_API_BASE_URL}/health" >/dev/null 2>&1; then
    TUNNEL_READY=true
    break
  fi
  sleep 0.5
done
if [[ "${TUNNEL_READY}" != "true" ]]; then
  echo "Timed out waiting for local event tunnel at ${HEAD_IN_CLOUDS_API_BASE_URL}." >&2
  exit 1
fi

xcodebuild build \
  -project "${PROJECT_PATH}" \
  -scheme HeadInClouds \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "id=${SIMULATOR_ID}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO

xcrun simctl boot "${SIMULATOR_ID}" || true
xcrun simctl bootstatus "${SIMULATOR_ID}" -b
xcrun simctl terminate "${SIMULATOR_ID}" com.headintheclouds.app.dev || true
xcrun simctl uninstall "${SIMULATOR_ID}" com.headintheclouds.app.dev || true
xcrun simctl install "${SIMULATOR_ID}" "${APP_PATH}"
SIMCTL_CHILD_HEAD_IN_CLOUDS_API_BASE_URL="${HEAD_IN_CLOUDS_API_BASE_URL}" \
SIMCTL_CHILD_HEAD_IN_CLOUDS_EVENTS_URL="${HEAD_IN_CLOUDS_EVENTS_URL}" \
SIMCTL_CHILD_HEAD_IN_CLOUDS_SHARE_BASE_URL="${HEAD_IN_CLOUDS_SHARE_BASE_URL}" \
SIMCTL_CHILD_HIC_ANALYTICS_SMOKE_RUN_ID="${SMOKE_RUN_ID}" \
xcrun simctl launch "${SIMULATOR_ID}" com.headintheclouds.app.dev --ui-testing-reset

LAST_OUTPUT="$(mktemp)"

for attempt in {1..12}; do
  if ssh -i "${SSH_KEY}" -o IdentitiesOnly=yes "${SSH_HOST}" \
    "cd '${REMOTE_APP_DIR}' && set -a && . deploy/tencent-cloud/.env.server && set +a && HIC_STAGING_BASE_URL=http://127.0.0.1:8787 HIC_SMOKE_RUN_ID='${SMOKE_RUN_ID}' HIC_EXPECTED_EVENTS='${EXPECTED_EVENTS}' npm run smoke:events:summary --prefix server" >"${LAST_OUTPUT}" 2>&1; then
    cat "${LAST_OUTPUT}"
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for expected staging events for ${SMOKE_RUN_ID}." >&2
cat "${LAST_OUTPUT}" >&2
exit 1
