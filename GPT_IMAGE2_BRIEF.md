# GPT Image 2 Brief — Head in the Clouds Cloud Card v2.3.1

> 用途：给 GPT Image 2 / 图像生成工具生成 Cloud Card 视觉参考。  
> 重点：只生成分享卡片视觉，不生成 App UI。  
> 配套产品文档：[PRD.md](PRD.md) v2.3.1；设计文档：[DESIGN_BRIEF.md](DESIGN_BRIEF.md)。

---

## 0. 当前结论

不需要继续广撒网生成四种大方向。第一轮结果已经证明：**复古明信片 / 票根信纸方向最强**，应该作为默认 Cloud Card 视觉。

如果还要用 GPT Image 2，只建议再生成一轮 **2-3 张复古明信片变体**，用于细化：

- 纸张比例和留白。
- 航班 metadata 的排版。
- 坐标路线的位置。
- 普通 UGC 的承接方式。

不要再生成金色云海、舷窗照片、暗云照片叠字作为默认方向。那些只能作为条件模板。

---

## 1. 生成目标

生成一组 Cloud Card 分享图方向。默认方向是复古明信片 / 票根信纸。卡片本身要像诗、唱片内页、艺术海报或实体收藏卡，不像手机 App 截图。

用户愿意分享它的原因应该是：

```text
这张图本身值得被看到。
```

而不是：

```text
帮 App 做推广。
```

---

## 2. 固定内容

### 主 quote

```text
我把没有说出口的话，带过了云层。
```

### 航班 metadata

```text
MU5301 · SHA → CTU · 2026.05.19 · 奔赴
```

### 路线 / 坐标

```text
SHA 31.2304°N → CTU 30.5728°N
```

### 品牌露出

```text
Head in the Clouds
云上心事
```

品牌只能极小，放在左下角或底边，不要喧宾夺主。

---

## 3. 通用约束

- 竖版分享图，建议 1080 × 1440 或 1080 × 1920。
- 不要手机 mockup。
- 不要 App UI 截图。
- 不要按钮。
- 不要“立即下载”。
- 不要 App Store badge。
- 不要大二维码；如需要入口，只能做极小、低调、像藏在票根里的识别标记。
- 不要真实登机牌、姓名、座位号、票号、条形码。
- 不要航班 dashboard、地图导航、延误信息。
- 不要卡通、二次元、可爱贴纸风。
- 不要紫色 AI SaaS 渐变。

---

## 4. Prompt A：Route Poem / 极简路线诗

```text
Create a vertical poetic share card for a flight memory app called "Head in the Clouds / 云上心事".

The card should look like a minimalist poetry poster and collectible art print, not a mobile app screenshot.

Visual direction:
- deep dawn blue-gray background with subtle paper grain
- a thin minimal flight route line from SHA to CTU, with tiny coordinate marks
- large elegant Chinese quote as the main visual focus:
  "我把没有说出口的话，带过了云层。"
- small metadata:
  "MU5301 · SHA → CTU · 2026.05.19 · 奔赴"
- tiny brand mark in the bottom-left:
  "Head in the Clouds / 云上心事"
- very small hidden recognition mark in the bottom-right, subtle like a stamp, not a big QR code

Typography:
- Chinese serif type, restrained and emotional
- flight metadata in small monospaced type
- lots of negative space

Mood:
quiet, private, cinematic, like something shared on WeChat Moments because it is beautiful.

Do not include:
phone mockup, app UI, buttons, "download now", App Store badge, boarding pass, passenger name, seat number, barcode, airline dashboard, map UI, cartoon style, purple SaaS gradient.
```

---

## 4A. Prompt A2：Default Boarding Postcard / 默认复古明信片

优先用这个 prompt 再跑 2-3 张变体。

```text
Create a vertical share card for "Head in the Clouds / 云上心事", using a vintage boarding postcard and ticket-stub visual direction.

This is the default Cloud Card template. It must work not only for poetic writing, but also for ordinary real UGC such as "飞机晚点了，累死。"

Composition:
- deep navy outer background
- a warm off-white paper ticket/postcard centered on the card
- subtle paper grain, worn edges, small perforation marks
- top-left small metadata:
  "MU5301"
  "SHA → CTU"
  "2026.05.19 · 奔赴"
- top-right subtle postal stamp with tiny brand text:
  "Head in the Clouds / 云上心事"
- center large Chinese quote:
  "我把没有说出口的话，带过了云层。"
- lower section thin coordinate route line:
  "SHA 31.2304°N → CTU 30.5728°N"
- bottom-left tiny app icon / brand:
  "Head in the Clouds / 云上心事"
- bottom-right very small hidden recognition mark, subtle like an ink stamp, not a large QR code

Style:
restrained, premium, poetic but not sentimental, collectible, like a beautiful postcard someone would share in WeChat Moments.

Important:
Do not use a full-bleed airplane window photo.
Do not use golden cloud photo background.
Do not make it a phone screenshot.
Do not include "download", "立即下载", App Store badge, CTA button, passenger name, seat number, barcode, or real boarding pass data.
Do not use WeChat green as a main color.
```

---

## 4B. Prompt A3：Ordinary UGC Stress Test / 普通内容压力测试

用这个 prompt 验证卡片能否承接低诗意文本。

```text
Create a vertical vintage boarding postcard Cloud Card for "Head in the Clouds / 云上心事".

This version is a stress test for ordinary, non-poetic UGC. The quote is:
"飞机晚点了，累死。"

The card should still look tasteful and shareable, like a restrained flight note on a ticket stub, not like a failed poetry poster.

Composition:
- deep navy outer background
- centered warm off-white ticket/postcard paper
- small metadata:
  "MU5301 · SHA → CTU · 2026.05.19 · 烦躁"
- simple coordinate route line:
  "SHA 31.2304°N → CTU 30.5728°N"
- large quote:
  "飞机晚点了，累死。"
- tiny brand:
  "Head in the Clouds / 云上心事"

Mood:
dry, deadpan, private, understated, like a note someone wrote during a delayed flight.

Avoid:
romantic sunset clouds, airplane window photos, emotional golden light, app UI, phone mockup, CTA buttons, App Store badge, big QR code, boarding pass private data.
```

---

## 5. Prompt B：Cloud Window / 舷窗云层

```text
Create a vertical artistic Cloud Card for "Head in the Clouds / 云上心事", a flight memory app.

The image should feel like looking out of an airplane window at dawn, but it must remain an abstract share card, not a realistic photo and not an app screenshot.

Elements:
- soft cloud texture and cabin-window light, deep blue-gray and warm pale gold
- subtle curved window shape suggested in the background
- thin route line "SHA → CTU" crossing the card like a quiet coordinate path
- large Chinese quote:
  "我把没有说出口的话，带过了云层。"
- small metadata:
  "MU5301 · SHA → CTU · 2026.05.19 · 奔赴"
- tiny bottom-left brand:
  "Head in the Clouds / 云上心事"

The composition should feel premium, emotional, restrained, and poetic. It should be something a user would share in WeChat Moments without feeling like an ad.

Negative constraints:
no mobile app UI, no CTA button, no App Store badge, no large QR code, no boarding pass, no passenger information, no travel planner dashboard, no anime, no cartoon stickers, no neon purple gradient.
```

---

## 6. Prompt C：Boarding Stub / 票根邮戳

```text
Create a vertical shareable art card inspired by a vintage boarding stub and postal stamp, for "Head in the Clouds / 云上心事".

Important:
It should not look like a real boarding pass. It must not contain passenger name, seat number, ticket number, barcode, or airline private information.

Visual direction:
- textured off-white paper on a deep dawn background
- subtle perforation marks, postal stamp feel, and route coordinates
- thin route diagram:
  "SHA 31.2304°N → CTU 30.5728°N"
- large elegant quote:
  "我把没有说出口的话，带过了云层。"
- small flight metadata:
  "MU5301 · SHA → CTU · 2026.05.19 · 奔赴"
- tiny app icon / brand mark in bottom-left:
  "Head in the Clouds / 云上心事"
- optional tiny hidden recognition glyph in bottom-right, like a stamp, not an obvious QR code

Mood:
private travel memory, poetic, collectible, not commercial.

Do not include:
real boarding pass layout, airline logo, barcode, QR code as main element, phone mockup, app screenshot, buttons, "download", App Store badge, map dashboard, cartoon style.
```

---

## 7. Prompt D：WeChat Moments Safe / 朋友圈安全版

```text
Design a vertical WeChat Moments share image for "Head in the Clouds / 云上心事".

It should look like a tasteful poem poster that someone would post because it expresses a flight memory, not because it advertises an app.

Composition:
- 9:16 vertical format
- large Chinese quote centered slightly above middle:
  "我把没有说出口的话，带过了云层。"
- a quiet route line below it:
  "SHA → CTU"
- small metadata:
  "MU5301 · 2026.05.19 · 奔赴"
- tiny bottom-left brand:
  "Head in the Clouds / 云上心事"
- bottom-right very subtle recognition mark, almost like a printed stamp

Style:
deep blue-gray dawn sky, faint clouds, fine grain, elegant serif typography, restrained cinematic mood, no obvious ad elements.

Strictly avoid:
phone UI, app screenshot, buttons, "立即下载", "download now", App Store badge, large QR code, boarding pass, passenger data, airline dashboard, cute cartoon, purple tech gradient.
```

---

## 8. 评估标准

生成后只保留满足以下标准的图：

- 单独看像艺术卡片，不像产品宣传图。
- Quote 是第一视觉焦点。
- 路线 / 坐标存在，但不抢主角。
- 品牌存在感低。
- 没有下载 CTA。
- 发朋友圈不尴尬。
- 能作为 Figma Make 的 Cloud Card 组件视觉参考。

---

## 9. 给 Figma Make 的使用方式

把选中的 GPT Image 2 结果作为视觉参考，不要直接当完整 UI。

在 Figma Make 里补充说明：

```text
Use the attached Cloud Card image only as visual direction for the 07 Card Studio and 08 Publish share image. Recreate it as editable design components in Figma. Do not place it as a flat bitmap unless used as a temporary reference.
```
