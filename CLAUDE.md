# ShipIt V4 — Agent Instructions

ShipIt V4 is the **native-primitives era** of ShipIt. It sheds the orchestration framework (commoditized by dynamic workflows + agent teams) and hardens the two durable things the platform won't do for you: **gate discipline** and the **learning loop**, reimplemented as hooks + CI so they actually fire.

Read `HISTORY.md` for the provenance and `docs/plans/2026-06-08-shipit-v4-architecture.md` for the full plan. v1 (`~/code/ShipIt`) and v3 (`~/code/shipit-v3`) are **read-only history** — port from them, never modify them.

## The learning loop (Phase 1b — the keystone)

Two capture paths, one shared core. **Model judges, code enforces.**

- **Path A — invoked.** `@retro` inline (an agent mention) or `/retro <learning>` to capture a specific learning. High precision.
- **Path B — autonomous.** A `Stop`-hook **tripwire** (`hooks/retro-tripwire.sh`, no LLM) marks any turn with file-edits / errors / correction-language. The **sweep** (`/retro` with no argument) batch-evaluates those markers later — the LLM cost is bounded and on-demand, never per-turn.
- **Shared core:** the retro agent (`agents/retro.md`) emits a **structured rubric** (`keep|drop`, `scope`, `type`, `review`) with a rationale per axis, then `scripts/route-learning.sh` *places* each `keep` at a mechanism that auto-loads next session.

| component | what it is |
|---|---|
| `agents/retro.md` | the judge — structured rubric, verify-the-working pass |
| `scripts/route-learning.sh` | the placer — deterministic type×scope routing table |
| `scripts/collect-candidates.sh` | sweep prep — markers → transcript slices (no LLM) |
| `hooks/retro-tripwire.sh` | the tripwire — free, every `Stop`, over-flags on purpose |
| `commands/retro.md` | the `/retro` entry point (Path A and Path B) |

## Gates (Phase 2 — in progress)

Gate discipline, converted from v3 prose into mechanism. **Two delivery paths:** universal cheap guards fire as **global plugin hooks** (every session, zero setup); repo-specific backstops get **installed per-repo** (CI + git hooks). See `docs/plans/2026-06-08-shipit-v4-phase2-gates.md`.

| gate (`gates/`) | mechanism | proven |
|---|---|---|
| `no-push-to-main.sh` | global PreToolUse(Bash) — blocks pushes to main | ✅ |
| `block-sensitive-paths.sh` | global PreToolUse(Write/Edit) — blocks `~/.ssh`, `*.pem`, … | ✅ |
| `detect-secrets.sh` | global PostToolUse(Write/Edit) — warns on secrets | ✅ |
| `check-docs-sync.sh` (+ `ci-templates/docs-check.yml`) | per-repo CI + commit reminder; `[no-docs]` | ✅ |
| `pre-push-checks.sh` (+ `ci-templates/ci.yml`) | per-repo `pre-push` hook + CI; `[no-test]` | ✅ |
| independent review | required CI check, non-Claude model via GitHub Models | ⏳ S6 |

The global guards are wired in `hooks/hooks.json`. The per-repo gates are wired by the installer (`scripts/install-gates.sh`, S5).

## Routing — the rule that makes it worth doing

A learning only counts if it **fires by itself next time**. Route to an auto-loading mechanism (a `CLAUDE.md` rule, an auto-loaded memory file, a hook) — never to a note nobody re-reads. That re-read failure is the V3 flaw this loop exists to fix.

**Hard safety (code-enforced):** anything **user-scope** or any **enforcement change** (a hook, a CI gate, a `MANDATORY.md` rule) is **proposed**, never auto-applied — it lands in `PROPOSED-LEARNINGS.md` for a human. The `route-learning.sh` script forces this even if the model says `direct`.

## Cost discipline (applies to V4 itself)

The autonomous sweep is recurring spend → Haiku, bounded, and it obeys `MANDATORY.md` rule #1: **estimate before any scheduled/recurring run.** The tripwire is free (bash, no LLM) by design — that split is deliberate.

## Keeping docs in sync with code

When you change `scripts/`, `agents/`, `commands/`, or `hooks/`, update the docs that describe them (`HISTORY.md`, this file, `docs/`). This is the pattern ProveIt proved out (`check-docs-sync.sh` + CI + a PreToolUse hook + `[no-docs]` override) — Phase 2 generalizes it here.

## Learnings

Durable, auto-loaded rules captured by the @retro learning loop.

- **The retro tripwire (hooks/retro-tripwire.sh) must always exit 0 — a Stop hook that blocks would wedge every turn in every session** — discovered designing Path B: the tripwire fires on every Stop; if it ever exit 2'd it would break the whole session, so blocking is reserved for gates, never the tripwire _(retro 2026-06-08)_
