# Deploy / Dev Gate Notes — Head in the Clouds

> Current scope: local dev gate only. This document records how to run the local iOS app/server checks and what still blocks staging/TestFlight release. Do not create `head_in_clouds/.dev.manifest.json` until the dev gate fields can truthfully be set to `true`.

## 0. Current Tencent Cloud Staging Target

| Item | Value |
|---|---|
| CVM public IP | `101.43.4.247` |
| OS image | Ubuntu Server 22.04 LTS |
| Region | Shanghai / `ap-shanghai` |
| API base URL | Configured and externally verified: `https://api.headinclouds.cn`; emergency IP fallback: `http://101.43.4.247` |
| Share/legal base URL | Configured and externally verified: `https://headinclouds.cn`; emergency IP fallback: `http://101.43.4.247` |
| COS bucket | `headsincould-1305013589` |
| COS region | `ap-shanghai` |
| COS public base URL | `https://headsincould-1305013589.cos.ap-shanghai.myqcloud.com` |
| Domain | `headinclouds.cn`, `www.headinclouds.cn`, `api.headinclouds.cn` |
| HTTPS | Let's Encrypt certificate active on CVM; expires 2026-08-23; certbot timer enabled. Root, www, and api HTTPS health checks passed from this Mac on 2026-06-25; canonical HTTP to HTTPS redirect is active. |

IP-based staging remains an emergency fallback only. iOS staging and external review URLs should use the HTTPS domains unless a specific platform review form rejects them.

## 1. Local Verification Commands

Run from `/Users/zhongwowen.3/startup` unless noted otherwise.

```bash
npm test --prefix head_in_clouds/server
npm run smoke:events --prefix head_in_clouds/server
```

Run deployment config checks after staging env variables are available:

```bash
HIC_ADMIN_TOKEN=... DATABASE_URL=... npm run check:deploy --prefix head_in_clouds/server
```

Run release preflight against the live HTTPS domains:

```bash
npm run check:release --prefix head_in_clouds/server
```

Run the PostgreSQL migration after TencentDB for PostgreSQL is created:

```bash
DATABASE_URL=... npm run db:migrate --prefix head_in_clouds/server
```

Run from `/Users/zhongwowen.3/startup/head_in_clouds/ios`.

```bash
swift run HeadInCloudsCoreChecks
```

Run from `/Users/zhongwowen.3/startup`.

```bash
xcodebuild build \
  -project head_in_clouds/ios/HeadInClouds.xcodeproj \
  -scheme HeadInClouds \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination id=430D7F48-C297-4DB8-B6DE-5C60E17F6D9F \
  -derivedDataPath head_in_clouds/ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

```bash
xcodebuild test \
  -project head_in_clouds/ios/HeadInClouds.xcodeproj \
  -scheme HeadInClouds \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination id=430D7F48-C297-4DB8-B6DE-5C60E17F6D9F \
  -derivedDataPath head_in_clouds/ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Run repeatable iOS simulator -> Tencent Cloud event readback smoke:

```bash
SMOKE_RUN_ID=ios-script-smoke-YYYYMMDD-HHMM head_in_clouds/ios/scripts/simulator-staging-smoke.sh
```

Run the reachable dev gate aggregator:

```bash
head_in_clouds/scripts/dev-gate-local.sh
RUN_IOS_SIMULATOR_SMOKE=true head_in_clouds/scripts/dev-gate-local.sh
```

Latest local evidence:

| Check | Result | Evidence |
|---|---|---|
| Server unit tests | pass, 89/89 | `npm test --prefix head_in_clouds/server`; local and CVM tests passed 89/89 on 2026-05-26 after IAP product-catalog, StoreKit signed-transaction JWS guards, App Store Server Notifications V2 receiver skeleton, oversized JSON 413 handling, admin event dashboard, PostgreSQL backup-upload tests, and deploy-config fail-fast tests were added. The local suite was also rerun with `IOS_BUNDLE_ID=com.headintheclouds.app` to match the CVM bundle check path. |
| Reachable dev gate aggregator | pass historically; latest component evidence green | `RUN_IOS_SIMULATOR_SMOKE=true head_in_clouds/scripts/dev-gate-local.sh` passed on 2026-05-26 after the StoreKit `appAccountToken` wiring. On 2026-06-25 the aggregator rerun passed server tests 89/89, the IAP `appAccountToken` source guard, Swift core checks, Xcode simulator build, and remote deploy config, then hit a transient SSH connection close during remote release preflight. The same remote release preflight, App Store notification smoke, backup verification, and iOS simulator staging smoke were rerun individually and passed. |
| Baseline event smoke | pass, 6/6 | `npm run smoke:events --prefix head_in_clouds/server`; passed again on 2026-06-25. |
| PRD contract event smoke | pass, 75/75 | `npm run smoke:events:contract:local --prefix head_in_clouds/server`; passed again on 2026-06-25 with `smoke_run_id=contract-smoke-1782367422660-18df7358`. |
| Swift core checks | pass | `swift run --package-path head_in_clouds/ios HeadInCloudsCoreChecks`; passed on 2026-05-29 after the Add Flight / Flight Reminder empty-state, keyboard, and legacy fixture migration regression fixes. |
| Xcode Debug simulator build | pass | `xcodebuild build -project head_in_clouds/ios/HeadInClouds.xcodeproj -scheme HeadInClouds -configuration Debug -sdk iphonesimulator -destination id=430D7F48-C297-4DB8-B6DE-5C60E17F6D9F -derivedDataPath head_in_clouds/ios/DerivedData CODE_SIGNING_ALLOWED=NO`; passed on 2026-05-26. After native WeChat SDK wiring, `xcodebuild build -project head_in_clouds/ios/HeadInClouds.xcodeproj -scheme HeadInClouds -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath head_in_clouds/ios/DerivedData CODE_SIGNING_ALLOWED=NO` passed again on 2026-06-25. |
| Xcode Release simulator build with AppIcon | pass | `xcodebuild build -project head_in_clouds/ios/HeadInClouds.xcodeproj -scheme HeadInClouds -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`; passed on 2026-05-29. The built app includes `CFBundleIconName=AppIcon`, `Assets.car`, and `AppIcon60x60@2x.png`. |
| Xcode unsigned iOS archive verification | pass | `xcodebuild archive -project head_in_clouds/ios/HeadInClouds.xcodeproj -scheme HeadInClouds -configuration Release -destination 'generic/platform=iOS' -archivePath head_in_clouds/ios/DerivedData/Archives/HeadInClouds-UnsignedVerification.xcarchive CODE_SIGNING_ALLOWED=NO`; passed on 2026-05-29. This proves device archive compile/resource packaging succeeds, but it is not uploadable to TestFlight because signing is disabled. |
| Xcode real-device Debug build/install/launch | pass | `xcodebuild build -project head_in_clouds/ios/HeadInClouds.xcodeproj -scheme HeadInClouds -destination id=00008150-000C483A0C78401C -derivedDataPath head_in_clouds/ios/DerivedData build` passed on 2026-06-25 with Xcode 26.6 RC2 for `Jones's iPhone` on iOS 26.5.1. Debug bundle `com.headintheclouds.app.dev`, version `0.1.0 (2)`, was listed as installed, `xcrun devicectl device process launch --device 00008150-000C483A0C78401C com.headintheclouds.app.dev` succeeded, and founder visually confirmed the app was visible on device. |
| Native WeChat share composer | pass, real device, formal bundle | Device app inventory verified WeChat with `xcrun devicectl device info apps --device 950F4B9F-70A9-54CA-ADB9-DB9800ED58E0 --include-all-apps --bundle-id com.tencent.xin`, returning `WeChat`, bundle `com.tencent.xin`, version `8.0.75`. The first native share test on the dev bundle exposed a missing SDK linker flag crash: `+[WXApi genExtraUrlByReq:withAppData:]: unrecognized selector`; adding `-ObjC` and `-lc++` fixed it. On 2026-06-26 the formal Release bundle `com.headintheclouds.app` was installed with display name `云上心事`, URL scheme `wx8468c4582175e88e`, and associated domains `applinks:headinclouds.cn` / `applinks:www.headinclouds.cn`. After fixing the live WeChat Universal Link callback path from HTTP 404 to HTTP 200 and adding `weixinURLParamsAPI`, real-device XCUITest verified the actual WeChat composer surfaces: `testNativeWeChatShareOpensWeChatWhenEnabled` passed with result bundle `/tmp/hic-wechat-share-chat-after-ulfix-20260626.xcresult` and saw friend-send composer signals; `testNativeWeChatMomentsShareOpensWeChatWhenEnabled` passed with `/tmp/hic-wechat-share-moments-after-ulfix-20260626.xcresult` and saw the Moments publish composer. Final send/publish confirmation callback is still a separate manual/provider action and has not been completed to avoid posting test content. |
| Xcode current-code signed archive | pass | `xcodebuild archive -project head_in_clouds/ios/HeadInClouds.xcodeproj -scheme HeadInClouds -configuration Release -destination 'generic/platform=iOS' -archivePath head_in_clouds/ios/DerivedData/Archives/HeadInClouds-LegacyRegressionFix-Build2.xcarchive -allowProvisioningUpdates -allowProvisioningDeviceRegistration` passed on 2026-05-29 after the legacy regression fix and build-number bump to `0.1.0 (2)`. |
| Xcode signed TestFlight archive/upload | pass, processing pending | `xcodebuild -exportArchive -archivePath head_in_clouds/ios/DerivedData/Archives/HeadInClouds-LegacyRegressionFix-Build2.xcarchive -exportOptionsPlist /tmp/head-in-clouds-upload-options.plist -exportPath /tmp/head-in-clouds-export-build2 -allowProvisioningUpdates` uploaded build `0.1.0 (2)` to App Store Connect at 15:57; output ended with `Uploaded package is processing`, `Upload succeeded`, `Uploaded HeadInClouds`, and `** EXPORT SUCCEEDED **`. TestFlight processing/availability still needs confirmation. |
| Xcode signing settings | pass | `DEVELOPMENT_TEAM=K338A7B5QX`; Debug bundle is `com.headintheclouds.app.dev` with `APS_ENVIRONMENT=development`; Release bundle is `com.headintheclouds.app` with `APS_ENVIRONMENT=production`; entitlements include Associated Domains and APNs. |
| Xcode UI smoke | pass, 15/15 | `xcodebuild test -project head_in_clouds/ios/HeadInClouds.xcodeproj -scheme HeadInClouds -configuration Debug -sdk iphonesimulator -destination id=430D7F48-C297-4DB8-B6DE-5C60E17F6D9F -derivedDataPath head_in_clouds/ios/DerivedData CODE_SIGNING_ALLOWED=NO`; passed on 2026-06-25. Result bundle: `/Users/zhongwowen.3/startup/head_in_clouds/ios/DerivedData/Logs/Test/Test-HeadInClouds-2026.06.25_14-10-16-+0800.xcresult`. Covered Add Flight, Card Studio feedback, quote editor keyboard/publish loop, returning-user relaunch, compose keyboard/tabs, discovery tabs, first-run private-card flow, flight context hydration guards, Flight Reminder, legacy fixture migration, opening/settings feedback, published-post relaunch, ticket proof buttons, human relaunch fixture cleanup, and verified same-flight publish. |
| Domain HTTPS health | pass | On 2026-06-25, `https://headinclouds.cn/health`, `https://www.headinclouds.cn/health`, and `https://api.headinclouds.cn/health` returned HTTP 200 from this Mac. `https://headinclouds.cn/` returned HTTP 200 and includes `云上心事`. |
| Domain HTTP redirect | pass | On 2026-06-25, `http://headinclouds.cn/health` returned HTTP 301 to `https://headinclouds.cn/health`, matching canonical release preflight expectations. |
| Public homepage fallback | pass, emergency only | `http://101.43.4.247/` returns HTTP 200 and includes `云上心事` / `给这一趟飞行，留下一句话`; keep it only as an emergency fallback because the HTTPS domain is now externally reachable. |
| IP staging health | pass | `curl -s http://101.43.4.247/health` -> `{"ok":true}` |
| IP staging readiness | pass | `curl -s http://101.43.4.247/health/ready` -> `ok=true`, `event_store.kind=postgres`, `app_store.kind=postgres` after the 2026-05-25 17:23 CST deployment. |
| SMS provider fail-closed | pass | `POST http://101.43.4.247/api/auth/sms/send` with a valid Bearer account returns HTTP 400 `sms provider is not configured` while `HIC_SMS_PROVIDER=disabled`. |
| SMS challenge table | pass | CVM PostgreSQL contains `public.sms_challenges` owned by `hic_app` after migration. |
| Object storage fail-closed | pass locally + IP staging | `POST /api/share-cards/render` is authenticated, owner-scoped, redacts exact public seat values, and returns HTTP 400 when object storage is not configured; local and CVM server tests passed 89/89 on 2026-05-26, and IP staging smoke returned `post_status=201`, `render_status=400`, `render_error=object storage provider is not configured`. |
| Structured request logs | pass | `journalctl -u head-in-clouds-api.service -n 20 --no-pager` shows JSON `http_request` with `request_id`, method, path-only URL, status, and duration. |
| Oversized JSON body guard | pass | `POST /events` now returns HTTP 413 `body_too_large` for request bodies over 64 KiB instead of dropping the connection; local and CVM server tests passed 89/89 on 2026-05-26. |
| Admin event dashboard | pass | `GET https://api.headinclouds.cn/api/admin/events/dashboard` is protected by `HIC_ADMIN_TOKEN` via Bearer or Basic Auth, renders event coverage/recent rows from PostgreSQL, and returns HTTP 401 with `WWW-Authenticate` when unauthenticated. CVM HTTPS smoke returned HTTP 200 `text/html; charset=utf-8` with `Event Dashboard`, expected event chips, and no exact seat leak. |
| PostgreSQL local backup | pass | `sudo /opt/head_in_clouds/current/deploy/tencent-cloud/backup-postgres.sh` created `/opt/head_in_clouds/backups/postgres/head_in_clouds-20260526T065344Z.dump` and `.sha256` on the CVM, with checksum + `pg_restore --list` validation before upload/rotation and upload skipped as expected because `UPLOAD_BACKUP_TO_OBJECT_STORAGE=false`. `sudo /opt/head_in_clouds/current/deploy/tencent-cloud/verify-latest-postgres-backup.sh` returned `Backup verification passed` for the same dump, 46881 bytes. Real COS upload evidence is still pending COS write credentials. |
| IP staging baseline event readback | pass | PostgreSQL `event_logs` readback contains `signup_completed`, `user_returned`, `core_action_completed`, `paywall_viewed`, `checkout_started`, server-side `subscription_created`; sampled at `2026-05-25 12:32 CST`. |
| Repeatable staging event smoke | pass, 6/6 | `npm run smoke:events:staging --prefix server` on CVM, `smoke_run_id=staging-smoke-1779689220792-3a1406a2`; baseline evidence ids: `4ec2a976-4a10-43eb-9982-e34d69553f59`, `1d32d9db-fe01-4e5f-8ab6-aa2e4f1bfaca`, `c53b0e28-daeb-419b-b3e7-f6cbe18ed58d`, `f98e30b5-4f2a-4aaa-85f9-8078918021a9`, `a0f0ef6f-6d7c-44da-b32b-a63086ae8127`, `b19cfb35-7bf2-458a-a1bc-a8cd9bd22803`. |
| Repeatable staging contract event smoke | pass, 75/75 | `npm run smoke:events:contract --prefix server` on CVM, `smoke_run_id=contract-smoke-1779693843680-4741f8b8`; PostgreSQL readback includes all synthetic PRD event names/properties, screen-prefixed `01a_landing_viewed` / `01b_landing_viewed`, and server-side `subscription_created=1c9ed435-cb05-4230-941d-c6679c7c2a60`. |
| Staging event summary query | pass, missing 0 | `npm run smoke:events:summary --prefix server` on CVM with `HIC_SMOKE_RUN_ID=ios-storekit-smoke-20260525-1518`; returned `total_events=2`, `missing_event_names=[]` for first-launch events. |
| AASA + WeChat Universal Link callback | pass with final app id | CVM HTTPS check returns `appID=K338A7B5QX.com.headintheclouds.app` and paths `/share/*`, `/wechat/*`, `/flight-spaces/*`, `/cards/*`. `https://headinclouds.cn/wechat/` now returns HTTP 200 HTML instead of 404, and real-device WeChat share composer tests pass for both friend and Moments paths. |
| Legal pages fallback | pass | `curl -i http://101.43.4.247/privacy` and `/terms` -> HTTP 200 `text/html; charset=utf-8`; GET bodies contain `隐私政策` and `用户协议`. |
| Release preflight on CVM | pass, 25/25 | `npm run check:release --prefix /opt/head_in_clouds/current/server` on the CVM passed root/www/api health, homepage, canonical HTTP redirect, readiness, IAP placeholder JWS guard, legal pages, final AASA app id, AASA paths, iOS HTTPS config, bundle ids, signing team, APNs entitlement/environments, associated domains, ATS, and IP-staging config on 2026-06-25. |
| Production deploy config on CVM | pass, recommended missing 0 | `deploy/tencent-cloud/deploy-host-systemd.sh` now loads the remote `.env.server` and runs `npm run check:deploy --prefix server -- --profile=production` after provisioning. The integrated check returned `ok=true`, `recommended_missing=[]`, and `production_missing_but_not_required_for_staging=[]` on 2026-05-26. The check parses the IAP JSON and fails fast on bad env quoting, unsupported object-storage provider values, `UPLOAD_BACKUP_TO_OBJECT_STORAGE=true` without Tencent COS, and incomplete Tencent COS credentials. |
| Release preflight from local workspace | pass, 25/25 | `npm run check:release --prefix head_in_clouds/server` passed from this Mac on 2026-06-25. This verifies the local network path to the public HTTPS domains, not just CVM-local reachability. |
| APNs provider config | pass, credentials loaded | CVM env now uses `APNS_TEAM_ID=K338A7B5QX`, `APNS_KEY_ID=JHT8332488`, `APNS_BUNDLE_ID=com.headintheclouds.app`, and `APNS_PRIVATE_KEY_FILE=/opt/head_in_clouds/secrets/apns/AuthKey_JHT8332488.p8`; server smoke loaded the key file and constructed a signed APNs request. |
| IAP product catalog guard | pass | Server-side `HIC_IAP_PRODUCTS_JSON='{"hic.postcard.plus":{"plan":"postcard_plus","amount":12,"currency":"CNY"}}'` is configured on CVM. `/api/iap/transactions/verify` rejects unknown products and amount/plan/currency mismatches instead of trusting client-provided payment metadata; live HTTPS tamper smoke on 2026-05-26 returned HTTP 400 `amount does not match configured product`. |
| App Store Connect IAP product | product created, verification pending | App Store Connect product `Postcard Plus` was created with product ID `hic.postcard.plus` and Apple ID `6773321108`. This unblocks StoreKit product lookup once the build and IAP metadata are review-ready, but release still needs sandbox tester purchase evidence and App Store Server Notification delivery evidence. |
| StoreKit signed transaction JWS guard | pass locally + HTTPS staging | Sandbox/production `/api/iap/transactions/verify` now requires a non-placeholder StoreKit signed transaction JWS shape, `ES256` header, `x5c`, and matching `transactionId` / `originalTransactionId` / `productId` / `environment` / bundle ID payload fields before the server accepts the transaction. CVM-side public HTTPS smoke on 2026-05-26 rejected `header.payload.signature` with HTTP 400 `signed_transaction_jws is invalid`. This is a structure/payload guard, not full Apple certificate-chain verification; StoreKit sandbox purchase evidence is still required. |
| StoreKit app account token wiring | pass locally | iOS checkout now calls StoreKit with `Product.PurchaseOption.appAccountToken(account.id)`, so App Store Server Notifications can include the same UUID and be linked to the first-party account. Xcode Debug simulator build passed on 2026-05-26, and `scripts/dev-gate-local.sh` includes a source guard for this wiring. Real StoreKit sandbox transaction evidence is still required. |
| App Store Server Notifications V2 receiver | pass locally + CVM tests + CVM structural smoke; ASC URL configured | `POST /api/iap/app-store/notifications` accepts unauthenticated Apple-style `signedPayload` only when the JWS shape, `ES256` header, `x5c`, bundle ID, environment, and nested `signedTransactionInfo` payload are valid. `SUBSCRIBED` / `DID_RENEW` / `DID_RECOVER` / `ONE_TIME_CHARGE` with `appAccountToken` can materialize a server-side subscription and emit `subscription_created`; `REFUND` records only `app_store_server_notification_received` and does not create an active subscription. Unit coverage is included in the 89/89 server suite, and the structural smoke is part of `scripts/dev-gate-local.sh`. Latest CVM smoke on 2026-06-25 used `assn-smoke-1782367490813-2bd02ac6` and wrote `app_store_server_notification_received=6df6fc27-a5f6-4ce3-8987-0b2ef226e465` and `subscription_created=c2490ed8-ad77-4fe3-a23e-79441a61245d`. App Store Connect Server Notification URL is configured to `https://api.headinclouds.cn/api/iap/app-store/notifications`; real Apple delivery evidence and Apple certificate-chain verification are still pending. |
| Notification dispatch units | pass, timer intentionally disabled | `systemctl cat head-in-clouds-notification-dispatch.service/timer` shows a 60s timer; `systemctl is-enabled` and `is-active` both return disabled/inactive because `HIC_NOTIFICATION_DISPATCH_ENABLED` remains false until real-device push-token delivery testing. |
| Historical IP iOS simulator launch -> staging events | pass, superseded by HTTPS smoke | Built, installed, and launched simulator app with `HEAD_IN_CLOUDS_API_BASE_URL=http://101.43.4.247` and `HIC_ANALYTICS_SMOKE_RUN_ID=ios-launch-smoke-20260525-1459`; staging summary returned `total_events=2`, `missing_event_names=[]`, with `app_first_launched=1` and `onboarding_step_viewed=1`. |
| iOS bundle HTTPS config -> staging events | pass | `HeadInClouds.app/Info.plist` expands `HEAD_IN_CLOUDS_API_BASE_URL=https://api.headinclouds.cn`, `HEAD_IN_CLOUDS_EVENTS_URL=https://api.headinclouds.cn/events`, and `HEAD_IN_CLOUDS_SHARE_BASE_URL=https://headinclouds.cn`. Latest simulator staging smoke on 2026-06-25 used `SMOKE_RUN_ID=ios-simulator-staging-smoke-20260625-140603`; it built, installed, launched, and remote summary returned `total_events=2`, `missing_event_names=[]`, with `app_first_launched=1` and `onboarding_step_viewed=1`. |
| Built iOS ATS policy | pass | Built `HeadInClouds.app/Info.plist` contains only `NSAllowsLocalNetworking=true` under `NSAppTransportSecurity`; no `NSExceptionDomains` / `101.43.4.247` HTTP exception remains. |
| Real-device XCUITest full smoke | pass, 15/15 | After enabling iOS Developer UI Automation on 2026-06-25, `xcodebuild test -project head_in_clouds/ios/HeadInClouds.xcodeproj -scheme HeadInClouds -destination id=00008150-000C483A0C78401C -derivedDataPath head_in_clouds/ios/DerivedData -resultBundlePath /tmp/hic-g1-realdevice-full-20260625-202257.xcresult` passed on `Jones's iPhone`: 15 tests, 0 failures. It covers Add Flight, Flight Reminder, keyboard show/dismiss, compose input modes, card studio feedback/editor/publish loop, discovery tabs, first-run private-card publish/copy/share navigation, relaunch persistence, fixture cleanup, and verified same-flight publish with ticket-proof OCR mock path. |

## 2. Local Runtime

Start the local server:

```bash
npm start --prefix head_in_clouds/server
```

Default local server port: `8787`.

Optional local environment:

| Key | Side | Purpose |
|---|---|---|
| `PORT` | server | Local API port. Defaults to `8787`. |
| `HIC_ADMIN_TOKEN` | server | Enables `GET /api/admin/events/recent` for staging/local event readback. |
| `DATABASE_URL` | server | PostgreSQL connection string for staging/production event logs and app data persistence. |
| `HIC_EVENT_STORE` | server | `postgres` in staging/production; defaults to `postgres` when `DATABASE_URL` exists and `file` otherwise. |
| `HIC_APP_STORE` | server | `postgres` in staging/production; defaults to `postgres` when `DATABASE_URL` exists and `file` otherwise. |
| `DATABASE_SSL_MODE` | server | `disable`, `require`, or `no-verify`. Use the TencentDB setting; do not guess in production. |
| `DATABASE_POOL_MAX` | server | PostgreSQL connection pool max. Start with `5` for 2C4G. |
| `HIC_REQUEST_LOGS` | server | Set `false` to disable structured JSON request logs; enabled by default for the Node service. |
| `HIC_LEGAL_CONTACT_EMAIL` | server | Contact email rendered on `/privacy` and `/terms`; replace placeholder before external release. |
| `HIC_NOTIFICATION_DISPATCH_ENABLED` | server | Set `true` only after APNs credentials are configured; otherwise timer stays disabled. |
| `HIC_PUSH_PROVIDER` | server | `apns` by default; `memory` is allowed only for local smoke, never production. |
| `NOTIFICATION_DISPATCH_INTERVAL` | server | systemd timer interval for due notification dispatch, default `60s`. |
| `NOTIFICATION_DISPATCH_LIMIT` | server | Max due notification jobs per dispatch run, default `50`. |
| `HIC_SMS_PROVIDER` | server | `disabled` by default; set `mock` only for staging QA code smoke, later `tencent` after real SMS provider integration. |
| `HIC_SMS_MOCK_CODE` | server | Mock provider verification code for non-production smoke, default `123456`. Do not use as production auth. |
| `TENCENTCLOUD_SECRET_ID` / `TENCENTCLOUD_SECRET_KEY` | server | Tencent Cloud API credentials for SMS provider only. Store as server secret, never in app or git. |
| `HIC_TENCENT_SMS_REGION` | server | Tencent SMS API region, defaults to `ap-guangzhou`. |
| `HIC_TENCENT_SMS_SDK_APP_ID` | server | Tencent SMS application SDK AppID, for example `1400006666`. |
| `HIC_TENCENT_SMS_SIGN_NAME` | server | Approved Tencent SMS signature name. |
| `HIC_TENCENT_SMS_TEMPLATE_ID` | server | Approved Tencent SMS verification-code template ID. |
| `HIC_WECHAT_PROVIDER` | server | `disabled` by default; set `wechat` only after WeChat Open Platform app approval and callback wiring. `mock` is local/staging-only. |
| `HIC_WECHAT_APP_ID` | server | WeChat Open Platform mobile app AppID for WeChat login token exchange. For iOS share registration, the same public AppID is also present in client Info.plist / URL Scheme. |
| `HIC_WECHAT_APP_SECRET` | server | WeChat Open Platform mobile app AppSecret for server-side login token exchange only. Store as server secret, never in iOS, Android, web client, git, docs, screenshots, or chat. If exposed in chat, rotate before use. |
| `HIC_IAP_PRODUCTS_JSON` | server | Server-authoritative StoreKit product catalog, for example `'{"hic.postcard.plus":{"plan":"postcard_plus","amount":12,"currency":"CNY"}}'`. Must be quoted when sourced by shell/systemd env files. |
| `HIC_OBJECT_STORAGE_PROVIDER` | server | `disabled` by default; set `tencent_cos` only after `COS_SECRET_ID` / `COS_SECRET_KEY` are configured. |
| `COS_BUCKET` / `COS_REGION` / `COS_PUBLIC_BASE_URL` | server | Tencent COS bucket identity and public base URL for rendered cards and redacted proof assets. |
| `COS_SECRET_ID` / `COS_SECRET_KEY` | server | Tencent COS write credentials. Store as server secret, never in app or git. |
| `HIC_BACKUP_OBJECT_PREFIX` | server / backup cron | COS object prefix for PostgreSQL backup uploads. Defaults to `backups/postgres`; only used when `UPLOAD_BACKUP_TO_OBJECT_STORAGE=true` is passed to `backup-postgres.sh`. |
| `HIC_APP_STORE_PATH` | server | Local JSON fallback path when `HIC_APP_STORE=file`. |
| `HEAD_IN_CLOUDS_API_BASE_URL` | iOS | First-party API base URL for posts, accounts, reminders, purchase verification, and default event/share URLs. |
| `HEAD_IN_CLOUDS_EVENTS_URL` | iOS | Explicit `/events` URL override if different from API base. |
| `HEAD_IN_CLOUDS_SHARE_BASE_URL` | iOS | Public share landing base URL for Cloud Card links. |
| `APPLE_APP_ID_PREFIX` | server | Apple Team ID / App ID prefix for AASA Universal Links. |
| `IOS_BUNDLE_ID` | server | Final iOS Bundle ID for AASA Universal Links. |
| `IOS_ASSOCIATED_DOMAIN_PATHS` | server | Comma-separated AASA paths. Defaults include `/share/*`, `/wechat/*`, `/flight-spaces/*`, and `/cards/*`. |
| `APNS_TEAM_ID` | server | Apple Developer Team ID for APNs provider token. |
| `APNS_KEY_ID` | server | APNs auth key ID. |
| `APNS_BUNDLE_ID` | server | Final iOS bundle identifier. |
| `APNS_PRIVATE_KEY` | server | APNs `.p8` private key content from secret manager only. |
| `APNS_PRIVATE_KEY_FILE` | server | Preferred CVM/systemd setting: path to a 600-permission APNs `.p8` file, so multiline private-key content is not stored directly in the env file. |
| `APNS_USE_SANDBOX` | server | Defaults to sandbox unless set to `false`. |

Secrets must stay in local env, CI secrets, or cloud secret manager. Do not commit `.env.local`, APNs `.p8`, provisioning profiles, WeChat secrets, SMS keys, DB credentials, or analytics provider keys.

WeChat secret placement:

- Native WeChat share on iOS needs only the approved public AppID, URL Scheme, and Universal Link. It must not use AppSecret.
- WeChat login needs `HIC_WECHAT_APP_SECRET` on the server only. Local development may use `head_in_clouds/server/.env.local`; Tencent CVM production/staging uses the server-side environment file or cloud Secret Manager that feeds the systemd service environment. Do not put it in `head_in_clouds/ios/App/Info.plist`, Xcode build settings, JavaScript bundles, or checked-in `.env.example` files.
- If the founder must act, the minimal request is: generate/rotate AppSecret in WeChat Open Platform, paste it into the specified server secret location, save, and reply `微信 Secret 已换`. The agent then restarts the service and verifies `/api/auth/wechat/exchange`.

## 3. Dev Gate Status

| Gate field | Current local status | Why not complete yet |
|---|---|---|
| `build_passed` | Locally yes for Swift core checks, simulator build, server/CVM gates, Release simulator build, real-device Debug build/install/launch, native WeChat SDK-linked simulator build, and App Store Connect upload of `0.1.0 (2)` | TestFlight processing/availability and internal tester install evidence are still pending, so this is not yet installable release-candidate evidence. |
| `e2e_passed` | Partial, current simulator UI smoke green | Fresh 2026-06-25 simulator XCUITest evidence passed 15/15, covering Add Flight, Card Studio, compose/discovery tabs, first-run private-card flow, reminder/form regressions, fixture cleanup, relaunch behavior, and verified same-flight publish. This is still narrower than the full PRD 23-screen P0/P1 matrix and does not replace real-device/manual provider walkthrough. |
| `manual_walkthrough` | Partial | Real-device Debug build/install/launch passed on 2026-06-25 and founder visually confirmed the app was visible. Real-device full XCUITest passed 15/15 for core app flows including Add Flight, Flight Reminder, keyboard show/dismiss, share-copy navigation, relaunch behavior, and verified same-flight publish. Native WeChat share composer tests passed on the formal `com.headintheclouds.app` Release bundle for both `微信` friend-send and `朋友圈` publish surfaces. Still missing non-automated or provider-backed real-device evidence: final WeChat send/publish confirmation callback, real camera/photo OCR on real media, non-WeChat iOS share sheet target behavior, local notification scheduling/delivery, offline/reconnect against real network toggles, and APNs routing. |
| `analytics_contract_verified` | Partial | HTTPS staging `/events` + PostgreSQL readback works for baseline 6, synthetic PRD contract smoke 75/75, admin event dashboard, server-side IAP product-catalog guard, StoreKit signed-transaction JWS structure/payload guard, App Store Server Notifications V2 receiver skeleton, ASC Server Notification URL configuration, and iOS simulator launch events. Still missing real UI/provider full-event evidence, CLS/provider evidence if required, StoreKit sandbox purchase evidence, full Apple certificate-chain verification, real Apple notification delivery evidence, WeChat login live evidence, SMS live evidence, and APNs delivery evidence. |

Current highest truthful state: domain/release preflight, local/server tests, simulator staging smoke, real-device Debug build/install/launch, real-device full XCUITest 15/15, and native WeChat friend/Moments composer handoff are green. Production/staging dev gate is not complete because TestFlight install evidence, non-automated real-device/provider walkthrough items, and real provider evidence are still missing.

## 4. External Setup Required Before Release Gate

Release gate actions and owners:

| Area | Owner | Required action / remaining evidence |
|---|---|---|
| Apple Developer / TestFlight | Agent, founder only for App Store Connect login/2FA or review decisions | Final Bundle ID, APNs key, Associated Domains server file, App Store Connect app record, iOS AppIcon packaging, real-device development signing, and App Store Connect upload of build `0.1.0 (2)` are configured. Still need build processing/TestFlight availability verification and internal tester install evidence. |
| China cloud | Agent | Tencent CVM, local PostgreSQL, HTTPS domain, release preflight, and backup verification are active. Still configure any remaining provider secrets, COS off-server backup credentials if needed, and production hardening. |
| Event pipeline | Agent | First-party `/events`, PostgreSQL readback, and token-protected admin event dashboard are deployed. Still capture real UI/provider PRD custom event evidence and configure CLS/provider export only if required. |
| APNs | Agent, founder only for Apple portal login/2FA if credential rotation is needed | APNs auth key and CVM env are configured. Still need real-device push-token registration, APNs delivery evidence, and then enabling the notification dispatcher. |
| StoreKit | Agent, founder only for App Store Connect review/metadata decisions | IAP product `hic.postcard.plus` / `Postcard Plus` / Apple ID `6773321108` exists, sandbox tester exists, App Store Server Notification URL is configured, and the server catalog is configured for the product. Still attach/submit IAP with the App version as required by App Store Connect, run sandbox purchase through first-party verification, and capture real `subscription_created`. |
| WeChat | Agent for native share and server wiring; founder only for WeChat Open Platform login/2FA, approval decisions, and AppSecret rotation/paste when the control plane cannot be proxied | WeChat Open Platform mobile app has been approved and AppID is available. Native iOS share is wired with AppID + URL Scheme + Universal Link and real-device composer tests passed against installed WeChat `com.tencent.xin` 8.0.75 on the formal `com.headintheclouds.app` Release bundle for both `微信` friend-send and `朋友圈` publish surfaces. Share does not require AppSecret. Still need final send/publish confirmation callback evidence if we decide to post/send a test item. Login server secret is configured on CVM, but iOS login SDK/callback and live login evidence are still pending. |
| SMS | Founder/admin for signature/template approval; agent after credentials are issued | Register domestic SMS signature/template and configure server-side send/verify endpoints after provider credentials are available. |
| Domain/legal | Agent, founder only for final legal copy/company filing decisions | HTTPS domain, homepage, privacy page, terms page, and AASA endpoint are live. Still replace final legal contact/copy and complete ICP/APP filing if required by the release channel. |
| Crash monitoring | Agent | Pick China-reachable crash reporting and verify a test crash from device/network. |

## 5. Release Boundary

Allowed before external setup:

- Continue iOS feature work behind adapters and mocks.
- Expand XCUITest coverage for PRD P0/P1 flows.
- Expand server tests and local event smoke readback.
- Improve local share landing and card rendering.
- Wire redacted proof-image upload into COS after proof image lifecycle policy is finalized.
- Build and deploy the Node server container after TencentDB PostgreSQL and staging env vars exist.

Not allowed to mark complete before external setup:

- `analytics_contract_verified=true`
- APNs delivery complete
- StoreKit payment verified
- WeChat login verified
- WeChat share final send/publish confirmation callback verified
- SMS verification provider complete
- TestFlight build processing/availability and internal tester install pending verification

## 6. Backend Deployment Shape

Current staging-ready shape:

```text
iOS app
  -> HTTPS API domain
  -> CVM systemd Node server
  -> local PostgreSQL event_logs on CVM
  -> local PostgreSQL app data tables on CVM
  -> COS for rendered share cards when configured; redacted proofs later
  -> CLS by collecting structured Node process logs and reverse proxy logs
```

Server artifacts:

| Artifact | Purpose |
|---|---|
| `server/Dockerfile` | Container image for CVM or Tencent container runtime. |
| `server/.env.example` | Non-secret env template. |
| `scripts/dev-gate-local.sh` | Aggregates the currently reachable local + CVM dev checks; optional `RUN_IOS_SIMULATOR_SMOKE=true` includes simulator event readback. |
| `deploy/tencent-cloud/.env.server.example` | Tencent Cloud staging env template with non-secret resource identifiers. |
| `deploy/tencent-cloud/docker-compose.yml` | Docker deployment path; currently not used because Docker Hub image pulls time out from the CVM. |
| `deploy/tencent-cloud/nginx-head-in-clouds.conf` | IP-based Nginx reverse proxy for fallback staging `/health` and API smoke; HTTPS domain config is applied by `enable-https.sh`. |
| `deploy/tencent-cloud/provision-ubuntu.sh` | One-time Ubuntu 22.04 provisioning script for Docker, Nginx, and firewall. |
| `deploy/tencent-cloud/deploy-to-cvm.sh` | SSH/rsync deploy wrapper. Requires local SSH key path and server-side `.env.server`. |
| `deploy/tencent-cloud/provision-host-systemd.sh` | Docker Hub fallback: installs Node from npmmirror, local PostgreSQL from apt, and systemd API service. |
| `deploy/tencent-cloud/deploy-host-systemd.sh` | Host-level deploy wrapper used when Docker Hub image pulls fail; now runs remote production `check:deploy` with `.env.server` after provisioning. |
| `deploy/tencent-cloud/backup-postgres.sh` | Creates restricted-permission `pg_dump --format=custom` backups for the CVM PostgreSQL database, verifies checksum + `pg_restore --list`, optionally uploads dump/checksum to object storage, and rotates old dumps. |
| `deploy/tencent-cloud/verify-latest-postgres-backup.sh` | Read-only CVM backup verifier for the newest dump/checksum pair. |
| `server/scripts/upload-backup-to-object-storage.mjs` | Uploads validated `head_in_clouds-*.dump` and `.sha256` files to the configured private object-storage prefix. |
| `deploy/tencent-cloud/enable-https.sh` | Domain-ready HTTPS setup: writes the Nginx server block and runs Certbot after DNS points to the CVM. |
| `ios/scripts/simulator-staging-smoke.sh` | Builds the simulator app, installs/launches it, and verifies first-launch events through the Tencent Cloud staging event summary endpoint. |
| `server/scripts/check-deploy-config.mjs` | Fails fast when required staging env vars are missing. |
| `server/scripts/migrate-postgres.mjs` | Applies `schema/001_initial.sql` to TencentDB PostgreSQL. |
| `server/scripts/contract-event-smoke.mjs` | Validates all PRD event names/properties against local or staging `/events` + admin readback. |
| `server/scripts/staging-event-summary.mjs` | Queries admin event summary by smoke run and fails when expected PRD events are missing. |
| `server/src/associated-domains.mjs` | Serves AASA JSON for Apple Universal Links and WeChat iOS Universal Link callback paths. |
| `server/src/server.mjs` | Serves `/health`, `/health/ready`, first-party API routes, share landing pages, AASA, and path-only structured request logs. |
| `server/src/admin-dashboard.mjs` | Renders token-protected event coverage and recent-event HTML for staging analytics evidence. |
| `server/src/legal-pages.mjs` | Serves China-market privacy policy and terms HTML skeletons at `/privacy` and `/terms`. |
| `server/src/dispatch-notifications.mjs` | Runs due notification dispatch with APNs by default; memory provider requires explicit local-only env. |
| `head-in-clouds-notification-dispatch.service/timer` | systemd notification scheduler created by host provisioning; disabled until `HIC_NOTIFICATION_DISPATCH_ENABLED=true`. |
| `server/src/postgres-event-store.mjs` | Production event store implementation for `event_logs`. |
| `server/src/postgres-app-store.mjs` | PostgreSQL-backed app-data store for accounts, flight contexts, posts, comments, reports, tokens, jobs, and subscriptions. |
| `server/src/store-factory.mjs` | Selects file vs PostgreSQL event/app stores from env. |

Current app-data persistence: staging uses PostgreSQL app tables through `PostgresSnapshotAppStore`; `FileAppStore` remains only as local fallback. This is acceptable for staging but should be replaced by fine-grained SQL repository methods before high-concurrency production traffic.

Current infrastructure decision: TencentDB for PostgreSQL is deferred because the quoted managed database price is too high for staging. IP staging uses PostgreSQL on the existing CVM. Move to TencentDB only after real usage justifies managed backup/high availability.

Manual PostgreSQL backup on the CVM:

```bash
sudo /opt/head_in_clouds/current/deploy/tencent-cloud/backup-postgres.sh
```

Expected result: a restricted-permission dump under `/opt/head_in_clouds/backups/postgres/` plus a `.sha256` checksum. The script fails before upload/rotation if checksum verification or `pg_restore --list` fails. Default retention is 7 days; override with `RETENTION_DAYS=14` if needed.

Verify the latest local backup without creating a new dump:

```bash
sudo /opt/head_in_clouds/current/deploy/tencent-cloud/verify-latest-postgres-backup.sh
```

Expected result: `Backup verification passed: ...` with the latest `.dump` path and byte size.

Off-server backup upload is opt-in until least-privilege COS write credentials are configured:

```bash
sudo UPLOAD_BACKUP_TO_OBJECT_STORAGE=true \
  /opt/head_in_clouds/current/deploy/tencent-cloud/backup-postgres.sh
```

Expected result after COS credentials exist: the script uploads both the `.dump` and `.sha256` objects under `HIC_BACKUP_OBJECT_PREFIX` using private ACL. Without `HIC_OBJECT_STORAGE_PROVIDER=tencent_cos` and `COS_SECRET_ID` / `COS_SECRET_KEY`, the upload path fails closed and the local dump remains on disk.

Optional daily cron:

```bash
sudo crontab -e
15 3 * * * /opt/head_in_clouds/current/deploy/tencent-cloud/backup-postgres.sh >> /var/log/head-in-clouds-backup.log 2>&1
```

## 7.5 Domain / HTTPS Setup

Use this after a real domain or subdomain resolves to `101.43.4.247`.
For release preflight, keep canonical HTTP → HTTPS redirect enabled. If a temporary HTTP fallback is ever needed for an external review form, pass `HIC_FORCE_HTTPS_REDIRECT=false` explicitly and treat release preflight as blocked until redirect is restored.

```bash
ssh -i /Users/zhongwowen.3/.ssh/head-in-clouds-tencent.pem -o IdentitiesOnly=yes ubuntu@101.43.4.247
cd /opt/head_in_clouds/current
sudo HIC_DOMAIN=headinclouds.cn HIC_ALT_DOMAINS="www.headinclouds.cn api.headinclouds.cn" HIC_FORCE_HTTPS_REDIRECT=true deploy/tencent-cloud/enable-https.sh
curl -s http://101.43.4.247/
curl -s https://headinclouds.cn/health
curl -s https://api.headinclouds.cn/health/ready
```

Expected result:

```json
{"ok":true}
```

The 2026-05-25 setup used Let's Encrypt without a contact email and succeeded for all three domains.

HTTPS verification status:

- Done: iOS `HEAD_IN_CLOUDS_API_BASE_URL=https://api.headinclouds.cn`.
- Done: iOS `HEAD_IN_CLOUDS_EVENTS_URL=https://api.headinclouds.cn/events`.
- Done: iOS `HEAD_IN_CLOUDS_SHARE_BASE_URL=https://headinclouds.cn`.
- Done: temporary ATS exception for `101.43.4.247` removed from `ios/App/Info.plist`.
- Done: iOS launch smoke and event readback passed with `SMOKE_RUN_ID=ios-simulator-staging-smoke-20260625-140603`.
- Done: `https://headinclouds.cn/.well-known/apple-app-site-association` contains final app id `K338A7B5QX.com.headintheclouds.app`.
- Pending: verify Universal Link open behavior from TestFlight or real-device release install.

Current deployed service:

| Component | Status |
|---|---|
| Nginx | active, proxies `:80` to `127.0.0.1:8787` |
| Node API | active via `head-in-clouds-api.service` |
| PostgreSQL | active on CVM, database `head_in_clouds`, user `hic_app` |
| Schema migration | applied through `npm run db:migrate` |
| App data smoke | passed on CVM; `accounts`, `flight_contexts`, and `cloud_posts` each contain the `app-smoke-1779687836132-25b353d3` fixture row |

## 7. Staging Deploy Commands

These commands require an SSH private key path. Do not paste the key content into chat.

One-time CVM provisioning:

```bash
SSH_HOST=root@101.43.4.247
SSH_KEY=/path/to/tencent-cvm.pem
scp -i "$SSH_KEY" head_in_clouds/deploy/tencent-cloud/provision-ubuntu.sh "$SSH_HOST:/tmp/provision-ubuntu.sh"
ssh -i "$SSH_KEY" "$SSH_HOST" "bash /tmp/provision-ubuntu.sh"
```

Deploy application files:

```bash
SSH_HOST=root@101.43.4.247 \
SSH_KEY=/path/to/tencent-cvm.pem \
head_in_clouds/deploy/tencent-cloud/deploy-to-cvm.sh
```

If Docker Hub cannot be reached from the CVM, use host systemd deployment:

```bash
SSH_HOST=ubuntu@101.43.4.247 \
SSH_KEY=/path/to/tencent-cvm.pem \
head_in_clouds/deploy/tencent-cloud/deploy-host-systemd.sh
```

Expected staging smoke after deployment:

```bash
curl -s http://101.43.4.247/health
```

Expected result:

```json
{"ok":true}
```

Repeatable staging event smoke on the CVM:

```bash
cd /opt/head_in_clouds/current
set -a
. deploy/tencent-cloud/.env.server
set +a
HIC_STAGING_BASE_URL=http://127.0.0.1:8787 npm run smoke:events:staging --prefix server
```

Expected result: JSON with `ok:true`, the six baseline event names, and one event id per event in `evidence`.

## 8. SSH Preflight

Current key path:

```text
/Users/zhongwowen.3/.ssh/head-in-clouds-tencent.pem
```

Run:

```bash
SSH_KEY=/Users/zhongwowen.3/.ssh/head-in-clouds-tencent.pem \
head_in_clouds/deploy/tencent-cloud/ssh-preflight.sh
```

If all users fail with `Permission denied (publickey,password)`, the CVM has not accepted this public key. In Tencent Cloud console, bind this key to the CVM or reset the CVM login method to this SSH key.

Public key command:

```bash
ssh-keygen -y -f /Users/zhongwowen.3/.ssh/head-in-clouds-tencent.pem
```

After Tencent Cloud accepts the key, expected result:

```text
SSH_OK_USER=root
```

If the accepted user is not `root`, set `SSH_HOST=<user>@101.43.4.247` when running `deploy-to-cvm.sh`.

Current verified SSH user:

```text
SSH_OK_USER=ubuntu
```
