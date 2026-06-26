# Design Spec: Head in the Clouds / 云上心事

## Status

- Stage: design
- Status: PM / PMO internal review passed, founder review pending
- Date: 2026-06-26
- Scope: source-aligned patch for 01a / 01b Opening IA

This spec does not replace the existing Figma Make design system. It patches the post-onboarding Opening hierarchy while preserving the v2.4 visual lock.

## Source Of Truth

- Figma Make: https://www.figma.com/make/AtPRtpoJCOkAhhDBkIuKak/%E4%BA%91%E4%B8%8A%E5%BF%83%E4%BA%8B%E8%AE%BE%E8%AE%A1
- `PRD.md` v2.4
- `DESIGN_BRIEF.md`
- `FIGMA_MAKE_BRIEF.md`
- `FIGMA_MAKE_PROMPT.md`
- Delta brief: `design/source-aligned-delta-brief-2026-06-26.md`

## Visual Drafts

- `design/source-aligned-opening-01a-first-published-2026-06-26.png`
- `design/source-aligned-opening-01b-returning-2026-06-26.png`
- `design/source-aligned-opening-contact-sheet-2026-06-26.png`

## IA Decision

Do not add a bottom tab bar in this patch.

The product remains an Opening-led emotional app:

- Primary recurring action: `写下这一趟`
- Secondary context actions: add flight, reminder, flight book, discovery
- Settings: top-right icon
- Same-flight space: entered from publish, notification, or verified flight context

## 01a Opening · First-Published

Use when the user has completed onboarding but has not published any post.

Required hierarchy:

1. Brand title and short emotional subtitle.
2. Large Cloud Card sample is allowed in this state.
3. Main message: user can write first and add flight later.
4. Primary CTA: `写下这一趟`.
5. Secondary compact actions:
   - `添加航班` with `扫登机牌 / 手输`
   - `登机提醒` with `起飞前 30 分钟`
6. Discovery remains a quiet text link, not a large CTA.
7. Bottom privacy reassurance remains.

Do not:

- Make scan flight the first required step.
- Show four same-weight full-width buttons.
- Add bottom tab navigation.

## 01b Opening · Returning

Use when the user has at least one post.

Required hierarchy:

1. Header: `最近的云上心事`.
2. Show the user's latest real card or draft preview, not the same static sample.
3. Add a compact recall module with quote and metadata.
4. Primary CTA remains `写下这一趟`.
5. Secondary compact actions:
   - `航班`
   - `提醒`
   - `飞行册`
6. Discovery remains a quiet link.
7. Settings remains top-right.

Do not:

- Reuse 01a static sample as the main returning-state content.
- Make `我的飞行册` a same-weight full-width homepage button.
- Put settings in bottom navigation.

## Visual Acceptance Rules

P0 visual regressions:

- App no longer resembles the original Figma Make / v2.4 visual language.
- Bottom tab is introduced without a separate founder decision.
- `写下这一趟` is not the single highest-weight CTA.
- Returning users still see the same large static sample card as the primary content.
- Add flight, reminder, flight book, and discovery appear as four equal large buttons.
- WeChat green appears outside WeChat login.

P1 visual checks:

- Text must not clip on iPhone 390 x 844.
- Compact action cards must not feel like a utility menu.
- The Cloud Card must remain the visual anchor, not a generic app screenshot.
- Dark background must remain atmospheric; card and action surfaces must keep paper / warm-light contrast.

## Implementation Notes For Dev

- Current SwiftUI entry point: `ios/App/Views/WelcomeView.swift`, `OpeningView`.
- Implementation should split first-published and returning visual states.
- Do not implement the rejected bottom IA spec in `context/feature-spec-2026-06-26-post-onboarding-bottom-ia.md`.
- Use the PNG drafts as layout references, not as raster assets inside the app.

## PM / PMO Internal Review

PM review: passed.

- The draft preserves source visual language.
- The primary action is clear.
- It removes equal-weight button stacking.
- It keeps verification after expression.

PMO review: passed.

- This is not a full redesign.
- It does not hand off an ugly bottom-tab draft.
- It can be shown to founder for review before dev continues.

Founder review: pending.
