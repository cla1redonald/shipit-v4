# HANDOFF — ShipIt V4

**Date:** 2026-06-08
**Status:** **Phase 1b (Retro v4) — DONE and proven.** Next: **Phase 2 — gates as hooks + CI.**
Read `docs/plans/2026-06-08-shipit-v4-architecture.md` for the full plan; this handoff is the on-ramp.

---

## Session Summary

Built **Phase 1b — the Retro v4 learning loop**, the keystone of V4. Smallest-thing-first, proven end-to-end on real learnings before adding machinery (the plan's gate).

**Model judges, code enforces. Enforce the process, not the verdict.** Two capture paths, one core:
- **Path A — invoked** (`@retro` inline, or `/retro <learning>`).
- **Path B — autonomous** — a `Stop`-hook **tripwire** (bash, no LLM, every turn, over-flags) marks candidates; the **sweep** (`/retro`, on-demand) batch-evaluates them. The expensive LLM judgment is bounded and never per-turn — the cost-safe split.

## What's built (committed `4cf927e` on branch `phase-1b-retro`)

| file | role |
|---|---|
| `agents/retro.md` | the judge — structured rubric (`keep/drop · scope · type · review`), rationale per axis, verify-the-working pass |
| `scripts/route-learning.sh` | the placer — deterministic type×scope table. **Hard safety: user-scope + enforcement forced to `propose`, never auto-applied** |
| `hooks/retro-tripwire.sh` + `hooks.json` | Path B tripwire — every `Stop`, always exit 0, marks edits/errors/corrections |
| `scripts/collect-candidates.sh` | sweep prep — markers → transcript slices (no LLM) |
| `commands/retro.md` | `/retro` entry point (Path A + Path B) |
| `commands/verify-scripts-in-sandbox.md` | a procedure the loop itself routed, then fleshed out |
| `plugin.json` v4.0.0, `marketplace.json`, `HISTORY.md`, `CLAUDE.md` | scaffold + provenance |

**Proven:** tripwire→markers→collect→rubric→route all exercised against sandbox repos + synthetic JSONL transcripts (read real output, not "it ran"). The retro agent ran for real, classified honestly, and routed a project rule into `CLAUDE.md` — which the harness injects at session start, so it **auto-loads next session.**

## Current State

- **`~/code/shipit-v4`** — on branch `phase-1b-retro`, commit `4cf927e`. `main` = the founding commit only.
- **Plugin symlink FIXED:** `~/.claude/local-plugins/shipit` → `~/code/shipit-v4` (was a dead link to `~/shipit-v2`). `/retro` + the tripwire load globally from the **next** session on (hooks load at startup).
- **Global config cleaned this session:** `~/.claude/CLAUDE.md` ShipIt section reframed to V4 (dropped `/orchestrate`); the `/shipit`-default `UserPromptSubmit` nudge **retired** (hook wiring removed, `shipit-reminder.sh` deleted, `feedback_shipit_is_default.md` deleted; its orthogonal "fix everything properly" note re-homed to `feedback_fix_everything_properly.md`).
- **Remote:** see below — established this session (or pending, per the push step).
- **History (do NOT modify — the museum):** v1 `~/code/ShipIt`, v3 `~/code/shipit-v3`. Port from them, never edit.

## Open Issues / Next

### Phase 2 — gates as hooks + CI (the next build)
Map each v3 `/shipit` gate to a real mechanism (plan §Phase 2):
- test / typecheck / build → CI + `pre-push` hook
- no-push-to-main → hook + CI
- docs-in-sync → **generalize ProveIt's `check-docs-sync.sh` + CI + PreToolUse hook + `[no-docs]`** (the reference impl)
- security scan → keep v3's hook
- review → `@reviewer` invoked by `/ship` or a PR check
- A thin `/ship` runs all gates on demand, but the **hooks make them fire even when `/ship` isn't called** — fixing v3's skippable-prose flaw. Override pattern (`[no-docs]`, `[no-retro]`) for conscious opt-out.

### Phase 1b tail (defer until Phase 2 or as needed)
- **Autonomous sweep triggers** (commit / marker-threshold / schedule). **Estimate cost first** (Haiku, bounded) — `MANDATORY.md` rule #1. The $24 lesson.
- **`route-learning.sh` rough edge:** procedure/fact filenames are slugged from the full statement → ugly long names. Add `--slug` or cap harder. (Caught when the loop scaffolded `verify-shell-scripts-by-running-them-against-a-t.md`.)
- Verify-the-working pass could become its own light verifier agent.
- Scope-promotion ladder (project→user on 2nd-repo recurrence) — still needs a cross-project learning index that doesn't exist. Deferred.

### Gotchas (carry forward — they cost real money/time)
- **Workflow `args` arrive as a JSON *string*** — `JSON.parse` it.
- **Soft prose rules get bypassed** — hooks + CI, not "NEVER SKIP".
- **Cost-estimate before any scheduled/recurring run** (`MANDATORY.md` #1). $24 burned learning this.
- **Spot-check actual output, not "it ran."**
- **User-global memory (`~/.claude/memory/`) does NOT auto-load** — route user-scope to `CLAUDE.md`/`MANDATORY.md`/hooks.
- **Writing to agent-loaded startup config** (`~/.claude/*`, the plugin symlink, `settings.json`) is **blocked by the auto-mode self-modification guard** — needs explicit user approval; route such learnings via *propose*, don't auto-apply.

## Resume Prompt

> Continue ShipIt V4. Phase 1b (Retro v4) is built and proven — read `~/code/shipit-v4/HANDOFF.md` and `docs/plans/2026-06-08-shipit-v4-architecture.md`. Next is **Phase 2: gates as hooks + CI** — generalize ProveIt's `check-docs-sync.sh` pattern, add a `pre-push` test/typecheck/build hook + a no-push-to-main hook, keep v3's security scan, and a thin `/ship` that runs them on demand while the hooks fire regardless. Smallest-thing-that-works first, prove each gate bites (deliberate-failure test) before the next. Respect the gotchas above (cost-estimate before any scheduled run; hooks/CI not prose; spot-check real output). v1/v3 are read-only history.
