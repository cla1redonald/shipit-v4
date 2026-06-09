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

## Gates (Phase 2)

Gate discipline, converted from v3 prose into mechanism. **Two delivery paths:** universal cheap guards fire as **global plugin hooks** (every session, zero setup); repo-specific backstops get **installed per-repo** (CI + git hooks). See `docs/plans/2026-06-08-shipit-v4-phase2-gates.md`.

| gate (`gates/`) | mechanism | proven |
|---|---|---|
| `no-push-to-main.sh` | global PreToolUse(Bash) — blocks pushes to main | ✅ |
| `block-sensitive-paths.sh` | global PreToolUse(Write/Edit) — blocks `~/.ssh`, `*.pem`, … | ✅ |
| `detect-secrets.sh` | global PostToolUse(Write/Edit) — warns on secrets | ✅ |
| `check-docs-sync.sh` (+ `ci-templates/docs-check.yml`) | per-repo CI + commit reminder; `[no-docs]` | ✅ |
| `pre-push-checks.sh` (+ `ci-templates/ci.yml`) | per-repo `pre-push` hook + CI; `[no-test]` | ✅ |
| `.github/workflows/independent-review.yml` | required CI check — a **non-Claude** model reviews every PR (author ≠ reviewer), keyless via **GitHub Models** | ✅ |
| `runtime-smoke-test.sh` (+ `ui-smoke.mjs`, `runtime-smoke.yml`) | **auto-fires on `deployment_status`** — hits the **live** artifact: HTTP non-5xx + the page **renders** (Playwright) + optional E2E; routes in `.shipit-gates/smoke.conf`; `[no-smoke]` | ✅ |

- **Global guards** are wired in `hooks/hooks.json`. **Per-repo gates** are wired by the installer `scripts/install-gates.sh` (S5; copies `gates/` → `.shipit-gates/`, drops CI + a `pre-push` hook). **`/ship`** (`commands/ship.md`) runs the lot on demand, but the hooks fire even when it isn't called — that's the v3 fix.
- **Runtime smoke-test** (`gates/runtime-smoke-test.sh`) is the gate the FocusBoard 504 taught us we needed: green build + tests + deploy + review can ALL be true on runtime-broken code (a Hono Web handler 504'd every route on the Node runtime; tests passed via `app.fetch()`, bypassing the deploy adapter). After a deploy it hits the **live** artifact in three tiers — **(1) HTTP** (`curl` each `SHIPIT_SMOKE_PATHS`, fail on 5xx/timeout) · **(2) UI** (`SHIPIT_SMOKE_UI=1` → Playwright loads the page and asserts it *renders*, reports console errors) · **(3) E2E** (`SHIPIT_SMOKE_E2E_CMD` runs the project's Cypress / Playwright-Test / Cucumber suite against the deploy). Deploy-conditional (skips with no URL); `[no-smoke]` override. The floor everyone gets; full flow-coverage plugs into tier 3. **It fires BY ITSELF in CI** via `gates/ci-templates/runtime-smoke.yml`, triggered on GitHub's `deployment_status` event — `environment_url` hands it the live URL with zero config (no token, no manual env). Per-repo routes live in `.shipit-gates/smoke.conf` (`install-gates.sh` seeds a default + copies `ui-smoke.mjs`). Also runnable on demand from `/ship`.
- **Independent review** (`independent-review.yml`, S6 v2) reviews **each changed file in its own GitHub Models call** (`openai/gpt-4.1`, swappable via the `SHIPIT_REVIEW_MODEL` repo variable), so every file is seen *complete* — killing the whole-diff truncation that made v1 speculate. Bounded to 25 files/PR (the rest are listed, never silently dropped). A final **cross-file pass** then reviews the change stat + signature-level diff across files to catch interactions a per-file review can't (a changed contract breaking a caller elsewhere). **Remaining limits:** a single >24k-char file is truncated (and flagged); the cross-file pass sees signatures, not full bodies. **Advisory by default — it posts findings but NEVER blocks the merge.** It catches *diff-level* issues (logic, contracts, naming), **not** runtime correctness (that's the runtime-smoke gate's job — this review once passed green on a deploy that 504'd everything). Set repo var **`SHIPIT_REVIEW_STRICT=true`** to give it teeth (blocks on any `[MUST-FIX]`). **Size-gated:** skips docs-only / trivial PRs (< `SHIPIT_REVIEW_MIN_LINES`, default 10). **Escape hatch:** `[no-review]` in a commit message skips it (like `[no-docs]`/`[no-test]`). **Branch protection** on `main` requires the `review` (always green in advisory mode), `docs-sync`, and `Test, Typecheck & Build` checks + a PR (no direct push).

## Composable subagents & skills (Phase 3)

V4 shed the orchestration *framework* but kept the few things people actually reached for, as **on-demand, composable subagents** (summon ad hoc — not a first-class roster) and **standalone skills**. For multi-agent builds, use native **dynamic workflows / agent teams**, not a roster.

- **Agents** (`agents/`): `retro` (the loop) · `reviewer` · `docs` · `engineer` · `researcher`.
- **Skills** (`commands/`): `/spec` · `/gameplan` · `/prd-review` · `/code-review` · `/tdd-build` · `/ship` · `/retro`.

Ported from v3 with the orchestration/team-mode coupling trimmed (no `/orchestrate`, no `MODE: team`). V4 deliberately does **not** ship the barely-used v3 roster (architect, pm, designer, devsecops, qa, strategist, orchestrator) — summon a specialist ad hoc if a build genuinely needs one.

## Routing — the rule that makes it worth doing

A learning only counts if it **fires by itself next time**. Route to an auto-loading mechanism (a `CLAUDE.md` rule, an auto-loaded memory file, a hook) — never to a note nobody re-reads. That re-read failure is the V3 flaw this loop exists to fix.

**Hard safety (code-enforced):** anything **user-scope** or any **enforcement change** (a hook, a CI gate, a `MANDATORY.md` rule) is **proposed**, never auto-applied — it lands in `PROPOSED-LEARNINGS.md` for a human. The `route-learning.sh` script forces this even if the model says `direct`.

**Scope-promotion ladder (live):** `route-learning.sh` records each project learning in a global index (`~/.claude/shipit-retro/learning-index.tsv`). When the same learning recurs in a **2nd distinct repo**, it proposes promoting it to user scope (never auto-promotes). Filenames use a short slug (`--slug` to override).

## Cost discipline (applies to V4 itself)

The sweep is recurring spend → Haiku, bounded, obeys `MANDATORY.md` rule #1: **estimate before any scheduled/recurring run.** The tripwire is free (bash, no LLM) by design — that split is deliberate. The **autonomous trigger** is cost-safe by construction: `gates/retro-sweep-nudge.sh` (a PostToolUse-on-`git commit` hook, no LLM) just *nudges* you to run `/retro` once the session's markers cross a threshold (`SHIPIT_SWEEP_THRESHOLD`, default 5). It **never spawns an LLM job** — the paid sweep stays you-triggered, on your Max plan. A truly-unattended cron is deliberately NOT shipped (the $24 lesson).

## Keeping docs in sync with code

When you change `scripts/`, `agents/`, `commands/`, or `hooks/`, update the docs that describe them (`HISTORY.md`, this file, `docs/`). This is the pattern ProveIt proved out (`check-docs-sync.sh` + CI + a PreToolUse hook + `[no-docs]` override) — Phase 2 generalizes it here.

## Learnings

Durable, auto-loaded rules captured by the @retro learning loop.

- **The retro tripwire (hooks/retro-tripwire.sh) must always exit 0 — a Stop hook that blocks would wedge every turn in every session** — discovered designing Path B: the tripwire fires on every Stop; if it ever exit 2'd it would break the whole session, so blocking is reserved for gates, never the tripwire _(retro 2026-06-08)_
