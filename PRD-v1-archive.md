# PRD：Head in the Clouds / 云上心事

> 由产品经理输出 · 日期：2026-05-15  
> 基于 OPPORTUNITY：2026-05-15-verified-flight-note  
> 项目目录：`head_in_clouds`  
> 阶段：Stage 1 高保真 MVP  
> Founder override：已跳过 validation，直接进入 PM。原因：该项目的生死线是拍照证明 + 情绪 UI/UX，低保真表单验证会误判。

---

## 0. 本次 PRD 修订结论

旧 PRD 最大问题：没有定义 `Post` 到底是什么，也没有定义评论权限和每个页面的真实内容，导致设计工具只能生成“漂亮但泛”的旅行日记 App。

本版明确：

- **Post 不是纯文字**，也不是普通图片动态。Stage 1 的 Post = `一张系统生成的云上心事卡 + 用户文字 + 航班证明元数据 + 可选随行照片`。
- **登机牌/电子机票照片不是 Post 内容**，只用于证明和识别，默认不公开、不保存原图。
- **视频不进 Stage 1**。视频会显著增加审核、存储、生成和内容安全复杂度。
- **评论只在本航班开放**。同旅程、目的地、热点均不开放自由评论，只能点赞、收藏、预设回应。
- **核心交互是 photo-first**：拍下登机牌/电子机票/航班截图 → 识别并确认 → 写心事 → 生成卡 → 发布/分享。

---

## 1. 产品定位

Head in the Clouds / 云上心事帮助真实飞行乘客在一次具体航班里留下高仪式感的情绪卡片。它不是 Flighty 那样的航班追踪工具，也不是 Day One 那样的私人日记；它的差异化是：

- 真实乘客证明：只有拍下/上传票证并确认航班后，才能发布到本航班。
- 情绪卡片生成：用户写下 30-300 字，系统生成一张可保存/分享的高审美卡片。
- 有边界的社交：本航班可自由评论，其他空间只保留轻互动，避免泛社交和骚扰。

## 2. Stage 1 成功标准

Stage 1 不是做完整社交网络，而是验证一个高保真核心闭环：

```text
拍下这趟飞行 → 确认这是我的航班 → 写下云上心事 → 生成一张想分享的卡 → 发布到本航班
```

Stage 1 结束时，必须能回答：

- 用户是否愿意拍/传票证？
- 用户是否愿意写 30-300 字？
- 生成卡片是否有分享冲动？
- 本航班可评论、其他空间不可评论的边界是否清楚？
- UI/UX 是否足够有情绪价值，而不是普通表单工具？

---

## 3. 核心内容模型

### 3.1 FlightProof（航班证明）

用户创建第一条内容前必须先生成一个 `FlightProof`。

| 字段 | 是否必填 | 说明 |
|---|---|---|
| `proof_id` | 必填 | 系统生成 |
| `proof_source_type` | 必填 | `boarding_pass_photo` / `e_ticket_screenshot` / `flight_itinerary_screenshot` |
| `flight_number` | 必填 | OCR 识别；失败时用户修正 |
| `flight_date` | 必填 | YYYY-MM-DD |
| `origin_airport` | 必填 | 机场三字码 + 城市名 |
| `destination_airport` | 必填 | 机场三字码 + 城市名 |
| `airline` | 可选 | 可识别则填 |
| `seat_label` | 可选 | 只保存如 `14A`，不保存真实姓名 |
| `cabin_class` | 可选 | Economy / Business 等 |
| `raw_image_retention` | 必填 | 默认 `deleted_after_extraction` |
| `sensitive_fields_redacted` | 必填 | 用户确认已遮挡或系统提示已处理 |

明确规则：

- 原始票证图片默认不公开。
- 原始票证图片默认不长期保存。
- Post 里永远不展示姓名、票号、证件号。
- 手动输入航班号只允许作为识别失败后的修正，不是主入口。

### 3.2 CloudPost（云上心事 Post）

Stage 1 的 Post 是一个混合内容对象。

| 内容块 | 是否必填 | 数量 | 说明 |
|---|---|---:|---|
| 系统生成卡片 `generated_card` | 必填 | 1 张 | 由航班、心境、文字和模板生成；这是 feed 主视觉。 |
| 正文 `note_text` | 必填 | 30-300 字 | 用户写下的心事；不是 caption，而是核心内容。 |
| 心境 `mood` | 必填 | 1 个 | 奔赴、告别、重逢、逃离、独行、归家、出差。 |
| 可选随行照片 `moment_photos` | 可选 | 0-3 张 | 只能是窗外、机场、座位、目的地等氛围照片；不能是票证照片。 |
| 视频 `video` | 不支持 | 0 | Stage 1 不支持用户视频。 |
| 链接 `external_link` | 不支持 | 0 | 防广告和审核复杂度。 |
| 位置信息 `route_meta` | 必填 | 1 组 | 航班号、日期、出发地、目的地。 |

Post 不是：

- 不是纯文字动态。
- 不是小红书图文笔记。
- 不是朋友圈相册。
- 不是航班记录条目。

### 3.3 Comment（评论）

| 字段 | 规则 |
|---|---|
| 内容类型 | 纯文字 |
| 字数 | 1-140 字 |
| 图片/视频 | 不支持 |
| 链接 | 不支持 |
| @提及 | 不支持 |
| 楼中楼 | 不支持；只做一级评论 |
| 删除 | 用户可删除自己的评论 |
| 举报 | 所有评论可举报 |

评论开放规则：

| 场景 | 可看评论 | 可写评论 | 说明 |
|---|---|---|---|
| 本航班 tab | 是 | 是，仅同航班已验证用户 | 产品最性感的“同机乘客”边界。 |
| 同旅程 tab | 否 | 否 | 只展示点赞、收藏、预设回应。 |
| 目的地 tab | 否 | 否 | 只展示点赞、收藏、预设回应。 |
| 热点 tab | 否 | 否 | 热点不变成公共评论场。 |
| 未验证用户 | 否 | 否 | 可看精选样例，不可评论。 |

重要展示规则：

- 同旅程/目的地/热点中不要显示评论按钮。
- 如果同一个 Post 在本航班里有评论，跨 tab 展示时也隐藏评论数，避免用户误解。
- 非本航班场景可展示一句约束文案：`评论只在本航班开放`。

---

## 4. 用户权限矩阵

| 用户状态 | 创建 Post | 发布到本航班 | 本航班评论 | 同旅程/目的地/热点互动 | 举报/屏蔽 |
|---|---|---|---|---|---|
| 未验证访客 | 否 | 否 | 否 | 可浏览热点样例 | 可举报 |
| 已上传但未确认航班 | 否 | 否 | 否 | 可浏览热点样例 | 可举报 |
| 已验证本航班乘客 | 是 | 是 | 是 | 点赞/收藏/预设回应 | 可举报/屏蔽 |
| 已验证其他航班乘客 | 可创建自己的航班 Post | 否 | 否 | 点赞/收藏/预设回应 | 可举报/屏蔽 |
| 内容作者 | 可编辑/删除自己的 Post | 是 | 可回复评论 | 可互动 | 可隐藏自己的 Post |

---

## 5. 信息架构

| # | 页面 | 目的 |
|---:|---|---|
| 1 | Opening | 说明产品、展示情绪样例、引导拍照。 |
| 2 | Capture | 拍/传登机牌、电子机票、航班截图。 |
| 3 | Privacy Redaction | 引导遮挡敏感信息，声明原图默认不保存。 |
| 4 | Unlocking / OCR | 识别航班信息，做情绪化解锁动效。 |
| 5 | Flight Confirm | 确认航班、日期、路线、座位可选字段。 |
| 6 | Compose Post | 选择心境、写正文、添加可选随行照片。 |
| 7 | Card Studio | 生成并切换卡片模板。 |
| 8 | Publish / Share | 保存、分享、发布到本航班。 |
| 9 | Flight Space | 本航班 feed + 评论。 |
| 10 | Discovery Spaces | 同旅程、目的地、热点，只能轻互动。 |
| 11 | Post Detail | 根据来源场景决定是否展示评论。 |
| 12 | Report / Block | 举报、屏蔽、隐藏内容。 |

---

## 6. 页面详细需求

### Screen 1：Opening

必须包含：

- 产品名：`Head in the Clouds`
- 中文副标题：`云上心事`
- 主文案：`拍下这趟飞行，留下只属于云上的心事`
- 一张真实感示例 `CloudPostCard`
- 主按钮：`拍下这趟飞行`
- 次按钮：`看看别人留下的`
- 隐私短句：`票证原图默认不保存`

不允许：

- 首屏出现航班号输入框。
- 首屏像航班查询工具。
- 首屏以 feed 为主。

### Screen 2：Capture

必须包含：

- 相机取景框。
- 上传入口：`从相册选择`
- 可识别类型提示：登机牌、电子机票、航班截图。
- 敏感信息提示：姓名、票号、证件号可先遮挡。
- 拍摄按钮。
- 备用入口：`识别失败？稍后手动修正`，不能叫“手动输入”。

### Screen 3：Privacy Redaction

必须包含：

- 上传图片预览。
- 高亮可能敏感区域：姓名、票号、证件号。
- 操作：`我已遮挡` / `帮我打码`。
- 文案：`我们只提取航班信息，原图默认删除。`
- CTA：`继续解锁`

### Screen 4：Unlocking / OCR

必须包含：

- 云层/航线/舷窗感动效。
- 文案：`正在解锁这趟云上的坐标`
- 展示逐步识别字段：航班号、日期、出发地、目的地。
- 识别失败时进入 Flight Confirm，标记需要用户修正。

### Screen 5：Flight Confirm

必须包含：

- 航班号：如 `MU5405`
- 日期：如 `2026-05-15`
- 航线：`上海 SHA → 成都 CTU`
- 可选座位：如 `14A`
- 可选航空公司。
- 隐私说明。
- CTA：`确认，这是我的这趟飞行`

### Screen 6：Compose Post

必须包含：

- 标题：`此刻，你想把什么留在云上？`
- 心境选择：奔赴、告别、重逢、逃离、独行、归家、出差。
- Prompt chips：`我为什么出发`、`我正在离开什么`、`我想抵达什么`、`如果这趟飞行会被记住`
- 正文输入框：30-300 字。
- 可选随行照片入口：`添加此刻的照片（0/3）`
- 照片规则说明：`不要上传登机牌原图；可上传窗外、机场、座位、目的地。`
- CTA：`生成我的云上心事`

### Screen 7：Card Studio

必须包含：

- 大尺寸卡片预览。
- 显示航线、日期、心境、正文节选。
- 模板选择：舷窗、胶片、邮戳、极简。
- 可选照片作为背景或内嵌小图。
- 操作：保存图片、分享、换模板、发布。
- 高级模板入口。

### Screen 8：Publish / Share

必须包含：

- 发布成功状态。
- 分享渠道：保存图片、微信、朋友圈、小红书、复制链接。
- 发布范围说明：`已发布到本航班 MU5405`
- 下一步按钮：`进入本航班`

### Screen 9：Flight Space（本航班）

必须包含：

- 航班 header：航班号、航线、日期。
- 当前用户 Post 置顶。
- 同航班 Post 列表。
- 每个 Post card 包含：生成卡缩略图、作者匿名身份、心境、正文节选、点赞、收藏、评论数、举报入口。
- 评论 composer：`给这趟飞行里的人留一句话`
- 评论区只在 Post detail 展开，不在 feed 里长展开。

### Screen 10：Discovery Spaces（同旅程 / 目的地 / 热点）

必须包含：

- 顶部 tab：本航班、同旅程、目的地、热点。
- 当前 tab 的解释文案。
- 卡片列表。
- 互动：点赞、收藏、预设回应、分享、举报。
- 锁定文案：`评论只在本航班开放。`

不允许：

- 评论按钮。
- 评论数。
- 私信、关注、头像墙。

### Screen 11：Post Detail

必须包含：

- 生成卡大图。
- 完整正文。
- 航线和心境。
- 可选随行照片 0-3 张。
- 互动区。
- 来源上下文：
  - 本航班进入：展示评论列表和评论输入框。
  - 同旅程/目的地/热点进入：不展示评论输入框，展示 `评论只在本航班开放`。

### Screen 12：Report / Block

必须包含：

- 举报原因：骚扰、广告、隐私泄露、冒犯内容、其他。
- 操作：举报、屏蔽此用户、隐藏此内容。
- 结果状态：`已隐藏，我们会处理。`

---

## 7. Must Have 功能

| # | 功能 | 描述 | 验收标准 |
|---:|---|---|---|
| 1 | Photo-first flight proof | 拍/传票证，识别航班信息，失败后修正。 | 首屏无航班号输入框；必须经过 capture 或 upload 才进入确认。 |
| 2 | Privacy redaction | 票证敏感信息提示和默认不保存原图。 | UI 明确展示敏感信息处理；数据模型不把原图作为公开内容。 |
| 3 | CloudPost creation | 心境 + 文字 + 可选 0-3 张随行照片 + 生成卡。 | 不允许纯文字 Post；每条 Post 至少生成 1 张卡。 |
| 4 | Permissioned interaction | 本航班可评论，其他空间不可自由评论。 | 权限矩阵在 UI 层可见，不同 tab 行为不同。 |
| 5 | Safety actions | 举报、隐藏、屏蔽、删除自己的内容。 | 每条 Post 和评论都有安全入口。 |

## 8. Won't Have

- 用户视频。
- 链接发布。
- 私信、关注、好友。
- 通用飞行追踪。
- 公开票证图片。
- 二级评论/楼中楼。
- 桌面优先界面。

---

## 9. 成功指标与埋点

| 指标 | 目标值 | 事件 |
|---|---:|---|
| 拍照启动率 | >=45% | `capture_started / landing_viewed` |
| 票证上传完成率 | >=60% | `ticket_photo_uploaded / capture_started` |
| 隐私确认率 | >=80% | `privacy_redaction_confirmed / ticket_photo_uploaded` |
| 航班确认率 | >=70% | `flight_proof_confirmed / ticket_photo_uploaded` |
| Post 生成率 | >=50% | `post_generated / flight_proof_confirmed` |
| Post 发布率 | >=35% | `post_published / post_generated` |
| 分享率 | >=20% | `card_shared / post_generated` |
| 本航班评论率 | >=15% | `comment_created / post_detail_viewed`（仅本航班） |
| 付费意向 | >=5 次 | `paywall_viewed`, `checkout_started` |

自定义事件：

- `landing_viewed`
- `capture_started`
- `ticket_photo_uploaded`
- `privacy_redaction_confirmed`
- `flight_proof_confirmed`
- `post_composer_started`
- `moment_photo_added`
- `post_generated`
- `template_changed`
- `post_published`
- `card_shared`
- `feed_tab_viewed`
- `post_detail_viewed`
- `comment_created`
- `preset_reaction_added`
- `post_saved`
- `content_reported`

Baseline 事件仍保留：

- `signup_completed`
- `user_returned`
- `core_action_completed`，`action_name="cloud_post_published"`
- `paywall_viewed`
- `checkout_started`
- `subscription_created`

## 10. 产品经理结论

继续 Stage 1，但验收标准必须提高：如果设计稿没有清楚表达 Post 内容结构、拍照证明仪式、评论权限边界，就不允许进入 dev。这个项目不是“把 feed 做漂亮”，而是要让用户相信：我真的在这趟飞行里，留下了一件只有此刻才能发生的东西。
