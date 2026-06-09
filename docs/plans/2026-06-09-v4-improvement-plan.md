# ShipIt V4 — Improvement Plan (post first in-the-wild run)

**Date:** 2026-06-09
**Trigger:** V4 was built this session, then **battle-tested in the wild** building FocusBoard's CLI/MCP Phase 0. This plan captures the honest assessment + the prioritized fixes. Start a next session here to evolve ShipIt.

## Honest assessment (what the wild run revealed)
V4's thesis — *shed orchestration, harden the two durable things (gate discipline + learning loop) so they fire by themselves; model judges, code enforces* — **mostly held, but inverted from how it was sold.**

- **The cheap parts carried it.** The single highest-value output all session was the **ad-hoc specialist summon** — the architect's review of the FocusBoard plan caught that the "API boundary" was half-aspirational, forced the PAT model, and turned the 12-function wall into the Hono-router decision. It *prevented a bad build*. The cheap mechanical gates (no-push-main, secrets, docs-sync) were quiet and reliable. The retro loop closed (captured the 504 lesson → produced the runtime-smoke gate → self-improved in real time).
- **The expensive headline feature underdelivered.** The **independent cross-model review** took ~7 calibration rounds, shipped with real bugs (strict-mode grep matched *"no [MUST-FIX]"* prose; a `set -e` bug; truncation/self-reference noise), leaned on `[no-review]`/admin-merge escape hatches, and — most damning — **passed GREEN on the FocusBoard PR that 504'd every route.** No diff review catches a runtime/adapter bug; it was oversold.
- **The real blind spot:** V4's gates proved code was *well-formed* (compiles, tested, reviewed), never that it *works deployed*. Every gate was green on a dead deploy. Only a human-prompted live `curl` caught it. **Patched mid-flight** with the new `runtime-smoke-test` gate — but only after the wild bit us.
- **Caveat:** `n=1`. Barely battle-tested. Self-review on V4's own PRs has limited signal (the gate reviewing the gate).

## Prioritized fixes

### P1 — Finish closing the runtime-verification gap (started)
The gap that actually mattered. `gates/runtime-smoke-test.sh` + `gates/ui-smoke.mjs` exist (HTTP curl + Playwright UI render + `SHIPIT_SMOKE_E2E_CMD` for Cypress/Playwright-Test/Cucumber). Remaining:
- **Wire it into the installer** (`scripts/install-gates.sh`) so every repo gets it, and into **CI templates** (`ci-templates/ci.yml`) so it runs post-deploy in CI — today it's only `/ship` prose (step 6), so it fires only when a human runs `/ship`.
- **Auto-discover the deploy URL** (parse Vercel/CI deploy output) instead of manual `SHIPIT_DEPLOY_URL`. This is the difference between "runs by itself" (the V4 thesis) and "runs if you remember."
- **Document the three tiers** + how a repo opts in (`SHIPIT_SMOKE_PATHS`, `SHIPIT_SMOKE_UI=1`, `SHIPIT_SMOKE_E2E_CMD`). FocusBoard is the first customer: `SHIPIT_SMOKE_PATHS=/api/capture`, `SHIPIT_SMOKE_UI=1`.
- Decide: when `SHIPIT_SMOKE_UI=1` but Playwright is absent, it currently warns-and-skips. For a repo that *opted in*, that should arguably hard-fail (don't silently pass an unverified UI).

### P2 — Demote and de-noise the cross-model review
It's a signal, not a gate. The evidence: repeated false positives + a green pass on broken code.
- **Make it advisory by default** (off the required-check / branch-protection path). Strict mode stays opt-in for repos that want it.
- **Reframe + document its scope:** it catches *diff-level* issues (logic, contracts, naming, obvious bugs), NOT runtime correctness. Stop implying it gates "does it work" — that's the smoke gate's job.
- **Kill the calibration tax:** replace verdict *grep* with structured parsing (a required `VERDICT:` line parsed as data, not pattern-matched against prose — that's what caused the strict-mode bug).
- **Size-gate it:** skip it on trivial PRs (e.g. < N changed lines / docs-only) so it's not paying LLM cost on a 3-line fix.

### P3 — Promote what actually worked
- **Make ad-hoc specialist summon a first-class, documented pattern** (a `/review` or a `/ship` step: "summon the architect for any PR touching architecture / data model / a new external boundary; the designer for any user-facing surface"). It was the best ROI in the session and is currently implicit/manual.
- Keep the retro loop. Add a lightweight **lifecycle for `PROPOSED-LEARNINGS.md`** — it accumulates and never clears (3 proposals were applied to `~/.claude` this session; the file still says "awaiting review"). Mark-applied / archive.

### P4 — Earn the confidence (battle-testing)
- Install the gates on 2–3 of Claire's other repos and observe a few real PRs before trusting the suite. `n=1` is not "proven."
- Note in docs that **meta-PRs (V4 reviewing V4) get limited review signal** — don't read green there as validation.

### P5 — Validation & loop-closing (do this BEFORE any new feature)
The risk has inverted: no longer "too much framework," now "building more on a base proven only on its author." **Stop adding gates; validate the base and close the one load-bearing gap.** Five items, full spec below:
- **P5a — Battle-test for real** (finishes P4's clause): run the full suite on **ProveIt** + one more genuinely-different repo; let ~10 real PRs flow before stacking anything new.
- **P5b — The loop-fired verifier** (the keystone fix): nothing currently proves a routed learning *actually fired* in a later session — the exact V3 failure V4 claims to have fixed, still unverified.
- **P5c — `PROPOSED-LEARNINGS.md` lifecycle**: applied/archived sections so it stops accumulating (cheap closure; was a known bug).
- **P5d — Make the cross-model review earn its keep, with data**: instrument it; if it never surfaces something the author didn't already know, cut it.
- **P5e — Plan-time specialist-nudge**: the architect's value is at PLAN time, but the nudge fires at commit time. Add a plan-time trigger.
- **Design principle (adopt now):** every future gate must have a **code-checkable ground truth** (runtime-smoke does; the cross-model review doesn't — which is *why* it misbehaved). No ground truth → ship it as a *nudge*, not a *gate*.

## Known bugs / cleanups (specific)
- `independent-review` strict mode: prose-matching verdict parser (replace with structured `VERDICT:` parse).
- `PROPOSED-LEARNINGS.md`: no applied/cleared lifecycle.
- `runtime-smoke` UI tier: graceful-skip vs. hard-fail decision for opted-in repos (above).
- Deploy-URL discovery is manual (P1).

## Status (2026-06-09)
- ✅ **P1 shipped** (PR #11): `runtime-smoke.yml` auto-fires on `deployment_status` (live URL via `environment_url`, zero config); `install-gates.sh` copies `ui-smoke.mjs` + seeds `.shipit-gates/smoke.conf`.
- ✅ **P2 shipped** (PR #11): cross-model review is **fully advisory** (never blocks; `SHIPIT_REVIEW_STRICT` opt-in keeps teeth) + size-gated (`SHIPIT_REVIEW_MIN_LINES`, default 10). The strict-mode prose-grep bug was already fixed.
- ✅ **P3 shipped**: `gates/specialist-nudge.sh` (commit-time PreToolUse, non-blocking) nudges `@architect` on architectural surfaces (migrations / `*.sql` / `schema.*` / `api/` / new `package.json` deps) and `@designer` on UI surfaces (components / `*.tsx`·`*.jsx` / `*.css`·`*.scss` / pages·routes). Ships `agents/architect.md` + `agents/designer.md` (team-mode coupling trimmed, like `reviewer.md`). Wired into `install-gates.sh` (idempotent jq-merge into `.claude/settings.json` PreToolUse, mirroring docs-sync). `CLAUDE.md` carries the trigger→`@agent` map + the "summon at PLAN time" note.
- ✅ **P4 shipped (first customer)**: ShipIt's gates installed on **FocusBoard** (PR #21, merged to FocusBoard `main`) — additive only (its existing custom `ci.yml` + `independent-review.yml` preserved). `runtime-smoke` wired to the real failure mode: `SHIPIT_SMOKE_PATHS=/api/capture` (unauth → 401 = function alive; a 504 fails the gate), `SHIPIT_SMOKE_UI=1` + `SELECTOR='#root > *'` (asserts React mounted, catches white-screen). **P1 proven end-to-end twice:** a manual live curl (`/`→200, `/api/capture`→401, `#root > *` rendered) AND `runtime-smoke` firing **by itself in CI** on the PR's preview deploy (`runtime-smoke OK`, 44s). `n` is now ≥1 *real* customer (not a meta-PR). Still open: 2–3 *more* repos before calling the suite broadly proven.
  - *Side-learning (→ MANDATORY.md rule #6):* the install ran in a checkout shared with a parallel FocusBoard session, which raced HEAD/branch state (a commit landed on the wrong branch; recovery dodged the other session's uncommitted WIP). Fix: a `git worktree` per concurrent session. The shared `pre-push` hook then correctly gated the other session's build before its push — the gate worked as designed.
- 🟡 **P5 in progress** — validation & loop-closing (spec below). **This is the gate before any P6/new feature.** The base must survive ~10 real PRs across ≥3 repos AND the learning loop must be *proven* to fire (not assumed) before more machinery is stacked on.
  - 🟡 **P5a (2/3 customers):** **ProveIt** is customer #2 (PR #61, merged) — a **targeted** install (runtime-smoke + advisory review + nudge), preserving its monorepo-aware `ci.yml`/`docs-check.yml`. `runtime-smoke` proven live + in CI on the preview (`/`→200, `/api/waitlist` GET→405 = function alive with **zero LLM cost** since the LLM routes are POST-only, `main` rendered). **Two findings:** (1) the specialist-nudge fired `@designer` on App Router **API routes** under `app/` — a real false positive, **fixed at source** (PR #16: dropped the bare `app/` matcher; `route.ts` stays `@architect`-only). (2) **`install-gates.sh` assumes a root single-package repo — it doesn't fit a monorepo** (ProveIt's app is in `web/`); needs a monorepo mode or a documented "targeted install" path. *Open:* 1 more repo + let ~10 real PRs accrue; start the battle-log.
  - ✅ **P5c shipped:** `PROPOSED-LEARNINGS.md` lifecycle — every entry now carries a `**Status:**` line; `scripts/proposed-learnings.sh` (`--list`/`--applied`/`--apply <n>`/`--archive <n>`) manages it; `route-learning.sh` writes new entries as `pending`. Reconciled the backlog: **8 of 11 entries marked applied** (rule #4, #6, the two global-CLAUDE.md Vercel facts, P1×2, P2, P3 — all verified present before stamping), **3 remain pending** (the #4 verify-corollary, the authed round-trip smoke gate, the acceptance-step-ordering /ship change).
  - ✅ **P5e shipped:** plan-time specialist-nudge. `specialist-nudge.sh` now fires a distinct **PLAN-TIME** `@architect` message when a `docs/plans/*.md` / `ARCHITECTURE.md` / `*prd*.md` is staged (the architect's highest-value moment), with the commit-time code-surface nudge kept as the backstop. `/spec` + `/gameplan` carry an exit-criteria item: summon `@architect` for any architectural surface *before* implementation.
  - ✅ **P5b shipped (v1, free core — keystone)**: the loop-fired verifier. `route-learning.sh` registry is now write-once v2 (`…⇥ACTION_MATCH⇥SURFACE_MATCH`) + tags rules with `learning:<slug>`; `retro-tripwire.sh` greps each turn's tool stream against those patterns and appends `fire`/`opp` events to an **append-only** `learning-events.tsv` (race-safe, MANDATORY #6); `scripts/learning-audit.sh` derives FIRES/OPPS at read time (`--fired`/`--dead-letters`/`--list`); `scripts/note-applied.sh` is the judgment-rule fallback. Designed via an **@architect plan-time review** (dogfooding P5e) which reshaped it: action-match over self-report, OPPS-denominator dead-letters, append-only over in-place mutation, and the honest "plumbing-test ≠ claim-validation" framing (now in the architecture doc's limits). **LLM `--audit` deferred to v2** (the one paid piece — bounded/you-triggered, kept out of the autonomous detection path per cost rule #1; will be added later). Tested end-to-end: fire detection, per-session dedup, genuine-miss/dormant/low-confidence buckets, note-applied fallback, 4-field migration, and the cardinal exit-0 under a malformed pattern.
  - ⏭️ **P5d** still open (review-earns-keep data now accruing on FocusBoard + ProveIt — tally over the next PRs); **P5a** 1 more repo + ~10 PRs + battle-log.

## P3 — implementation spec (agreed: make the @agent summon fire by itself)
**Decision:** the specialists already ARE `@agents` (`@architect`, `@designer`, `@reviewer` in `~/.claude/agents/`; ShipIt ships its own `reviewer`). So P3 is NOT a new skill and NOT a new agent — it's the missing half: a **nudge that summons the existing @agent at the right moment**, in the same family as `gates/docs-sync-reminder.sh` and `gates/retro-sweep-nudge.sh` (read those two first — they are the template).

Build:
1. **`gates/specialist-nudge.sh`** (NEW) — a commit-time `PreToolUse`(Bash) nudge, non-blocking (mirror `docs-sync-reminder.sh`'s structure + exit-0 behaviour). Inspect the staged diff:
   - **Architectural surfaces** → nudge *"summon `@architect` before shipping"*: `**/migrations/**`, `*.sql`, schema/data-model files, `api/` boundary files, new dependencies added to `package.json`, new external integrations.
   - **UI surfaces** → nudge *"summon `@designer`"*: `**/components/**`, `*.tsx`/`*.jsx`, `*.css`/Tailwind, pages/routes.
   - One concise line per matched surface; never block.
2. **Ship `agents/architect.md` + `agents/designer.md`** with the plugin (it already ships `reviewer.md`) — adapt from `~/.claude/agents/` so installed repos are self-contained and the nudge points at real agents.
3. **Wire into `install-gates.sh`** — add the specialist-nudge to `.claude/settings.json` `PreToolUse` via the same idempotent jq-merge used for `docs-sync-reminder` (the `gates/*.sh` copy already ships the script).
4. **`CLAUDE.md`** — a pattern entry: the trigger→`@agent` map + the nudge; note the architect's highest value was at PLAN time (summon before building, not just before shipping).

Verify: stage a fake migration → nudge names `@architect`; stage a `*.tsx` → nudge names `@designer`; `install-gates.sh` into a scratch repo → `.claude/settings.json` carries the nudge; dogfood PR through V4's gates.

## P5 — implementation spec (validation & loop-closing)

**Framing.** V4's success criterion is *"a learning fires by itself next time"* and *"the suite is trusted."* Neither is actually proven yet — P1–P4 built the mechanisms and proved the *runtime* mechanism end-to-end, but the *learning loop's* re-read half (the precise thing that killed V3) is still **assumed**, and `n` is still ≈1. P5 closes both. **Sequencing: P5c + P5e are cheap and can land immediately; P5b is the keystone and gates everything; P5a runs in parallel and is the real evidence. Do NOT start a P6 until P5a has ~10 real PRs and P5b shows ≥1 verified fire.**

### P5a — Battle-test for real (the evidence)
- **Install the full suite on ProveIt** (`~/code/proveit`) — the cited "reference implementation" that today runs only the *precursors* (docs-sync + cost hooks), NOT the full v4 gate set. Make it real: `scripts/install-gates.sh ~/code/proveit`, wire `.shipit-gates/smoke.conf` to ProveIt's actual critical route(s) + UI selector, **preserve any existing custom CI** (the FocusBoard lesson — additive only, don't clobber).
- **Plus one more genuinely-different repo** (ideally not a Claire-from-scratch-with-ShipIt-habits repo — that's what weakens FocusBoard as evidence). Roami/Weather-Mood/Load-Check are candidates.
- **Observe, don't trust:** let ~10 real PRs flow across the repos. **Track per gate:** false-positive rate, the `[no-docs]`/`[no-smoke]`/`[no-review]` escape-hatch rate (a high rate = a miscalibrated gate training reflexive opt-out), and whether `runtime-smoke` ever catches a real break.
- **Verify:** a short `docs/` battle-log table (repo × gate × PRs-observed × FP-rate × escape-rate × did-it-ever-catch-anything). The suite is "broadly proven" only when ≥3 repos × ~10 PRs show low FP + low escape rates.

### P5b — The loop-fired verifier (the keystone)
The whole architecture rests on *routed learning → fires in a future session*. Routing to `MANDATORY.md`/`CLAUDE.md` provably loads (SessionStart injection). **What's missing is proof the loaded rule ever changed behavior** — V3's write-worked/re-read-failed flaw, still unverified in V4.
- **Build a lightweight "fired" signal.** Each routed learning gets a stable id/slug (the index in `route-learning.sh` already exists). Add a way to record a *fire event*: the cheapest version is a marker the tripwire (or a `/retro` sub-step) writes when a session's action traces to a routed rule (e.g. an `applied-learning:<slug>` line, written by hand at first, then prompted). Aggregate into the existing `~/.claude/shipit-retro/learning-index.tsv` as a `last-fired` column.
- **A learning with zero fires after N sessions is a dead letter** — surfaced for review (was it mis-routed? too vague? routed to a mechanism that doesn't actually auto-load?). This is the feedback the loop has never had.
- **Honest limit (state it):** "fired" is itself model-judged (did this action trace to that rule?) — it's a net, not a proof. But *some* signal beats the current *none*. No LLM in the detection path (cost rule #1); aggregation stays free.
- **Verify:** route a test learning, start a fresh session, trigger the behavior, confirm a fire event is recorded against its slug and `last-fired` updates.

### P5c — `PROPOSED-LEARNINGS.md` lifecycle (cheap closure)
- Add an explicit lifecycle: an `## Applied` / `## Archived` section (or a one-line `STATUS:` per entry), and a tiny `scripts/proposed-learnings.sh` (`--apply <slug>` moves an entry to Applied with a date; `--list` shows pending). Today it's hand-marked (`✅ APPLIED 2026-06-09` was written by hand this session).
- **Verify:** `--list` shows only pending; applying one moves it; the file no longer mixes pending + done.

### P5d — Make the cross-model review earn its keep (decide with data)
- It's advisory + size-gated now (de-risked), but advisory-and-useless is just latency + a GitHub Models call. **Instrument, then decide.** Over P5a's ~10 PRs, the review comment already posts findings — manually (or via a tally) record: did it surface anything the author/Claude **didn't already know**? 
- **Decision rule:** if the "novel catch" rate is ~0 across the battle-test, **cut it** (or downgrade to opt-in-only). Don't keep it on sunk cost. If it earns ≥a few real catches, keep advisory.
- **Verify:** a one-line verdict in the battle-log ("review: N PRs, M novel catches → keep / cut").

### P5e — Plan-time specialist-nudge (the P3 follow-up)
- The architect's highest value is at **PLAN time**; `specialist-nudge.sh` fires at **commit time** (design already built — backstop, not value). Add a plan-time trigger: nudge `@architect` when a `docs/plans/*.md` / PRD / `ARCHITECTURE.md` is staged, and/or fold the summon into `/gameplan` + `/spec` (their templates can emit "architectural surface detected — summon @architect now, before building"). Keep the commit-time nudge as the backstop.
- **Verify:** stage a new `docs/plans/*.md` → nudge fires at plan time naming `@architect`; `/gameplan` on an architecture-touching spec prompts the summon.

### Design principle (adopt for all future gates)
**Ground-truth filter:** before building any gate, ask *"is there a code-checkable ground truth?"* `runtime-smoke` has one (HTTP status / DOM render) — it's the gate that actually caught the 504. The cross-model review has none (judgment all the way down) — which is *why* it false-positived for 7 rounds and passed green on broken code. **No ground truth → ship it as a non-blocking nudge, not a blocking gate.** This single rule predicts both outcomes in advance; apply it to every P6+ idea.

## What NOT to change
The thesis is sound; don't re-add orchestration. The cheap gates, the ad-hoc specialists, and the retro loop are the keepers. The fix is **rebalancing**: less weight on the LLM review, more on runtime verification + the specialist pattern. **And (P5):** don't add the *next* mechanism until the current base is validated and the learning loop is *proven* to fire — stacking on an unproven base is the one move that turns V4 back into V3.
