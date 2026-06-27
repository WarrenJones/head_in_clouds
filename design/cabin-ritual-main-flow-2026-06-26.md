# Cabin Ritual Main Flow Visual Draft

## Status

- Project: `head_in_clouds`
- Date: 2026-06-26
- Stage: design
- Status: founder-approved visual source
- Decision boundary: locked for post-onboarding main-flow dev, with explicit exclusions below
- Selected direction: C / Cabin Ritual

This package expands the selected Cabin Ritual direction into the smallest screen set that can test whether the product can close its main loop.

Founder review on 2026-06-27: passed. The six-screen direction is approved as the visual target for the post-onboarding main flow.

## Why This Is More Than A Home Page Patch

Only redesigning the home page would improve first impression but would not close the product loop. The minimum useful design target must cover:

1. A returning user can start from Today without seeing the same repeated sample card.
2. The user can write one sentence without flight verification.
3. The user can turn that sentence into a private Cloud Card.
4. The user can save or share the private card, then optionally verify the flight for same-flight publishing.
5. The user can come back to Flight Book and browse Discover without unwinding a back stack.

## Artifacts

- Contact sheet: `design/cabin-ritual-main-flow-2026-06-26/contact-sheet.svg`
- Screen 01: `design/cabin-ritual-main-flow-2026-06-26/01-today-returning.png`
- Screen 02: `design/cabin-ritual-main-flow-2026-06-26/02-write-compose.png`
- Screen 03: `design/cabin-ritual-main-flow-2026-06-26/03-card-studio.png`
- Screen 04: `design/cabin-ritual-main-flow-2026-06-26/04-save-share.png`
- Screen 05: `design/cabin-ritual-main-flow-2026-06-26/05-flight-book.png`
- Screen 06: `design/cabin-ritual-main-flow-2026-06-26/06-discover.png`

## Screen Coverage

### 01 Today Returning

Purpose: make the returning state feel current, personal, and writable.

Must preserve:
- Settings stays top-right.
- `写` remains the highest-weight action.
- Add flight and reminder are contextual, not full-width peers.
- The old repeated static sample-card fatigue is removed.

### 02 Write Compose

Purpose: let the user write one sentence before any proof.

Must preserve:
- One-sentence-first prompt.
- Draft/offline reassurance.
- Flight status is a chip, not the primary task.
- No bottom shell while composing.

### 03 Card Studio

Purpose: make the Cloud Card the emotional payoff.

Must preserve:
- Private card can be generated before verification.
- Ticket/postcard card style remains the default.
- Template controls are secondary to the card.

### 04 Save / Share

Purpose: close the private-card loop.

Must preserve:
- Save/share is the primary path.
- Same-flight publishing is a secondary path gated by verification.
- Privacy copy states that raw boarding pass and exact seat are not public.

### 05 Flight Book

Purpose: support return use and personal memory archive.

Must preserve:
- User can revisit previous cards.
- The screen feels like a keepsake archive, not a utility list.
- Bottom shell lets the user move without back-stack unwinding.

### 06 Discover

Purpose: support browsing without turning the product into social noise.

Must preserve:
- Discovery content is readable but quieter than writing.
- Read-only boundary is visible for unverified users.
- No exact seat numbers.
- No comment composer in discovery-only state.

## PM Internal Review

Status: passed.

Rationale:
- This package answers the founder's concern that home-only work cannot close the loop.
- The six screens cover the core private-card path plus the minimum global shell.
- The direction stays closer to the PRD v2.4 emotional premise than the rejected utility menu drafts.
- The visual direction now has founder approval and can be translated into `DESIGN_SPEC.md`.

Remaining PM concerns before locked-for-dev:
- Generated mock text and details must be normalized into exact UI copy.
- Settings/account full screen is not yet designed; only the entry is covered.
- Flight verification screens are still out of scope for this package.

## PMO Internal Review

Status: passed for post-onboarding main-flow design gate.

Rationale:
- Founder approved the six-screen visual direction on 2026-06-27.
- This is enough to unblock a refreshed test-plan for the approved main-flow scope.
- Dev still must not invent missing surfaces; unapproved screens must follow the rules in `DESIGN_SPEC.md`.

## Next Gate

Founder review answered:

```text
Can this Cabin Ritual direction, across these six screens, be refined into the locked-for-dev design source?
```

Decision: approve direction.

Next:
- Normalize implementation rules into `DESIGN_SPEC.md`.
- Mark `.design.manifest.json` completed after validation.
- Refresh `TEST_PLAN.md` against the approved six-screen source before `dev`.
