# ShipIt V4 — Architecture & Migration Plan

**Date:** 2026-06-08
**Status:** Proposed — founding document
**Author:** Claire Donald (with Claude)

---

## The story (why V4 exists)

ShipIt has tracked Claude's maturation, and that arc is worth preserving:

- **v1 (`~/code/ShipIt`, Feb 2026)** — a multi-agent *framework* built because the platform couldn't coordinate agents itself.
- **v3 (`~/code/shipit-v3`, Apr 2026)** — the orchestration era: 13 agents, `/orchestrate`, a hand-rolled two-tier memory/retro system.
- **v4 (this)** — the **native-primitives era.** The platform now ships dynamic workflows, agent teams, native memory, hooks, and CI. The half of ShipIt that *was* infrastructure is now redundant; the half that's **discipline + learning** is the durable value — but it was soft-enforced (prose) and its learning loop's re-read half never actually worked.

**v1 and v3 stay exactly where they are, untouched, as history.** V4 is a fresh, much smaller thing.

## Core thesis

> Shed the orchestration framework (it got commoditized by native primitives). Keep and *harden* the two things the platform will never do for you: **your gate discipline** and **your learning loop** — reimplemented so they actually fire.

Principles:
- **Model judges, code enforces.** (Same split that makes dynamic workflows reliable.)
- **Enforce the *process*, not the *verdict*.** Force the evaluation-against-criteria to happen and be shown; trust the conclusion.
- **Rules as a substrate.** Graduated learnings/gates fire *under* every session — native workflow, agent team, or plain chat — not only when you remember to invoke a skill.
- **Right-sized.** The thing that actually worked this session was lightweight (a correction → one memory file + one CLAUDE.md rule + one hook). Don't rebuild a framework to replace a habit. Add machinery only where there's evidence the manual version fails.

## Keep / drop / convert (from the v3 inventory + real usage data)

Usage across all transcripts (subagent invocations): `reviewer 29 · retro 29 · engineer 27 · researcher 19 · docs 19 · data-engineer 14 · qa/devsecops/architect ~2 each · strategist/pm/designer/orchestrator ~0`.

- **Drop:** `/orchestrate`, `shipit-parallel`, and the ~7 barely-used agents as a *roster*. For multi-agent builds, use native **dynamic workflows / agent teams**.
- **Keep (as composable, on-demand subagents — not a framework):** `retro`, `reviewer`, `docs`, `engineer`, `researcher`. Others can be summoned ad hoc but aren't first-class.
- **Keep (as independent skills):** `spec`, `gameplan`, `prd-review`, `code-review`, `tdd-build` — genuinely useful standalone.
- **Convert:** the 12 prose `/shipit` gates → real **hooks + CI**, so "NEVER SKIP" becomes true.

---

## Phase 1 — Foundation: consolidate + Retro (the heart)

### 1a. Consolidate
- `~/code/shipit-v4` becomes the **single source of truth** (v3 has 4 duplicate copies of the `/shipit` skill and a dead plugin symlink → `~/shipit-v2`).
- Fix the plugin install (`marketplace.json` + symlink) to point at v4.
- `HISTORY.md` records the v1 → v3 → v4 arc and points at the old repos (kept read-only).

### 1b. Retro v4 — two capture paths, one core

**Path A — invoked (`@retro`).** You (or Claude) call it to capture a specific problem. High precision; the path used most in v3. **Decided:** `@retro` stays the **primary invoked verb — an inline agent mention** (*"@retro, this keeps happening"*), matching existing muscle memory. An optional `/retro` slash command may be added later *only* as an on-demand "run the full sweep now" trigger — not required for Phase 1.

**Path B — autonomous = tripwire + sweep.** Don't detect learnings live (unreliable). Instead:
- **`Stop` hook = a near-zero-cost tripwire (bash, no LLM).** Each turn: did it edit files / contain correction-language / throw an error? If yes, append a one-line marker to a session scratch file. Fires every turn, costs nothing, misses nothing.
- **The retro *sweep* (the LLM evaluation) runs at a bounded checkpoint, NOT every Stop** — at commit/PR, when the marker buffer crosses a threshold, or on a cheap schedule. It batch-evaluates the flagged candidates retrospectively (catches what nobody noticed live).

**Shared core — the judgment, enforced as process not verdict:**
- The retro agent emits **structured output**, a rubric with a *rationale per axis* (you can't fill it without doing the evaluation):
  - `keep | drop` (one-off vs proven) — why
  - `scope: project | user` — "would this hold in a different repo?" → reasoning
  - `type: rule | fact | check | procedure` — why
  - `review: direct | propose` — blast radius
- A light verify pass checks the **working is present and responsive** (flags empty/boilerplate rationale) — it never overrules the conclusion.

**Routing — deterministic table, executed by a script (model classifies, code places):**

| type ↓ / scope → | **project** | **user** |
|---|---|---|
| rule | `<repo>/CLAUDE.md` | `~/.claude/MANDATORY.md` |
| fact | project memory (`projects/<x>/memory/`) | `~/.claude/CLAUDE.md` *(not global memory — it doesn't auto-load)* |
| check | repo CI + project hook | global hook (`~/.claude/settings.json`) |
| procedure | project/plugin skill | global skill (`~/.claude/skills/`) |

- **Review gate:** project + low-risk → `route-learning.sh` writes directly; **user-scope or any enforcement change → propose** (PR / `PROPOSED-LEARNINGS.md`), never auto-apply.
- **Scope-promotion ladder (stretch, not Phase 1):** a learning starts project-scoped and promotes to user when it recurs in a 2nd project. *Honest gap: needs a cross-project learning index that doesn't exist yet — deferred.*

**Cost discipline applies to V4 itself:** the autonomous sweep is recurring spend → Haiku, bounded, cadence-tunable, and obeys `MANDATORY.md` rule #1 (estimate before any scheduled run).

### Honest limits (kept on the table, not hidden)
- **Sincerity can't be fully enforced** — a model can write specific-looking-but-shallow rationale. Mitigation: require concrete references (the actual learning, the actual cross-repo comparison); verifier flags generic boilerplate. Enforced *to the degree the reasoning is checkable.*
- **The sweep is a net, not a guarantee** — retrospective transcript review still misses subtle things and surfaces some noise.

---

## Phase 2 — Gates as hooks + CI (harden the discipline)

Map each v3 `/shipit` gate to its real mechanism (currently all prose except 3 hooks):

| Gate | V4 mechanism |
|---|---|
| test / typecheck / build | CI (per-repo) + a `pre-push` hook |
| no-push-to-main | hook + CI |
| docs-in-sync | generalize the pattern already built for ProveIt (`check-docs-sync.sh` + CI + PreToolUse hook + `[no-docs]`) |
| security scan | keep v3's existing hook |
| review (`@reviewer`) | a subagent invoked by `/ship` or a PR check |
| retro | Phase 1 |

- A thin **`/ship`** skill remains as the human-facing "run all gates now," but **the hooks make them fire even when `/ship` isn't called** — fixing v3's fatal flaw (gates were skippable prose).
- **Override pattern** (`[no-docs]`, `[no-retro]`, …) for genuine exceptions — enforce the gate, allow a conscious opt-out.

## Phase 3 — Shed orchestration / slim the roster
- Remove `/orchestrate`, `shipit-parallel`.
- High-use agents become standalone subagent definitions; the rest are archived in v3 history.
- Doc: "for multi-agent builds, use native dynamic workflows / agent teams."

## Phase 4 — Package & dogfood
- Clean plugin packaging (`marketplace.json`, symlink, `plugin.json` v4.0.0).
- **ProveIt is the reference implementation** — it already runs the docs-sync gate + cost hooks + dynamic workflows. V4 generalizes what proved out there.

---

## Success criteria
- A correction in any repo gets **flagged autonomously (tripwire) or via `@retro`**, **evaluated against the rubric (process enforced)**, **routed to the right scope/mechanism**, and **loads/fires in future sessions** — verifiably.
- Gates fire via **hooks/CI, not prose** — "NEVER SKIP" is actually true.
- ShipIt's surface is a **fraction of v3**; nothing re-implements a native primitive.
- v1 and v3 are **preserved, untouched, as history.**

## Open questions / risks
- Sincerity-enforcement ceiling (above).
- Cross-project scope promotion needs an index (deferred).
- Autonomous sweep cadence/cost tuning.
- Which checkpoint(s) trigger the sweep (commit vs threshold vs schedule) — decide in build.

## Suggested first step
Phase 1b is the keystone — **build Retro v4 (tripwire + sweep + rubric + routing) and prove the loop closes end-to-end on one real learning**, before touching gates or packaging. Everything else hangs off a working learning loop.
