# Design Spec: Head in the Clouds / 云上心事

## Status

- Stage: design
- Status: completed
- Date: 2026-06-27
- Scope: post-onboarding main-flow UI source
- Approved direction: C / Cabin Ritual
- Founder review: passed on 2026-06-27

This spec replaces the rejected 2026-06-26 shell drafts. The approved source is the Cabin Ritual six-screen package:

- Contact sheet: `design/cabin-ritual-main-flow-2026-06-26/contact-sheet.svg.png`
- Source SVG: `design/cabin-ritual-main-flow-2026-06-26/contact-sheet.svg`
- Today: `design/cabin-ritual-main-flow-2026-06-26/01-today-returning.png`
- Write / Compose: `design/cabin-ritual-main-flow-2026-06-26/02-write-compose.png`
- Card Studio: `design/cabin-ritual-main-flow-2026-06-26/03-card-studio.png`
- Save / Share: `design/cabin-ritual-main-flow-2026-06-26/04-save-share.png`
- Flight Book: `design/cabin-ritual-main-flow-2026-06-26/05-flight-book.png`
- Discover: `design/cabin-ritual-main-flow-2026-06-26/06-discover.png`
- Review package: `design/cabin-ritual-main-flow-2026-06-26.md`

## Source Of Truth

- PRD: `PRD.md` v2.4
- Design brief: `DESIGN_BRIEF.md`
- Approved visual source: `design/cabin-ritual-main-flow-2026-06-26/`
- Rejected evidence only:
  - `design/source-aligned-*`
  - `design/high-fidelity-shell-*`
  - `design/rejected-2026-06-26-new-visual-exploration.md`

Do not use rejected images as implementation targets.

## Product IA

Post-onboarding uses a refined four-entry app shell:

```text
今天        飞行册        写        发现
Today       Flight Book   Write     Discover
```

Rules:

- `写` is the center primary action, not an equal utility tab.
- `今天` is the default returning state.
- `飞行册` is the user's private keepsake archive.
- `发现` is public / same-route / destination reading.
- Settings/account stays top-right.
- Add flight and boarding reminder are contextual actions, not tabs.
- Compose / Card Studio / Save Share may hide the bottom shell while active.

## Screen Specs

### 01 Today Returning

Source: `01-today-returning.png`

Purpose: let a returning user start writing without seeing the same static sample card every time.

Must include:

- Brand header: `云上心事 / Head in the Clouds`.
- Settings/account entry in the top-right.
- Main headline: `今天这趟，先留一句话。`
- Warm paper note module with one-sentence prompt.
- Primary CTA: `写下这一句`.
- Contextual secondary actions:
  - `添加航班号`
  - `登机前提醒`
- Bottom shell with `今天` active and center `写`.

Do not:

- Stack four full-width feature buttons.
- Make scan/add-flight the first task.
- Reuse the old large static sample card as the returning user's main content.

### 02 Write / Compose

Source: `02-write-compose.png`

Purpose: make one-sentence writing immediate and ceremonial.

Must include:

- Back/cancel affordance.
- Title: `写这一趟`.
- Draft status: `已保存`.
- Prompt: `这次飞行，我只想说：`
- Large warm paper text area.
- Placeholder: `比如：我把没有说出口的话，带过了云层。`
- Flight status chip: `未添加航班 · 稍后补`.
- Offline reassurance: `离线也会保存在本机`.
- Optional inspiration chips.
- Primary CTA: `生成私人明信片`.
- Secondary action: `添加航班，解锁同班机`.

Do not:

- Require flight verification before writing.
- Show a bottom tab bar while the user is composing.
- Treat short text as incomplete.

### 03 Card Studio

Source: `03-card-studio.png`

Purpose: turn the sentence into the emotional payoff.

Must include:

- Title: `云上心事卡`.
- Status: `私人卡 · 未发布`.
- Large Cloud Card hero.
- Default template: `票根明信片`.
- Secondary templates:
  - `航线诗笺`
  - `飞行日志`
- Note: `未验证也可以先保存私人卡`.
- Primary CTA: `保存 / 分享私人卡`.
- Secondary action: `验证航班并发布到同班机`.

Do not:

- Make the card look like a screenshot of the app.
- Add generic editor toolbars.
- Put verification above private-card generation.

### 04 Save / Share

Source: `04-save-share.png`

Purpose: close the private-card loop.

Must include:

- Title: `保存与分享`.
- Subtitle: `私人卡不会进入同班机`.
- Cloud Card preview.
- Primary actions:
  - `保存到相册`
  - `发给微信朋友`
  - `分享到朋友圈`
- Secondary section:
  - `想让同班机的人看到？`
  - `验证航班后，同班机的人才能看到和留言。`
  - CTA: `验证航班并发布`
- Privacy note: `不会公开登机牌原图和具体座位号`.
- Completion action: `完成`.

Do not:

- Use App Store download CTA.
- Use WeChat green as global brand color.
- Treat same-flight publishing as equal to private share before verification.

### 05 Flight Book

Source: `05-flight-book.png`

Purpose: give returning users a private keepsake archive.

Must include:

- Title: `我的飞行册`.
- Count/status copy, for example `已留下 7 趟飞行`.
- Short emotional subcopy.
- Card grid or refined vertical card stack.
- Each card shows:
  - quote
  - route/date or confirmation state
  - status tag such as `私人卡` / `同班机`
- Optional sync state such as `落地后已同步`.
- Bottom shell with `飞行册` active.

Do not:

- Hide the archive behind Settings.
- Use a generic table/list.
- Make users back out through Today or Compose to reach their cards.

### 06 Discover

Source: `06-discover.png`

Purpose: support quiet reading without turning the product into a social feed.

Must include:

- Title: `别人留下的`.
- Subtitle: `同一段云层里，有人也写下了心事。`
- Segments:
  - `同航线`
  - `目的地`
  - `此刻`
- 3+ note/card rows.
- Anonymous identity only:
  - `靠窗的人`
  - `同机乘客`
  - `通道旁的人`
- Boundary copy: `未验证同班机时，只能阅读，不能留言。`
- CTA: `添加航班，解锁同班机留言`.
- Bottom shell with `发现` active.

Do not:

- Show exact seat numbers.
- Add comment composer in discovery-only state.
- Add like counts or social-noise affordances.

## Visual Rules

- Base mood: cabin ritual, dawn-blue atmosphere, soft cabin/window light.
- Core surfaces: warm ticket paper and paper-note texture.
- Accent: restrained cabin gold.
- Typography: refined Chinese serif for emotional headlines; compact metadata for flight details.
- Keep controls sparse; no utility dashboard density.
- Use WeChat green only for WeChat-specific share/login affordances.
- Avoid purple SaaS gradients, crude bottom tabs, giant button stacks, and generic card grids.

## Approved Dev Scope

Dev may implement:

- Post-onboarding app shell.
- Today returning state.
- Compose screen.
- Card Studio result screen.
- Save / Share screen.
- Flight Book screen.
- Discover screen.
- Navigation among `今天 / 飞行册 / 写 / 发现`.

Dev must not invent:

- Full Account & Settings screen beyond the top-right entry.
- Flight verification detail flow beyond the CTA entry.
- Report/block screens.
- Shared-card landing page.

If those surfaces are required during implementation, they must use minimal system-safe fallback or return to design for a focused addendum.

## P0 Acceptance Rules

- A user can move among `今天`, `飞行册`, `写`, and `发现` without unwinding a back stack.
- `写` is visually the highest-weight action.
- Writing and private Cloud Card generation are not blocked by flight verification.
- Returning users do not see the same repeated static sample card as the primary home experience.
- Private-card save/share is the primary completion path.
- Same-flight publish/comment remains verification-gated.
- Public surfaces never expose exact seat, name, ticket number, ID/passport, phone, or raw proof content.
- The implemented UI must visually match the approved Cabin Ritual package, not the rejected shell drafts.

## Follow-Up Design Addenda

These are not blockers for the approved post-onboarding main-flow dev scope, but they are blockers before external launch review:

- Account & Settings full screen.
- Flight verification detail flow.
- Report/block flow.
- Shared-card landing page.
- Home returning empty state, if implementation cannot derive it cleanly from Today.

## PM / PMO Internal Review

PM review: passed for the post-onboarding main-flow scope.

- The approved six screens cover the core private-card path.
- The visual direction supports the product's emotional value better than the rejected utility-menu drafts.
- The scope is narrow enough for dev while still closing the main loop.

PMO review: passed for design gate, with follow-up boundaries.

- Founder approved the six visual screens on 2026-06-27.
- Test plan must be refreshed before dev.
- Dev remains blocked until `test-plan` is completed and approved.
