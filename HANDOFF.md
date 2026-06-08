# HANDOFF — ShipIt V4

**Date:** 2026-06-08
**Status:** ✅ **DONE.** Phase 1b (learning loop) **and** Phase 2 (gates) are built, proven, merged to `main`, and dogfooded. The review gate is **strict** and `main` is **branch-protected**. There is no open build work — V4 is a working product.

Read `HISTORY.md` for the provenance, `docs/plans/2026-06-08-shipit-v4-architecture.md` for the founding plan, and `docs/plans/2026-06-08-shipit-v4-phase2-gates.md` for the gates plan. v1 (`~/code/ShipIt`) and v3 (`~/code/shipit-v3`) are **read-only history** — port from them, never modify.

---

## What V4 is (delivered)

Two durable things the platform won't do for you, both hardened so they actually fire:

### 1. The learning loop (Phase 1b)
**Model judges, code enforces.** Two capture paths, one core:
- **Path A — invoked:** `@retro` inline, or `/retro <learning>`.
- **Path B — autonomous:** a `Stop`-hook **tripwire** (`hooks/retro-tripwire.sh`, bash, no LLM, every turn) marks candidates; the **sweep** (`/retro`) batch-evaluates them on demand (the cost-safe split).
- **Core:** `agents/retro.md` emits a structured rubric (keep/drop · scope · type · review, rationale per axis); `scripts/route-learning.sh` *places* each keep at an auto-loading mechanism. **Hard safety:** user-scope + enforcement changes are forced to *propose*, never auto-applied.

### 2. The gate set (Phase 2)
v3's prose gates, now mechanism. **Global plugin hooks** (zero setup) + **per-repo installer**.

| gate | mechanism |
|---|---|
| `gates/no-push-to-main.sh` | global PreToolUse(Bash) — blocks pushes to main |
| `gates/block-sensitive-paths.sh` | global PreToolUse(Write/Edit) — blocks `~/.ssh`, `*.pem`, … |
| `gates/detect-secrets.sh` | global PostToolUse — warns on secrets |
| `gates/check-docs-sync.sh` + CI | code-changed-without-docs; `[no-docs]` |
| `gates/pre-push-checks.sh` + CI | test/typecheck/build, skip-if-absent; `[no-test]` |
| `.github/workflows/independent-review.yml` | **per-file** cross-model review (non-Claude `gpt-4.1` via keyless GitHub Models) — the author doesn't review its own work |
| `scripts/install-gates.sh` | idempotent per-repo installer (CI + git hooks + settings) |
| `commands/ship.md` (`/ship`) | runs every gate on demand; hooks fire regardless |

## Enforcement state (live on the GitHub repo)

- **Repo:** https://github.com/cla1redonald/shipit-v4 (public). `main` only — all feature branches deleted.
- **Branch protection on `main`:** requires checks **`review` · `docs-sync` · `Test, Typecheck & Build`** + a PR (no direct push), 0 human approvals, `enforce_admins=false` (you can admin-merge).
- **Review = STRICT:** repo var `SHIPIT_REVIEW_STRICT=true` → any `[MUST-FIX]` blocks. Model swappable via `SHIPIT_REVIEW_MODEL`.
- **Escape hatches** (for a verified false positive): `[no-review]` in a commit message, or admin-merge.
- **Plugin symlink:** `~/.claude/local-plugins/shipit` → `~/code/shipit-v4` (loads globally each session).
- **Global config cleaned:** `~/.claude/CLAUDE.md` reframed to V4 (`/orchestrate` dropped); the `/shipit`-default `UserPromptSubmit` nudge retired.

## How to work on V4 now

`main` is protected, so: **branch → PR → pass the gates → merge.** Even a docs change goes through a PR (the review gate runs on it). This HANDOFF update was itself the first real exercise of that flow.

## Honest limits (documented, accepted)
- **LLM review has an irreducible noise floor** — identical content can get different verdicts. Strict mode will occasionally false-block; that's what `[no-review]` / admin-merge are for. Always verify a finding against the real code before acting (we caught every false positive this way).
- **Per-file review can't see cross-file interactions** — the tradeoff for killing whole-diff truncation.

## Phase 3 + the deferred enhancements — ALL DONE
- ✅ **Phase 3 roster packaging** — `agents/`: reviewer, docs, engineer, researcher (+ retro). `commands/`: /spec, /gameplan, /prd-review, /code-review, /tdd-build (+ /ship, /retro). Ported from v3, orchestration/team-mode coupling trimmed; no dangling refs to agents V4 doesn't ship.
- ✅ **Autonomous sweep trigger** — cost-safe: `gates/retro-sweep-nudge.sh` (PostToolUse on `git commit`, no LLM) nudges you to run `/retro` once markers cross `SHIPIT_SWEEP_THRESHOLD`. Never spawns an LLM job; no cron (the $24 lesson).
- ✅ **`route-learning.sh` slug cleanup** — short filenames + `--slug`.
- ✅ **Scope-promotion ladder** — global index (`~/.claude/shipit-retro/learning-index.tsv`); a 2nd-repo recurrence proposes user-scope promotion (never auto).
- ✅ **Cross-file review** for S6 — a final pass reviews the change-stat + cross-file signature diff after the per-file loop.

**Nothing is open. V4 is complete.** (Only an unattended-cron sweep remains deliberately NOT built — it would bill the API wallet; build it only with an explicit cost estimate + approval.)

## Gotchas (carry forward)
- **Workflow `args` arrive as a JSON string** — `JSON.parse` it.
- **GitHub runs `run:` blocks with `set -e`** — aggregator scripts must be set-e-proof (cost a debugging cycle on the review gate).
- **GitHub Models caps requests** (~8k tokens for gpt-4o) — hence per-file review.
- **Soft prose rules get bypassed** — hooks + CI, not "NEVER SKIP".
- **Cost-estimate before any scheduled/recurring run** (`MANDATORY.md` #1). The $24 lesson.
- **Spot-check actual output, not "it ran."**
- **Writing to agent-loaded config** (`~/.claude/*`, the plugin symlink, `settings.json`) is **blocked by the self-modification guard** — needs explicit user approval.

## Resume Prompt

> ShipIt V4 is **complete** — read `~/code/shipit-v4/HANDOFF.md`. The learning loop (Phase 1b) and the gate set (Phase 2) are built, merged, dogfooded; the review gate is strict and `main` is branch-protected. There is no open build work. If extending it, `main` is protected: branch → PR → pass `review`/`docs-sync`/`CI` → merge (use `[no-review]` or admin-merge for a verified false positive). Optional follow-ups (none blocking): autonomous retro-sweep triggers (estimate cost first), `route-learning.sh` slug cleanup, cross-project scope-promotion index, cross-file review for S6. v1/v3 are read-only history.
