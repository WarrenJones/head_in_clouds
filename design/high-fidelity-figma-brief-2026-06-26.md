# High-Fidelity Figma Brief: Source-Aligned App Shell

## Status

This is the next design input after the 2026-06-26 IA draft was rejected as a locked-for-dev visual target.

- IA decision: approved.
- Current PNG contact sheet: rejected for implementation quality.
- Dev status: blocked until a new high-fidelity source-aligned design passes PM, PMO, and founder review.

## Source Of Truth

- Original Figma Make design: `https://www.figma.com/make/AtPRtpoJCOkAhhDBkIuKak/%E4%BA%91%E4%B8%8A%E5%BF%83%E4%BA%8B%E8%AE%BE%E8%AE%A1`
- Product mood: refined emotional flight-memory app, not a utility dashboard.
- Visual language to preserve: dawn/cabin-light atmosphere, warm paper Cloud Card, Chinese serif display, English italic brand accent, gold primary action, quiet flight metadata.

## Keep The Approved IA

Post-onboarding uses a 4-entry app shell:

```text
今天        飞行册        写        发现
Today       Flight Book   Write     Discover
```

Rules:

- `写` is the center primary action.
- `今天` is the default post-onboarding state.
- `飞行册` is the user's archive.
- `发现` is browse/read-only discovery.
- Settings remains top-right.
- Add flight and reminder are contextual actions inside `今天`, not tabs.

## Redesign Required

The next design must not copy the rejected contact sheet. It should use the approved IA but raise visual quality to the original product level.

Required improvements:

- Make the shell feel native and premium, not like an engineering tab bar.
- Treat the center `写` action as a crafted product gesture, not just a gold circle.
- Reduce menu feeling on `今天`; create one emotionally dominant state module plus quiet contextual actions.
- Use stronger typographic hierarchy and spacing polish.
- Make card previews feel tactile and collectible.
- Keep the deep atmosphere, but avoid screens becoming flat dark panels.
- Ensure the design can be shown to real users without apology.

## Screens Required

Export each screen at iPhone 390x844 or equivalent:

1. `Today` with no content / first meaningful state.
2. `Today` returning with latest card or draft.
3. `Flight Book` with card archive.
4. `Write / Compose` immersive writing state.
5. `Discover` with public notes.
6. Optional settings entry treatment if the top-right icon opens a sheet.

Also export one contact sheet containing all screens.

## Review Gate

Do not mark design completed unless all checks pass:

- PM confirms IA and product hierarchy.
- PMO confirms it does not look like a draft, menu, or utility app.
- Founder sees the actual contact sheet in chat and approves it as locked for dev.
- `.design.manifest.json.status` remains `rejected` until that approval happens.

