# Claude Design Round 1: Head in the Clouds / 云上心事

> 用途：只给 Claude Design 第一轮视觉探索使用。  
> 不要同时上传 PRD、OPPORTUNITY、旧 DESIGN_BRIEF 或其他上下文文件。  
> 本轮目标不是做完整 App，而是判断核心情绪体验是否成立。

## 1. 本轮唯一目标

Design only the first emotional loop:

```text
Opening -> Write / Compose -> Card Reveal
```

如果这 3 张屏不能让人想继续使用，后面的 feed、评论、同旅程、热点都不需要设计。

## 2. 产品本质

Head in the Clouds / 云上心事是一款给真实飞行乘客的情绪型 micro app。

它不是航班追踪工具，不是旅行攻略，不是普通日记，也不是泛社交社区。

用户真实坐上一次航班后，把这趟飞行变成一张有仪式感、愿意分享的云上心事卡。

核心感觉：

```text
我真的在这趟飞行里，留下了一件只属于此刻的东西。
```

## 3. 不可违背的约束

1. 用户第一动作是拍/上传登机牌、电子机票或航班截图。
2. 但公开内容不是票证，公开内容是一张系统生成的 Cloud Card。
3. 不要把产品设计成航班号输入表单。
4. 不要让登机牌成为主视觉；它只是证明，不是情绪输出。
5. 不要设计 feed、评论、profile、tab、举报、地图、航班状态、延误、登机口、行李转盘。
6. 不要做通用旅行 App UI。
7. 不要做 dashboard 信息密度。
8. 不要做紫色 AI SaaS 风。

## 4. 需要输出的内容

Generate 3 radically different visual directions.

每个方向只做同样 3 个 iPhone mobile screens，尺寸按 390 x 844：

1. Opening
2. Write / Compose
3. Card Reveal

不要合并成一个方向，也不要直接展开完整产品。

## 5. 三个视觉方向

### Direction A: Cloud Letter / 云端来信

关键词：

- 私密信件
- 云层上的短笺
- 柔软纸张
- 淡金色舷窗光
- 中文正文像手写日记
- 整体安静、克制、温柔

避免：

- 可爱贴纸风
- 普通笔记 App
- 过度复古信纸

### Direction B: Cabin Cinema / 机舱电影

关键词：

- 夜间机舱
- 舷窗光
- 电影片名感
- 暗蓝灰 + 暖金
- 强对比但不科技
- 像电影开场前的一张静帧

避免：

- 黑色科技风
- Flighty 式航班工具感
- 大量数据组件

### Direction C: Ticket Poem / 票根诗集

关键词：

- 票根
- 邮戳
- 胶片边框
- 旅行纪念物
- 纸质触感
- 像把一次飞行压进一页诗集

避免：

- 直接复制登机牌
- 航空公司官网风
- 复杂票务字段

## 6. 三个屏幕的具体要求

### Screen 1: Opening

目的：让用户 3 秒内知道这是一个飞行里的情绪仪式，不是航班工具。

必须包含：

- 品牌名：`Head in the Clouds`
- 中文名：`云上心事`
- 主文案：`拍下这趟飞行，留下只属于云上的心事`
- 一张很强的 Cloud Card 示例，作为首屏主视觉
- 主按钮：`拍下这趟飞行`
- 隐私短句：`票证原图默认不保存`

禁止：

- 航班号输入框
- 地图
- 航班状态
- feed
- 大面积功能介绍

### Screen 2: Write / Compose

目的：让用户愿意写下 30-300 字，而不是面对一个普通文本框。

假设用户已经完成票证拍摄和航班解锁，不需要设计拍照页。

必须包含：

- 小型飞行证明条：`MU5405 · 上海 SHA -> 成都 CTU · 14A`
- 标题：`此刻，你想把什么留在云上？`
- 心境选择：`奔赴`、`告别`、`重逢`、`逃离`、`独行`
- Prompt chips：
  - `我为什么出发`
  - `我正在离开什么`
  - `我想抵达什么`
- 30-300 字正文输入区
- 随行照片入口：`添加此刻的照片 0/3`
- 提醒：`不要上传登机牌原图`
- CTA：`生成我的云上心事`

写作区不能像后台表单，要像正在写一封只属于这趟飞行的信。

### Screen 3: Card Reveal

目的：让用户看到生成结果后想保存、分享、发布。

必须包含：

- 一张大尺寸 Cloud Card，必须是主视觉，占屏幕视觉重量 55%-70%
- Cloud Card 内包含：
  - 航线：`上海 SHA -> 成都 CTU`
  - 航班：`MU5405`
  - 心境：`奔赴`
  - 正文节选：`我在起飞前最后一次看见这座城市的灯。它们像没有说出口的话，一点点退到云层下面。`
  - 低调品牌水印：`head in the clouds`
- 操作：
  - `保存图片`
  - `分享`
  - `发布到本航班`

验收标准：

```text
如果这张 Cloud Card 不值得发到朋友圈 / 小红书，这一轮设计失败。
```

## 7. 内容样例

航班：

```text
MU5405
上海 SHA -> 成都 CTU
2026-05-15
14A · 靠窗
```

正文：

```text
我在起飞前最后一次看见这座城市的灯。
它们像没有说出口的话，一点点退到云层下面。
```

心境：

```text
奔赴
```

## 8. Claude Design 指令

Use the attached requirements as strict constraints.

Start from a blank canvas. Ignore all previous attempts.

Generate 3 radically different visual directions:

1. Cloud Letter
2. Cabin Cinema
3. Ticket Poem

For each direction, design only these 3 mobile screens:

1. Opening
2. Write / Compose
3. Card Reveal

Do not design any feed, comments, profile, tabs, map, flight status, flight delay, boarding gate, report flow, or social network page.

The design fails if it looks like a generic travel app, flight tracker, note-taking app, or SaaS dashboard.

The design succeeds only if the generated Cloud Card feels emotionally desirable and share-worthy.
