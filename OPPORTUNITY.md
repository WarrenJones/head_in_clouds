# 需求机会：Head in the Clouds

> 由需求调查员输出 · 日期：2026-05-15  
> 机会类型：📱 Micro App  
> Track：micro_app  
> Monetization：iap / one-time purchase / template packs
> 对外产品名：Head in the Clouds  
> 中文副标题：云上心事

---

## 一句话描述

真实乘客在一趟飞行前后想留下带有仪式感的飞行记忆，但现在只能写普通日记、发小红书或用偏工具化的航班记录 App；Head in the Clouds 让用户通过航班/登机牌证明解锁一张“云上心事”，并浏览同航班、同旅程、同目的地的匿名故事。

## 命名判断

- **为什么不用 Verified Flight Note**：它是功能描述，不是品牌；听起来像合规工具或航班记录插件，无法承接网易云评论里的情绪共鸣。
- **为什么叫 Head in the Clouds**：名字直接来自用户截图里的歌曲语境，同时有双关含义：人在云上飞，心也暂时离开地面。这个名字天然适合表达离别、奔赴、重逢、逃离、旅行这些飞行情绪。
- **为什么中文副标题叫“云上心事”**：它比“云端来信”更短、更暧昧，也不把产品限定成写信工具；它表达的是飞行时那种“人在云上，心里有事”的状态，能覆盖离别、奔赴、重逢、逃离和独自旅行。

## Micro App 场景

- **用户场景**：候机、起飞前、飞行中离线写草稿、落地后发布；用户处在离别、奔赴、重逢、旅行、工作转场等高情绪密度时刻。
- **分发入口**：网易云 3.2 万赞评论源头故事、小红书/抖音“飞行日记/旅行记录/航班故事”、App Store `flight diary` / `flight logbook` / `travel journal`、Reddit travel / iOS communities。
- **留存理由**：每次飞行生成一张记忆卡；同旅程/目的地内容可浏览收藏；年度飞行回忆册和高级模板形成后续回访。
- **MVP 发布路径**：先 PWA/landing + interactive mock；验证通过后 iOS TestFlight。正式 App Store 上架后置，避免 UGC/隐私审核提前拖慢验证。

---

## 痛点证据

1. 用户提供的网易云音乐评论截图显示：评论建议航空公司把座椅杂志换成日记本，让乘客写下故事并汇编成“飞行日记”，该评论约 32,440 likes。这个证据说明“飞行中的陌生人故事容器”有强中文情绪共鸣。
2. FlightLog App Store 页面显示其为乘客/频繁旅行者提供 flight journal / boarding pass scanning / sharing cards，并有 IAP：Lifetime $24.99、monthly $1.99、annual $8.99，证明 flight logbook 相邻品类有付费。来源：https://apps.apple.com/us/app/flightlog-flight-logbook/id6756842867
3. Flighty Pro 定价 $4.99/week、$59.99/year、$299 lifetime，证明飞行场景下的 iOS 用户愿意为高质量航班体验付费。来源：https://flighty.com/pricing
4. Day One / Polarsteps 证明 travel journal / personal journal 相邻需求存在，且 premium subscription 可行。来源：https://dayoneapp.com/guides/premium-subscription/day-one-pricing-features-guide/ 与 https://stories.polarsteps.com/stories/best-travel-apps
5. CAAC 2025 春运 40 天运输 90.2M passengers，daily average 2.255M，说明中国飞行场景规模足够大，首发中国市场不是小样本。来源：https://www.caac.gov.cn/English/News/202503/t20250306_226880.html
6. V2EX 有用户寻找国外航班 Live Activity 类 App，接受手动添加和付费/买断，说明中文技术用户对飞行 App 有付费意愿。来源：https://global.v2ex.com/t/996396

---

## 目标用户画像

- **职业/角色**：18-35 岁 iOS 用户、学生/年轻白领/独立旅行者/异地恋和跨城奔赴人群、频繁差旅但有表达欲的人。
- **技术水平**：普通移动互联网用户，能接受扫码/上传截图，但不愿填写复杂表单。
- **地区市场**：首发中国市场验证情绪和分发；若成立，再做英语版验证付费。
- **在哪里出没**：网易云音乐评论区、小红书旅行/情绪内容、抖音旅行日常、即刻、V2EX、Reddit travel / iOS communities。
- **现在替代方案**：普通日记、备忘录、小红书、朋友圈、Day One、Apple Journal、Polarsteps、FlightLog、Flighty。缺口是这些产品没有“真实乘客 + 同航班/同旅程情绪空间”。

---

## 竞品矩阵

| 竞品 | 核心功能 | 定价/变现 | 主要缺口 | 我们的切入 |
|---|---|---|---|---|
| FlightLog | 航班 logbook、boarding pass scanning、统计、分享卡 | IAP / subscription / lifetime | 偏工具/记录，不是陌生人故事和情绪空间 | verified passenger emotional note |
| Flighty | 高质量航班追踪、提醒、导入、Live Activities | $4.99/week, $59.99/year, $299 lifetime | 偏效率/状态，不是记忆创作 | 情绪卡片和同旅程内容 |
| Day One / Apple Journal | 私人日记 | subscription / free | 泛日记，无 flight proof 和旅程社交 | 航班场景限定 |
| Polarsteps | 旅行轨迹和旅行故事 | premium adjacent | 旅行维度较长，不聚焦一趟飞行 | 一次飞行的短时情绪 |
| 航旅纵横 / 飞常准 | 国内航班状态、值机、行程 | 工具/服务 | 强工具弱表达 | 不做航班状态，做记忆容器 |

---

## 产品形态

### 四个 Tab

1. **本航班**：同一航班号 + 日期。只有验证为本航班乘客的人可以发卡、自由评论、点赞、收藏。
2. **同旅程**：同出发地 → 同目的地，可跨航司/跨时间。允许浏览、点赞、收藏、预设回应，不开放自由评论。
3. **目的地**：飞往同一城市的人。允许浏览、点赞、收藏，不开放自由评论。
4. **热点**：高收藏/高共鸣/人工精选的记忆卡。允许浏览、点赞、收藏，不开放自由评论。

### 为什么只允许本航班自由评论

本航班是真实关系密度最高的空间，验证过的同机乘客形成最小信任边界。其他空间关系弱，开放自由评论会快速变成泛社交/搭讪/广告/审核压力，所以第一版只做低风险互动。

---

## 差异化切入点

不是 flight tracker，也不是 travel journal，而是“真实乘客才能留下的飞行记忆卡”。核心差异是：

- proof-of-passenger：航班/登机牌验证；
- emotional artifact：高审美卡片生成；
- bounded social：只在同航班开放自由评论；
- density fallback：同旅程/目的地/热点解决同航班稀疏问题。

---

## 变现路径

- **第一版**：免费生成基础卡片；高级模板/动态卡片/去水印 IAP。
- **建议定价**：¥6-18 单模板包；¥28-68 旅程卡片包；年度回忆册后置。
- **不做订阅**：飞行频率不够高，订阅会提高早期转化阻力。
- **付费验证指标**：≥5 个 paywall/template clicks 或 ≥2 个真实付费。

---

## Micro App 实验计划

- **MVP 范围**：landing + high-fidelity mock + PWA/interactive card generator；主流程支持拍下/上传登机牌、电子机票或航班截图，识别失败时再手动修正航班信息，随后生成卡片、浏览 mock same-trip feed、点赞/收藏模拟。
- **7-14 天目标**：
  - >=300 landing visits；
  - >=50 generated memory cards；
  - >=30 flight proof confirmations；
  - >=20 published notes；
  - card share rate >=20%；
  - like/save interaction rate >=30%；
  - >=5 paywall/template clicks or >=2 paid template purchases。
- **内容分发计划**：围绕“网易云 3.2 万赞飞行日记评论变成 App”发布 5-8 条小红书/即刻/朋友圈/Reddit 内容。
- **继续投入标准**：写卡、发布、分享三个动作同时过线。
- **Kill 标准**：用户只夸浪漫但不写卡；拒绝航班证明；分享率 <10%；UGC 风险在小流量下已不可控。

## Track-specific Validation Plan

- **Track**：micro_app
- **验证材料**：landing / mock / PWA prototype / card generator / sample feeds。
- **7-14 天目标**：同上。
- **通过标准**：真实航班信息提交、写卡、发布、分享、付费点击同时达到最低线。
- **Kill 标准**：任一核心动作明显断裂。
- **验证通过后是否进入 PM**：true only if validation manifest proves activation/share/paywall signals and founder approves.

---

## 落地裁决（Pre-flight）

- **最终裁决**：`micro_test`
- **Track**：micro_app
- **Monetization**：iap / one-time purchase / template packs
- **Ready for PM**：false
- **PMO track-specific 结论**：
  1. 用户从哪里发现它：GO，小红书/即刻/网易云源头故事/ASO/Reddit 均有入口。
  2. 用户为什么回来：GO with risk，依赖飞行频次、同旅程浏览和卡片收藏/分享。
  3. 同类 App 是否赚钱：GO，FlightLog/Flighty/Day One/Polarsteps 等相邻品类有付费。
  4. MVP 1-2 周能否公开分发：GO，PWA/landing/TestFlight 可验证，不必先上 App Store。
  5. 是否只靠更好看：GO，差异化来自 verified passenger + bounded social，不只是 UI。
- **Adversarial 审查模型**：same-session-gpt-5
- **Adversarial fallback**：true
- **Adversarial 审查结论**：CONDITIONAL_GO
- **validation kind**：micro_app_test
- **验证动作**：7-14 天 landing + card generator + content distribution + paywall click test。
- **通过标准**：见实验计划。
- **最晚验证日期**：2026-05-29
- **为什么值得现在做**：它是一个用户给出的高情绪种子，且能用 PWA/mock 在 7-14 天内验证，不需要先做完整 App 或航空公司合作。

---

## 技术可行性评估

- **核心功能能在 1-2 周内完成**：验证版可以；正式社交版不可以。
- **主要技术风险**：boarding pass privacy、UGC moderation、same-flight cold start、OCR 准确率、App Store review。
- **复用现有技术栈**：验证版可用 Next.js/Supabase；正式 iOS 可用 SwiftUI + VisionKit。Apple VisionKit 支持识别文本、日期、航班号等内容。来源：https://developer.apple.com/documentation/visionkit?language=objc
- **审核风险**：UGC 必须有举报、屏蔽、内容过滤和处理机制；隐私标签必须披露 User Content / Identifiers / Usage Data 等收集情况。来源：https://developer.apple.com/appstore/resources/approval/guidelines.html 与 https://developer.apple.com/app-store/app-privacy-details/

---

## 评分

| 维度 | 权重 | 得分（/10） | 理由 |
|---|---:|---:|---|
| 搜索/下载需求 | 20% | 7.0 | 有 flight log/travel journal 付费相邻品类和网易云强情绪信号，但还没证明“飞行故事卡”搜索需求。 |
| 分发可行性 | 20% | 7.6 | 源头故事适合小红书/即刻/朋友圈传播；ASO 可用 flight diary/flight logbook。 |
| 竞品变现 | 15% | 7.2 | FlightLog/Flighty/Day One/Polarsteps 均证明相邻付费，但不是完全同类。 |
| 留存频次 | 15% | 5.9 | 最大弱点：飞行不是高频；靠同旅程浏览、收藏、年度回忆补。 |
| 技术可行性 | 20% | 7.4 | PWA/mock/TestFlight 可行；正式 UGC + OCR + privacy 较重。 |
| 差异化包装 | 10% | 9.0 | Head in the Clouds / 云上心事承接源头歌曲和云端双关，verified passenger + bounded social 形成产品差异。 |
| **加权总分** | | **7.27 / 10** | 进入 micro_test，但必须先 validation。 |

---

## 调查员结论

- **推荐等级**：推荐进入 micro_test validation。
- **核心理由**：它不是泛日记/泛社交，而是由真实乘客证明和飞行场景限定构成的情绪型微社交产品；验证成本低，失败成本可控。
- **最大风险**：用户可能喜欢概念但不愿意写卡/验证航班；UGC 和隐私处理必须从第一天设计好。
- **下一步**：Founder review 后跑 validation，而不是直接写正式 App。
