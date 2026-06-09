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
| `scripts/route-learning.sh` | the placer — deterministic type×scope routing table; stamps new proposals `**Status:** pending` |
| `scripts/proposed-learnings.sh` | lifecycle for `PROPOSED-LEARNINGS.md` — `--list`/`--apply <n>`/`--archive <n>` so proposals don't sit "awaiting review" forever (P5c) |
| `scripts/collect-candidates.sh` | sweep prep — markers → transcript slices (no LLM) |
| `hooks/retro-tripwire.sh` | the tripwire — free, every `Stop`, over-flags on purpose; **also emits loop-fired events (P5b)** |
| `scripts/note-applied.sh` | record a fire for a JUDGMENT rule (the fallback signal; action rules fire for free) |
| `scripts/learning-audit.sh` | read-time view of the loop-fired signal — `--fired`, `--dead-letters`, `--list` |
| `hooks/retro-sweep-session-end.sh` | autonomous trigger (opt-in) — fires the sweep at `SessionEnd`; all guards, no LLM itself |
| `scripts/run-sweep.sh` | the autonomous sweep worker — Haiku (no tools) judges, code routes; capped + recursion-guarded |
| `commands/retro.md` | the `/retro` entry point (Path A and Path B) |

### Did the learning actually fire? (P5b — the loop-fired verifier)

V4's whole claim is *"a routed learning fires by itself next time"* — the exact thing V3 never **verified**. P5b gives it the first real feedback, **free, no LLM**:

- **The signal is action-shape, not presence.** Rules are injected every session (SessionStart), so "in context" is always true — useless. Instead, `@retro`/`route-learning.sh` can tag a learning with an **`--action-match`** grep pattern (its distinctive *doing*, e.g. `git worktree add`) and a **`--surface-match`** (its *precondition*, e.g. a commit touching `api/`). The tripwire greps each turn's **tool stream** against them and appends `fire`/`opp` events — **with zero agent compliance**. This is the only signal that can prove a rule fired *unprompted*.
- **Data shape (race-safe, honoring MANDATORY #6).** Registry `~/.claude/shipit-retro/learning-index.tsv` is **write-once** (`SIG⇥REPO⇥DATE⇥TYPE⇥ACTION_MATCH⇥SURFACE_MATCH`). Fires go to an **append-only** `learning-events.tsv` (single-line `O_APPEND`). Counts are **derived at read time** by `learning-audit.sh` (distinct sessions per SIG) — nothing is ever mutated in place, so concurrent sessions can't race it.
- **Dead letters need a denominator.** `learning-audit.sh --dead-letters`: a **genuine miss** = surface arose ≥k sessions but FIRES=0 (re-route / sharpen / drop); **dormant** = surface never arose (legit waiting); **low-confidence** = a judgment rule (no patterns) unfired past the age window (eyeball it).
- **Judgment rules** (no code-checkable action, e.g. "don't over-promise") can't be auto-detected — they use the **`scripts/note-applied.sh <slug>`** fallback (you log it when you apply it; the slug rides in the rule's `_(… learning:<slug>)_` tag). Honest limit: self-report under-counts.
- **Two kinds of test.** The closed-loop route→apply→FIRES=1 is a **plumbing** test only. The *claim* ("it fires unprompted") is validated **observationally** — action-match fires accruing across real sessions with nobody calling `note-applied`.
- **v2 (deferred):** a you-triggered, bounded **Haiku `--audit`** over only the judgment-rule dead letters (line-ranges only, cap, estimate-first) — the one paid piece, kept out of the autonomous detection path (cost rule #1).

## Gates (Phase 2)

Gate discipline, converted from v3 prose into mechanism. **Two delivery paths:** universal cheap guards fire as **global plugin hooks** (every session, zero setup); repo-specific backstops get **installed per-repo** (CI + git hooks). See `docs/plans/2026-06-08-shipit-v4-phase2-gates.md`.

| gate (`gates/`) | mechanism | proven |
|---|---|---|
| `no-push-to-main.sh` | global PreToolUse(Bash) — blocks pushes to main | ✅ |
| `block-sensitive-paths.sh` | global PreToolUse(Write/Edit) — blocks `~/.ssh`, `*.pem`, … | ✅ |
| `detect-secrets.sh` | global PostToolUse(Write/Edit) — warns on secrets | ✅ |
| `check-docs-sync.sh` (+ `ci-templates/docs-check.yml`) | per-repo CI + commit reminder; `[no-docs]`. CODE_RE covers app layouts (`src/ app/ web/ api/ …`) + ShipIt's own — not just ShipIt's, which made it a silent no-op on app repos | ✅ |
| `pre-push-checks.sh` (+ `ci-templates/ci.yml`) | per-repo `pre-push` hook + CI; `[no-test]` | ✅ |
| `.github/workflows/independent-review.yml` | required CI check — a **non-Claude** model reviews every PR (author ≠ reviewer), keyless via **GitHub Models** | ✅ |
| `runtime-smoke-test.sh` (+ `ui-smoke.mjs`, `runtime-smoke.yml`) | **auto-fires on `deployment_status`** — hits the **live** artifact: HTTP non-5xx + the page **renders** (Playwright) + optional E2E; routes in `.shipit-gates/smoke.conf`; `[no-smoke]` | ✅ |

- **Global guards** are wired in `hooks/hooks.json`. **Per-repo gates** are wired by the installer `scripts/install-gates.sh` (S5; copies `gates/` → `.shipit-gates/`, drops CI + a `pre-push` hook). **`/ship`** (`commands/ship.md`) runs the lot on demand, but the hooks fire even when it isn't called — that's the v3 fix.
- **Runtime smoke-test** (`gates/runtime-smoke-test.sh`) is the gate the FocusBoard 504 taught us we needed: green build + tests + deploy + review can ALL be true on runtime-broken code (a Hono Web handler 504'd every route on the Node runtime; tests passed via `app.fetch()`, bypassing the deploy adapter). After a deploy it hits the **live** artifact in three tiers — **(1) HTTP** (`curl` each `SHIPIT_SMOKE_PATHS`, fail on 5xx/timeout; a path may pin an exact expected status with `=NNN` — e.g. `/api/health/deep=200` — which catches routing regressions hiding behind "not a 5xx", like Vercel platform-404ing a multi-segment path) · **(1b) AUTHED** (when a low-privilege test token is present as a CI secret, `SHIPIT_SMOKE_AUTH_TOKEN`, the gate curls `SHIPIT_SMOKE_AUTH_PATHS` with the Bearer header and/or runs `SHIPIT_SMOKE_AUTH_CMD`, a project round-trip: create → list-shows-it → delete. Tiers 1+2 prove liveness/routing/auth, NEVER data correctness — FocusBoard's inbox status-filter bug returned wrong rows to authed callers and passed every unauth gate; this tier is the first that catches that class. No token → skips with a note) · **(2) UI** (`SHIPIT_SMOKE_UI=1` → Playwright loads the page and asserts it *renders*, reports console errors; on a **401/403** page — e.g. a Vercel-protected preview — it **skips honestly** rather than false-passing on the protection screen, and fails on any other 4xx/5xx; the public production deploy is where the UI is truly verified) · **(3) E2E** (`SHIPIT_SMOKE_E2E_CMD` runs the project's Cypress / Playwright-Test / Cucumber suite against the deploy). Deploy-conditional (skips with no URL); `[no-smoke]` override. The floor everyone gets; full flow-coverage plugs into tier 3. **It fires BY ITSELF in CI** via `gates/ci-templates/runtime-smoke.yml`, triggered on GitHub's `deployment_status` event — `environment_url` hands it the live URL with zero config (no token, no manual env). Per-repo routes live in `.shipit-gates/smoke.conf` (`install-gates.sh` seeds a default + copies `ui-smoke.mjs`). Also runnable on demand from `/ship`.
- **Independent review** (`independent-review.yml`, S6 v2) reviews **each changed file in its own GitHub Models call** (`openai/gpt-4.1`, swappable via the `SHIPIT_REVIEW_MODEL` repo variable), so every file is seen *complete* — killing the whole-diff truncation that made v1 speculate. Bounded to 25 files/PR (the rest are listed, never silently dropped). A final **cross-file pass** then reviews the change stat + signature-level diff across files to catch interactions a per-file review can't (a changed contract breaking a caller elsewhere). **Remaining limits:** a single >24k-char file is truncated (and flagged); the cross-file pass sees signatures, not full bodies. **Advisory by default — it posts findings but NEVER blocks the merge.** It catches *diff-level* issues (logic, contracts, naming), **not** runtime correctness (that's the runtime-smoke gate's job — this review once passed green on a deploy that 504'd everything). Set repo var **`SHIPIT_REVIEW_STRICT=true`** to give it teeth (blocks on any `[MUST-FIX]`). **Size-gated:** skips docs-only / trivial PRs (< `SHIPIT_REVIEW_MIN_LINES`, default 10). **Escape hatch:** `[no-review]` in a commit message skips it (like `[no-docs]`/`[no-test]`). **Branch protection** on `main` requires the `review` (always green in advisory mode), `docs-sync`, and `Test, Typecheck & Build` checks + a PR (no direct push).

## Composable subagents & skills (Phase 3)

V4 shed the orchestration *framework* but kept the few things people actually reached for, as **on-demand, composable subagents** (summon ad hoc — not a first-class roster) and **standalone skills**. For multi-agent builds, use native **dynamic workflows / agent teams**, not a roster.

- **Agents** (`agents/`): `retro` (the loop) · `reviewer` · `docs` · `engineer` · `researcher` · `architect` · `designer`.
- **Skills** (`commands/`): `/spec` · `/gameplan` · `/prd-review` · `/code-review` · `/tdd-build` · `/ship` · `/retro`.

Ported from v3 with the orchestration/team-mode coupling trimmed (no `/orchestrate`, no `MODE: team`). The first wild run showed the **ad-hoc specialist summon** was the single highest-value output of the session (the architect caught a half-aspirational API boundary at plan time), so V4 ships `architect` + `designer` alongside `reviewer` and fires them by themselves via the **specialist-nudge** (below). The rest of the v3 roster (pm, devsecops, qa, strategist, orchestrator) is still **not** shipped — summon one ad hoc if a build genuinely needs it.

### Specialist-nudge — summon the right @agent by itself

The best ROI of the first run was implicit and manual (you had to remember to summon the architect). `gates/specialist-nudge.sh` makes it fire on its own: a non-blocking PreToolUse(Bash) reminder (same family as `docs-sync-reminder.sh` / `retro-sweep-nudge.sh`) that, on a `git commit`, inspects the **staged** diff and nudges you to summon the matching specialist. It never blocks (exit 0) and spawns no LLM — it just points at a real, installed agent.

| Staged surface | Nudges you to summon |
|---|---|
| **`docs/plans/*.md`, `ARCHITECTURE.md`, `*prd*.md`** (PLAN TIME) | **`@architect`** — review the *design* before building |
| `migrations/`, `*.sql`, `schema.*`, `api/`, a new `package.json` dependency (commit-time backstop) | **`@architect`** |
| `components/`, `*.tsx` / `*.jsx`, `*.css` / `*.scss` (a Next.js page is a `.tsx`; a `route.ts` is an API file → `@architect`, not here) | **`@designer`** |

The architect's highest-value moment is at **PLAN time** (summon before building, not just before merging). P5e wires that in two places: the nudge fires a distinct PLAN-TIME message when a plan/PRD/architecture doc is staged, and `/spec` + `/gameplan` carry an exit-criteria item to summon `@architect` for any architectural surface *before* implementation. The commit-time code-surface nudge is the backstop for when that didn't happen. Installed per-repo by `install-gates.sh` (copies the script into `.shipit-gates/`, jq-merges the hook into `.claude/settings.json`).

## Routing — the rule that makes it worth doing

A learning only counts if it **fires by itself next time**. Route to an auto-loading mechanism (a `CLAUDE.md` rule, an auto-loaded memory file, a hook) — never to a note nobody re-reads. That re-read failure is the V3 flaw this loop exists to fix.

**Hard safety (code-enforced):** anything **user-scope** or any **enforcement change** (a hook, a CI gate, a `MANDATORY.md` rule) is **proposed**, never auto-applied — it lands in `PROPOSED-LEARNINGS.md` for a human. The `route-learning.sh` script forces this even if the model says `direct`.

**Scope-promotion ladder (live):** `route-learning.sh` records each project learning in a global index (`~/.claude/shipit-retro/learning-index.tsv`). When the same learning recurs in a **2nd distinct repo**, it proposes promoting it to user scope (never auto-promotes). Filenames use a short slug (`--slug` to override).

## Cost discipline (applies to V4 itself)

The sweep is recurring spend → Haiku, bounded, obeys `MANDATORY.md` rule #1: **estimate before any scheduled/recurring run.** The tripwire is free (bash, no LLM) by design — that split is deliberate.

Two triggers, both cost-safe:
- **Nudge (default).** `gates/retro-sweep-nudge.sh` (PostToolUse-on-`git commit`, no LLM) *nudges* you to run `/retro` once the session's markers cross `SHIPIT_SWEEP_THRESHOLD` (default 5). Never spawns an LLM — the paid sweep stays you-triggered.
- **Autonomous session-end (opt-in, P-hands-off).** `hooks/retro-sweep-session-end.sh` + `scripts/run-sweep.sh` run the sweep **by themselves when a session ends** — *only* when `~/.claude/shipit-retro/auto-sweep` says `session-end` (no file → off; `rm` it or `SHIPIT_AUTO_SWEEP=off` to disable). Originally deferred (the $24 lesson); shipped on **Claire's explicit approval (2026-06-09)** with hard caps that keep rule #1 satisfied: **zero spend on idle** (exits before any LLM call if no markers), **Haiku only**, **≤ `SHIPIT_SWEEP_MAX` (20) candidates/sweep**, **recursion-guarded** (`SHIPIT_IN_SWEEP`), **detached** (never blocks exit), and — crucially — the **model gets NO tools**: it reads candidates as text and returns `@KEEP` blocks (model judges); `run-sweep.sh` parses them and runs `route-learning.sh` (code enforces — user-scope/enforcement still go to `PROPOSED-LEARNINGS.md`, never auto-applied). Worst-case ≈ $2–4/mo on API pricing; on a Max-authed `claude` it draws subscription quota instead. **Note:** project-scope learnings are auto-written to `<repo>/CLAUDE.md` (visible in `git status`, reversible) — only user/enforcement are gated behind your review.

## Keeping docs in sync with code

When you change `scripts/`, `agents/`, `commands/`, or `hooks/`, update the docs that describe them (`HISTORY.md`, this file, `docs/`). This is the pattern ProveIt proved out (`check-docs-sync.sh` + CI + a PreToolUse hook + `[no-docs]` override) — Phase 2 generalizes it here.

## Learnings

Durable, auto-loaded rules captured by the @retro learning loop.

- **The retro tripwire (hooks/retro-tripwire.sh) must always exit 0 — a Stop hook that blocks would wedge every turn in every session** — discovered designing Path B: the tripwire fires on every Stop; if it ever exit 2'd it would break the whole session, so blocking is reserved for gates, never the tripwire _(retro 2026-06-08)_
