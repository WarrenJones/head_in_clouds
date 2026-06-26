# 埋点契约 — Head in the Clouds

> 当前状态：dev 本地事件管道骨架 + first-party API contract。已落地 `AnalyticsTracking` protocol、`EventEnvelope`、`FanoutAnalyticsTracker`、`EventPipelineAnalyticsTracker`、`URLSessionEventIngestionClient`、带 Bearer account token 的 first-party `/events` API、受 `HIC_ADMIN_TOKEN` 保护的事件查询端点和只读 event dashboard、provider-agnostic `event_logs` schema、本地 baseline 事件 smoke runner、IP staging PostgreSQL event readback、PRD §13.3 全量事件 synthetic contract smoke、iOS → first-party API 的 context/proof/post/feed/push-token/boarding-reminder/account-upgrade/SMS challenge/WeChat code exchange/comment/purchase/share-card-render adapter、分享落地页 + 动态 `og.svg` 端点、服务端 APNs provider、通知发送后服务端埋点、腾讯 COS fail-closed 对象存储适配器，以及 StoreKit 2 purchase skeleton + purchase `appAccountToken` 账号归属 + 服务端 IAP fail-closed 验证骨架 + 服务端权威商品目录 + StoreKit signed-transaction JWS 结构/载荷校验 + App Store Server Notifications V2 receiver skeleton。StoreKit sandbox/生产真实购买 evidence、完整 Apple 证书链校验、真实 App Store Server Notifications delivery evidence、APNs 真机 delivery evidence、真实 UI/provider 触发的完整 PRD 自定义事件 evidence、CLS/provider evidence 尚未配置，不能声明 `analytics_contract_verified=true`。

上游依据：`head_in_clouds/PRD.md` §13.3。  
QA 依据：`head_in_clouds/TEST_PLAN.md` §6。

---

## 0. 实现技术栈

- **Stage 1 App**：iOS SwiftUI / VisionKit
- **Current dev adapter**：`AnalyticsTracking` protocol + `InMemoryAnalyticsTracker` + `FanoutAnalyticsTracker` + `EventPipelineAnalyticsTracker` + `URLSessionEventIngestionClient`
- **Production analytics target**：first-party `/events` API + China-region event store/dashboard
- **Optional analytics downstream**：domestic analytics provider preferred; PostHog Cloud only as server-side async relay if needed
- **Server target**：China-accessible first-party backend for trusted events, payments/IAP, auth, persistence, and notification dispatch

---

## 1. Baseline 事件（6 条必须有）

| # | Event name | 触发时机 | 必含 properties | Current status |
|---|---|---|---|---|
| 1 | `signup_completed` | Guest 升级微信/手机号成功 | `user_id`, `utm_source`, `utm_medium`, `utm_campaign`, `referrer`, `signup_method` | local adapter implemented, production auth pending |
| 2 | `user_returned` | 用户在注册日之外任一天触发任何事件 | `user_id`, `days_since_signup` | local adapter implemented; staging contract evidence captured |
| 3 | `core_action_completed` | 私人卡生成 / 同班机发布 | `user_id`, `action_name` | local adapter implemented |
| 4 | `paywall_viewed` | 用户看到付费墙 | `user_id`, `plan_shown`, `source_page` | local paywall adapter implemented; product decision/evidence pending |
| 5 | `checkout_started` | 用户点击付费按钮进入 IAP | `user_id`, `plan`, `price_cny` | local checkout event + purchase verification adapter implemented; StoreKit pending |
| 6 | `subscription_created` / IAP success | 支付成功服务端验证后 | `user_id`, `plan`, `amount`, `currency`, `transaction_id` | StoreKit 2 client skeleton + first-party server verification skeleton implemented; sandbox/production now require signed transaction JWS; product/price come from server catalog; App Store Server Notifications V2 receiver skeleton can also emit this event for active entitlement notifications with `appAccountToken`; real sandbox/provider evidence pending |

---

## 2. 项目自定义核心事件

| # | Event name | 触发时机 | 必含 properties | 来源 PRD 指标 | Current status |
|---|---|---|---|---|---|
| 7 | `compose_started` | 进入 06 Compose | `source` | 写作启动率 | local adapter implemented |
| 8 | `private_card_generated` | 生成私人 Cloud Card | `template_id`, `has_flight_context`, `verified` | 私人卡生成率 | local adapter implemented |
| 9 | `same_flight_publish_blocked` | 未验证 / 无网阻塞同班机发布 | `reason` | 验证后置边界 | local adapter implemented |
| 10 | `same_flight_publish_completed` | 验证后发布到同班机 | `flight_space_id`, `template_id` | 同班机发布完成率 | local adapter implemented with required properties; staging contract evidence captured; server-confirmed UI evidence pending |
| 11 | `offline_draft_saved` | 离线写作保存本地草稿 | `content_length`, `has_flight_context` | 离线可靠性 | local adapter implemented with required properties; staging contract evidence captured |
| 11a | `draft_resumed` | App 启动时恢复未完成草稿 | `draft_age_ms`, `source` | 中断恢复漏斗 | local adapter implemented |
| 12 | `offline_sync_started` | queued 内容开始同步 | `queue_id` | 离线同步成功率 | local adapter implemented with required properties; staging contract evidence captured |
| 13 | `offline_sync_completed` | queued 内容同步成功 | `queue_id` | 离线同步成功率 | local adapter implemented with required properties; staging contract evidence captured |
| 14 | `app_first_launched` | 全新安装首次启动 | `device_id`, `app_version` | 首次入口漏斗 | local adapter implemented |
| 15 | `onboarding_step_viewed` | 00a-00d 展示 | `step` | onboarding 漏斗 | local adapter implemented |
| 16 | `onboarding_completed` | 00d Guest 开始 | `guest` | onboarding 完成率 | local adapter implemented |
| 17 | `guest_mode_chosen` | 00d 选择 Guest | `device_id`, `source` | Guest 激活 | local adapter implemented |
| 18 | `landing_viewed` / `01a_landing_viewed` / `01b_landing_viewed` | Opening 展示 | `is_returning`, `post_count` | C-1 写作启动分母 | local adapter implemented |
| 19 | `compose_mode_selected` | 选一句话/模板/语音 | `mode` | 写作模式使用 | local adapter implemented |
| 20 | `template_prompt_selected` | 选择模板 | `template_id` | 模板降门槛 | local adapter implemented |
| 21 | `voice_recording_started` / `voice_transcribed` | 模拟语音转文字 | `success`, `duration_ms`, `content_length` | 语音输入漏斗 | local adapter implemented |
| 22 | `cloud_card_rendered` | 07 Card Studio 本地渲染 | `template_id`, `offline` | 卡片生成质量 | local adapter implemented |
| 23 | `headline_quote_edited` | 修改卡片大字 quote | `auto_generated_before`, `length` | quote 编辑率 | local adapter implemented |
| 24 | `private_card_saved` / `cloud_card_saved` / `private_card_shared` / `card_shared` | 保存/分享私人卡 | `channel`, `template_id` | C-3 分享冲动 | local adapter implemented |
| 25 | `flight_intent_created` | 手动添加航班/提醒 | `source`, `flight_number_hash`, `reminder_offset_minutes` | 飞行前锚定 | local adapter implemented |
| 26 | `flight_verification_started` / `capture_started` / `capture_completed` / `ocr_failed` / `flight_confirmed` / `flight_proof_created` / `flight_verification_completed` | 添加票证验证 | `method`, `success`, `proof_source_type`, `ocr_confidence`, `ocr_corrected` | 验证后置漏斗 | local adapter implemented |
| 27 | `same_flight_publish_started` | 尝试发布同班机 | `verified` | 同班机 gate | local adapter implemented |
| 28 | `boarding_reminder_scheduled` / `boarding_reminder_sent` | 保存登机提醒 / 服务端发送提醒成功 | `flight_number_hash`, `reminder_offset_minutes` | 登机提醒激活与打开率分母 | local adapter + first-party reminder job adapter + server-side sent event implemented |
| 29 | `share_landing_opened` | 16 分享落地页打开 | `source`, `flight_number_hash`, `route` | 分享承接 | local adapter implemented |
| 30 | `account_upgrade_started` / `account_upgrade_completed` | 微信/手机号保存账号 | `method`, `source`, `merged_with_existing`, `merged_post_count` | Guest 升级 | local adapter + first-party account merge API implemented |
| 31 | `account_settings_viewed` / `sign_out_completed` / `account_deletion_requested` / `account_deletion_confirmed` / `account_deletion_completed` | 设置页账号动作 | `account_type`, `method`, `reauth_method`, `recovery_days` | 合规账号动作 | local reauth gate + first-party soft-delete API implemented |
| 32 | `flight_space_viewed` | 进入 09 Flight Space | `source`, `verified` | 同班机召回/浏览 | local adapter implemented |
| 33 | `report_submitted` / `block_user` | 举报/屏蔽 | `target_type`, `reason` | UGC 安全 | local adapter + first-party report/block API implemented |
| 34 | `sign_in_started` / `sign_in_succeeded` / `sign_in_failed` | 打开微信/手机号保存账号并发生结果 | `method`, `source`, `reason` | 登录结果漏斗 | local adapter + WeChat availability gate implemented; production provider pending |
| 35 | `account_upgrade_prompt_viewed` / `account_upgrade_prompt_actioned` / `account_upgrade_prompt_shown` / `account_upgrade_prompt_dismissed` | 第 2 / 第 3 张同班机 Post 后展示保存账号提示 | `kind`, `post_count`, `action`, `variant`, `trigger` | Guest 升级触发策略 | local adapter + PRD alias events implemented |
| 36 | `comment_written` | 已验证同班机用户发表评论 | `is_same_flight`, `comment_length` | 同班机评论权限 | local adapter + first-party comment API implemented |
| 37 | `permission_granted` / `permission_denied` | 相机/相册/通知权限真实申请结果 | `type`, `source_screen`, `reason` | 权限前置说明有效性 | local camera + photo-library + notification permission adapters implemented; device evidence pending |
| 38 | `share_landing_same_flight_tapped` / `share_landing_reminder_started` | 16 分享落地页继续动作 | `installed_app`, `route`, `flight_number_hash` | 分享落地页继续率 | local adapter implemented |
| 39 | `same_flight_notes_viewed` | 进入同班机笔记列表 | `source`, `verified` | 同班机浏览漏斗 | local adapter implemented |
| 40 | `same_flight_note_notification_sent` / `same_flight_note_notification_opened` | 同班机新笔记通知发送 / 点开 | `flight_number_hash`, `hours_after_post` | 同班机通知打开率 | server-side sent event + local route adapter implemented; real APNs evidence pending |
| 41 | `post_detail_viewed` | 进入 11A/11B Detail | `source`, `can_comment` | 同班机/detail 浏览漏斗 | local adapter implemented |
| 42 | `sms_code_sent` / `sms_code_verified` / `sms_code_resend` | 手机号验证码获取、验证、重发 | `phone_country_code` | 手机号登录漏斗 | iOS calls first-party SMS challenge endpoints and upgrades with server-returned provider hash; production SMS provider pending |
| 43 | `wechat_auth_initiated` / `wechat_auth_callback_received` | 微信授权开始与回调 | `source`, `status` | 微信登录漏斗 | local mock adapter + first-party server code exchange implemented; production WeChat SDK/callback evidence pending |
| 44 | `discovery_viewed` | 打开 10 Discovery | `tab_name` | 发现页浏览漏斗 | local adapter implemented |

仍未落地：权限授权/拒绝真机 walkthrough evidence、APNs 真机 delivery evidence、StoreKit sandbox/生产 IAP receipt validation evidence、真实 App Store Server Notifications delivery evidence、真实 UI/provider 触发的全量事件 evidence、CLS/provider export evidence（如需要）、生产微信 SDK 登录/分享 evidence、生产短信服务商模板/签名审核。

---

## 3. 每个事件的实现位置 & 验证证据

| Event name | Code location | Fired by | Staging evidence |
|---|---|---|---|
| first-party event envelope + HTTP request builder | `ios/Sources/HeadInCloudsCore/Analytics.swift` | iOS client event pipeline | Local check runner: `swift run HeadInCloudsCoreChecks` |
| first-party `/events` API + protected event evidence query | `server/src/server.mjs:53` / `server/src/server.mjs:64` / `server/src/http.mjs` / `server/src/events.mjs` / `server/src/event-store.mjs` / `server/src/postgres-event-store.mjs` / `server/src/store-factory.mjs` | account-authenticated server event ingestion + admin-only recent readback and HTML dashboard; local file store in dev, PostgreSQL `event_logs` store in staging/production; JSON bodies over 64 KiB fail closed with HTTP 413 `body_too_large` | Local/CVM server tests 80/80; HTTPS staging readback from `https://api.headinclouds.cn/events` passed on CVM; local simulator smoke uses SSH tunnel because this Mac cannot reach the public HTTPS API path |
| baseline event local smoke runner | `server/scripts/local-event-smoke.mjs` / `server/package.json` | local first-party event evidence workflow for baseline 6 readback | Local smoke: `npm run smoke:events --prefix head_in_clouds/server` |
| baseline event staging smoke runner | `server/scripts/staging-event-smoke.mjs` / `server/package.json` | repeatable remote first-party event evidence workflow for baseline 6 against a deployed API + PostgreSQL event store | CVM smoke passed on 2026-05-25: `smoke_run_id=staging-smoke-1779689220792-3a1406a2`; evidence ids: `signup_completed=4ec2a976-4a10-43eb-9982-e34d69553f59`, `user_returned=1d32d9db-fe01-4e5f-8ab6-aa2e4f1bfaca`, `core_action_completed=c53b0e28-daeb-419b-b3e7-f6cbe18ed58d`, `paywall_viewed=f98e30b5-4f2a-4aaa-85f9-8078918021a9`, `checkout_started=a0f0ef6f-6d7c-44da-b32b-a63086ae8127`, `subscription_created=b19cfb35-7bf2-458a-a1bc-a8cd9bd22803`. |
| PRD §13.3 contract event smoke runner | `server/scripts/contract-event-smoke.mjs` / `server/package.json` | synthetic contract verification for all PRD event names/properties against local or deployed first-party `/events` + admin readback; also verifies raw email/exact seat/raw OCR fields are stripped and `subscription_created` is server-side | Local smoke passed on 2026-05-25 with `checked_event_count=75`; CVM PostgreSQL readback passed on 2026-05-25 with `smoke_run_id=contract-smoke-1779693843680-4741f8b8`, `checked_event_count=75`, including `01a_landing_viewed=a445f621-b6f1-4308-9a15-51c7d7cdc8d0`, `01b_landing_viewed=e743708e-f50d-4539-a1b3-104fba890b49`, `onboarding_step_viewed=7e6179e5-c17d-4012-a89b-54ba30193acb`, `subscription_created=1c9ed435-cb05-4230-941d-c6679c7c2a60`. |
| staging event summary/dashboard + readiness/log evidence | `server/src/server.mjs` / `server/src/admin-dashboard.mjs` / `server/src/event-store.mjs` / `server/src/postgres-event-store.mjs` / `server/scripts/staging-event-summary.mjs` | admin-only event evidence JSON query and HTML dashboard by `smoke_run_id`; `/health/ready` verifies PostgreSQL app/event stores; request logs emit path-only JSON without query strings | CVM summary passed on 2026-05-26 with `smoke_run_id=ios-simulator-staging-smoke-20260526-1408`, `total_events=2`, `missing_event_names=[]`; `GET /api/admin/events/dashboard` returned HTTP 200 `text/html` with event coverage/recent rows and unauthenticated requests return HTTP 401; `https://api.headinclouds.cn/health/ready` returned both stores `postgres`; journalctl request logs are path-only JSON. |
| event/public text sanitizer | `ios/Sources/HeadInCloudsCore/Analytics.swift` / `ios/Sources/HeadInCloudsCore/Services.swift` / `ios/App/Views/ComposeView.swift` / `server/src/sanitize.mjs` / `server/src/app-store.mjs` | iOS client + server event guardrail + public share/feed/card-preview/share-image/share-caption exact-seat and contact redaction | Swift core checks + Xcode simulator build + Node server tests 80/80 |
| iOS event fan-out to local QA log + first-party `/events` | `ios/Sources/HeadInCloudsCore/Analytics.swift:17` / `ios/App/AppState.swift:31` / `ios/App/AppState.swift:1044` / `ios/App/Info.plist` / `ios/HeadInClouds.xcodeproj/project.pbxproj` / `ios/scripts/simulator-staging-smoke.sh` | iOS client analytics sink with Bearer account token; bundle config points to `HEAD_IN_CLOUDS_API_BASE_URL=https://api.headinclouds.cn`, `HEAD_IN_CLOUDS_EVENTS_URL=https://api.headinclouds.cn/events`, and `HEAD_IN_CLOUDS_SHARE_BASE_URL=https://headinclouds.cn`; simulator smoke can override via `SIMCTL_CHILD_HEAD_IN_CLOUDS_*` through local SSH tunnel | Swift core checks + Xcode simulator build; repeatable simulator staging smoke passed on 2026-05-26 with `smoke_run_id=ios-simulator-staging-smoke-20260526-171159`, staging summary `missing_event_names=[]`, `app_first_launched=1`, `onboarding_step_viewed=1` |
| `event_logs` schema | `server/schema/001_initial.sql` / `server/scripts/migrate-postgres.mjs` | China-region PostgreSQL migration reference | Local schema test + migration applied on CVM PostgreSQL |
| IAP transaction verification + `subscription_created` server event | `ios/Sources/HeadInCloudsCore/APIClient.swift` / `ios/App/AppState.swift` / `server/src/api.mjs` / `server/src/iap-products.mjs` / `server/src/storekit-jws.mjs` / `server/src/storekit-notifications.mjs` / `server/src/app-store.mjs` / `server/scripts/app-store-notification-smoke.mjs` / `server/schema/001_initial.sql` | iOS StoreKit 2 purchase adapter passes the current local account UUID via `Product.PurchaseOption.appAccountToken` before first-party verification; server writes `subscription_created` only after verification endpoint accepts transaction or an active entitlement server notification with `appAccountToken` is accepted. Sandbox/production requests must include `signed_transaction_jws`, plan/amount/currency are derived from server-side `HIC_IAP_PRODUCTS_JSON`, and JWS header/payload fields must match the request and bundle ID. This is not full Apple certificate-chain verification. | Swift core checks + Xcode simulator build + Node server tests 89/89 locally; source guard in `scripts/dev-gate-local.sh`; CVM-side public HTTPS placeholder JWS smoke returned HTTP 400; CVM ASSN structural smoke `assn-smoke-1779786718393-94a28be0` wrote `subscription_created=63d234d1-5f34-4e41-a73a-0d52719c5c0d`; StoreKit sandbox and real App Store Server Notification evidence pending |
| `app_store_server_notification_received` | `server/src/api.mjs` / `server/src/storekit-notifications.mjs` / `server/scripts/app-store-notification-smoke.mjs` / `server/test/api.test.mjs` | server-side event after a valid App Store Server Notifications V2-style `signedPayload` is accepted. Records notification type/subtype/uuid, environment, product id when present, and whether an `appAccountToken` was linked; refund notifications do not create active subscriptions. | Node server tests 89/89 locally and on CVM; local smoke `assn-smoke-1779786554250-2b07d78b`; latest CVM smoke `assn-smoke-1779786718393-94a28be0` wrote event id `99a27866-533f-4488-ab0b-17b944ee4ed3`; App Store Connect URL configured to `https://api.headinclouds.cn/api/iap/app-store/notifications`; real Apple delivery evidence pending |
| first-party app API request builder | `ios/Sources/HeadInCloudsCore/APIClient.swift:12` | iOS client API adapter | Local check runner: `swift run HeadInCloudsCoreChecks` |
| shared card landing + dynamic OG image | `server/src/server.mjs:100` / `server/src/share-card-page.mjs:1` / `server/src/share-card-page.mjs:154` | first-party shared landing server | Local server tests: `npm test --prefix head_in_clouds/server` |
| server-rendered share card upload | `ios/Sources/HeadInCloudsCore/APIClient.swift` / `ios/App/AppState.swift` / `server/src/api.mjs` / `server/src/object-storage.mjs` / `server/src/share-card-page.mjs` | iOS non-blocking first-party share-card render call + authenticated owner-scoped server render/upload to object storage; disabled/fail-closed until COS secrets are configured | Swift core checks + Node server tests 80/80; real COS upload evidence pending |
| flight context/proof/post sync adapters | `ios/Sources/HeadInCloudsCore/APIClient.swift:98` / `ios/Sources/HeadInCloudsCore/APIClient.swift:132` / `ios/Sources/HeadInCloudsCore/APIClient.swift:157` | iOS client API adapter | Local check runner: `swift run HeadInCloudsCoreChecks` |
| `user_returned` | `ios/App/AppState.swift:116` / `ios/App/AppState.swift:1026` | local iOS state adapter; once per account per calendar day after signup day | Xcode simulator build |
| same-flight feed adapter | `ios/Sources/HeadInCloudsCore/APIClient.swift:182` / `server/src/api.mjs:43` | iOS client + server API | Swift core checks + Node server tests |
| boarding pass OCR parser + scanner entry | `ios/Sources/HeadInCloudsCore/BoardingPassParser.swift:22` / `ios/App/BoardingPassScannerView.swift:7` / `ios/App/AppState.swift:311` | iOS VisionKit scan path + safe field extraction | Swift core checks + Xcode simulator build |
| stable flight number hash | `ios/App/AppState.swift:649` | iOS client same-flight key generation | Xcode simulator build passed |
| APNs token capture + first-party registration | `ios/App/NotificationRouting.swift:52` / `ios/App/AppState.swift:388` / `ios/Sources/HeadInCloudsCore/APIClient.swift:40` / `ios/App/HeadInClouds.entitlements` / `ios/HeadInClouds.xcodeproj/project.pbxproj` | iOS app delegate + first-party API adapter; entitlements include `aps-environment`, Debug uses development APNs, Release uses production APNs, and signing team is `K338A7B5QX` | Swift core checks + Xcode simulator build + CVM release preflight 25/25; real-device APNs token evidence pending |
| APNs provider payload + dispatcher | `server/src/apns-provider.mjs:6` / `server/src/notification-dispatcher.mjs:12` | server notification worker; supports `APNS_PRIVATE_KEY_FILE` for systemd/CVM secret storage | Local/CVM server tests 80/80; CVM smoke loaded `/opt/head_in_clouds/secrets/apns/AuthKey_JHT8332488.p8` and constructed a signed APNs request; real-device delivery evidence pending |
| `boarding_reminder_sent` / `same_flight_note_notification_sent` | `server/src/notification-dispatcher.mjs:33` / `server/src/notification-dispatcher.mjs:44` / `server/src/app-store.mjs:487` / `server/test/notification-dispatcher.test.mjs:42` | server-side event append after APNs provider reports successful send; same-flight event derives `hours_after_post` from source post and sent time | Node server tests |
| local notification permission result adapter | `ios/Sources/HeadInCloudsCore/Adapters.swift:30` / `ios/App/UserNotificationScheduler.swift:12` / `ios/App/AppState.swift:526` | iOS notification scheduler + state feedback | Swift core checks + Xcode simulator build |
| first-party boarding reminder job adapter | `ios/Sources/HeadInCloudsCore/APIClient.swift:20` / `ios/Sources/HeadInCloudsCore/APIClient.swift:203` / `ios/App/AppState.swift:546` / `server/src/api.mjs:85` | iOS client + first-party server API | Swift core checks + Node server tests |
| account upgrade API contract + merge API | `ios/Sources/HeadInCloudsCore/APIClient.swift:44` / `ios/Sources/HeadInCloudsCore/APIClient.swift:241` / `server/src/api.mjs:8` / `server/src/app-store.mjs:29` | iOS client + first-party server API | Swift core checks + Node server tests |
| account deletion API contract + soft-delete API | `ios/Sources/HeadInCloudsCore/APIClient.swift:48` / `ios/Sources/HeadInCloudsCore/APIClient.swift:271` / `server/src/api.mjs:14` / `server/src/app-store.mjs:87` | iOS client + first-party server API | Swift core checks + Node server tests |
| account provider dedup schema | `server/schema/001_initial.sql:4` / `server/schema/001_initial.sql:119` | China-region DB migration reference | Local schema test |
| report/block API adapter | `ios/Sources/HeadInCloudsCore/APIClient.swift:306` / `ios/Sources/HeadInCloudsCore/APIClient.swift:332` / `ios/App/AppState.swift` / `ios/App/Views/FeatureViews.swift` / `server/src/api.mjs:65` / `server/src/api.mjs:71` / `server/src/app-store.mjs` | iOS selected post target + first-party server API; block can resolve author by `post_id`, and iOS no longer sends placeholder moderation IDs when no real target exists | Swift core checks + Xcode simulator build + Node server tests 80/80 |
| same-flight comment API adapter | `ios/Sources/HeadInCloudsCore/APIClient.swift:355` / `ios/App/AppState.swift:728` / `ios/App/Views/FeatureViews.swift:423` / `server/src/api.mjs:49` | iOS client + first-party server API | Swift core checks + Node server tests |
| own post deletion API adapter | `ios/Sources/HeadInCloudsCore/APIClient.swift:28` / `ios/Sources/HeadInCloudsCore/APIClient.swift:388` / `ios/App/AppState.swift:816` / `ios/App/Views/FeatureViews.swift:446` / `server/src/api.mjs:49` | iOS client + first-party server API | Swift core checks + Xcode simulator build + Node server tests |
| `compose_started` | `ios/Sources/HeadInCloudsCore/Services.swift:105` | local adapter, later iOS client | Local check runner: `swift run HeadInCloudsCoreChecks` |
| `private_card_generated` | `ios/Sources/HeadInCloudsCore/Services.swift:111` | local adapter, later iOS client | Local check runner: `swift run HeadInCloudsCoreChecks` |
| `same_flight_publish_blocked` | `ios/Sources/HeadInCloudsCore/Services.swift:136` | local adapter, later iOS client/server | Local check runner: `swift run HeadInCloudsCoreChecks` |
| `same_flight_publish_completed` | `ios/Sources/HeadInCloudsCore/Services.swift:146` | local adapter, later server-confirmed | Local check runner: `swift run HeadInCloudsCoreChecks` |
| `offline_draft_saved` | `ios/Sources/HeadInCloudsCore/Services.swift:73` / `ios/App/AppState.swift:256` / `ios/App/AppState.swift:290` | local adapter, later iOS client | Local check runner: `swift run HeadInCloudsCoreChecks` |
| `draft_resumed` | `ios/App/AppState.swift:975` / `ios/App/AppState.swift:1148` | local iOS state adapter + draft updated timestamp | Xcode simulator build passed |
| `offline_sync_started` | `ios/Sources/HeadInCloudsCore/Services.swift:87` / `ios/App/AppState.swift:1202` | local adapter + iOS network-reconnect trigger + persisted queued post retry, later server-confirmed | Local check runner + Xcode simulator build |
| `offline_sync_completed` | `ios/Sources/HeadInCloudsCore/Services.swift:96` / `ios/App/AppState.swift:1208` | local adapter + iOS network-reconnect trigger + persisted queued post retry, later server-confirmed | Local check runner + Xcode simulator build |
| `offline_sync_failed` | `ios/App/AppState.swift:1215` | local iOS state adapter after reconnect sync failure; failed queued records remain retryable | Xcode simulator build passed |
| `app_first_launched` | `ios/App/AppState.swift:70` | local iOS state adapter | Simulator screenshot: `/private/tmp/head_in_clouds_flight_space_api_slice_20260521.png` |
| `onboarding_step_viewed` | `ios/App/AppState.swift:155` | local iOS state adapter | Simulator build/install/launch |
| `onboarding_completed` | `ios/App/AppState.swift:162` | local iOS state adapter | Simulator build/install/launch |
| `guest_mode_chosen` | `ios/App/AppState.swift:161` | local iOS state adapter | Simulator build/install/launch |
| `landing_viewed` | `ios/App/AppState.swift:165` | local iOS state adapter | Simulator build/install/launch |
| `core_action_completed` | `ios/App/AppState.swift:239` / `ios/App/AppState.swift:333` | local iOS state adapter | Xcode simulator build passed |
| `compose_mode_selected` | `ios/App/AppState.swift:192` | local iOS state adapter | Xcode simulator build passed |
| `template_prompt_selected` | `ios/App/AppState.swift:196` | local iOS state adapter | Xcode simulator build passed |
| `voice_recording_started` / `voice_transcribed` | `ios/App/AppState.swift:200` | local iOS state adapter | Xcode simulator build passed |
| `cloud_card_rendered` | `ios/App/AppState.swift:235` | local iOS state adapter | Xcode simulator build passed |
| `headline_quote_edited` | `ios/App/AppState.swift:248` | local iOS state adapter | Xcode simulator build passed |
| `private_card_saved` / `cloud_card_saved` / `private_card_shared` / `card_shared` | `ios/App/AppState.swift:392` / `ios/App/AppState.swift:393` / `ios/App/AppState.swift:330` / `ios/App/AppState.swift:331` / `ios/App/Views/ComposeView.swift:477` | local iOS state adapter + QA alias events + system share sheet trigger | Xcode simulator build |
| `flight_intent_created` | `ios/App/AppState.swift:271` | local iOS state adapter | Xcode simulator build passed |
| `flight_verification_started` | `ios/App/AppState.swift:354` | local iOS state adapter | Xcode simulator build passed |
| `capture_started` / `capture_completed` / `ocr_failed` | `ios/App/AppState.swift:367` / `ios/App/AppState.swift:373` / `ios/App/AppState.swift:379` | local iOS Vision parser adapter; no raw OCR text in properties | Xcode simulator build |
| `flight_confirmed` / `flight_proof_created` / `flight_verification_completed` | `ios/App/AppState.swift:400` / `ios/App/AppState.swift:404` / `ios/App/AppState.swift:409` / `ios/App/AppState.swift:429` / `ios/App/AppState.swift:433` / `ios/App/AppState.swift:438` | local iOS proof creation + verification adapter | Xcode simulator build |
| `same_flight_publish_started` | `ios/App/AppState.swift:453` | local iOS state adapter | Xcode simulator build passed |
| `flight_space_viewed` | `ios/App/AppState.swift:484` | local iOS state adapter | Xcode simulator build passed |
| `boarding_reminder_scheduled` | `ios/App/AppState.swift:613` / `ios/App/AppState.swift:638` | local iOS state adapter + first-party reminder job adapter | Swift core checks + Xcode simulator build |
| `boarding_reminder_opened` | `ios/App/AppState.swift:657` | local iOS state adapter | Xcode simulator build passed |
| `permission_granted` / `permission_denied` | `ios/App/AppState.swift:389` / `ios/App/AppState.swift:343` / `ios/App/AppState.swift:406` / `ios/App/AppState.swift:450` / `ios/App/AppState.swift:732` / `ios/App/AppState.swift:745` / `ios/App/AppState.swift:752` | local iOS state adapter + camera/photo/notification authorization result | Swift core checks + Xcode simulator build |
| `share_landing_opened` | `ios/App/AppState.swift:912` | local iOS state adapter | Xcode simulator build passed |
| `share_landing_same_flight_tapped` / `share_landing_reminder_started` | `ios/App/AppState.swift:1030` / `ios/App/AppState.swift:1038` / `ios/App/Views/FeatureViews.swift:1022` / `ios/App/Views/FeatureViews.swift:1026` | local iOS state adapter + share landing CTA | Xcode simulator build |
| `same_flight_notes_viewed` | `ios/App/AppState.swift:488` / `ios/App/Views/FeatureViews.swift:302` | local iOS state adapter + Flight Space appear | Xcode simulator build |
| `same_flight_note_notification_opened` | `ios/App/AppState.swift:940` / `ios/App/RootView.swift:228` | local iOS notification route adapter | Xcode simulator build; real APNs evidence pending |
| `post_detail_viewed` | `ios/App/AppState.swift:932` / `ios/App/RootView.swift:150` / `ios/App/RootView.swift:156` | local iOS state adapter + detail appear | Xcode simulator build |
| `account_upgrade_started` / `sign_in_started` / `sign_in_succeeded` / `sign_in_failed` / `signup_completed` / `account_upgrade_completed` | `ios/App/AppState.swift:696` / `ios/App/AppState.swift:700` / `ios/App/AppState.swift:771` / `ios/App/AppState.swift:734` / `ios/App/AppState.swift:757` / `ios/App/AppState.swift:765` | local iOS state adapter + first-party account upgrade adapter | Swift core checks + Xcode simulator build |
| `sms_code_sent` / `sms_code_verified` / `sms_code_resend` | `ios/App/AppState.swift` / `ios/App/Views/FeatureViews.swift` / `server/src/api.mjs` / `server/src/sms-provider.mjs` / `server/schema/001_initial.sql` | iOS SMS gate + first-party SMS challenge API + Tencent Cloud SendSms adapter; full phone number is not tracked, server stores only `phone_hash` and `code_hash` | Swift core checks + Xcode simulator build + Node server tests 80/80 |
| `wechat_auth_initiated` / `wechat_auth_callback_received` | `ios/App/AppState.swift:685` / `ios/App/AppState.swift:688` / `ios/App/Views/FeatureViews.swift:789` / `ios/Sources/HeadInCloudsCore/APIClient.swift:64` / `ios/Sources/HeadInCloudsCore/APIClient.swift:413` / `server/src/api.mjs:47` / `server/src/wechat-provider.mjs` | local mock callback + first-party `/api/auth/wechat/exchange` server-side authorization-code exchange; iOS sends only auth code, server stores only provider hashes, and provider fails closed while disabled | Swift core checks + Xcode simulator build + Node server tests 80/80; real WeChat SDK callback evidence pending |
| `account_upgrade_prompt_viewed` / `account_upgrade_prompt_actioned` / `account_upgrade_prompt_shown` / `account_upgrade_prompt_dismissed` | `ios/App/AppState.swift:1011` / `ios/App/AppState.swift:1318` / `ios/App/RootView.swift:185` / `ios/App/Views/FeatureViews.swift:696` | local iOS state adapter + upgrade prompt sheet + PRD alias events | Xcode simulator build passed |
| `account_settings_viewed` / `sign_out_completed` / `account_deletion_requested` / `account_deletion_confirmed` / `account_deletion_completed` | `ios/App/AppState.swift:861` / `ios/App/AppState.swift:865` / `ios/App/AppState.swift:886` / `ios/App/AppState.swift:891` / `ios/App/AppState.swift:1162` | local iOS reauth gate + first-party account deletion adapter | Swift core checks + Xcode simulator build |
| `report_submitted` / `block_user` | `ios/App/AppState.swift:918` / `ios/App/AppState.swift:947` | local iOS state adapter + first-party report/block adapter | Swift core checks + Xcode simulator build |
| `comment_written` | `ios/App/AppState.swift:739` / `ios/App/Views/FeatureViews.swift:423` | local iOS state adapter + first-party comment adapter | Swift core checks + Xcode simulator build |
| `paywall_viewed` / `checkout_started` | `ios/App/AppState.swift:1113` / `ios/App/AppState.swift:1121` / `ios/App/Views/FeatureViews.swift:1111` / `ios/App/Views/FeatureViews.swift:1119` | local iOS paywall + checkout adapter; checkout calls first-party verification endpoint when API base URL is configured | Swift core checks + Xcode simulator build |
| `subscription_created` | `server/src/api.mjs` / `server/src/iap-products.mjs` / `server/src/storekit-jws.mjs` / `server/src/storekit-notifications.mjs` / `server/test/api.test.mjs` / `server/test/iap-products.test.mjs` / `server/test/storekit-jws.test.mjs` | server-side event after first-party IAP transaction verification or accepted active App Store Server Notification; not emitted by iOS client; sandbox/production requests fail closed without StoreKit signed transaction JWS; unknown products, placeholder/mismatched JWS payloads, refund notification materialization, and client amount/plan/currency mismatches are rejected | Node server tests 89/89 locally and on CVM; CVM-side public HTTPS placeholder JWS smoke returned HTTP 400; StoreKit sandbox and real notification delivery evidence pending |
| `discovery_viewed` | `ios/App/AppState.swift:696` / `ios/App/RootView.swift:126` / `ios/App/Views/FeatureViews.swift:885` | local iOS state adapter when Discovery appears | Xcode simulator build |
| first-run private-card + same-flight UI smoke | `ios/HeadInCloudsUITests/HeadInCloudsUITests.swift:1` / `ios/App/HeadInCloudsApp.swift:10` / `ios/App/Views/ComposeView.swift:204` / `ios/App/Views/WelcomeView.swift:36` / `ios/App/Views/FeatureViews.swift:1` | XCUITest reset path covers 00a Welcome → 00b Permission Primer → 00c Privacy Promise → 00d Get Started → 01a Opening → 06 Compose → 07 Card Studio → 08 Publish, copy-link shared landing, 02 Add Flight Info → 09 Flight Space same-flight publish, Add Flight no-fake-prefill + keyboard dismiss regression, Flight Reminder no-fake-prefill + keyboard dismiss regression, and legacy fixture-state migration regression | Fresh 2026-05-29 `xcodebuild test` passed 5/5. Result bundle: `/Users/zhongwowen.3/Library/Developer/Xcode/DerivedData/HeadInClouds-dzeowonbkgynhvawnefprvzzbphu/Logs/Test/Test-HeadInClouds-2026.05.29_15-47-53-+0800.xcresult` |

**Important**：上述 contract smoke evidence 证明中国区 staging `/events` + PostgreSQL readback + admin dashboard 能接收和查询全量 PRD 事件名/properties，并能做敏感字段剥离；它不等于真实 UI/provider walkthrough evidence。真实 dev complete 前，本表必须补上真实 UI/provider 触发证据、CLS/provider query（如需要）、StoreKit sandbox、APNs 真机 delivery、微信/SMS provider 的真实触发证据。

---

## 4. 验证清单

- [x] 本地 analytics adapter 存在。
- [x] First-party event envelope 存在。
- [x] iOS analytics fan-out to local QA log + first-party `/events` 存在。
- [x] First-party `/events` API local skeleton 存在，并要求 Bearer account token。
- [x] Protected local event readback endpoint exists for staging evidence workflow.
- [x] Local baseline event smoke runner validates readback for `signup_completed`, `user_returned`, `core_action_completed`, `paywall_viewed`, `checkout_started`, and server-side `subscription_created`.
- [x] Repeatable staging event smoke runner exists for deployed API + PostgreSQL readback.
- [x] PRD §13.3 synthetic contract smoke runner validates 75 event names/properties against local and CVM PostgreSQL readback.
- [x] Provider-agnostic `event_logs` schema 存在。
- [x] Local `user_returned` baseline adapter 存在。
- [x] First-party push token registration adapter 存在。
- [x] First-party same-flight comment adapter 存在。
- [x] First-party own post deletion adapter 存在。
- [x] First-party boarding reminder job adapter 存在。
- [x] Server-side `boarding_reminder_sent` / `same_flight_note_notification_sent` events exist after push provider success.
- [x] Local OCR/proof verification event adapters 存在。
- [x] Local same-flight detail/share-retention event adapters 存在。
- [x] Local notification permission result adapter 存在。
- [x] Server-side APNs provider skeleton 存在。
- [x] CVM APNs Team ID / Key ID / Bundle ID / private-key-file config 存在，并能完成服务端签名构造。
- [x] Local paywall/checkout adapter + first-party IAP verification skeleton 存在。
- [x] Server-side IAP product catalog guard exists and rejects product/amount/plan/currency mismatch.
- [x] StoreKit signed-transaction JWS structure/payload guard exists for sandbox/production and rejects placeholder or mismatched transaction payloads.
- [x] App Store Server Notifications V2 receiver skeleton exists and records `app_store_server_notification_received` while only materializing active entitlement notification types.
- [x] iOS StoreKit purchase call attaches the current account UUID as `appAccountToken` so App Store Server Notifications can be linked back to a first-party account.
- [x] Boarding pass OCR parser + VisionKit scanner entry 存在。
- [x] 已实现第一批核心事件触发点。
- [x] 本地 check runner 覆盖私人卡、同班机 gate、离线同步、隐私 label。
- [x] XCUITest smoke 覆盖新用户首次私人卡主链路 00a → 08、分享落地页、以及验证航班发布到同班机 02 → 09。
- [x] First-party `/events` API deployed to China-accessible IP staging.
- [x] China-region staging PostgreSQL event readback configured for baseline evidence.
- [ ] StoreKit sandbox/production server-side capture configured for payment/IAP success.
- [x] App Store Connect Server Notification URL configured.
- [ ] Real App Store Server Notification delivery evidence captured.
- [ ] APNs real-device delivery evidence captured.
- [ ] 表 3 每一行有 real UI/provider staging event evidence。
- [x] Baseline 6 events 全部可见 in IP staging PostgreSQL readback.
- [x] PRD §13.3 全量事件名/properties 可通过 synthetic contract smoke 在 IP staging PostgreSQL readback 看到。
- [x] Properties 敏感信息扫描通过 synthetic contract smoke（raw email / exact seat / raw OCR stripped）。

---

## 5. 变更管理

- 新增事件：先改 `PRD.md` / `TEST_PLAN.md` / 本文件，再实现。
- 重命名事件：不允许直接改，必须新增事件并保留旧事件至少一个运营周期。
- Properties 变更：只能新增字段，不删除已上线字段语义。
