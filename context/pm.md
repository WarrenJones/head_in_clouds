---
project: head_in_clouds
role: pm
date: 2026-05-15
source_opportunity: 2026-05-15-verified-flight-note
brand_name: Head in the Clouds
chinese_subtitle: 云上心事
---

# PM Context: Head in the Clouds / 云上心事

Founder decision on 2026-05-15: skip validation and enter PM Stage 1 because the project lives or dies on UI/UX and emotional value. This is an explicit founder override, not evidence that validation metrics were already met.

Product constraint:

- Stage 1 must be photo-first. The primary action is to capture a boarding pass, e-ticket, or flight itinerary screenshot. Manual flight number entry is only a fallback after capture fails.
- The emotional payoff must happen before any generic feed mechanics. If the capture-to-card reveal is average, the project should stop.
- Do not turn this into a flight tracker, travel journal, or anonymous chat app.
- Stage 1 should avoid hard dependency on network effect by shipping sample/curated feeds for same-route, destination, and hot tabs, while same-flight comments only unlock when real same-flight density exists.
- Privacy is product, not compliance afterthought: do not store raw ticket images by default; extract minimum flight metadata and delete the original unless the user explicitly saves it.

## 2026-06-26 PM Override: Expression-first IA Supersedes Photo-first Opening

The 2026-05-15 photo-first constraint is superseded for Stage 1 by PRD v2.4:

- Primary action is expression-first: user writes one sentence before flight proof.
- Flight information, boarding pass scan, and reminders are contextual actions, not persistent home-screen peers.
- Post-onboarding app shell must use a durable mobile IA, not a landing-page style stack of feature buttons.
- Stage 1 IA decision: 3 destination tabs plus one center creation action.
  - Today: current/recent state and lightweight context.
  - Write: center primary action, direct to Compose.
  - Flight Book: user's own history.
  - Discover: public/same-journey exploration.
- Settings/account stays in the top-right affordance and does not become a tab.

Any implementation that keeps `add flight`, `boarding reminder`, `my flights`, and `discover` as equal full-width home buttons is a P0 product regression.
