# 测试报告：Head in the Clouds / 云上心事

**项目**：head_in_clouds  
**测试日期**：2026-06-01  
**测试平台**：iOS SwiftUI；iPhone 17 Simulator；server unit tests；PM/UX static walkthrough  
**本轮范围**：PMO 把关、PM 逻辑闭环、UI 交互反馈、QA 自动化全量回归。

---

## 判定结果

**本地 iOS simulator QA gate：PASS。**  
**生产上线 / 外部 TestFlight 可评估版本：NO-GO。**

这两个结论必须分开：本轮已经真实跑完本地 UI 自动化，不再是“静态看起来可以”；但备案、微信、SMS、APNs、IAP、远端部署和真机 provider evidence 仍未闭环，所以不能宣称达到上线条件。

| Gate | 当前状态 | 判定 |
|---|---|---|
| Swift core checks | `HeadInCloudsCoreChecks passed` | PASS |
| Server unit tests | `89/89` tests passed | PASS |
| XCUITest build | `** TEST BUILD SUCCEEDED **` | PASS |
| Simulator XCUITest execution | `15/15` tests passed | PASS |
| Git whitespace check | `git diff --check -- head_in_clouds` 无输出 | PASS |
| Remote SSH / deploy gate | `Connection closed by 101.43.4.247 port 22` | BLOCKED |
| 第三方 provider gate | 微信 / SMS / APNs / IAP 真实链路未完成 | BLOCKED |
| 真机 walk-through | 本轮按要求未做真机；下一阶段必须做 | PENDING |

---

## 本轮已修复

| 问题 | 处理 |
|---|---|
| UI tests 后人工打开 App 反复进入欢迎页 | `tearDown` 不再 reset；测试残留清理只清测试内容，不清已完成 onboarding 的账号状态。 |
| 返回用户没有自动化覆盖 | 新增完成 onboarding 后重启、发布后重启两个回归测试。 |
| “添加航班信息 / 添加登机提醒”默认填入样例航班 | 表单默认值改为空；新增 fixture / current flight 不注入表单的回归测试。 |
| 键盘无法收起 | Compose、卡片编辑、航班信息、登机提醒输入均覆盖键盘“完成”或 dismiss 路径。 |
| Compose tab 点不了 | 模板 / 语音 tab 有 stable accessibility id，切换时主动收键盘。 |
| Discovery tab 是静态假按钮 | 同旅程 / 同目的地 / 热点 / 随机均变成真实 Button，并有状态文案断言。 |
| 分享落地页不能返回、没有转发链接 | Landing 增加返回、复制转发链接、看同班机、添加提醒闭环测试。 |
| 设置页行点击无反馈 | 设置行扩大可点区域；反馈 toast 增加 stable accessibility id 和可见文本断言。 |
| 按钮 / 状态没有触感 | 全局按钮 press scale / brightness / glow + haptic；发布成功有 success seal / card entrance。 |
| TEST_PLAN 容易被误读成 Web/PWA 首版路径 | 明确 Stage 1 只按 iOS App 验收；Web 只做官网、协议、分享落地页。 |

---

## 已验证

| 验证项 | 命令 | 实际结果 |
|---|---|---|
| Swift core checks | `swift run --package-path ios HeadInCloudsCoreChecks` | PASS |
| Server unit tests | `npm test --prefix server` | PASS：`89/89` |
| XCUITest build | `xcodebuild build-for-testing -project ios/HeadInClouds.xcodeproj -scheme HeadInClouds -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO` | PASS |
| Full simulator UI regression | `xcodebuild test-without-building -project ios/HeadInClouds.xcodeproj -scheme HeadInClouds -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO -only-testing:HeadInCloudsUITests/HeadInCloudsUITests` | PASS：`15/15` |
| Git whitespace check | `git diff --check -- head_in_clouds` | PASS |
| SSH probe | `ssh -i /Users/zhongwowen.3/.ssh/head-in-clouds-tencent.pem ubuntu@101.43.4.247 'echo ok'` | BLOCKED：`Connection closed by 101.43.4.247 port 22` |

XCUITest result bundle:

```text
/Users/zhongwowen.3/Library/Developer/Xcode/DerivedData/HeadInClouds-dzeowonbkgynhvawnefprvzzbphu/Logs/Test/Test-HeadInClouds-2026.06.01_11-07-57-+0800.xcresult
```

---

## QA 覆盖清单

### 已真实执行通过的 iOS UI cases

| Case | 状态 |
|---|---|
| 首次进入 00a-00d，到 opening | PASS |
| 私人明信片发布、复制链接、landing 返回闭环 | PASS |
| 验证航班并发布到同班机 fixture 路径 | PASS |
| 真实模式下票证按钮不创建假航班 | PASS |
| Card Studio 按钮有可见反馈 | PASS |
| Compose 键盘完成、模板 tab、语音 tab | PASS |
| Discovery 四个 tab 切换 | PASS |
| 设置页关键 row 可点击、有反馈、可返回 | PASS |
| 添加航班信息默认空、可输入、可收键盘 | PASS |
| 登机提醒默认空、可输入、可收键盘 | PASS |
| legacy fixture flight 清理后不污染表单 | PASS |
| existing current flight 不注入新表单 | PASS |
| onboarding 完成后重启不回欢迎页 | PASS |
| 发布后重启不回欢迎页，飞行册计数保留 | PASS |
| UI test fixture residue 在人工模式被清理 | PASS |

### PM / UI 静态走查结论

| 面 | 当前结论 | 剩余风险 |
|---|---|---|
| 首次进入 | 00a-00d 存在；不是从 returning screen 开始；Guest 持久化已测。 | 真机权限弹窗节奏仍需下一阶段验证。 |
| 写作 | 一句话为最小发布单元；ghost text 已存在；无 200 字门槛；语音入口已接 iOS Speech + 麦克风权限，不再是模拟转写。 | 语音识别准确率和权限弹窗节奏仍需真机验证。 |
| 航班信息 | 写作不强制先填航班；发布同班机才要求验证；相机扫描、票证截图、行程截图均接入 Vision OCR 路径。 | OCR 准确率仍需真机 + 真实票证样本验证。 |
| 分享闭环 | Landing 不是下载墙；有复制转发链接、同班机、提醒入口。 | 公网链接、Universal Link、微信分享卡片需备案和微信能力。 |
| 发现页 | tabs 不再是静态；空态文案明确不冒充真实 UGC。 | 没有真实内容前，内容消费体验无法验收。 |
| 设置 / 安全 | 关键 row 有反馈；举报/屏蔽/隐藏入口已有反馈。 | 后台审核和管理台 evidence 未完成。 |
| 动效 / 情绪 | 按钮触感、toast、发布成功反馈已加。 | 真机视觉仍需判断是否过重或廉价。 |

---

## 当前未完成

| 项 | 影响 | 下一步 |
|---|---|---|
| 远端 SSH / deploy gate | 无法验证生产配置、release preflight、备份、远端 smoke | 修复腾讯云 SSH：安全组、sshd、实例登录用户或密钥。 |
| 备案 / 域名 | `headinclouds.cn` 仍不能作为稳定公网能力验收 | 备案通过后复测官网、API、分享 landing、AASA。 |
| 微信开放平台 | 微信登录 / 分享不能通过生产验收 | 审核通过后配置 AppID、Universal Link、URL Scheme、iOS bundle。 |
| SMS | 手机号登录不能真实验收 | 配置腾讯云短信签名、模板、SecretId/SecretKey，并跑真码。 |
| APNs | 登机提醒 / 同班机新笔记远程通知不能验收 | 真机 token 注册 + 服务端 APNs 投递 evidence。 |
| IAP | Postcard Plus 不能验收为真实购买 | StoreKit sandbox purchase + App Store Server Notification evidence。 |
| 真机 full walkthrough | 键盘遮挡、权限弹窗、分享 sheet、动效手感必须真机确认 | 下一阶段按 TEST_PLAN P0/P1 全量真机走查。 |

---

## PMO 结论

本轮本地开发/QA 能达到的最高状态已经收敛到：core PASS、server PASS、XCUITest build PASS、iOS simulator UI regression `15/15 PASS`。  

下一阶段不是继续修 simulator 暴露的问题，而是外部 gate 和真机 gate：先修远端 SSH，再等备案 / 微信审核，同时接 SMS、APNs、IAP；这些不闭环前，不能对外说“可上线”。
