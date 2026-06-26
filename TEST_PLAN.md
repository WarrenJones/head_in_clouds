# 测试计划：Head in the Clouds / 云上心事

**项目**：head_in_clouds  
**基于 PRD 版本**：v2.4 · 2026-05-20 · 表达先行 + 验证后置  
**目标平台**：Stage 1 只按 iOS App（SwiftUI / VisionKit）验收；Web 仅作为官网、隐私协议、分享落地页的辅助承载，不是第一版产品实现路径。Stage 1 先 TestFlight，不上 App Store。
**生成时间**：2026-05-20  
**状态**：Phase 1 待 founder review；通过后才允许 dev 起跑。

---

## 0. 测试目标

v2.4 的测试目标不是证明“扫描登机牌能跑”，而是证明新漏斗成立：

1. 用户能否不扫描登机牌，直接写一句并生成私人 Cloud Card？
2. “验证后置”是否仍让用户理解这是飞行产品，而不是普通日记？
3. Cloud Card 是否像一张值得单独分享的明信片，而不是 App 截图？
4. 离线写作、离线卡片预览、落地同步是否不会丢稿？
5. 同班机发布、评论、同班机通知是否被航班验证严格保护？
6. 分享落地页是否能承接外部流量，而不是直接把用户丢到 App Store？
7. 公共区域是否完全不暴露姓名、票号、证件号、具体座位号？

**旧 test-plan 中的 photo-first / 30-300 字 / post_generated / post_published 全部废弃。** 本计划以 PRD v2.4 为准。

---

## 1. Scope & Non-goals

### 必须覆盖（Stage 1 IN SCOPE）

- 00a-00d 首次体验、Guest mode、权限前置说明、隐私承诺。
- 01a / 01b Returning opening、09b My Flights、11A 自己卡片详情。
- 06 Compose 一句话优先、模板、语音转文字、离线草稿。
- 07 Card Studio 默认复古明信片模板、普通 UGC 兜底、私人分享。
- 08 Private Share 与 Same Flight Publish 的拆分。
- 02-05 Add Flight Info / Flight Proof 验证后置流程。
- 09 / 10 / 11 / 16 同班机、Discovery、详情、分享落地页的权限与隐私。
- 15 登机前提醒、同班机新笔记通知。
- 13 / 14 账号升级、微信/手机号登录、删除账号。
- 举报、屏蔽、隐藏、删除自己的内容。
- PRD §13.3 全量埋点 + QA baseline 6 条。

### 不测（PRD §11 Won't Have；出现即 NO-GO）

- 视频内容、外链、DM、关注、公开关注列表。
- 实时航班追踪、登机口、延误查询 API。
- 公开票证原图分享。
- Threaded 评论、楼中楼、@ 提及。
- 搜索、年度报告 / 飞行 wrapped。
- Apple / Google / 邮箱登录（除非 App Store 4.8 审核回退触发）。
- Cloud Card 上的强下载 CTA / App Store badge / “立即下载”。

---

## 2. 核心能力门槛

> 功能能跑不等于项目成立。v2.4 的核心能力门槛优先验证“低门槛创作 + 分享扩散 + 验证边界”。

| 能力 | PRD 来源 | 可测试的验收标准 | 达标判定 |
|---|---|---|---|
| C-1 写作启动 | §13.2 `compose_started / landing_viewed` | 10 名真实用户从 01a/01b 进入，主 CTA 是否进入 06 Compose | ≥ 5/10 主动点“写下这一趟”；事件率 ≥45% |
| C-2 私人卡完成 | §13.1 / §13.2 | 进入 Compose 后，60 秒内写一句并生成私人 Cloud Card | ≥ 5/10 生成；`private_card_generated / compose_started >= 55%`，最低 gate 45% |
| C-3 分享冲动 | §13.1 | 看到 07/08 Private Share 后主动保存或分享 | ≥ 3/10 真实分享；`private_card_shared / private_card_generated >= 25%`，最低 gate 20% |
| C-4 卡片审美抗 UGC 波动 | §9 07 / §15 风险 | 用 5 条普通文本（含“飞机晚点了，累死”）生成卡，盲评是否愿意发朋友圈 | ≥ 6/10 认为“像明信片/票根，不像截图” |
| C-5 验证后置边界感 | §3.3 / §9 08 / §10 #3 | 用户能说清“私人卡不需验证；同班机发布/评论需验证” | ≥ 8/10 正确回答；未验证发布同班机 100% 被拦 |
| C-6 离线可靠性 | §2 / §13.2 | 无网络写作、生成本地卡、排队同步、失败重试 | 0 丢稿；`offline_sync_completed / offline_sync_started >= 95%` |
| C-7 隐私信任 | §3.3 / §10 #20 | 公开区域和埋点不出现具体座位号、姓名、票号、证件号 | 0 泄露；任一泄露直接 NO-GO |

**C-1 / C-2 / C-3 任一不达标 = Stage 1 验证失败，回 PM/Design，不进 dev 扩展。**  
**C-5 / C-6 / C-7 任一失败 = NO-GO，不能用“体验问题”降级。**

---

## 3. P0 测试 Case（必须 100% 通过）

### 3.1 First Launch / Guest / 权限节奏

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P0-01 | 00a 首次 hook | 全新设备冷启 App | 看到“登机前 30 分钟，给这趟飞行留一句话”；主 CTA 是“写下这一趟”，不是“扫描登机牌” |
| P0-02 | 00b 权限前置说明 | 00a → 点主 CTA | 展示相机/相册/通知用途说明；不得提前弹系统权限框；主 CTA 是“继续，不现在授权” |
| P0-03 | 00c 隐私承诺 | 00b → 00c | 明确“票证原图默认不保存”“不显示姓名/座位号/票号”“评论只在同班机内” |
| P0-04 | Guest mode | 00d 点“开始我的第一次飞行” | 无需注册创建 Guest Account，并进入 01a |
| P0-05 | 首次主路径不扫码 | 01a 点“写下这一趟” | 直接进入 06 Compose；不要求航班号、登机牌、权限 |

### 3.2 Compose 一句话优先

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P0-06 | 未添加航班也可写 | 无 FlightContext / FlightProof 进入 06 | 顶部 chip 显示“未添加航班 · 稍后补”；输入框可用 |
| P0-07 | 一句话完成态 | 输入 1-20 字，点“生成私人明信片” | 允许生成；不得提示“字数不够”或要求 200 字 |
| P0-08 | 空白墙消除 | 打开 06 输入框 | placeholder/ghost text 至少 3 行引导：为了什么飞、坐在哪里、想带什么上飞机 |
| P0-09 | 模板写作 | 选择 3 个模板之一并填空 | 模板内容进入正文；用户可编辑；不清空已输入文本 |
| P0-10 | 语音转文字 | 按住说话 → 转写 → 确认 | 文本进入正文；转写成功后音频临时文件删除 |
| P0-11 | 草稿本地保存 | 输入文字后杀 App 重开 | 回到 06 或 draft_resume，原文和保存状态存在 |

### 3.3 Card Studio / Private Share

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P0-12 | 私人卡无需验证 | 未验证状态从 06 → 07 | 成功生成 Cloud Card；metadata 可显示“航班待确认”，不得阻塞 |
| P0-13 | 默认模板 | 07 首次展示 | 默认是 `boarding_postcard`：深蓝底 + 米黄票根/信纸 + 路线坐标 + 大字 quote |
| P0-14 | 普通 UGC 兜底 | 用“飞机晚点了，累死。”生成卡 | 走 flight_log / 票根备注风格；不强套金色云海诗意图 |
| P0-15 | quote 可编辑 | 点卡片大字 quote 并修改 | 更新后卡片重新渲染；正文不丢失 |
| P0-16 | Private Share | 08 Private Share 保存/分享图片 | 不要求验证；不进入同班机；图片无 App Store badge / “立即下载” |
| P0-17 | 分享落地页 | 识别二维码 / deep link 打开分享 | 进入 16 Shared Card Landing / Same Flight Notes；不得直接跳 App Store |

### 3.4 Add Flight Info / Same Flight Gate

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P0-18 | 手动航班信息 | 02 从未添加状态进入；再输入航班号 + 日期/航线 | 输入框默认必须为空，只能显示示例 placeholder；用户输入后可创建 FlightContext；无需接 flight tracking API；不得预填 `MU5301` / `SHA → CTU` 等样例航班 |
| P0-18A | 旧版本样例航班迁移 | 从旧构建升级或带有历史本地状态启动；本地曾保存 `MU5301` / `SHA → CTU` 样例 FlightContext | App 启动时清理未被用户内容引用的样例航班；02 / 15 仍默认空值；用户输入不得被拼接成 `MU5301CA1234` |
| P0-19 | 票证验证 | 上传登机牌/电子票/行程截图 | 进入 03/04/05；生成 FlightProof 或可修正字段 |
| P0-20 | 未验证拦同班机发布 | 未验证从 08 点“发布到同班机” | 被引到 02；内容和卡片状态保留；触发 `same_flight_publish_blocked(reason=unverified)` |
| P0-21 | 验证后发布 | 完成 05 Confirm 后回 08 发布 | `same_flight_publish_completed`；进入 09 Flight Space |
| P0-22 | 同班机评论权限 | 已验证同航班用户进入 11A | 显示评论框；可评论 |
| P0-23 | 非同班机只读 | 未验证 / 不同航班用户进入同一 detail | 无评论框；显示“评论只在本航班开放” |

### 3.5 隐私 / 数据隔离 / 安全

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P0-24 | 公开区域无具体座位 | 检查 09 / 10 / 11 / 16 | 不出现 `14A` / `21C` 等具体座位；只显示“靠窗的人 / 通道旁的人 / 同机乘客” |
| P0-25 | 票证敏感信息 | 上传含姓名/票号/证件号票证，完成验证 | 原图不进入公开内容；Post / Comment / Share / analytics 不含姓名、票号、证件号 |
| P0-26 | 原图保留策略 | FlightProof 确认后查存储 | 票证原图按 PRD 默认删除；仅保留 hash 或本人可见脱敏图 |
| P0-27 | 未鉴权 API | 直接请求 `/api/posts/create`, `/api/flight-proof/create`, `/api/comments/create` 无 token | 401 / 403；不创建数据 |
| P0-28 | 双账号数据隔离 | 账号 A 建 Post，账号 B 直接 GET/PATCH/DELETE A 的私有资源 | 403 / 404；不能编辑/删除；RLS / 服务端校验命中 |

### 3.6 离线 / 通知

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P0-29 | 离线写作 | 飞行模式进入 06 写一句 | 本地保存；顶部显示“已离线保存，落地后自动同步” |
| P0-30 | 离线卡片预览 | 无网络从 06 → 07 | 本地渲染 preview；不因上传失败阻塞 |
| P0-31 | 落地同步 | 离线生成卡后联网 | 自动 `offline_sync_started` → `offline_sync_completed`；失败时可重试，内容不丢 |
| P0-32 | 登机提醒 | 15 从未添加状态进入；手动输入航班号并开启 30 分钟提醒 | 输入框默认必须为空，只能显示示例 placeholder；本地/服务端调度成功；通知点开进入 06 Compose；不得预填 `MU5301` / `SHA → CTU` 等样例航班 |
| P0-33 | 同班机新笔记通知 | 用户已验证并发同班机 Post，24-48h 内同航班有新 Post | 收到通知；点开进入 09 对应新笔记；未验证用户不收到同班机通知 |

### 3.7 账号升级 / 合规动作

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P0-34 | 账号升级软硬 modal | Guest 第 2 / 第 3 张同班机 Post 后 | 第 2 张显示软 modal；第 3 张显示硬 modal；第 4 张以后不重复弹 |
| P0-35 | 微信 / 手机号登录 | 14 分别走微信、手机号验证码 | 微信按钮视觉权重最高；无微信 App 时灰显并提示手机号；手机号 +86 默认、60 秒倒计时、3 次错误限流 |
| P0-36 | Guest 数据不丢 | Guest 写卡后绑定微信/手机号；卸载重装后登录 | user_id 或 merge 逻辑保留历史 Post，落 01b |
| P0-37 | 删除账号 | 13 点删除账号 | 二次确认 + 当前登录方式校验；软删除 + 30 天恢复期文案 |
| P0-38 | UGC 安全动作 | 任意 Post / Comment 执行举报、隐藏、屏蔽、删除自己的内容 | 12 Report < 3 步可达；动作立即生效；自己的 Post/Comment 可删除 |

---

## 4. P1 测试 Case（≥ 80% 通过）

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P1-01 | Returning routing | 已发布 ≥1 张卡后重开 App | 落 01b，不再走 00a-00d / 01a |
| P1-02 | My Flights 留存 | 01b → 09b | 列表显示航班、日期、第一句话摘句；不是纯航班号历史 |
| P1-03 | 自己详情 | 09b 点自己卡 → 11A | 可看完整正文、卡片、编辑/删除入口 |
| P1-04 | 航班状态 chip | 06 分别在未绑定/已添加/已验证状态查看 | chip 文案准确：未添加、航班号、已验证同班机 |
| P1-05 | 三模板可用 | 07 切换 `boarding_postcard` / `route_poem` / `cloud_window` | 均可渲染；切换不丢正文和 quote |
| P1-06 | cloud_window 推荐约束 | 文案/照片不匹配时查看模板推荐 | 不默认推荐照片叠字；默认仍是明信片或 flight_log |
| P1-07 | Flight Confirm 来源 CTA | 从 06/07/08/15/01 进入 05 | CTA 分别为确认并发布、确认并设置提醒、解锁同班机 |
| P1-08 | OCR 失败 fallback | 上传糊图/非票证 | 不死循环；进入可修正字段；内容不丢 |
| P1-09 | 国际航班号 | 输入/识别 JL123 / BA286 / UA857 | 不被国内格式校验拒绝 |
| P1-10 | Discovery 锁定 | 10 切不同 tab | 同旅程/目的地/热点均无评论框，有锁定解释 |
| P1-11 | 同班机冷启动 | 进入只有自己一条 Post 的 Flight Space | 显示“你是第一个留下的人”类 empty state |
| P1-12 | 分享渠道 | 08 Private Share | 保存图片 / 微信 / 朋友圈 / 小红书 / 复制链接入口齐全 |
| P1-13 | 分享 landing 继续 | 16 上点“看同班机笔记/添加提醒” | 已安装走 App，未安装 Web fallback 可预览并进入 15 |
| P1-14 | 设置页连接状态 | 13 绑定微信后查看状态 | 不用大面积微信绿；显示独立产品风格的已连接状态 |
| P1-15 | 登录失败处理 | 微信取消 / SMS 发送失败 / 验证码错误 / 限流 | 文案明确；可回到手机号或稍后重试 |
| P1-16 | 相册权限时机 | 仅保存图片时触发相册权限 | 权限在真实使用点申请；拒绝后仍可复制链接 |
| P1-17 | 通知权限时机 | 仅设置提醒时触发通知权限 | 拒绝后提醒不创建，并给出可理解状态 |
| P1-18 | 分享图尺寸 | 保存 Cloud Card 图片 | 图片清晰、无裁切、无多余 UI chrome |
| P1-19 | OG / QR 端点 | Web fallback / 动态分享图 | HTTP 200 且 body size > 1000 bytes；不能 0 bytes |
| P1-20 | 交互反馈 | 保存、分享、复制、发布、举报等按钮 | 2 秒内有可见反馈；不只改 aria-label/title |

---

## 5. P2 测试 Case（≥ 60% 通过）

| # | 功能 | 测试步骤 | 预期结果 |
|---|---|---|---|
| P2-01 | 视觉调性 | 检查 00a / 07 / 08 | 深蓝氛围 + 米白纸张，核心操作不全黑、不像海外小众工具 |
| P2-02 | 文案一致性 | 全流程扫 CTA | 统一“写下这一趟 / 生成私人明信片 / 验证航班并发布到同班机” |
| P2-03 | WeChat 绿限制 | 检查 13 / 14 | `#07C160` 只用于微信登录按钮，不用于大面积状态卡 |
| P2-04 | 00a 不炫技 | 首次欢迎页 | 不放完整复杂样例卡；hook 先击中，再展示价值 |
| P2-05 | 输入体验 | 小屏 iPhone 在 02 / 06 / 15 打字 | 键盘弹起后 CTA 可达；输入区不被遮挡；键盘必须有可见方式收起，不能只能靠系统返回/杀 App |
| P2-06 | 07 metadata 层级 | 查看卡片小字信息 | 航班/日期/主题词不抢大字 quote |
| P2-07 | 08 状态解释 | 私人分享和同班机发布并列展示 | 用户能一眼理解两者区别 |
| P2-08 | 09 信息密度 | Flight Space 列表 | 摘句、主题、时间、模糊身份足够，不只是航班号 |
| P2-09 | 10 白色弹窗修复 | Discovery 中弹窗/卡片 | 不出现未适配深色主题的默认白弹窗 |
| P2-10 | 15 提醒设置 | 时间/航班输入 | 文案轻，不像航班工具；不展示延误/登机口承诺 |
| P2-11 | 16 未安装状态 | 浏览器打开 share landing | 可读、可保存提醒，不出现强下载墙 |
| P2-12 | 错误态语气 | 网络失败、OCR 失败、权限拒绝 | 文案冷静、具体，不情绪绑架 |
| P2-13 | Loading 动效 | OCR / 转写 / 卡片生成 | 有飞行/纸张/坐标感，不是普通 skeleton |
| P2-14 | 无工程缩写 | 用户可见 UI 扫描 | 不出现 tok / req / ms / cnt / avg 等工程词 |

---

## 6. 埋点契约 Case（P0，全部通过；缺一条 = NO-GO）

> Dev 完成时必须交付 `head_in_clouds/ANALYTICS_CONTRACT.md`，包含每个事件的 code location、触发步骤、properties、中国区 first-party event pipeline staging evidence。PRD §13.3 中每个事件至少要有一条 QA 验证路径。
>
> 中国市场生产验收不再以 iOS App 直连 PostHog Cloud 为目标。验收口径改为：App → first-party `/events` API → 中国区 staging event log/dashboard；PostHog 只能作为服务端异步下游，不作为客户端可用性的判断依据。

### 6.1 Baseline 6 条（ops 周报硬依赖）

| # | Event | 触发步骤 | 预期 properties | 验证方式 |
|---|---|---|---|---|
| B-01 | `signup_completed` | Guest 升级微信/手机号成功 | `user_id`, `method`, `utm_source` 非空 | Event Pipeline staging |
| B-02 | `user_returned` | 次日打开 App | `user_id`, `days_since_signup==1` | Event Pipeline staging |
| B-03 | `core_action_completed` | 完成私人卡生成 / 同班机发布 | `action_name=private_card_generated` 或 `same_flight_publish_completed` | Event Pipeline staging |
| B-04 | `paywall_viewed` | 触发高级模板/付费入口 | `plan_shown`, `source_page` | Event Pipeline staging |
| B-05 | `checkout_started` | 点付费按钮 | `plan`, `price_cny` | Event Pipeline staging |
| B-06 | `subscription_created` / IAP 成功事件 | StoreKit sandbox 或服务端 receipt 验证 | `$lib` 为服务端来源，不是客户端 `web` | Apple/IAP log + Event Pipeline staging |

### 6.2 Onboarding / Opening

| # | Event | 触发步骤 | 预期 properties | 验证方式 |
|---|---|---|---|---|
| A-01 | `app_first_launched` | 全新安装首次启动 | `device_id`, `app_version` | Event Pipeline staging |
| A-02 | `onboarding_step_viewed` | 依次进入 00a/00b/00c/00d | `step` 正确 | Event Pipeline staging |
| A-03 | `onboarding_completed` | 00d Guest 开始 | `duration_ms`, `guest=true` | Event Pipeline staging |
| A-04 | `permission_granted` / `permission_denied` | 相机/相册/通知真实申请 | `type`, `source_screen` | Event Pipeline staging |
| A-05 | `guest_mode_chosen` | 00d 点开始 | `device_id`, `source=00d` | Event Pipeline staging |
| A-06 | `01a_landing_viewed` / `01b_landing_viewed` / `landing_viewed` | 首次/回访 Opening | `is_returning`, `post_count` | Event Pipeline staging |

### 6.3 Compose / Card / Offline

| # | Event | 触发步骤 | 预期 properties | 验证方式 |
|---|---|---|---|---|
| A-07 | `compose_started` | 从 01a/01b/提醒/share landing/draft resume 进入 06 | `source` 枚举正确 | Event Pipeline staging |
| A-08 | `compose_mode_selected` | 选一句话/模板/语音/free text | `mode` 正确 | Event Pipeline staging |
| A-09 | `template_prompt_selected` | 选模板 | `template_id` | Event Pipeline staging |
| A-10 | `voice_recording_started` / `voice_transcribed` | 录音并转写 | `success`, `duration_ms`；不带音频内容 | Event Pipeline staging |
| A-11 | `draft_resumed` | 杀 App 后恢复草稿 | `draft_age_ms`, `source` | Event Pipeline staging |
| A-12 | `offline_draft_saved` | 离线写作 | `content_length`, `has_flight_context` | Event Pipeline staging / local log |
| A-13 | `private_card_generated` | 生成私人卡 | `template_id`, `has_flight_context`, `verified=false/true` | Event Pipeline staging |
| A-14 | `cloud_card_rendered` | 07 渲染卡片 | `template_id`, `offline` | Event Pipeline staging |
| A-15 | `headline_quote_edited` | 编辑大字 quote | `auto_generated_before`, `length` | Event Pipeline staging |
| A-16 | `private_card_saved` / `cloud_card_saved` | 保存图片 | `template_id`, `channel=save_image` | Event Pipeline staging |
| A-17 | `private_card_shared` / `card_shared` | 微信/朋友圈/小红书/复制链接 | `channel`, `template_id` | Event Pipeline staging |
| A-18 | `offline_sync_started` / `offline_sync_completed` / `offline_sync_failed` | 离线卡联网同步 | `queue_id`, `reason` | Event Pipeline staging |

### 6.4 Flight Verification / Same Flight

| # | Event | 触发步骤 | 预期 properties | 验证方式 |
|---|---|---|---|---|
| A-19 | `flight_intent_created` | 15 或 02 手动航班号 | `source`, `flight_number` 脱敏, `reminder_offset_minutes` | Event Pipeline staging |
| A-20 | `flight_verification_started` | 02 上传票证或手动确认 | `source`, `method` | Event Pipeline staging |
| A-21 | `capture_started` / `capture_completed` / `ocr_failed` | 票证照片/截图验证 | `proof_source_type`, `upload_method`；不带 OCR raw text | Event Pipeline staging |
| A-22 | `flight_confirmed` / `flight_proof_created` / `flight_verification_completed` | 05 Confirm | `method`, `success`, `ocr_corrected` | Event Pipeline staging |
| A-23 | `same_flight_publish_started` | 点发布到同班机 | `verified` | Event Pipeline staging |
| A-24 | `same_flight_publish_blocked` | 未验证发布同班机 | `reason=unverified/no_network` | Event Pipeline staging |
| A-25 | `same_flight_publish_completed` | 验证后发布成功 | `flight_space_id`, `template_id` | Event Pipeline staging |
| A-26 | `flight_space_viewed` | 进入 09 | `source`, `verified=true` | Event Pipeline staging |
| A-27 | `post_detail_viewed` | 进入 11A/11B | `source=same_flight/discovery`, `can_comment` | Event Pipeline staging |
| A-28 | `comment_written` | 同班机评论 | `is_same_flight=true`, `comment_length` | Event Pipeline staging |

### 6.5 Reminder / Share Landing / Retention

| # | Event | 触发步骤 | 预期 properties | 验证方式 |
|---|---|---|---|---|
| A-29 | `boarding_reminder_scheduled` | 15 设置提醒 | `flight_number` 脱敏, `reminder_at` | Event Pipeline staging |
| A-30 | `boarding_reminder_sent` / `boarding_reminder_opened` | 触发并打开通知 | `flight_number` 脱敏 | Event Pipeline + local/APNs push log |
| A-31 | `share_landing_opened` | 打开 16 | `source`, `flight_number` 脱敏, `route` | Event Pipeline staging |
| A-32 | `share_landing_same_flight_tapped` | 16 点同班机笔记 | `installed_app`, `route` | Event Pipeline staging |
| A-33 | `share_landing_reminder_started` | 16 设置提醒 | `flight_number` 脱敏 | Event Pipeline staging |
| A-34 | `same_flight_note_notification_sent` / `opened` | 24-48h 新笔记通知 | `flight_number` 脱敏, `hours_after_post` | Event Pipeline + APNs push log |
| A-35 | `same_flight_notes_viewed` | 从通知/分享/App 进入笔记 | `source` | Event Pipeline staging |

### 6.6 Account / Settings / Safety

| # | Event | 触发步骤 | 预期 properties | 验证方式 |
|---|---|---|---|---|
| A-36 | `account_upgrade_prompt_shown` / `dismissed` | 第 2/3 张同班机 Post 后 | `variant`, `trigger` | Event Pipeline staging |
| A-37 | `account_upgrade_started` / `completed` | 走微信或手机号升级 | `method`, `source`, `merged_with_existing` | Event Pipeline staging |
| A-38 | `account_settings_viewed` | 打开 13 | `account_type` | Event Pipeline staging |
| A-39 | `sign_in_started` / `succeeded` / `failed` | 微信/手机号登录 | `method`, `reason` | Event Pipeline staging |
| A-40 | `sms_code_sent` / `verified` / `resend` | 手机号验证码 | `phone_country_code`，不含完整手机号 | Event Pipeline staging |
| A-41 | `wechat_auth_initiated` / `wechat_auth_callback_received` | 微信授权 | `source`, `success` | Event Pipeline staging |
| A-42 | `sign_out_completed` | 退出登录 | `method` | Event Pipeline staging |
| A-43 | `account_deletion_requested` / `confirmed` | 删除账号 | `reauth_method` | Event Pipeline staging |
| A-44 | `discovery_viewed` | 打开 10 | `tab_name` | Event Pipeline staging |
| A-45 | `report_submitted` / `block_user` | 举报/屏蔽 | `target_type`, `reason` | Event Pipeline staging |

### 6.7 埋点安全自查（P0）

| # | 检查项 | 预期 |
|---|---|---|
| A-SEC-01 | Event properties 扫描 | 不出现 password / 明文 email / phone_e164 / credit_card / id_card / passport_no / ticket_no / api_token |
| A-SEC-02 | 航班号脱敏 | 事件属性只能 hash 或 prefix，不传完整航班号到 event pipeline 或任何下游 analytics |
| A-SEC-03 | 票证 OCR raw text | 不进入 event properties |
| A-SEC-04 | 公开座位号 | 任何 public event 不含 `seat_number` 或 `14A` 类值 |
| A-SEC-05 | 服务端收入事件 | IAP / subscription 成功事件必须来自服务端 webhook / receipt verification，不是客户端 track |

---

## 7. 漏斗通过线

| 漏斗 | 公式 | 目标 | 类型 |
|---|---|---:|---|
| Onboarding 完成率 | `onboarding_completed / app_first_launched` | ≥ 70% | gate |
| 写作启动率 | `compose_started / (01a_landing_viewed + 01b_landing_viewed)` | ≥ 45% | gate |
| 私人卡生成率 | `private_card_generated / compose_started` | ≥ 55% | north star；最低 45% gate |
| 60 秒一句话完成率 | 60s 内 `private_card_generated / compose_started` | ≥ 45% | gate |
| 航班验证启动率 | `flight_verification_started / private_card_generated` | ≥ 25% | directional |
| 同班机发布完成率 | `same_flight_publish_completed / flight_verification_started` | ≥ 60% | gate |
| Cloud Card 分享率 | `private_card_shared / private_card_generated` | ≥ 25% | gate；最低 20% |
| 登机提醒打开率 | `boarding_reminder_opened / boarding_reminder_sent` | ≥ 20% | gate |
| 离线同步成功率 | `offline_sync_completed / offline_sync_started` | ≥ 95% | gate |
| 分享落地页继续率 | `(share_landing_same_flight_tapped + share_landing_reminder_started) / share_landing_opened` | ≥ 15% | directional |
| 同班机新笔记通知打开率 | `same_flight_note_notification_opened / same_flight_note_notification_sent` | ≥ 18% | gate |

---

## 8. 按页面验收（PRD 23 屏）

| 页面 | 必须存在 | 不允许存在 | 关键 case |
|---|---|---|---|
| 00a Welcome | hook / 明信片纸张锚点 / “写下这一趟” | 注册框、扫描硬门槛、完整炫技样例 | P0-01 |
| 00b Permission Primer | 相机/相册/通知用途说明 / “继续，不现在授权” | 提前系统权限弹窗 | P0-02 |
| 00c Privacy Promise | 原图默认不保存 / 不显示姓名座位票号 | 模糊承诺 | P0-03 |
| 00d Get Started | Guest start / 已有账号登录 | 强注册 | P0-04 |
| 01a Opening First | 大 Cloud Card sample / 写下这一趟 / 添加航班号次入口 | 扫码主路径 | P0-05 |
| 01b Returning | 最近卡 / settings / 写下一趟 / 我的飞行册 | 回访还走 01a | P1-01 |
| 02 Add Flight Info | 手动航班号+日期 / 票证快捷验证 | 写作前不可跳过 | P0-18 |
| 03 Privacy | 脱敏说明 / 原图策略 | 默认保存原图 | P0-25 |
| 04 Unlock | OCR / 识别中状态 | 死循环 | P1-08 |
| 05 Confirm | 可修正字段 / 来源化 CTA | 姓名/证件号必填 | P0-19 / P1-07 |
| 06 Compose | 一句话、模板、语音、离线状态、航班 chip | 字数不足阻塞 | P0-06 ~ P0-11 |
| 07 Card Studio | boarding_postcard 默认 / quote 编辑 / UGC 兜底 | App 截图式分享卡 | P0-12 ~ P0-15 |
| 08 Publish / Share | Private Share / Same Flight Publish 拆分 | 私人卡强制验证 | P0-16 / P0-20 / P0-21 |
| 08b Upgrade Modal | 第 2 张软、第 3 张硬 | 每次都弹 | P0-34 |
| 09 Flight Space | 同班机列表 / 模糊身份 / 评论入口 | 具体座位号 | P0-22 / P0-24 |
| 09b My Flights | 航班历史 + 第一句话摘句 | 纯航班号列表 | P1-02 |
| 10 Discovery | 4 tab / 只读锁定 / 深色主题适配 | 白色默认弹窗、评论框 | P0-23 / P2-09 |
| 11 Detail | 11A 可评论 / 11B 只读 | discovery detail 评论框 | P0-22 / P0-23 |
| 12 Report | 举报、隐藏、屏蔽 | 入口超过 3 步 | P0-38 |
| 13 Settings | 账号状态、通知、删除账号 | 微信绿大面积状态卡 | P0-37 / P2-03 |
| 14 Sign In | 微信优先、手机号次选 | 只有微信且不可替代 | P0-35 |
| 15 Reminder | 手动航班提醒 / 30 分钟默认 | 航班追踪工具化 | P0-32 |
| 16 Shared Landing | 卡片落地、同班机笔记、提醒入口 | 直接 App Store / 强下载墙 | P0-17 |

---

## 9. 边界与异常 case

| # | 场景 | 步骤 | 预期 |
|---|---|---|---|
| E-01 | 空正文 | 06 不输入点 CTA | 不生成；提示轻量补一句 |
| E-02 | 极短正文 | 输入“累” | 可生成私人卡 |
| E-03 | 超长正文 | 输入 >200 字 | 阻止或截断，并明确剩余字数 |
| E-04 | 离线杀进程 | 离线写完杀 App，联网重开 | 草稿和 queued 状态存在 |
| E-05 | 重复点发布 | 连点 Same Flight Publish | 只创建一条 Post，按钮有 pending 态 |
| E-06 | OCR 完全失败 | 上传纯黑/风景 | 10 秒内 fallback 到可修正字段 |
| E-07 | 非票证图片 | 上传猫照 | 不误生成 verified FlightProof |
| E-08 | 不同日期同航班号 | 同一 MU5301 不同日期 | FlightSpace 分离 |
| E-09 | 未来航班提醒 | 未来航班手动录入 | 可设置提醒，不要求 proof |
| E-10 | 过去航班提醒 | 过去航班尝试提醒 | 不创建过期提醒，提示只能写卡/补发布 |
| E-11 | 微信 App 未装 | 14 查看登录 | 微信按钮灰显，手机号可用 |
| E-12 | SMS 限流 | 连续输错 3 次 | 限流，不泄露手机号是否已注册 |
| E-13 | 被屏蔽用户 | A 屏蔽 B 后看 09/10/11 | B 内容不再出现 |
| E-14 | 分享图损坏 | QR/deep link 无效 | 16 有兜底可读内容，不崩溃 |

---

## 10. 测试环境 & 数据

### 10.1 设备

- iPhone 12/13/14/15 任一主测机 + 一台小屏旧机型（SE / 8）。
- iOS 16+，开启/关闭相机、相册、通知权限组合测试。
- Safari / Chrome Mobile 验证 16 Shared Landing 与 Web fallback。
- 飞行模式 / 弱网 / 无网环境用于离线测试。

### 10.2 测试 fixture

`head_in_clouds/test_fixtures/`（dev 阶段创建）：

| 类型 | 数量 | 用途 |
|---|---:|---|
| 登机牌照片（脱敏） | 6 | FlightProof / redaction |
| 电子机票截图 | 4 | ticket_screenshot |
| 行程/航班截图 | 4 | itinerary_screenshot |
| 反例图片 | 3 | 非票证、纯黑、风景 |
| 模糊/翻拍/极端角度 | 3 | OCR 失败 fallback |
| 普通 UGC 文本 | 5 | 卡片审美抗波动 |
| 诗意 UGC 文本 | 5 | 卡片上限表现 |

### 10.3 Canonical 案例

- 航班：`MU5301`，上海 SHA → 成都 CTU，日期使用测试当天 + 1。
- 公开身份：只允许“靠窗的人 / 通道旁的人 / 同机乘客 / 前舱附近的人”。
- 禁止公开：`14A`、真实姓名、票号、证件号、完整手机号。
- 普通文本 fixture：`飞机晚点了，累死。`
- 情绪文本 fixture：`上次坐这趟还是去年。这次终于不是出差，是去看一个等了我四个月的人。`

### 10.4 测试账号

- Guest A：首次用户，一张私人卡。
- Guest B：第 2 / 第 3 张同班机 Post，用于升级 modal。
- Verified A/B/C：同一航班同一日期，用于评论和新笔记通知。
- Verified D：同航班号不同日期，用于隔离。
- User E：未验证，只能私人卡和只读 discovery。
- Upgraded user：微信/手机号登录，用于换设备拉回。

---

## 11. App Store / 合规自查

| # | 项 | 标准 | case |
|---|---|---|---|
| AS-01 | 用户举报内容 | 每条 Post / Comment 都有举报入口 | P0-38 |
| AS-02 | 屏蔽用户 | 屏蔽后该用户内容不再出现 | P0-38 / E-13 |
| AS-03 | 隐藏内容 | 立即从当前视图消失 | P0-38 |
| AS-04 | 作者删除 | 自己 Post / Comment 可删除 | P0-38 |
| AS-05 | 删除账号 | 13 可达，二次确认，软删除 + 恢复期 | P0-37 |
| AS-06 | 隐私标签 | User Content / Identifiers / Usage Data；不收集 Financial / Contacts / Health | dev 准备截图 |
| AS-07 | 微信登录 4.8 风险 | 如审核要求 Apple Sign In，回退设计可复用 v2.1 | PM 决策记录 |
| AS-08 | 通知权限 | 只在提醒/同班机通知实际使用时申请 | P1-17 |

---

## 12. Dev 完成标准

Dev 在 `.dev.manifest.json` 必须四项全 `true`，才允许跑 test-exec：

| 字段 | 含义 | 验证 |
|---|---|---|
| `build_passed` | iOS / PWA build 全绿 | Xcode Archive / Web build 成功 |
| `e2e_passed` | 自动化 e2e 全过 | XCUITest + Playwright fallback |
| `manual_walkthrough` | 23 屏 + 关键状态全部走过 | dev 录屏 + 截图归档 |
| `analytics_contract_verified` | PRD §13.3 + baseline 事件全部可见 | Event Pipeline staging URL / 查询结果 / 截图 |

必须交付 artifact：

- `head_in_clouds/ANALYTICS_CONTRACT.md`
- `head_in_clouds/DEPLOY.md`
- `head_in_clouds/test_fixtures/` fixture 说明
- 23 屏 walkthrough 截图或录屏

任一项缺失 → 不允许进入 test-exec。

---

## 13. Test-exec GO / NO-GO 判定

### GO

- P0 通过率 100%。
- P1 通过率 ≥80%。
- P2 通过率 ≥60%。
- 核心能力门槛 C-1 ~ C-7 全部达标。
- 埋点 baseline 6 条 + PRD §13.3 全量事件可见，properties 齐全。
- 漏斗 gate 达标或有真实样本不足说明，但 C-1/C-2/C-3 不可豁免。
- App Store / UGC / 删除账号合规项全部存在。

### NO-GO

- 任一 P0 失败。
- 写作或私人卡被航班验证阻塞。
- 未验证用户能发布同班机、评论、收到同班机通知。
- 离线写作 / 卡片 / 同步任一丢稿。
- 公开区域出现具体座位号、姓名、票号、证件号。
- Cloud Card 上出现 App Store badge / “立即下载”。
- 埋点缺任一 baseline 或自定义关键事件。
- C-1 / C-2 / C-3 任一不达标。

### GO with Notes

- P0 100% + C-1~C-7 全过 + analytics 全过，但 P1/P2 低优先级问题未全修。
- 所有 notes 必须进入 TEST_REPORT 的已知问题表，并指定修复版本。

---

## 14. 汇总

| 类别 | 数量 |
|---|---:|
| P0 | 38 |
| P1 | 20 |
| P2 | 14 |
| 边界 / 异常 case | 14 |
| 核心能力门槛 | 7 |
| 漏斗 gate / directional 指标 | 11 |
| 埋点 case | 45 组，覆盖 PRD §13.3 全量事件 + baseline 6 条 |
| 埋点安全自查 | 5 |
| App Store / 合规自查 | 8 |

> 测试角色完成 Phase 1。Founder review 通过后再 approve test-plan；dev 必须先看到这份 v2.4 测试计划再开工。
