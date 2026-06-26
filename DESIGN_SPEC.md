# Design Spec: Head in the Clouds / 云上心事

## Status

- Stage: design
- Status: rejected as locked-for-dev visual design
- Date: 2026-06-26
- Scope: source-aligned post-onboarding app shell IA only

This file keeps the IA decision but does not authorize development. The current PNG contact sheet is a draft-level structure/visual exploration and fails the PMO locked-for-dev visual quality gate. Dev must wait for a source-aligned high-fidelity Figma/export review.

The previous `Opening-only / no bottom navigation` draft over-corrected the problem by removing global navigation. The correct IA remains a refined 4-entry app shell, not a generic 5-tab utility bar and not a single landing page.

## Source Of Truth

- Figma Make: https://www.figma.com/make/AtPRtpoJCOkAhhDBkIuKak/%E4%BA%91%E4%B8%8A%E5%BF%83%E4%BA%8B%E8%AE%BE%E8%AE%A1
- `PRD.md` v2.4
- `DESIGN_BRIEF.md`
- `FIGMA_MAKE_BRIEF.md`
- `FIGMA_MAKE_PROMPT.md`
- IA decision: `design/source-aligned-app-shell-ia-2026-06-26.md`
- Rejected prior draft: `design/source-aligned-delta-brief-2026-06-26.md`

## Product IA Decision

Post-onboarding must have a global app shell.

Use 4 shell entries:

```text
今天        飞行册        写        发现
Today       Archive       Write     Discover
```

Rules:

- `写` is the center primary action, not an equal utility tab.
- `今天` is the default stateful home after onboarding.
- `飞行册` is the user's card archive.
- `发现` is public / same-route / destination discovery.
- Settings stays top-right.
- Add flight and reminder stay contextual inside `今天`, not tabs.

## IA Drafts Not Approved For Dev

- `design/source-aligned-shell-today-2026-06-26.png`
- `design/source-aligned-shell-flightbook-2026-06-26.png`
- `design/source-aligned-shell-compose-2026-06-26.png`
- `design/source-aligned-shell-discover-2026-06-26.png`
- `design/source-aligned-shell-contact-sheet-2026-06-26.png`

These PNGs may be used to explain the IA only. They must not be used as the final visual target for SwiftUI implementation.

## Required Next Design Pass

Before dev resumes, design must produce a locked-for-dev high-fidelity source:

- Use the original Figma Make visual language as source of truth.
- Keep the 4-entry IA: `今天`, `飞行册`, center `写`, `发现`.
- Redesign the bottom shell, card modules, typography scale, spacing, icon treatment, and active states so the product feels refined, not like a menu or draft.
- Export a new contact sheet plus individual 390x844 screens.
- Remove `Draft` from the review artifact only after PM, PMO, and founder review pass.

## Screen: Today

Purpose: let the user understand what matters now and start writing quickly.

State priority:

1. Unsaved draft recovery.
2. Latest real Cloud Card / memory.
3. Next flight reminder.
4. No-content sample card.

Required elements:

- Brand header and settings icon.
- Latest card / draft / empty-state module.
- Primary path to write via shell center action.
- Contextual actions:
  - Add flight.
  - Set reminder.
- A quiet route to discovery when appropriate.

Do not:

- Show the same static sample card every time after the user has content.
- Stack four full-width same-weight action buttons.

## Screen: Flight Book

Purpose: let the user revisit their own Cloud Cards without going through Home buttons.

Required elements:

- Title: `我的飞行册`.
- Count and sync / guest status.
- 2-column card grid or compact vertical card list.
- Latest card first.
- Bottom shell with `飞行册` active.

Do not:

- Hide this behind Settings.
- Make the user back out from Compose/Home to reach it.

## Screen: Write / Compose

Purpose: make writing feel focused and ceremonial.

Behavior:

- Tapping shell `写` opens 06 Compose.
- Compose may hide the bottom shell while active.
- Back / cancel returns to `今天`.
- Saved draft appears in `今天`.

Required elements:

- Title: `这次飞行，我只想说：`
- One-line-first input.
- Flight status chip.
- Draft / offline save state.
- Primary CTA: `生成私人明信片`.

## Screen: Discover

Purpose: allow browsing without competing with writing.

Required elements:

- Title: `别人留下的`.
- Segments such as `同航线` / `目的地` / `此刻`.
- Public card feed.
- Clear read-only boundary for non-same-flight content.
- Bottom shell with `发现` active.

Do not:

- Add comment composer for discovery-only content.
- Make discovery visually louder than writing.

## Bottom Shell Visual Rules

The shell must feel designed for 云上心事:

- Deep translucent rail, not default system tab bar.
- Gold center `写` action.
- Quiet labels for `今天`, `飞行册`, `发现`.
- No fifth tab.
- No large WeChat green or utility-dashboard styling.

## P0 Acceptance Rules

- A user can move between `今天`, `飞行册`, `写`, and `发现` without unwinding a back stack.
- Returning users do not see the same large static sample card as their main content.
- `写` remains the highest-weight action.
- Add flight and reminder are contextual actions, not tabs.
- Settings remains top-right.
- The draft preserves the original Figma / v2.4 visual language.

## Implementation Notes For Dev

- Current SwiftUI entry point: `ios/App/Views/WelcomeView.swift`, `OpeningView`.
- Dev should implement a post-onboarding shell instead of a single Opening-only screen.
- The shell controls navigation among Today, Flight Book, Compose entry, and Discover.
- Compose / Card Studio / Publish can be immersive and hide the shell while active.
- Use PNG drafts as layout references, not raster assets.

## PM / PMO Internal Review

PM review: IA passed; visual not passed.

- The IA is now stable: emotional app shell, not landing page and not utility tab bar.
- It addresses the back-stack navigation problem.
- It keeps writing as the product's center of gravity.
- It still needs high-fidelity visual treatment before dev.

PMO review: failed visual quality gate.

- This corrects the previous over-removal of global navigation.
- The current contact sheet is not good enough to implement.
- The artifact must go back to design/Figma before test-plan/dev resumes.

Founder review: visual concern raised; design is blocked.
