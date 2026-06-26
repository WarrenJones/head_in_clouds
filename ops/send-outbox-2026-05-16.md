# Send Outbox — 2026-05-16

These are the only items today that require you (boss) to do something. Everything else is auto-executed.

---

## 1. Approve head_in_clouds PM (orchestrator command)

```bash
cd /Users/zhongwowen.3/startup && npx tsx orchestrate.ts approve pm --project=head_in_clouds
```

What happens after you run it:
- orchestrator marks pm → done
- test-plan + design unlock (per workflow.yaml: `design.depends_on: [pm]`, `test-plan.depends_on: [pm]`)
- PMO can then auto-trigger `next test-plan --project=head_in_clouds` tomorrow morning

Status when you read this:
- PM completed: 2026-05-15 16:50 CST (≈ 19h ago at this file write)
- waiting_review since: 2026-05-15
- Artifacts ready: `head_in_clouds/PRD.md` · `DESIGN_BRIEF.md` · `DESIGN_DETAIL.md` · `CLAUDE_DESIGN_ROUND1.md` · `OPPORTUNITY.md` · `context/pm.md`

If you want to REJECT instead:
```bash
npx tsx orchestrate.ts reject pm --project=head_in_clouds --note="..."
```

If you want to KILL the whole project (PM doesn't feel right, no point dev):
```bash
npx tsx orchestrate.ts kill --project=head_in_clouds --note="..."
```

---

## 2. Upload `CLAUDE_DESIGN_ROUND1.md` to Claude Design (external, when convenient)

File path: `/Users/zhongwowen.3/startup/head_in_clouds/CLAUDE_DESIGN_ROUND1.md`

Why it's outboxed and not auto-done: Claude Design is an external Anthropic visual tool that requires manual upload. No API I can drive.

What to do:
1. Open Claude Design (https://claude.ai or your usual entry point).
2. New chat → paste the file content (the whole thing, it's a self-contained brief).
3. Wait for 3 directions × 3 screens (Opening / Compose / Card Reveal) per the brief.
4. Save the returned mocks somewhere accessible (Drive / Notion / wherever) and ping me the link.

The brief is locked to:
- 3 directions: Cloud Letter / Cabin Cinema / Ticket Poem
- 3 screens only — DO NOT let it expand to feed/comments/profile/tabs
- iPhone 390 × 844

Why it's worth doing today: the design Round 1 result feeds the test-plan acceptance bar. If you wait > 4 days, the test-plan stage will be drafted blind and have to be re-drafted.

---

That's it. Two items. No other manual work needed today.
