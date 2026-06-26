#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STARTUP_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"
IOS_DIR="${PROJECT_ROOT}/ios"
SERVER_DIR="${PROJECT_ROOT}/server"
REMOTE_HOST="${REMOTE_HOST:-ubuntu@101.43.4.247}"
SSH_KEY="${SSH_KEY:-/Users/zhongwowen.3/.ssh/head-in-clouds-tencent.pem}"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/opt/head_in_clouds/current}"
SIMULATOR_ID="${SIMULATOR_ID:-430D7F48-C297-4DB8-B6DE-5C60E17F6D9F}"
RUN_IOS_SIMULATOR_SMOKE="${RUN_IOS_SIMULATOR_SMOKE:-false}"

step() {
  printf '\n==> %s\n' "$1"
}

remote() {
  ssh -i "${SSH_KEY}" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "${REMOTE_HOST}" "$@"
}

run_remote_with_env() {
  local command="$1"
  remote "bash -lc 'set -a && source ${REMOTE_APP_DIR}/deploy/tencent-cloud/.env.server && set +a && ${command}'"
}

step "Server unit tests"
npm test --prefix "${SERVER_DIR}"

step "IAP app account token source guard"
grep -Fq "appAccountToken: account.id" "${IOS_DIR}/App/AppState.swift"
grep -Fq "Product.PurchaseOption> = [.appAccountToken(appAccountToken)]" "${IOS_DIR}/App/AppState.swift"

step "Swift core checks"
(cd "${IOS_DIR}" && swift run HeadInCloudsCoreChecks)

step "Xcode simulator build"
xcodebuild build \
  -project "${IOS_DIR}/HeadInClouds.xcodeproj" \
  -scheme HeadInClouds \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "id=${SIMULATOR_ID}" \
  -derivedDataPath "${IOS_DIR}/DerivedData" \
  CODE_SIGNING_ALLOWED=NO

step "Remote deploy config"
run_remote_with_env "npm run check:deploy --prefix ${REMOTE_APP_DIR}/server -- --profile=production"

step "Remote release preflight"
remote "npm run check:release --prefix ${REMOTE_APP_DIR}/server"

step "Remote App Store notification smoke"
run_remote_with_env "HIC_STAGING_BASE_URL=http://127.0.0.1:8787 npm run smoke:iap:app-store-notification --prefix ${REMOTE_APP_DIR}/server"

step "Remote latest PostgreSQL backup verification"
remote "sudo ${REMOTE_APP_DIR}/deploy/tencent-cloud/verify-latest-postgres-backup.sh"

if [[ "${RUN_IOS_SIMULATOR_SMOKE}" == "true" ]]; then
  step "iOS simulator staging smoke"
  SSH_HOST="${REMOTE_HOST}" \
  SSH_KEY="${SSH_KEY}" \
  SIMULATOR_ID="${SIMULATOR_ID}" \
  "${IOS_DIR}/scripts/simulator-staging-smoke.sh"
else
  step "iOS simulator staging smoke skipped"
  echo "Set RUN_IOS_SIMULATOR_SMOKE=true to launch the simulator and verify first-launch events."
fi

step "Git whitespace check"
(cd "${STARTUP_ROOT}" && git diff --check -- head_in_clouds)

echo
echo "Dev gate reachable checks passed. External/provider gates still require real account, real device, APNs, StoreKit, WeChat, SMS, and COS evidence."
