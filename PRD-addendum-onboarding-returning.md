# PRD Addendum — Onboarding + Returning User States

> **来源**：2026-05-16 创始人 review Figma Make 5/16 publish 版本时指出 2 个 PRD gap：
> (1) 老用户（已上传过机票、有历史）进来仍看首次用户的 Opening 屏 = 体验断裂
> (2) 整个 PRD 没有 onboarding / 注册 / 账号设计
>
> 这份 addendum 不替代 PRD.md，是补丁。Stage 1 dev 启动前必须落地。
>
> **作者**：小品（PM）· 2026-05-16
> **状态**：draft → 待创始人 approve

---

## 1. 用户状态机（之前 PRD 缺）

进入 App 时按以下顺序判断：

```
有 auth session？
├── 否 → First-time experience（00a-00d）
└── 是 →
    ├── 用户当前有未发布草稿（compose 状态进行中）？
    │   └── 是 → 直接进 06 Compose（恢复草稿）
    ├── 有发布过至少 1 张 Post？
    │   └── 是 → Opening (Returning state)
    └── 否 → Opening (First-published state) ≈ 现在的 Opening 但少 Cloud Card sample 噱头
```

---

## 2. 新增 First-Launch Flow（00a-00d, 4 屏）

**only 第一次开 App 触发，之后永远不展示。**

### 00a Welcome

- 品牌大字：Head in the Clouds / 云·上·心·事
- 副标题：一句话 value prop —— "**拍下你这趟飞行，留下只有此刻能写的话**"
- 主 CTA：「开始」→ 跳 00b
- 不要：注册框、登录入口（00d 才做）、Cloud Card 完整 sample（00a 是 hook，不是炫技）

### 00b Permission Primer（**必须 必须 必须** 在系统权限弹框前）

- 3 张图 + 1 句话各自解释：
  - 📷 相机 —— "拍下你的登机牌或票证截图"
  - 🖼️ 相册 —— "如果你想从相册选已有截图"
  - 🔔 通知（可选）—— "起飞前提醒你写下心事"（Stage 1 可不要）
- 底部：「全部允许」按钮 → 弹系统权限框（一次性请求两个或三个）
- 注意：iOS 14+ 推荐这种"前置说明"模式，能把权限通过率从 ~40% 拉到 70%+

### 00c Privacy Promise

- 标题："你的票，只在你手里"
- 3 条 bullet：
  - 🔒 票证原图**默认不保存到云**——OCR 完成后立即销毁
  - 👁 你的飞行号 / 出发到达 / 时间会出现在 Cloud Card 上，**不显示你的姓名 / 座位号 / 票号**
  - 💬 评论只在你自己那趟航班内可见，**陌生人看不到具体票证细节**
- 主 CTA：「我知道了，继续」→ 跳 00d

### 00d Auth (Account Creation / Sign In)

⚠️ **创始人决策点**：Stage 1 是否要账号？三种选择：

| 选项 | 优点 | 缺点 | 推荐？ |
|---|---|---|---|
| A. **必须注册**（Apple Sign In / 邮箱） | 立刻可跨设备 / 有 user_id 做数据分析 | 注册墙摩擦最高 | ❌ Stage 1 不推荐 |
| B. **Guest mode + 后期升级** | 注册摩擦零 / 用户可先体验 | 数据策略复杂（local-only? device-bound?） | ✅ **推荐** |
| C. **完全免账号（device-bound）** | 摩擦最低 | 换机数据丢失 | Stage 1 可接受，Stage 2 须支持迁移 |

**我（PM）的判断**：**B 方案**——Guest mode 第一张卡，发布后第二张卡触发「绑定账号才能保存历史」软提示（不强制）。第三张卡触发硬提示。这样：
- 第一次体验摩擦 0
- 用户愿意发布 = 已感知价值 = 此时要账号能接受
- App Store 审核也好过（不是注册墙）

如果你选 B，00d 改成 "Get started as guest" 单按钮，跳过传统 sign in 屏。

---

## 3. Opening 屏改造 —— 两种状态分支

| 状态 | 显示什么 | 主 CTA |
|---|---|---|
| **First-published**（已 onboarded 但还没发过 Post） | 现在 Figma Make 的 Opening（Cloud Card sample + "拍下这趟飞行"） | "拍下这趟飞行" → 02 Capture |
| **Returning**（≥1 张已发布） | 顶部："最近的云上心事" + 最新一张 Card 缩略图（点开进 11A Detail）<br>中部："**准备好下一次飞行了吗？**"<br>主 CTA："拍下新航班"<br>次入口："我的飞行册（{N}）" → 跳 09b My Flights | "拍下新航班" → 02 Capture |

**关键不一样**：
- 老用户看到自己东西在最显眼位置，不再是营销 landing
- "拍下这趟飞行" → "拍下新航班"（暗示已经有历史）
- 多一个"我的飞行册"入口，能回到所有过往 Post

---

## 4. 新增 09b My Flights（飞行册）

老用户从 Opening 进入，展示他所有过往飞行的卡片网格。

布局：
- 顶部：「我的飞行册 · {N} 趟」
- 时间倒序 grid：每张卡 = 一次飞行的 Cloud Card 缩略（航班号 + 主题词 + 日期）
- 点击 → 跳 11A Detail
- 底部 fixed CTA："拍下新航班" → 02 Capture（保证主转化路径不被埋没）

**不做**（明确剔出 Stage 1）：
- 搜索 / 过滤
- 按目的地分组
- 年度回忆册（Stage 2 才做）

---

## 5. 对 Figma Make 设计的具体要求

需要 Figma Make 补 5 个新屏（建议屏号）：

| Figma Make 屏号 | 名称 | 触发条件 |
|---|---|---|
| 00a | Welcome | First launch only |
| 00b | Permission Primer | First launch only |
| 00c | Privacy Promise | First launch only |
| 00d | Get Started (Guest) | First launch only |
| 01b | Opening · Returning state | Has ≥1 published Post |
| 09b | My Flights（飞行册） | Tap "我的飞行册" from 01b |

**01 Opening 现版 = 01a First-published state**（保留作为 onboarded 但还没发的状态）

**新增连接关系**：
- 00d Get Started → 01a Opening (First-published)
- 01b Opening Returning → 02 Capture（主 CTA）
- 01b Opening Returning → 09b My Flights（次入口）
- 09b My Flights tap card → 11A Detail
- 09b My Flights bottom CTA → 02 Capture

---

## 6. Acceptance Criteria（dev 启动前必须满足）

- [ ] AC1：First-launch user **不能**直接看到 01a Opening——必须先过 00a-00d 4 屏
- [ ] AC2：Returning user（已发布 ≥1）**不能**看到 01a，必须看 01b
- [ ] AC3：00b Permission Primer 必须在系统权限弹框**之前**显示
- [ ] AC4：00d 选 Guest mode 后，第二次进 App 不再触发 00a-00d 任一屏
- [ ] AC5：01b Opening Returning 显示"我的飞行册（{N}）"，{N} 数字正确
- [ ] AC6：09b 飞行册按时间倒序，最新在最上
- [ ] AC7：埋点新增：`onboarding_step_viewed(step)` / `onboarding_completed` / `guest_mode_chosen` / `myflights_viewed`

---

## 7. 创始人需要决策的（≤2 条）

1. **账号策略**：A / B / C 三选一（我推 B）
2. **00d 是否在 Stage 1 必须**：如果选 C（device-bound 无账号），00d 可移除，省 1 屏

我默认按 B 方案写 Figma Make 要求。你不反对就继续。
