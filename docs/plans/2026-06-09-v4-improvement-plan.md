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

## What NOT to change
The thesis is sound; don't re-add orchestration. The cheap gates, the ad-hoc specialists, and the retro loop are the keepers. The fix is **rebalancing**: less weight on the LLM review, more on runtime verification + the specialist pattern.
