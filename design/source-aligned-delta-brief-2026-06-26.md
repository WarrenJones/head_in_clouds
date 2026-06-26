# Source-Aligned Delta Brief: Opening IA Patch

## PM / PMO Decision

We are not replacing the original Figma Make design.

The existing design language remains the source of truth:

- Dawn / cabin-light atmosphere.
- Deep blue-gray, cloud white, window gold, paper cream.
- Chinese serif + English italic display + monospaced flight metadata.
- Cloud Card as a physical-feeling postcard / ticket-stub artifact.
- Dark atmosphere only as a layer; core reading and writing surfaces stay warm paper / light card based.

This delta brief only patches homepage IA and hierarchy problems that appeared after real-device review.

## Problem To Fix

The current post-onboarding home state has three product problems:

1. The same large sample card appears every time, which causes repeat-visit fatigue.
2. Too many same-weight actions are stacked on the home screen, making the product feel like a menu instead of a refined emotional product.
3. Secondary flows such as flight scan, reminder, flight book, and discovery are competing with the primary writing action.

## Non-Goals

- Do not create a new visual system.
- Do not introduce a generic 5-tab bottom navigation.
- Do not turn the app into a utility dashboard.
- Do not make scanning or flight verification the first required step.
- Do not use WeChat green outside WeChat login.

## Required Patch: 01a Opening First-Published

Keep the original first-published structure:

- Brand title and poetic subtitle.
- Large Cloud Card sample.
- Primary CTA: `写下这一趟`.
- Secondary entries: flight info, reminder, discovery.

Patch the hierarchy:

- The sample Cloud Card may remain large on the first meaningful home view.
- `写下这一趟` must be visually dominant and singular.
- `添加航班号 / 扫登机牌` and `添加登机提醒` are contextual secondary actions, not equal primary buttons.
- `看看别人留下的` is a quiet exploration link or compact row, not a large competing CTA.
- The page must make clear: `航班信息可以稍后补`.

## Required Patch: 01b Opening Returning

Returning users should not see the same static sample card as the main content.

Required structure:

1. Latest real Cloud Card or draft preview.
2. A short emotional recall line tied to that latest card.
3. Primary CTA: `写下这一趟`.
4. Compact secondary actions:
   - `添加航班`
   - `登机提醒`
   - `飞行册`
5. Settings remains a small top-right icon.

If the user has no real card yet, 01b falls back to 01a logic.

## Navigation Decision

Do not add a 5-tab bottom nav in this patch.

Reason:

- The PRD defines an opening-led product, not a utility app with five equally frequent top-level modules.
- `写作` is the primary recurring behavior.
- `航班验证` is a gate and context enhancer, not a permanent primary destination.
- `提醒` is an intent setup flow, not a daily tab.
- `飞行册` and `发现` are valid destinations, but they should not outrank writing on the emotional home screen.

Allowed navigation model for this patch:

- Opening / Home remains the emotional hub.
- Primary creation is a dominant CTA.
- Flight Book and Discovery are secondary destinations.
- Settings is top-right.
- Same-flight space is entered from publish, notification, or a verified flight context.

## Design Review Gate

Do not write `DESIGN_SPEC.md` until PM and PMO can both answer yes:

- Does this still look like the original 云上心事 design?
- Does it preserve the Cloud Card visual language?
- Does it reduce repeat-visit fatigue without killing the product mood?
- Does it avoid a same-weight button stack?
- Would this be acceptable to show to a real user as a refined emotional product?

Current status: pending source-aligned visual draft.
