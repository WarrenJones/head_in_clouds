# Source-Aligned App Shell IA

Status: IA approved, visual draft rejected. Use this document as the structural input for the next high-fidelity Figma pass, not as a locked-for-dev visual spec.

## PM Decision

The post-onboarding product must not be a one-screen landing page.

It needs a persistent app shell after onboarding, because users must be able to move between their current flight moment, writing, past cards, and discovery without unwinding a back stack.

The correct decision is:

```text
Use a refined 4-entry bottom shell.
Reject both extremes:
1. No global navigation.
2. A generic 5-tab utility bar.
```

## Product Logic

Head in the Clouds / 云上心事 is an emotional flight-memory app, not a utility dashboard.

The shell must express this hierarchy:

1. `今天` — current state, latest card, draft, next flight, contextual actions.
2. `写` — primary center action, opens Compose as an immersive flow.
3. `飞行册` — user's saved Cloud Cards and flight memories.
4. `发现` — other people's public notes, same route / destination / hot notes.

Settings remains top-right. It is not a tab.

Flight scan and reminder are not tabs. They are contextual actions inside `今天`, and can also appear at relevant moments in publish / reminder setup flows.

## State Model

The app shell starts after onboarding.

```text
Open app after onboarding
├── Has unsaved draft → Today shows draft recovery first
├── Has at least 1 card → Today shows latest real card / memory module
├── Has future flight reminder → Today shows next-flight intent module
└── Has no content → Today shows a light Cloud Card sample and writing prompt
```

The static sample Cloud Card is only appropriate for the no-content first-published state. It must not be the main returning-state content.

## Bottom Shell Rules

Allowed entries:

- `今天`
- `飞行册`
- `写`
- `发现`

Not allowed:

- `添加航班` as a tab.
- `登机提醒` as a tab.
- `设置` as a tab.
- Five equal tabs.
- A generic utility-app tab bar that visually competes with the Cloud Card.

## Compose Behavior

Tapping `写` opens 06 Compose.

Compose is an immersive flow and may hide the bottom shell while writing, card generation, and publish actions are active.

When the user completes, cancels, or backs out:

- Successful private card → return to `今天` or `飞行册`.
- Same-flight publish → enter same-flight space.
- Cancel with draft → return to `今天` with draft recovery visible.

## Design Source Boundary

This is a source-aligned patch.

Keep:

- Dawn / cabin-light dark atmosphere.
- Paper / ticket Cloud Card language.
- Chinese serif + English italic display.
- Gold primary action.
- Warm paper and light card contrast.

Do not:

- Redesign the brand.
- Replace the Figma Make visual language.
- Use a standard iOS tab bar without visual adaptation.
- Make the app look like a flight utility.
