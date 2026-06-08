# HANDOFF — ShipIt V4 build kickoff

**Date:** 2026-06-08
**Goal of next session:** BUILD **Phase 1b (Retro v4 — the keystone)** per
`~/code/shipit-v4/docs/plans/2026-06-08-shipit-v4-architecture.md`.
Read the plan first — this handoff is the on-ramp, the plan is the spec.

---

## Session Summary

Designed **ShipIt V4** — the "native-primitives era" rebuild of ShipIt. Nothing built yet; the deliverable was the founding plan + this handoff.

- Inventoried v3: the 12 prose `/shipit` gates, the 13-agent roster, and the Retro two-tier learning loop. Pulled **real usage data** from transcripts (`reviewer 29 · retro 29 · engineer 27 · researcher 19 · docs 19` are the workhorses; `architect/qa/devsecops ~2`, `strategist/pm/designer/orchestrator ~0`).
- Converged on a **right-sized** design: shed the orchestration framework (commoditized by native dynamic workflows / agent teams), harden the two durable things — **gates** and the **learning loop** — via hooks/CI. **Model judges, code enforces. Enforce the *process*, not the *verdict*.**
- Retro v4 = **`@retro` (invoked, inline)** + **autonomous `Stop`-hook tripwire → bounded sweep**, both feeding one shared **rubric → routing-table → review-gate** core.
- This came out of the ProveIt session. **ProveIt is the reference implementation** — it already has the docs-sync gate, cost hooks, and dynamic workflows V4 will generalize.

## Current State

- **`~/code/shipit-v4`** — fresh. Contains `docs/plans/2026-06-08-shipit-v4-architecture.md` (the plan) + this `HANDOFF.md`. Git-initialised with a founding commit.
- **History (do NOT modify — these are the museum):**
  - v1 → `~/code/ShipIt` (v1.0.0, Feb 2026) + `shipit-sdk`
  - v3 (canonical current, the porting source) → `~/code/shipit-v3` (v3.1.0, Apr 2026) — has `agents/retro.md`, the populated `memory/` tree, `commands/shipit.md` (gate sequence), `hooks/`.
- **Broken, fix during build:** `~/.claude/local-plugins/shipit` → `~/shipit-v2` is a **dead symlink**; the `/shipit` skill exists in **4 duplicate copies** (v3 command + `~/.claude/skills/shipit` + `~/.agents/skills/shipit` + the parallel one).
- No tests/build/lint yet (greenfield). No remote on `shipit-v4` yet.

## Open Issues

### Phase 1b — ordered task list (smallest end-to-end FIRST)
1. **Minimal repo setup:** `plugin.json` (v4.0.0), `.claude-plugin/marketplace.json`, `HISTORY.md` (the v1→v3→v4 arc), fix the dead plugin symlink to point at v4. Keep it tiny.
2. **Port the `retro` agent** from `~/code/shipit-v3/agents/retro.md` → V4 retro subagent, adapted to emit **structured output**: per learning `{ statement, keep|drop, scope: project|user, type: rule|fact|check|procedure, review: direct|propose }` **with a rationale per axis** (enforce the working is shown).
3. **`route-learning.sh`** — the deterministic routing table (type×scope → mechanism; see plan §1b table). Model classifies; this script *places + formats*. project rule→`<repo>/CLAUDE.md`, user rule→`~/.claude/MANDATORY.md`, fact→memory/`CLAUDE.md`, check→hook+CI, procedure→skill. **Never write user-scope/enforcement directly — propose (PR/`PROPOSED-LEARNINGS.md`).**
4. **`Stop`-hook tripwire** — cheap bash, NO LLM: did the turn edit files / contain correction-language / error? → append one line to a session scratch file. (Per-turn; the full sweep does NOT run here — see plan, this is the cost-safe split.)
5. **Sweep trigger (start simplest):** wire `@retro`/`/retro` to read the scratch markers + transcript and run the retro agent → route. Defer commit-checkpoint/threshold/schedule triggers until the manual path works.
6. **PROVE the loop on ONE real learning:** capture → rubric → route → confirm it actually loads in a fresh session. This is the gate before ANY more machinery.
7. Only then: the verify-the-working pass, review-gate polish, autonomous checkpoint triggers.

### Gotchas learned this session (respect these — they cost real money/time to find)
- **Workflow `args` arrive as a JSON *string*, not an object** — `JSON.parse` it. Silent failure otherwise (it runs on the wrong inputs). [[project-workflow-args-are-json-strings]]
- **Soft prose rules get bypassed.** "NEVER SKIP" in a skill is not enforcement. Use **hooks + CI**. (v3's whole gate problem.)
- **Cost-estimate-before-spend is MANDATORY** (`~/.claude/MANDATORY.md` rule #1) — the autonomous sweep is recurring spend → Haiku, bounded, estimate first. ($24 was burned this session learning this.)
- **Spot-check actual output, not just "it ran."** The swarm "succeeded" on the wrong subject; only reading real values caught it.
- **User-global memory (`~/.claude/memory/`) does NOT auto-load** — route user-scope learnings to `CLAUDE.md`/`MANDATORY.md`/hooks, not global memory.

### Deferred (not Phase 1)
- Cross-project scope-promotion ladder (needs a learning index that doesn't exist).
- Sweep cadence/cost tuning; autonomous checkpoint triggers (commit/threshold/schedule).

## Resume Prompt

> Build ShipIt V4 Phase 1b (Retro v4), the keystone. Read `~/code/shipit-v4/docs/plans/2026-06-08-shipit-v4-architecture.md` and `~/code/shipit-v4/HANDOFF.md` first. Work in `~/code/shipit-v4` (fresh repo); v1 (`~/code/ShipIt`) and v3 (`~/code/shipit-v3`) are read-only history — port the retro agent + memory format FROM v3, don't modify it. Follow the ordered Phase 1b task list in the handoff: minimal repo setup → port retro agent with the structured rubric → `route-learning.sh` routing table → cheap `Stop`-hook tripwire → wire `@retro` to run the sweep → **then prove the whole loop end-to-end on ONE real learning before adding anything else.** Respect the gotchas (Workflow args = JSON string; hooks/CI not prose; estimate cost before any paid/scheduled run and get my OK; spot-check real output). Smallest-thing-that-works first, exactly like we did ProveIt.
