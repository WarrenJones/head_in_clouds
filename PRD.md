# PRD：Head in the Clouds / 云上心事 — v2.4 Expression First

> **版本**：v2.4 · 2026-05-20 表达先行 + 验证后置
> **作者**：小品（PM）
> **状态**：draft，待创始人 approve
> **替代**：[PRD-v1-archive.md](PRD-v1-archive.md)（2026-05-15 版，已归档）
> **吸收**：[PRD-addendum-onboarding-returning.md](PRD-addendum-onboarding-returning.md)（5/16 onboarding + returning user 补丁）
>
> **修订历史**：
> - v2.0 (2026-05-16)：v1 完整重写，补 onboarding + returning state + 状态机 + 6 场景 + 5 闭环
> - v2.1 (2026-05-17)：补登录链路（Apple Sign In + 邮箱 magic link）
> - **v2.2 (2026-05-17)**：创始人决定**只做微信登录 + 手机号短信验证码**，移除 Apple Sign In / 邮箱 magic link。屏数 21 不变（08b / 13 / 14 屏保留，内容改）。
> - **v2.3 (2026-05-19)**：创始人指出原漏斗高估“飞行中主动想起 App”的概率。本版把主逻辑改成：飞行前用航班提醒锚定意图，飞行中离线一句话写作，落地自动同步，Cloud Card 作为获客资产扩散，48 小时内用同班机新笔记召回。
> - **v2.3.1 (2026-05-19)**：根据 GPT Image 2 产出的四张分享卡评审，锁定“复古明信片 / 票根信纸”作为默认 Cloud Card 方向；照片叠字模板降级为可选。同步收敛深色 UI 和微信绿使用边界。
> - **v2.4 (2026-05-20)**：根据设计/交互复审，把主路径从“扫描登机牌优先”调整为“表达先行，验证后置”。用户可先写一句并生成私人 Cloud Card；航班验证只作为发布到同班机、评论、同班机通知的门槛。同步修复公开区域具体座位号暴露与隐私承诺冲突。
>
> **本次改动动机**：触发场景窄、飞行情绪密度不稳定、国内航班 WiFi 覆盖弱、200 字写作门槛高；同时“先扫描登机牌”会把系统需要放在用户表达动机之前。Stage 1 必须验证“用户无需先证明自己，也能在 60 秒内完成一句话私人 Cloud Card；验证后才进入同班机社交”，否则不继续扩社交和 IAP。
>
> **⚠️ App Store 4.8 风险提示**：iOS App 用了 social login service（微信）作为账号设立方式时，App Store 政策原则上要求**同时提供 Apple Sign In 作为等价选项**。中国区 App（抖音 / 美团 / 京东等）通常用"手机号+微信"组合通过审核，但仍可能被刁难。如审核驳回，回退方案：把 Apple Sign In 重新加回 14（这次砍掉的代码可复用）。

---

## 0. 修订关键点（vs v1 / v2.1 / v2.2）

| 维度 | v1 | v2.4 |
|---|---|---|
| 屏数 | 12 | **23**（00a-00d / 01a / 01b / 02-08 / **08b** / 09 / 09b / 10 / 11A / 11B / 12 / **13** / **14** / **15** / **16**） |
| Onboarding | ❌ 没有 | ✅ 4 屏 first-launch flow |
| 账号策略 | ❌ 没说 | ✅ Guest mode + 软升级（默认） |
| **登录方式** | ❌ 没画 | ✅ **微信登录（主）+ 手机号短信验证码（辅）**——v2.1 的 Apple Sign In / 邮箱 magic link 已移除 |
| Returning user Opening | ❌ 和首次用户同一屏 | ✅ 独立 01b 屏 |
| 我的飞行册 | ❌ 没设计 | ✅ 09b 屏 |
| 用户状态机 | ❌ 没有 | ✅ §4 完整决策树 |
| Scenario 矩阵 | ❌ 没有 | ✅ §5 十一大主场景（新增 S8-S11：登机提醒 / 离线同步 / 分享落地页 / 同班机召回） |
| 闭环 | 1 个隐含 | ✅ §6 十条显式闭环（新增飞行前锚定、离线同步、分享扩散、同班机召回） |
| 写作单元 | 30-300 字正文 | ✅ 最小发布单元是一句话；模板和语音只降低门槛，不把短内容视为未完成 |
| Cloud Card | 分享结果 | ✅ 主动获客资产：默认“复古明信片 / 票根信纸”方向；照片叠字只做可选模板；图片内无下载 CTA，只保留极小品牌标识和同班机入口 |
| 航班验证 | 创作前硬门槛 | ✅ 表达先行，验证后置：私人卡不需要验证；同班机发布 / 评论 / 通知必须验证 |
| 隐私边界 | 未显式约束座位号 | ✅ 公开区域禁止具体座位号，只能显示“靠窗的人 / 通道旁的人 / 同机乘客”等模糊身份 |
| 视觉系统 | 未定义 | ✅ 深色只做氛围层；核心操作和阅读区域用米白 / 纸张 / 浅色卡片承载；微信绿仅限微信登录按钮 |
| 通知 | Stage 2 | ✅ Stage 1 必做：登机前 30 分钟提醒 + 飞后 24-48h 同班机新笔记提醒 |
| 离线 | 草稿恢复 | ✅ Stage 1 基础设施：离线写作、离线卡片预览、落地自动同步 |
| 数据模型 | ✅ 保留 | ✅ 增加 Account / FlightBook / FlightIntent / CloudCardShare（v2.2 字段改成微信 / 手机号） |

---

## 1. 产品定位（不变）

**Head in the Clouds（中文：云上心事）** 是一款飞行场景内的情绪记忆 micro App。

用户先写下这一趟飞行里的一句话，立即生成一张系统生成的"云上心事卡"；航班号、登机牌或行程截图用于补全航线信息与验证同班机身份，而不是表达前的硬门槛。私人 Cloud Card 可不验证直接保存/分享；只有发布到同班机、评论同班机笔记、接收同班机新笔记通知时，才必须完成航班验证。

**核心心理 anchor**：人在云上飞，心也暂时离开地面。

**反对的产品形态**：
- 不是航班记录工具（不卖 flight log / 不显示登机口实时数据）
- 不是普通日记（每张卡必须锚定一个飞行意图或航线语境；同班机社交必须有航班验证）
- 不是匿名社交网络（评论权限严格按"是否同航班"边界，不做关注 / 私信 / 公开 feed）

---

## 2. Stage 1 成功标准（修订）

Stage 1 不是做完整社交，而是验证一个**飞行前锚定 → 飞行中低门槛创作 → 飞行后扩散召回**的多闭环核心：

1. ✅ 手动录入航班 / 添加提醒 → 登机前提醒 → 打开 App → 写一句（**飞行前激活闭环**）
2. ✅ 写一句话 / 选模板 / 语音转文字 → 私人 Cloud Card → 保存/分享（**核心情绪闭环**）
3. ✅ 添加航班号 / 拍照证明 → 验证航班 → 发布到同班机 → 看同航班别人留下（**同班机解锁闭环**）
4. ✅ Onboarding → 第一次使用全套流程 → 第一张私人卡生成 / 同班机 Post 发出（**首次用户闭环**）
5. ✅ 老用户回来 → 看上次卡 → 写下一趟 / 补航班验证 → 又一张 Post（**复访闭环**）
6. ✅ 浏览同旅程 / 目的地 → 进卡片详情 → 评论权限边界感知（**发现闭环 + 边界感知闭环**）
7. ✅ 任何卡片可被举报 / 屏蔽（**合规闭环**）
8. ✅ 离线写作 → 本地保存 → 落地联网自动同步（**离线激活闭环**）
9. ✅ Cloud Card 保存/分享 → 关注者长按/识别 → 进入同班机笔记页（**获客扩散闭环**）
10. ✅ 发布后 24-48h 收到"同班机有人留言" → 回到 Flight Space（**飞后留存闭环**）

Stage 1 结束时必须能回答：
- 用户能否不扫描登机牌也敢先写一句，并完成私人 Cloud Card？
- 航班验证后置是否仍然让用户觉得这是"飞行专属"，而不是普通日记？
- Cloud Card 内容质量是否被用户当作"值得分享"的东西，而不是 App 截图？
- 一句话写作和模板是否显著提升首次发布率？
- 登机前提醒是否能把"我想用"提前到候机厅，而不是等起飞后才想起？
- 离线写作是否做到不会丢稿、不会发布失败后消失？
- 同航班/同旅程的边界感是否真实可感（不会感觉"被陌生人冒犯"）？
- **是否能让用户回来第二次写（returning rate）？** ← v2 新增

---

## 3. 核心内容模型

### 3.1 FlightContext / FlightProof（航班上下文与验证 · v2.4 修订）

v2.4 把航班信息拆成两层：
- `FlightContext`：用户手动输入、提醒带入或从分享页带入的航班上下文，可用于写作和私人卡片，不代表同班机身份已验证。
- `FlightProof`：用户通过登机牌 / 电子机票 / 行程截图完成验证后生成，用于解锁同班机发布、评论和同班机通知。

| 字段 | 类型 | 说明 |
|---|---|---|
| `flight_number` | string | 必填（如 MU5405） |
| `from_iata` / `to_iata` | string | 出发 / 到达机场代码 |
| `departure_date` | date | 飞行日期（决定属于哪个 FlightSpace） |
| `verification_status` | enum | `unverified` / `pending` / `verified` / `failed` |
| `verification_method` | enum | `manual` / `boarding_pass_photo` / `ticket_screenshot` / `itinerary_screenshot` |
| `source_image_hash` | string | 票证原图 SHA256，仅校验，**原图发布后删** |
| `redacted_image_url` | string | 脱敏后的票证小图，可选保留供本人查看 |

### 3.2 CloudPost（云上心事 Post · v2.3 改一句话优先）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | |
| `user_id` | uuid | 关联 Account（含 Guest Account） |
| `flight_context_id` | uuid | 可为空；没有航班上下文也可先写私人草稿 |
| `flight_proof_id` | uuid | 可为空；只有发布到同班机 / 评论同班机时必填 |
| `publish_scope` | enum | `private_card` / `same_flight` |
| `theme_word` | string | 用户选的 1 个主题词（如 "奔赴" / "归途" / "逃离"） |
| `text` | string | 用户的心事文本，最短 1 句话，最长 200 字；短内容是完成态，不是草稿 |
| `text_mode` | enum | `one_line` / `template` / `voice_transcript` / `free_text` |
| `prompt_template_id` | string | 模板写作时填，如 `flying_to_because` |
| `headline_quote` | string | 卡片上大字摘取的最精彩一句，默认从 `text` 自动抽取，用户可编辑 |
| `voice_audio_local_id` | string | 语音输入的本地临时 ID；转写成功后删除音频 |
| `offline_status` | enum | `local_only` / `syncing` / `synced` / `sync_failed` |
| `card_template_id` | enum | 系统提供的卡片样式之一 |
| `companion_photos` | array | 随行照片 0-3 张（可选） |
| `published_at` | timestamp | |
| `is_draft` | boolean | true = 未发布草稿 |

### 3.3 Comment（评论 · 不变）

| 字段 | 类型 | 说明 |
|---|---|---|
| `post_id` | uuid | |
| `user_id` | uuid | |
| `text` | string | ≤ 100 字 |
| `created_at` | timestamp | |

**权限**：只有同航班且已验证的用户（即 user 在该 flight_number + departure_date 上有 `verification_status=verified` 的 FlightProof）才能评论。其他用户进 Discovery 看的 Post Detail 是只读。

**公开隐私边界**：任何公共 Feed、Detail、分享落地页、评论列表都不得显示具体座位号（如 `14A` / `21C` / `7F` / `33B`）。可显示的身份只能是模糊描述，如“靠窗的人”“通道旁的人”“同机乘客”“前舱附近的人”。

### 3.4 Account · v2 新增（v2.2 改国内登录方式）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | |
| `auth_method` | enum | `guest` / `wechat` / `phone` |
| `device_id` | string | Guest mode 时绑定 device |
| `wechat_openid` | string | 微信登录后填（App 级唯一 ID） |
| `wechat_unionid` | string | 微信登录后填（同主体跨 App 唯一 ID，用于 dedup） |
| `phone_e164` | string | 手机号登录后填，E.164 国际格式（如 `+8613800138000`） |
| `created_at` | timestamp | |
| `upgraded_at` | timestamp | guest → wechat/phone 升级时间 |

**升级 trigger 5 个入口**（v2.1 新增明确）：

| # | 入口 | 强度 | UI |
|---|---|---|---|
| T1 | 00d 上「已有账号？登录」次入口 | 用户主动 | 14 Sign In Sheet |
| T2 | 第 2 张 Post 发布完，自动弹 08b modal | 软提示，可关闭 | 08b → 14 |
| T3 | 第 3 张 Post 发布完，再次自动弹 08b modal | 硬提示，必须选 yes/no | 08b → 14 |
| T4 | 01b / 09b 右上角 settings icon → 13 | 用户主动 | 13 → 14 |
| T5 | 用户换设备，老 device_id 的 Guest 数据无法同步时，自动引导到 14 | 系统驱动 | 直接 14 |

升级后：原 Guest Account 的 user_id 不变，只是 `auth_method` / `wechat_openid` / `wechat_unionid` / `phone_e164` / `upgraded_at` 字段被填充。**用户的所有 Post 不丢**。

**dedup 规则**（v2.2 必须实装）：
- 微信升级时若 `wechat_unionid` 已被其他 user_id 占用 → 把当前 Guest 的 Post 全部 migrate 到老 user_id，删除新 user_id（提示用户"找到你之前的账号，已合并"）
- 手机号同理（按 `phone_e164` 查重）

### 3.5 FlightBook（我的飞行册 · v2 新增）

不是新表，是 `CloudPost WHERE user_id = current` 的视图。按 `departure_date DESC` 排序。

### 3.6 FlightIntent（登机前提醒 · v2.3 新增）

用户可以在飞行前手动录入航班号 / 日期 / 起降城市来创建提醒，不依赖 flight tracking API。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | |
| `user_id` | uuid | |
| `flight_number` | string | 必填 |
| `departure_date` | date | 必填 |
| `from_iata` / `to_iata` | string | 可选，用户可手动填 |
| `scheduled_boarding_at` | timestamp | 用户输入或系统根据起飞前 45 分钟估算 |
| `reminder_at` | timestamp | 默认登机前 30 分钟 |
| `reminder_sent_at` | timestamp | 发送后填 |
| `opened_from_reminder_at` | timestamp | 用户点通知打开后填 |

### 3.7 CloudCardShare（卡片分享入口 · v2.3 新增）

Cloud Card 必须能作为独立图片传播。图片内不放下载 CTA，只放极小 app icon / watermark 与可识别入口。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | |
| `cloud_post_id` | uuid | |
| `share_image_url` | string | 生成的分享图 |
| `deep_link_url` | string | 指向 16 Shared Card Landing / Same Flight Notes |
| `qr_payload` | string | 图片内极低调二维码或可识别链接 payload |
| `channel` | enum | `wechat_moments` / `wechat_chat` / `xiaohongshu` / `save_image` / `copy_link` |
| `created_at` | timestamp | |

---

## 4. 用户状态机 · v2.3 修订

```
用户打开 App
│
├── 有未完成的 onboarding？
│   └── 是 → 跳到 onboarding 上次断点（00a-00d）
│
├── 有 active session（含 Guest）？
│   ├── 否 → 走 first-launch flow（00a-00d）
│   └── 是 ↓
│
├── 是否从登机提醒 / 同班机新笔记通知进入？
│   ├── 登机提醒 → 直接进 06 Compose（带 flight intent，默认一句话输入）
│   └── 同班机新笔记 → 直接进 09 Flight Space（定位到新笔记）
│
├── 有未同步离线稿或未发布 draft？
│   ├── 有未同步离线稿 → 进入 06 Compose / 08 Publish 状态，顶部显示"已离线保存，联网后自动同步"
│   └── 有普通 draft → 直接进 06 Compose（恢复草稿，顶部提示"继续上次")
│
├── 有未验证私人卡？
│   └── 进入 07 / 08，允许继续保存/分享私人卡；如要发布同班机则引导到 02-05 验证
│
├── 已发布 ≥ 1 张 Post？
│   ├── 否 → 01a Opening · First-published state
│   └── 是 → 01b Opening · Returning state
```

**关键不变量**：onboarding 一旦完成永不再展示（even after 卸载重装在同设备上，via device_id keychain 写入）。
**v2.3 新不变量**：只要用户开始输入一句话，即使没有网络、没有完成发布、没有完成账号升级，也必须先本地落盘；任何失败都不能让内容消失。
**v2.4 新不变量**：航班验证不得阻塞写作和私人 Cloud Card；它只阻塞 `publish_scope=same_flight`、同班机评论和同班机召回通知。

---

## 5. 用户场景矩阵（十一大主场景）· v2.3 修订

| # | 用户 | 触发 | 路径 | 终态 |
|---|---|---|---|---|
| **S1** | 首次用户，候机想写 | 看完小红书来下载 | 00a → 00b → 00c → 00d → 01a → 06 → 07 → 08 Private Share；若选择同班机 → 02 → 03 → 04 → 05 → 08 Same Flight → 09 | 第一张私人 Cloud Card 或同班机 Post 发布（Guest） |
| **S2** | 首次用户，只想看不想写 | 朋友推荐，在地面闲逛 | 00a → 00b → 00c → 00d → 01a → 点"看看别人留下的" → 10 Discovery → 退出 | 0 Post，标记 explore-only segment |
| **S3** | 老用户，新一趟飞行 | 候机 / 落地 | 01b（看上次卡）→ 06 → 07 → 08 Private Share；发布同班机时补 02-05 验证 → 09 | 新一张私人卡或同班机 Post 发布 |
| **S4** | 老用户，纯浏览过往 | 周末怀念 | 01b → 09b 飞行册 → 11A Detail（自己的）→ 返回 | 0 新 Post，留存信号 |
| **S5** | 老用户，发现别人 | 飞行中 / 飞行后 | 01b → 09 本航班 → 10 Discovery → 11B 锁定 Detail | 0 评论但有 view |
| **S6** | 中断恢复 | 写到一半关闭 App，2 小时后回来 | 任意入口 → 直接 06 Compose（draft 恢复） | 完成发布 |
| **S7** | Guest 用户升级账号（v2.1 新增 · v2.2 改微信） | 第 2 张 Post 发完，弹 08b 软提示 ➜ 接受 | 08 → 08b modal → 14 Sign In Sheet (微信) → 升级完成 → 01b | `auth_method` 从 `guest` 变成 `wechat`，user_id 不变，Post 不丢 |
| **S7b** | 换设备的老 Guest 用户 | 重装 App / 换手机后 | 00a → 00b → 00c → 00d **底部「已有账号？登录」** → 14 Sign In Sheet → 微信或手机号 | 拉回老 user_id 所有 Post（按 `wechat_unionid` / `phone_e164` 查重） |
| **S8** | 飞行前有意图但容易忘 | 候机前手动录入 MU5301 | 01a / 01b → 15 Flight Reminder Setup → 登机前 30 分钟推送 → 点通知 → 06 Compose | 至少开始一句话草稿，航班验证可稍后补 |
| **S9** | 国内航班无 WiFi | 飞机上离线写了一句 / 录音转文字 | 06 Compose（offline）→ 07 Studio（offline preview）→ 08 Private Share queued；若已验证则 Same Flight queued → 落地联网自动同步 | 内容不丢；私人卡可保存，同班机发布需验证后同步 |
| **S10** | 朋友圈关注者被 Cloud Card 打动 | 看见朋友分享的艺术卡片 | 长按识别 / 点链接 → 16 Shared Card Landing → 看同班机/同航线笔记 → 选择保存卡片或添加自己的航班提醒 | 新用户进入同航线触发池，不直接 App Store 跳转 |
| **S11** | 发完后 24-48h 即将流失 | 同班机有人新发笔记 | 推送「MU5301 上昨天有人留下了一条笔记」→ 09 Flight Space → 11A Detail | 飞后召回，打开同班机内容 |

**每个场景必须能跑通**，否则 dev 拒绝开工。

---

## 6. 十条显式闭环

### 闭环 A：首次完整（First-time complete）
```
Open → 00a Welcome → 00b Permission → 00c Privacy → 00d Get Started (Guest)
  → 01a Opening (first-published state)
  → 06 Compose → 07 Studio → 08 Private Share
  → 可选：02 Add Flight Info → 03 Privacy → 04 Unlock → 05 Confirm
  → 08 Same Flight Publish → 09 Flight Space (本航班，自己 Post 置顶)
```
退出此循环：用户完成 1 张私人 Cloud Card 或同班机 Post，状态机翻到 returning。

### 闭环 B：复访写作（Returning write）
```
Open → 01b Opening (returning state) → "写下这一趟"
  → 06 → 07 → 08 Private Share
  → 如需同班机 → 02 → ... → 08 Same Flight Publish → 09 Flight Space
```
退出此循环：n+1 张私人卡或同班机 Post 发布。

### 闭环 C：社交（Same-flight social）
```
08 Same Flight Publish → 09 Flight Space (Feed) → 点别人卡 → 11A Detail (本航班，可评)
  → 写评论 → 返回 09
```
退出此循环：1+ 评论发出（社交边界感知成立）。

### 闭环 D：发现（Discovery & boundary）
```
09 Flight Space → 10 Discovery Spaces (同旅程 / 同目的地 / 热点)
  → 点别人卡 → 11B Detail (锁定，不可评，显示"评论只在本航班开放")
  → 返回 10
```
退出此循环：用户感知到"评论只在本航班开放"边界（埋点验证）。

### 闭环 E：合规（Report & block）
```
任何 11A/11B Detail → 长按或菜单 → 12 Report / Block
  → 提交举报 OR 屏蔽该用户 → 返回上一层
```
退出此循环：举报/屏蔽完成（App Store 1.2 UGC 合规硬要求）。

### 闭环 F：账号升级（v2.1 新增 · v2.2 改国内方式）
```
触发任一：
  T1: 00d 上"已有账号？登录"次入口
  T2: 第 2 张 Post 发完弹 08b modal（软）
  T3: 第 3 张 Post 发完弹 08b modal（硬）
  T4: 01b / 09b 右上 settings → 13 → "保存我的账号"
  T5: 换设备时检测 Guest user_id 失效

  → 14 Sign In Sheet（微信登录主 + 手机号短信验证码辅）
  → 成功 → toast "保存好了，所有飞行已同步" → 回上一屏
  → 失败 / 取消 → 静默返回，仍以 Guest 继续
```
退出此循环：`Account.auth_method` 从 `guest` 变成 `wechat` 或 `phone`。

### 闭环 G：飞行前锚定（Pre-boarding activation）
```
01a / 01b → 15 Flight Reminder Setup
  → 创建 FlightIntent
  → 登机前 30 分钟推送
  → 用户点开 → 06 Compose（默认一句话输入）
```
退出此循环：用户在起飞前已经打开 App 并开始草稿，避免把触发时刻押在飞行中。

### 闭环 H：离线写作与落地同步（Offline-first publish）
```
06 Compose（无网络）→ 本地保存 CloudPost(local_only, publish_scope=private_card)
  → 07 Studio 本地生成 Cloud Card preview
  → 08 Private Share 标记 queued
  → 落地联网 → 自动 sync；如用户选择同班机，补验证后进入 09 Flight Space
```
退出此循环：离线内容成功同步；如果失败，用户看到可重试状态，内容仍保留。

### 闭环 I：Cloud Card 获客扩散（Share-led acquisition）
```
08 Publish → 保存/分享 Cloud Card
  → 关注者在朋友圈/聊天看到图片
  → 长按识别 / 点链接 → 16 Shared Card Landing
  → 看同班机或同航线笔记 → 添加自己的航班提醒 / 打开 App
```
退出此循环：分享图带来同航线高意图访问，而不是直接要求下载。

### 闭环 J：飞后同班机召回（Post-flight retention）
```
用户已在 MU5301 发布 Post
  → 24-48h 内同班机出现新 Post
  → 推送 "MU5301 上昨天有人留下了一条笔记"
  → 09 Flight Space → 11A Detail
```
退出此循环：用户回来看同一段时空里陌生人的新内容。

---

## 7. 用户权限矩阵（修订）

| 用户身份 | 可看 | 可评 | 可举报 |
|---|---|---|---|
| 未登录（onboarding 中） | 仅 00a-00d | ❌ | ❌ |
| Guest mode 已 onboard 但无 Post | 01a / 09（浏览模式）/ 10 / 11B | ❌ | ✅ |
| Guest mode 已 Post（本航班） | 01b / 09 / 10 / 11A 本航班 / 11B 同旅程 / 09b 飞行册 | ✅ 本航班 | ✅ |
| 微信/手机号已升级 | 同上 + 跨设备同步 | ✅ 本航班 | ✅ |

---

## 8. 信息架构（修订）

```
首次启动
└── 00a Welcome
    └── 00b Permission Primer
        └── 00c Privacy Promise
            └── 00d Get Started (Guest)
                └── 01a Opening (First-published)
                    └── 06 Compose → 07 Studio → 08 Private Share
                        ├── 保存/分享私人卡
                        └── 添加航班并发布同班机
                            └── 02 Add Flight Info → 03 Privacy → 04 Unlock → 05 Confirm
                                └── 08 Same Flight Publish → 09 Flight Space (本航班)
                                    ├── 10 Discovery Spaces (同旅程/目的地)
                                    │   └── 11B Detail (锁定)
                                    │       └── 12 Report / Block
                                    └── 11A Detail (本航班，可评)
                                        └── 12 Report / Block

再次启动（已 onboard）
└── 01b Opening (Returning)
    ├── 主 CTA "写下这一趟" → 06 Compose
    ├── 次 CTA "添加航班信息 / 扫登机牌" → 02 Add Flight Info ...
    ├── 次 CTA "添加登机提醒" → 15 Flight Reminder Setup
    ├── 次 CTA "看看别人留下的" → 09（如果有 active flight）/ 10 Discovery
    └── "我的飞行册（N）" → 09b My Flights
        └── 11A Detail (自己的，可编辑/删除)

中断恢复
└── 任何入口 → 06 Compose (draft 恢复)

外部分享入口
└── Cloud Card 图片长按识别 / deep link
    └── 16 Shared Card Landing
        ├── 已安装 App → 打开 09 Flight Space / 10 Discovery
        └── 未安装 App → Web fallback 预览 + 添加航班提醒引导
```

---

## 9. 页面详细需求（23 屏，v2.3 新增 15 / 16）

### 00a Welcome · v2.4 调整

- 深蓝 dawn 氛围可以保留，但中间必须有米白 / 纸张 / 明信片式视觉锚点，避免全屏深色带来的小众/海外感
- 品牌大字：Head in the Clouds（英文 italic）/ 云·上·心·事（中文 serif）
- 主 hook（必须在首次打开就给“原来飞行体验可以这样”的顿悟）：「**登机前 30 分钟，给这趟飞行留一句话**」
- 副 hook：「落地后，生成一张只属于云上的明信片」
- 主 CTA：「写下这一趟」→ 跳 00b
- 次入口：「添加航班信息」→ 15 或 02（根据是否只设提醒 / 是否验证同班机）
- **不要**：注册框、登录入口、完整 Cloud Card sample（00a 是 hook，不是炫技）

### 00b Permission Primer · v2 新增

- 标题：「为了你的飞行心事，我们需要：」
- 3 张图 + 1 句话各自解释：
  - 📷 相机 —— "拍登机牌 / 票证截图时申请"
  - 🖼️ 相册 —— "从相册选截图，或保存 Cloud Card 时申请"
  - 🔔 通知 —— "添加登机提醒、同班机新笔记提醒时申请"
- 底部主 CTA：「继续，不现在授权」→ 跳 00c
- 说明：「以上权限均在你实际用到时才申请，不提前索权」

### 00c Privacy Promise · v2 新增

- 标题：「你的票，只在你手里」
- 3 条 bullet（每条带 icon）：
  - 🔒 票证原图**默认不保存到云**——OCR 完成后立即销毁
  - 👁 卡片只显示飞行号 / 出发到达 / 时间，**不显示姓名 / 座位号 / 票号**
  - 💬 评论只在你那趟航班内可见，**陌生人看不到具体票证细节**
- 主 CTA：「我知道了，继续」→ 跳 00d

### 00d Get Started (Guest) · v2 新增（v2.1 加「已有账号？登录」次入口）

- 标题：「准备好了吗？」
- 副标题：「不需要注册，直接开始你的第一次」
- 主 CTA：「开始我的第一次飞行」→ 创建 Guest Account（device-bound）→ 跳 01a
- **底部次入口（v2.1 新增）：「已有账号？登录」**（小字 link）→ 14 Sign In Sheet → 成功跳 01b / 取消回 00d
- 底部细字：「之后可以选择绑定微信或手机号，换设备也能找回」（v2.2 解释升级路径）

### 01a Opening · First-published state（v1 的 Opening 改名）

- 现 v1 Opening 设计保留 → 大 Cloud Card sample (MU5405 · 奔赴 · SHA → CTU)
- 品牌 / 副标题 / 主次 CTA / 隐私 reassurance 全保留
- **状态条件**：用户 onboarded 且**还没发过任何 Post**
- 主 CTA：「写下这一趟」→ 06 Compose
- 次 CTA 0：「添加航班号 / 扫登机牌」→ 02 Add Flight Info
- 次 CTA 1：「添加登机提醒」→ 15 Flight Reminder Setup
- 次 CTA 2：「看看别人留下的」→ 10 Discovery（因为没自己航班，去看公共池）
- 轻提示：「航班信息可以稍后补。验证后才能进入同班机。」

### 01b Opening · Returning state · v2 新增（v2.1 加 settings icon）

- 顶部：「最近的云上心事」+ 最新一张 Card 缩略图（点开 → 11A Detail）
- **顶部右上角 settings icon**（齿轮 / 头像，v2.1 新增）→ 13 Account & Settings
- 中部：「**准备好下一次飞行了吗？**」
- 主 CTA：「写下这一趟」→ 06 Compose
- 次入口 0：「添加航班号 / 扫登机牌」→ 02 Add Flight Info
- 次入口 1：「添加登机提醒」→ 15 Flight Reminder Setup
- 次入口 2：「我的飞行册（{N}）」（{N} = 该 user 已发布 Post 数）→ 09b My Flights
- 隐私 reassurance：保留底部小字
- **状态条件**：用户已发布 ≥ 1 张 Post

### 02 Add Flight Info / 03 Privacy / 04 Unlock / 05 Confirm · v2.4 验证后置

这组屏幕不再是写作前硬门槛，而是“补全航班信息 / 解锁同班机”的增强流程。沿用 v1 §6 中 Screen 2-5 的视觉规格（见 PRD-v1-archive.md §6）。重要补充：
- 02 Capture 顶部左上角增加「← 返回」按钮，跳 01a 或 01b（根据来源）
- 02 必须同时提供轻量手动输入：航班号 + 日期；登机牌 / 电子机票 / 行程截图只是快捷验证方式
- 02 标题改为「添加航班信息」，副标题：「写作不需要验证；发布到同班机时需要确认这趟航班」
- 05 Confirm 如果用户上传的是未来航班 / 手动录入航班号，底部增加「设置登机前 30 分钟提醒」开关，默认开启
- 05 主 CTA 根据来源变化：
  - 从 06 / 07 / 08 来：`确认并发布到同班机`
  - 从 15 来：`确认并设置提醒`
  - 从 01a / 01b 来：`解锁同班机`

### 06 Compose · v2.3 重写为一句话优先

- 页面标题：「这次飞行，我只想说：」
- 默认输入框只要求一句话，placeholder：「比如：我把没有说出口的话，带过了云层。」
- 文案规则：最短 1 个汉字可保存；推荐 8-60 字；最长 200 字；短内容是完成态，不提示"字数不够"
- 模板入口（水平卡片）：
  - 「飞往 ___，因为 ___，起飞时我 ___」
  - 「如果能带一样东西上飞机，是 ___」
  - 「落地以后，我希望 ___」
- 语音入口：按住说话 → 本地降噪 / 转文字 → 用户确认后填入正文；音频转写成功后删除
- 顶部状态：
  - 在线：`草稿已保存`
  - 离线：`已离线保存，落地后自动同步`
  - 同步失败：`同步失败，内容已保存 · 重试`
- 顶部航班状态 chip：
  - 未绑定航班：`未添加航班 · 稍后补`
  - 已添加航班：`MU5301 · SHA → CTU`
  - 已验证航班：`MU5301 · 已验证同班机`
- 主 CTA：「生成私人明信片」→ 07 Studio
- 次入口：「添加航班，解锁同班机」→ 02 Add Flight Info

### 07 Studio · v2.3 Cloud Card 作为获客资产

- 目标：卡片像诗 / 艺术品，不像 App 截图
- 默认模板锁定为 `boarding_postcard`：深蓝底 + 米黄信纸 / 票根 + 航班号信息 + 大字句子 + 坐标路线。它必须能承接普通 UGC，不依赖用户写得很诗意。
- 必须元素：
  - 飞行路线 + 起降城市极简线条/坐标感（如 `SHA 31.2304°N → CTU 30.5728°N`）
  - 从正文抽取的 `headline_quote` 大字排版，用户可点按编辑
  - 航班号、日期、主题词做小号 metadata
  - 左下角极小 app icon / watermark，不放「立即下载」
  - 低调二维码或可识别 payload，指向 16 Shared Card Landing
- 未验证状态：Cloud Card 仍可生成；航班 metadata 显示「航班待确认」或用户手动输入的路线，不得阻塞保存/分享
- 至少 3 个模板：`boarding_postcard`（默认）/ `route_poem` / `cloud_window`。`cloud_window` 这种照片叠字模板只有在用户文案和照片足够匹配时推荐，不得作为默认。
- 普通 UGC 兜底：如果文本偏日常或抱怨（如“飞机晚点了，累死”），卡片应走 `flight_log` / deadpan / flight note / 票根备注风格，而不是强行套金色云海和诗意滤镜。
- 离线时也必须能生成本地 preview；联网后再上传高清分享图

### 08 Publish · v2.4 拆分私人分享 / 同班机发布

- 08 必须拆成两种状态：
  - `Private Share`：只保存图片 / 分享到朋友圈、微信、小红书，不进入同班机；不要求航班验证
  - `Same Flight Publish`：验证航班后发布到同班机；发布后进入 09 Flight Space
- 发布前显示同步状态：
  - 在线：立即发布
  - 离线：保存为 queued，本地给出已发布感，落地后自动同步
- 成功后主 CTA：「保存 / 分享私人卡」；次 CTA：「验证航班并发布到同班机」
- 文案必须明确：
  - `私人卡不会进入同班机。`
  - `验证航班后，同班机的人才能看到和留言。`
- 分享图内不得出现 App Store CTA；分享链路进入 16 Shared Card Landing / Same Flight Notes
- 同班机发布完成后进入 09 Flight Space；私人分享完成后回 01a / 01b 或 09b，不强行进 09
- **08 Same Flight Publish 完成后（v2.1 新增）**：如当前 Account 为 Guest 且本次为第 2 张同班机 Post 发布 → 跳 09 Flight Space 后**自动叠加** 08b Account Upgrade Modal（软）。若为第 3 张同班机 Post 发布且 T2 时被关闭过 → 改弹硬版（必须选 yes/no，不能简单 X 关）。第 4 张及以后**不再自动弹**，只走 T4（settings 主动升级）。

### 08b Account Upgrade Modal · v2.1 新增

**形态**：底部 sheet（不是全屏），盖在 09 Flight Space 上，背景轻度模糊。

**软版（T2，第 2 张 Post 发完）**：
- 标题：「✈️ 第二次起飞了」
- 副标题：「想把这些云上心事留住吗？绑定微信或手机号，换手机也能找回」
- 主 CTA：「保存我的账号」→ 14 Sign In Sheet
- 次 CTA：「以后再说」→ 关闭 modal，留在 09
- 右上角 X：关闭 = 同次 CTA

**硬版（T3，第 3 张 Post 发完且 T2 被关过）**：
- 标题：「再不保存就可能丢了」
- 副标题：「3 趟飞行了，换设备 / 卸载后就找不回来。30 秒搞定。」
- 主 CTA：「保存我的账号」→ 14
- 次 CTA：「我接受丢失风险」（小字 link，需点击确认弹框 "确定不保存？卸载后无法恢复" → "确定不保存"）→ 关闭 modal
- 无右上角 X（强制选）

**埋点**：`account_upgrade_prompt_shown(variant: soft/hard)` / `account_upgrade_dismissed(variant)` / `account_upgrade_started` / `account_upgrade_completed`

### 09 Flight Space（本航班）· v2.3 小改

布局保持 v1：航班 header + 本人 Post 置顶 + Feed 列表 + 「再写一张」浮动 CTA。

- 如果从同班机新笔记通知进入：顶部显示「昨天同班机有人留下了新笔记」并定位到新卡
- 如果有 queued / sync_failed 的离线稿：本人 Post 区域显示状态条，不混入公共 Feed
- Feed 顶部可以显示「同一趟航班 · 只属于这段时空」来强化边界
- 公开身份不显示具体座位号。用「靠窗的人」「通道旁的人」「同机乘客」「前舱附近」替代 `14A / 21C / 7F / 33B`。

### 09b My Flights · v2 新增（v2.1 加 settings icon）

- 顶部：「我的飞行册 · {N} 趟」
- **顶部右上角 settings icon**（齿轮 / 头像，v2.1 新增，与 01b 同款同位）→ 13 Account & Settings
- 时间倒序 grid：每张卡 = 一次飞行的 Cloud Card 缩略（航班号 + 主题词 + 日期）
- 点击 → 11A Detail（自己的 Post，可编辑文本 / 删除）
- 底部 fixed CTA：「写下新航班」→ 06 Compose
- 空状态：「还没有飞行记录」+ 主 CTA「写下第一趟」
- **不做**（Stage 2）：搜索 / 按目的地分组 / 年度回忆册

### 10 Discovery / 11A / 11B / 12 · v2.3 小改

沿用 v1 §6（见 PRD-v1-archive.md §6）。

- 11A / 11B 的分享入口生成 v2.3 Cloud Card，不截屏当前 UI
- 11A 同班机 Detail 支持触发 24-48h 新笔记通知；11B Discovery Detail 不触发同班机通知
- 公开区域禁止具体座位号；评论和身份标签统一用模糊身份。

### 13 Account & Settings · v2.1 新增

**入口**：01b / 09b 右上 settings icon。

**布局**（单屏，从上到下分 4 块）：

1. **账号状态卡**（顶部 hero）：
   - Guest 状态：头像占位（云朵 icon）+ 「未保存账号」+ 副标题「{N} 趟飞行存在本机，换设备会丢」+ 主 CTA「保存我的账号」（醒目）→ 14
   - 已升级（微信）：头像（拉微信昵称头像）+ 「已用微信保存 · {nickname}」+ 副标题「{N} 趟飞行已同步」+ 无 CTA
   - 已升级（手机号）：头像占位 + 「已用手机号保存 · {phone mask 如 138****0000}」+ 同上
   - 视觉约束：`#07C160` 微信绿只允许用于 14 的微信登录按钮；13 的已连接状态不得用大面积微信绿，改用低饱和蓝灰 / 墨绿小点 / “已保存”stamp。

2. **数据**（list group）：
   - 「我的飞行册（{N}）」→ 09b
   - 「我发布的评论数：{N}」（只读，不进 detail）
   - 「我被屏蔽的用户：{N}」→ 进 list 可解除（Stage 1 简版）

3. **设置**（list group）：
   - 「相机 / 相册权限」→ 跳系统 Settings
   - 「通知」→ 管理登机提醒 / 同班机新笔记提醒（Stage 1 必做）
   - 「清除本机草稿」→ 二次确认 → 删除所有 `is_draft=true` 的 Post

4. **法务 & 退出**（list group，最底）：
   - 「隐私政策」→ in-app webview
   - 「用户协议」→ in-app webview
   - 「联系我们」→ mailto: hello@headintheclouds.app
   - **「退出登录」**（仅升级账号显示）→ 二次确认 "退出后本机会变成新 Guest，原账号下飞行仍在云端" → 执行退出
   - **「删除账号」**（仅升级账号显示，红字）→ 二次确认 + **当前登录方式的二次校验**（微信：弹微信授权确认；手机号：发新短信验证码到原绑定号码）→ 软删除，30 天恢复期（App Store 5.1.1 合规硬要求）

**埋点**：`account_settings_viewed` / `sign_out_completed` / `account_deletion_requested`

### 14 Sign In Sheet · v2.1 新增（v2.2 改国内方式）

**形态**：从底部弹起的 sheet（不是全屏），盖在触发屏上。背景轻度模糊触发屏。

**触发来源**：00d 次入口 / 08b modal / 13 主 CTA / S7b 系统驱动。

**布局**：
- 顶部 close X（右上）
- 标题：「保存你的飞行」
- 副标题：「下次换手机，所有云上心事还在」
- **主按钮（v2.2 改）**：
  - 🟢 **「微信一键登录」**（微信绿 `#07C160` 底白字，含 WeChat icon；按钮样式按微信开放平台《微信终端 SDK 设计规范》出）→ 触发 `WXApi.sendAuthReq`（scope=`snsapi_userinfo`，state=随机）→ 唤起微信 App 授权 → 回调拿 `code` → 后端换 `access_token` / `openid` / `unionid` → 创建或合并 Account
- 分隔线：「— 或 —」
- **次按钮（v2.2 改）**：
  - 📱 「手机号登录」→ 点击在 sheet 内内联展开（不切屏）：
    - 区号选择器（默认 `+86`，可下拉选其他）+ 手机号 input（11 位 +86 或国际格式）
    - 主 CTA「获取验证码」→ 后端走腾讯云 / 阿里云 SMS → 短信「【云上心事】您的验证码：123456，5 分钟内有效」
    - 6 位验证码 input + 60 秒倒计时（结束可点「重新发送」）
    - 输完 6 位自动提交 → 后端校验 → 创建或合并 Account
- 底部细字：「登录即表示同意 [用户协议] 和 [隐私政策]」（点击 → in-app webview）
- 加载状态：当前主按钮转圈，禁用 X

**成功状态**：
- toast：「✅ 保存好了，所有飞行已同步」
- 自动关闭 sheet，回到触发屏；触发屏状态机重算（Guest → upgraded）
- 触发 `account_upgrade_completed(method: wechat/phone)`
- 若后端检测到 `wechat_unionid` / `phone_e164` 已存在另一 user_id → 自动合并 Post 到老 user_id，toast 改为「✅ 找到你之前的账号，已合并 {M} 趟飞行」

**失败 / 取消**：
- 微信用户拒绝授权 / 取消：静默关闭 sheet，无 toast
- 微信 App 未安装：禁用微信按钮 + 灰显小字「未检测到微信，请用手机号登录」
- 短信发送失败：sheet 内提示「短信发送失败，请重试或换号码」
- 验证码错误 3 次：后端按手机号 10 分钟限流，提示「尝试次数过多，请 10 分钟后再试」
- 网络错误：sheet 内显示「网络问题，请重试」，按钮可重试，X 可关闭
- 触发 `sign_in_failed(method: wechat/phone, reason: cancelled/no_wechat_app/sms_send_fail/code_invalid/rate_limited/network/server)`

**Stage 1 不做**：Apple Sign In / Google / 邮箱 magic link / 微博 / QQ / 找回密码（短信验证码无密码模型本身已覆盖）。

**⚠️ App Store 4.8 风险**：iOS App 用微信作为账号设立方式时，Apple 政策原则上要求同时提供 Apple Sign In 作为等价选项。中国区抖音 / 京东 / 美团等用"手机号+微信"组合通常能通过审核但仍可能被刁难。**回退方案**：若审核驳回 → 把 Apple Sign In 加回 14 作为第三按钮（v2.1 设计可复用），不阻塞 Stage 1 主流程。

### 15 Flight Reminder Setup · v2.3 新增

**入口**：01a / 01b 次 CTA、05 Confirm 未来航班开关、16 Shared Card Landing。

**目标**：让用户在候机厅就打开 App，而不是等起飞后才想起。

**布局**：
- 标题：「把这趟飞行留住」
- 航班号输入：`MU5301`，自动大写，支持手动输入
- 日期选择：默认今天，可选未来日期
- 起降城市 / 机场：可选，用户手动填；Stage 1 不接 flight tracking API
- 提醒时间：默认「登机前 30 分钟」，可改为 15 / 45 分钟
- 通知预览：「你要登上 MU5301 了，今天有什么想留下来的？」
- 主 CTA：「设置提醒」→ 创建 FlightIntent → 返回 01a / 01b
- 次 CTA：「现在就写一句」→ 06 Compose（带 flight intent）

**失败状态**：
- 未开通知权限：展示系统 Settings 引导，不阻断创建 FlightIntent；下一次打开 App 仍提示
- 用户只填航班号不填城市：允许保存，城市在 05 Confirm 或后续编辑补齐

### 16 Shared Card Landing / Same Flight Notes · v2.3 新增

**入口**：Cloud Card 图片二维码 / 可识别链接 / deep link。

**目标**：让分享图带来的访问先进入"同班机笔记"语境，而不是 App Store 下载页。

**布局**：
- 顶部展示原 Cloud Card，保持艺术卡片比例，不加 App UI chrome
- 下方显示：
  - 「这张卡来自 MU5301 · SHA → CTU」
  - 同班机笔记预览 1-3 条；如果没有同班机，显示同航线 / 同目的地精选
  - CTA 1：「看同班机笔记」→ 已安装 App 打开 09；未安装则 Web 只读预览
  - CTA 2：「我也飞过 / 下次也要飞这条航线」→ 15 Flight Reminder Setup
- 品牌露出保持克制：只在底部显示「Head in the Clouds · 云上心事」
- 不出现「立即下载」「打开 App Store」强 CTA；只有用户主动继续时再根据平台引导安装

**埋点**：`share_landing_opened` / `share_landing_same_flight_tapped` / `share_landing_reminder_started`

---

## 10. Must-Have（修订）

| # | 功能 | 必须工作的场景 | 不可降级 |
|---|---|---|---|
| 1 | First-launch onboarding | S1 / S2 | 00b 必须在系统权限框前出现 |
| 2 | Guest mode 一键开始 | S1 / S2 | 无需注册即可发布第一张 |
| 3 | 表达先行 + 验证后置 | S1 / S3 / S8 / S9 | 不允许用航班验证阻塞写作或私人卡；但同班机发布 / 评论 / 通知必须验证 |
| 4 | 用户状态机 | S3 / S4 | Returning user **必须** 落 01b 而非 01a |
| 5 | 我的飞行册 | S4 / S5 | 从 01b 必须可达 09b |
| 6 | **一句话优先 Compose**（v2.3） | S1 / S3 / S8 / S9 | 最小 1 句话可发布，不得要求 200 字；模板和语音必须是降门槛入口 |
| 7 | 同航班权限 | S3 / S5 / S6 | 评论框只在 11A 出现 |
| 8 | Discovery 锁定 | S5 | 11B 不能出现评论框，且显示"评论只在本航班开放" |
| 9 | **离线写作 / 离线卡片预览 / 落地自动同步**（v2.3） | S6 / S9 | 内容先本地落盘；发布失败不能丢稿 |
| 10 | 举报 / 屏蔽 | 任何 | 12 Report 必须 < 3 步可达 |
| 11 | **微信一键登录**（v2.2） | S7 / S7b | 14 必须有微信开放平台官方按钮，视觉权重最高；微信 App 未装时按钮灰显并提示用手机号 |
| 12 | **手机号 + 短信验证码**（v2.2） | S7 / S7b | 14 必须有手机号次选项；区号默认 +86；60 秒倒计时；3 次错误限流 |
| 13 | **账号升级软硬两版 modal**（v2.1） | S7 | 第 2 张 Post 后软，第 3 张 Post 后硬 |
| 14 | **账号设置 + 删除账号**（v2.1） | 任何升级账号 | 13 必须可达，删除账号是 App Store 5.1.1 硬要求 |
| 15 | **Guest → 微信/手机号 升级不丢数据**（v2.2） | S7 / S7b | user_id 不变；若 unionid / phone_e164 已存在另 user_id 则合并到老 id |
| 16 | **Cloud Card 获客卡片**（v2.3） | S1 / S3 / S10 | 卡片像诗/艺术品；路线+城市+大字 quote；无 App Store CTA |
| 17 | **Shared Card Landing**（v2.3） | S10 | 分享入口进同班机/同航线笔记，不直接进下载页 |
| 18 | **登机前提醒**（v2.3） | S8 | 手动航班号即可创建；默认登机前 30 分钟推送 |
| 19 | **同班机新笔记通知**（v2.3） | S11 | 发布后 24-48h 内同班机新内容可召回 |
| 20 | **公开隐私边界**（v2.4） | 09 / 10 / 11 / 16 | 公开区域不得显示具体座位号、姓名、票号、证件号 |

---

## 11. Won't Have（Stage 1 明确剔出）

- ❌ 视频内容（user-generated video）
- ❌ 外链 / DM / 关注 / 公开关注列表
- ❌ Flight tracker 实时数据（不是航班工具）
- ❌ 公开票证原图分享
- ❌ Threaded 评论（评论无嵌套）
- ❌ 跨航班的关注关系
- ❌ 搜索（My Flights / Discovery / Comments 都不要搜索）
- ❌ 实时航班追踪 / 登机口 / 延误查询 API（Stage 1 只做用户手动录入）
- ❌ 除登机提醒、同班机新笔记外的营销通知
- ❌ 跨设备数据迁移（Stage 2，目前仅微信 / 手机号升级后才支持，未升级 Guest 卸载后丢）
- ❌ Apple Sign In / Google / 邮箱登录（v2.2 移除，回退预案见 §9 14）
- ❌ 微博 / QQ 登录
- ❌ 任何"年度报告" / "飞行 wrapped"（Stage 2+）
- ❌ Cloud Card 上的强下载 CTA / App Store badge / "立即下载"

---

## 12. 关键决策点（创始人需要表态）

### D1：账号策略
- ✅ **PM 默认选 B：Guest mode + 软升级**
- 可选 A：必注册（牺牲转化）
- 可选 C：永远 device-bound（牺牲跨设备）

### D2：onboarding 4 屏 / 3 屏
- ✅ **PM 默认 4 屏（00a-00d）**——含独立 Get Started 屏给 Guest mode 仪式感
- 可选 3 屏：00b + 00c 合并，省一屏但权限请求节奏变快

### D3：returning Opening 上显示什么时间窗口的"最近卡"
- ✅ **PM 默认显示最新 1 张**——简单，不打分组
- 可选：显示"本月"或"按目的地"

### D4：Stage 1 是否实装举报后台
- ✅ **PM 默认实装最简版**：用户能提交，后台只发邮件给 admin（Warren）人工审，不做自动屏蔽
- 必须实装某种形式（App Store 1.2 UGC 审核硬要求）

### D5：通知是否进 Stage 1
- ✅ **PM 默认进 Stage 1**：只做两类高意图通知，登机前 30 分钟、同班机新笔记
- 不做普通运营 push，不做每日提醒

### D6：最小发布单元
- ✅ **PM 默认一句话就是完成态**
- 不做 200 字门槛，不做"内容太短"提示

### D7：Cloud Card 分享策略
- ✅ **PM 默认无下载 CTA**：卡片先作为诗/艺术品传播，入口指向同班机笔记
- 不做截图式 UI 分享，不做 App Store badge

### D8：航班验证时机
- ✅ **PM 默认表达先行，验证后置**：私人卡不需要航班验证；同班机发布、评论、同班机通知必须验证
- 不做“扫描登机牌才能写”的硬门槛

**默认全选 PM 推荐，你回 "yes v2.4 prd" 我按这跑。某一项要换，明说"D6 我要保留长文门槛"之类。**

---

## 13. 成功指标与埋点（修订）

### 13.1 北极星

- 首次完成发布率（onboarded → 第一张 Post 发布）≥ 35%
- 一句话发布率（进入 Compose → 60 秒内生成 Cloud Card）≥ 45%
- 私人卡生成率（进入 Compose → `private_card_generated`）≥ 55%
- 同班机发布转化率（`same_flight_publish_completed / private_card_generated`）≥ 25%
- Cloud Card 分享率（`card_shared / private_card_generated`）≥ 25%
- D7 returning rate（首次完成发布后 7 天内再来）≥ 25%

### 13.2 漏斗 gate（沿用 test-plan，新增 onboarding 部分）

- onboarding 完成率：`onboarding_completed / app_first_launched ≥ 70%`
- 写作启动率：`compose_started / (01a_or_01b_landing_viewed) ≥ 45%`
- 航班验证启动率：`flight_verification_started / private_card_generated ≥ 25%`
- 同班机发布完成率：`same_flight_publish_completed / flight_verification_started ≥ 60%`
- 私人卡完成率：`private_card_generated / compose_started ≥ 45%`
- 卡片分享率：`card_shared / private_card_generated ≥ 20%`
- 登机提醒打开率：`boarding_reminder_opened / boarding_reminder_sent ≥ 20%`
- 离线同步成功率：`offline_sync_completed / offline_sync_started ≥ 95%`
- 分享落地页继续率：`share_landing_same_flight_tapped_or_reminder_started / share_landing_opened ≥ 15%`
- 同班机新笔记通知打开率：`same_flight_note_notification_opened / same_flight_note_notification_sent ≥ 18%`

### 13.3 埋点契约（v2 新增 + 沿用）

**v2 新增**：
- `app_first_launched`（设备首次启动）
- `onboarding_step_viewed(step: 00a/00b/00c/00d)`
- `onboarding_completed`
- `permission_granted(type: camera/photos/notification)` / `permission_denied(type)`
- `guest_mode_chosen`
- `01a_landing_viewed` / `01b_landing_viewed`
- `myflights_viewed`
- `myflights_card_tapped`
- `draft_resumed`（从中断恢复）
- `compose_started(source: 01a/01b/reminder/share_landing/draft_resume)`
- `private_card_generated(template_id, has_flight_context: bool, verified: bool)`
- `private_card_saved`
- `private_card_shared(channel)`
- `flight_verification_started(source: 02/07/08/15/16, method: manual/boarding_pass_photo/ticket_screenshot/itinerary_screenshot)`
- `flight_verification_completed(method, success: bool)`
- `same_flight_publish_started`
- `same_flight_publish_completed`
- `same_flight_publish_blocked(reason: unverified/no_network)`

**v2.3 新增（漏斗重构）**：
- `flight_intent_created(source: 01a/01b/05/16, flight_number, reminder_offset_minutes)`
- `boarding_reminder_scheduled(flight_number, reminder_at)`
- `boarding_reminder_sent(flight_number)`
- `boarding_reminder_opened(flight_number)`
- `compose_mode_selected(mode: one_line/template/voice_transcript/free_text)`
- `template_prompt_selected(template_id)`
- `voice_recording_started` / `voice_transcribed(success: bool)`
- `offline_draft_saved`
- `offline_sync_started` / `offline_sync_completed` / `offline_sync_failed(reason)`
- `headline_quote_edited`
- `cloud_card_rendered(template_id, offline: bool)`
- `cloud_card_saved`
- `share_landing_opened(source: qr/deeplink/copy_link, flight_number, route)`
- `share_landing_same_flight_tapped`
- `share_landing_reminder_started`
- `same_flight_note_notification_sent(flight_number, hours_after_post)`
- `same_flight_note_notification_opened(flight_number)`
- `same_flight_notes_viewed(source: notification/share_landing/app)`

**v2.1 新增（登录链路）· v2.2 改 method 枚举**：
- `account_upgrade_prompt_shown(variant: soft/hard, trigger: t2_after_2nd_post/t3_after_3rd_post)`
- `account_upgrade_dismissed(variant: soft/hard)`
- `account_upgrade_started(source: 00d/08b/13/s7b_replace_device)`
- `account_upgrade_completed(method: wechat/phone, source, merged_with_existing: bool)`
- `account_settings_viewed`
- `sign_in_started(method: wechat/phone, source)`
- `sign_in_succeeded(method)`
- `sign_in_failed(method, reason: cancelled/no_wechat_app/sms_send_fail/code_invalid/rate_limited/network/server)`
- `sign_out_completed`
- `account_deletion_requested` / `account_deletion_confirmed`
- `sms_code_sent(phone_country_code)` / `sms_code_verified` / `sms_code_resend`
- `wechat_auth_initiated` / `wechat_auth_callback_received`

**沿用 v1**：
- `landing_viewed`（迁移到 01a/01b 区分）
- `capture_started` / `capture_completed` / `ocr_failed`
- `flight_confirmed` / `flight_proof_created`
- `private_card_generated` / `same_flight_publish_completed`
- `card_shared`
- `flight_space_viewed` / `discovery_viewed`
- `post_detail_viewed(source: same_flight/discovery)`
- `comment_written`（带 `is_same_flight: bool`）
- `report_submitted` / `block_user`
- `signup_completed`（auth upgrade，不是 Guest 创建）
- `user_returned`（D2/D7/D30 计算用）

---

## 14. Stage 1 验收条件（dev 启动前 PM 必检）

dev approve 前 PM 亲自走一遍 **11 大场景（S1-S11，含 S7b）** 的 Figma Make 设计。**任何 1 个场景在设计上跑不通都不允许进 dev**。

具体检查：
- [ ] S1 全 23 屏首次用户流可顺序走完 + 无断点；用户可不扫描登机牌直接写一句并生成私人 Cloud Card
- [ ] S2 用户在 01a 选"看看别人留下的"后能到 10 Discovery，回流时不再触发 00a-00d
- [ ] S3 第二次开 App 默认落 01b 不是 01a
- [ ] S4 01b → 09b → 11A 链路通，11A 上可看到自己的 Post 编辑入口
- [ ] S5 11B 上**没有评论框**，显示"评论只在本航班开放"
- [ ] S6 关闭 App 重开后能直接落 06 Compose 并显示原文和保存状态
- [ ] **S7 第 2 张 Post 发完，08 Publish → 09 后自动叠 08b 软 modal；选「保存我的账号」→ 14 Sign In Sheet → 走微信一键登录 → 回 01b / 09b，settings icon 显示「已用微信保存 · {nickname}」**（v2.2）
- [ ] **S7b 卸载重装后 00a-00d 流程里底部「已有账号？登录」可点 → 14 → 走微信或手机号 → 拉回所有老 Post（按 unionid / phone_e164 查重合并），落 01b**（v2.2）
- [ ] **S8 01a / 01b → 15 可手动录入航班号，创建登机前 30 分钟提醒；点通知直接进入 06 Compose**
- [ ] **S9 在无网络状态下 06 输入一句话 → 07 生成本地卡片 → 08 Private Share queued；联网后私人卡同步成功；如要进 09，必须补航班验证且内容不丢**
- [ ] **S10 Cloud Card 分享图长按识别 / deep link 进入 16，不直接跳 App Store；16 可看同班机/同航线笔记并进入 15**
- [ ] **S11 用户发布后 24-48h 内同班机新 Post 触发通知；点开定位到 09 的新笔记**
- [ ] **全公开区域（09 / 10 / 11 / 16）不得出现具体座位号；只能显示“靠窗的人 / 通道旁的人 / 同机乘客”等模糊身份**
- [ ] **14 上微信按钮视觉权重最高（绿底）；微信 App 未安装时按钮灰显，提示"用手机号登录"；手机号区号默认 +86，60 秒倒计时**（v2.2）
- [ ] **13 Account & Settings 上「删除账号」是红字，二次确认 + 当前登录方式重新校验（微信授权 / 短信验证码），再软删除 + 30 天恢复期文案**（App Store 5.1.1 硬要求，v2.2）

---

## 15. 产品经理结论

v2.4 PRD 的核心判断：原方案把激活押在"用户飞行中主动想起 App"，且把"扫描登机牌"放在表达之前，这两个假设都偏重。新方案改成**表达先行、验证后置**：飞行前锚定，飞行中/候机厅先写一句并生成私人 Cloud Card，飞行后通过 Cloud Card 扩散；只有发布到同班机、评论和同班机召回才要求航班验证。默认分享卡片锁定为复古明信片方向，避免真实 UGC 质量波动导致卡片审美坍塌。

至此：首次用户 + 老用户 + 中断恢复 + Guest 升级 + 换设备拉回 + 登机提醒 + 离线同步 + 私人卡分享 + 同班机验证发布 + 分享落地页 + 同班机召回状态分支齐全，10 条闭环显式化，权限矩阵 / 数据模型 / 埋点 / Won't Have / App Store 合规要求（5.1.1 删除账号 / 1.2 UGC 举报）全部对齐。

**已知风险**（创始人 review 时关注）：
- ⚠️ **触发频次仍低**：v2.3 只是在低频场景里提高激活和扩散，不改变"飞行本身低频"事实。Stage 1 必须严看 Cloud Card 分享率和提醒打开率。
- ⚠️ **Cloud Card 审美决定获客上限**：如果卡片不够像艺术品，朋友圈扩散会失败。设计验收必须看"是否愿意单独分享这张图"，而不是 UI 是否完整。
- ⚠️ **真实 UGC 质量不可控**：不能假设用户都会写出诗意句子。默认 Cloud Card 必须能承接“晚点了，累死”这类普通文本；否则内容质量下降会让整个视觉系统崩。
- ⚠️ **全深色 UI 是双刃剑**：深色有品味但在中国主流 App 语境里偏小众。Stage 1 只把深色作为氛围层，核心阅读和操作用浅色纸张/卡片降低距离感。
- ⚠️ **离线优先工程成本高**：离线草稿、离线卡片 preview、sync queue、冲突/重试都必须做，否则国内航班体验会崩。
- ⚠️ **验证后置会削弱仪式感**：必须通过航班状态 chip、Cloud Card metadata 和“发布同班机需验证”文案维持飞行专属感，不能退化成普通日记。
- ⚠️ **隐私信任链很脆**：公开区域一旦出现具体座位号、姓名、票号、证件号，就会直接破坏 00c Privacy Promise。
- ⚠️ **App Store 4.8**：iOS 用微信作为账号设立时 Apple 政策要求同时给 Apple Sign In。中国区抖音 / 京东 / 美团等组合通常能过，但若被驳回 → 回退方案在 §9 14 末尾（把 v2.1 设计的 Apple Sign In 加回作第三按钮）。
- ⚠️ **微信开放平台审核**：mobile app 类型审核需要主体、AppID、Universal Link、隐私政策 URL；周期 1-3 工作日。dev 启动同步申请，不阻塞 UI 设计。
- ⚠️ **SMS 服务商合规**：腾讯云 / 阿里云 SMS 都要求短信模板审核（"【签名】您的验证码：123456，5 分钟内有效"格式），签名需要工信部备案；周期 1-5 工作日。dev 启动同步申请。
- ⚠️ **中国区基础设施**：生产主链路不得依赖 Supabase Cloud 或 iOS 客户端直连 PostHog Cloud。后端数据、事件、分享落地页必须走中国可访问的一方服务；PostHog 只能作为服务端异步下游，不作为客户端可用性或验收依据。

**dev 启动前必须满足**：
1. 创始人 approve v2.4 PRD（这份文档，跑 `npx tsx orchestrate.ts approve pm --project=head_in_clouds`）
2. 创始人对 §12 七个决策点表态（默认 yes 也算明确表态）
3. Figma Make 先按 v2.4 重跑核心屏 00a / 01a / 06 / 07 / 08 / 15 / 16；其中 06/08 必须体现私人卡不需验证、同班机发布需验证，07 默认 Cloud Card 必须采用复古明信片方向
4. test-plan 同步更新覆盖 S1-S11 + S7b 共 12 条验收流（test 角色任务）
5. **运营侧**：dev 开工同时启动微信开放平台 App 审核 + SMS 服务商签名审核（这俩拿不到 dev 也写不通登录流程）
6. **基础设施侧**：dev 进入真实 provider 集成前，先确定中国区云厂商、生产域名、first-party `/events` API 与 staging event dashboard。

满足后，**dev 直接开干**（按 feedback_feature_spec_autoflow 规则），不再问。
