# ShipIt — the arc

ShipIt has tracked Claude's maturation. Each version is kept where it was built, **read-only, as history** — don't modify the old repos.

| Version | Where | When | What it was |
|---|---|---|---|
| **v1** | `~/code/ShipIt` (v1.0.0) + `shipit-sdk` | Feb 2026 | A multi-agent **framework**, built because the platform couldn't coordinate agents itself. |
| **v3** | `~/code/shipit-v3` (v3.1.0) | Apr 2026 | The **orchestration era**: 13 agents, `/orchestrate`, a hand-rolled two-tier memory/retro system. The canonical "current" before v4, and the porting source. |
| **v4** | `~/code/shipit-v4` (this, v4.0.0) | Jun 2026 | The **native-primitives era**. The platform now ships dynamic workflows, agent teams, native memory, hooks, and CI. The half of ShipIt that *was* infrastructure is redundant; the half that's **discipline + learning** is the durable value — rebuilt so it actually fires. |

## Provenance — how I got here

I didn't set out to rebuild ShipIt. I set out to build **ProveIt** — a small product-validation tool — and in doing it I kept reaching for three things the platform now gives you for free: a **docs-sync gate** (a cheap bash + CI check, no LLM), **cost hooks** that make me estimate spend before a run, and **dynamic workflows** where code does the coordination and the model only does the judgment. None of that needed a framework. It just needed a few hooks and a script.

That was the tell. ShipIt v1 (Feb 2026) existed because back then the platform *couldn't* coordinate agents — so I built the coordination. v3 (Apr 2026) doubled down: 13 agents, `/orchestrate`, a hand-rolled two-tier memory system. By June, the platform shipped dynamic workflows, agent teams, native memory, hooks, and CI. The scaffolding I'd built was now load-bearing on nothing.

So before assuming, I looked at the receipts. I pulled **real subagent-usage counts from my own transcripts**: `reviewer 29 · retro 29 · engineer 27 · researcher 19 · docs 19 · data-engineer 14`, then a cliff — `qa / devsecops / architect ~2 each`, and `strategist / pm / designer / orchestrator ~0`. The orchestration roster I'd been carrying was barely used. The workhorses were a handful of plain subagents and, tellingly, **retro** — the learning loop — was right at the top.

Then the uncomfortable part: the two things I actually relied on were both **soft-enforced prose**. The gates said "NEVER SKIP" and got skipped (twice, on retro specifically). The learning loop's *write* half worked, but its *re-read* half — the part that's supposed to make a lesson fire in the next session — never really did. The durable value of ShipIt was never the framework. It was the **discipline** and the **learning**, and both were running on good intentions.

That's the whole reason V4 is small. I'm not porting a framework. I'm keeping the two things the platform will never do for me — gate discipline and the learning loop — and rebuilding them so they **actually fire**: model judges, code enforces. ProveIt is where each piece proved out first; V4 generalizes it.

## Why v4 exists

The orchestration framework got commoditized by native primitives. What the platform will *never* do for you is **your gate discipline** and **your learning loop** — and in v3 both were soft-enforced (prose) and the learning loop's re-read half never actually worked.

V4 keeps and *hardens* exactly those two things:

- **Model judges, code enforces.** Force the evaluation to happen and be shown; trust the conclusion.
- **Enforce the process, not the verdict.**
- **Rules as a substrate** — graduated learnings/gates fire *under* every session, not only when you remember to invoke a skill.
- **Right-sized** — add machinery only where there's evidence the manual habit fails.

## What carried over from v3 (ported, not copied wholesale)

- The **retro agent** (`agents/retro.md`) and its **graduation instinct** — now emitting a structured rubric with a rationale per axis (`agents/retro.md` in v4).
- The **memory format** — adapted to the v4 routing table (type × scope → mechanism).

## What got dropped

- `/orchestrate`, `shipit-parallel`, and the ~7 barely-used agents as a *roster*. For multi-agent builds, use native **dynamic workflows / agent teams**.
  - *(P3 amendment, Jun 2026)* The first wild run showed the **ad-hoc specialist summon** was the single highest-value output of the session, so `architect` + `designer` were re-shipped — not as a roster, but as on-demand agents fired by themselves via `gates/specialist-nudge.sh` (commit-time, non-blocking; nudges `@architect` on migrations/`*.sql`/`api/`/new deps, `@designer` on components/`*.tsx`/`*.css`). Still dropped: pm, devsecops, qa, strategist, orchestrator.

## What shipped after the first wild run (the improvement plan)

`docs/plans/2026-06-09-v4-improvement-plan.md` captured the honest post-mortem and a P1–P4 fix list. All four shipped:

- **P1 — runtime verification** (the gap that mattered): `runtime-smoke.yml` auto-fires on `deployment_status`, hits the **live** artifact (HTTP non-5xx + Playwright render + optional E2E). Green build/tests/deploy/review could all be true on a dead deploy — only this catches it.
- **P2 — demoted the cross-model review** to **advisory by default** (never blocks; `SHIPIT_REVIEW_STRICT` opt-in) + size-gated. It catches *diff-level* issues, not runtime correctness — it once passed green on the deploy that 504'd everything.
- **P3 — promoted the specialist summon** to a self-firing `gates/specialist-nudge.sh` (see the amendment above).
- **P4 — earned the confidence:** the gates were installed on **FocusBoard** (the first *real* customer, not a meta-PR), with `runtime-smoke` wired to `/api/capture`. **P1 proved out end-to-end** — both a manual live curl and `runtime-smoke` firing by itself in CI on the preview deploy. The install also surfaced a parallel-session git-collision lesson, now **MANDATORY.md rule #6** (a `git worktree` per concurrent session). `n` is now ≥1 real customer; the suite isn't "broadly proven" until 2–3 more.

## Reference implementation

**ProveIt** (`~/code/proveit`) is the proving ground — it already runs the docs-sync gate, cost hooks, and dynamic workflows. V4 generalizes what proved out there.

See `docs/plans/2026-06-08-shipit-v4-architecture.md` for the full plan.
