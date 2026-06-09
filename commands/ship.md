---
name: ship
description: Run all ShipIt V4 gates on demand, then open the PR. The gates also fire by themselves (hooks + CI) even if you never call /ship — this is the convenience that runs them in one pass and triggers the LLM-billed ones (retro sweep, and the independent review on the PR).
---

# /ship — run the gates, then open the PR

You are running the ShipIt V4 ship sequence. **The gates are not optional and not yours to skip** — most fire automatically (hooks + CI). `/ship` runs them all in one pass *now* and opens the PR so the independent review fires. If a gate fails, stop and fix it; don't push past it.

Run in order, on the current branch (never on `main`):

1. **Branch check.** If on `main`, stop — `git switch -c <branch>` first. (The `no-push-to-main` hook enforces this anyway.)

2. **Mechanical gates (free, no LLM).** Run them and fix anything red before continuing:
   ```bash
   bash gates/pre-push-checks.sh        # test / typecheck / build + conflict markers ([no-test] override)
   bash gates/check-docs-sync.sh --staged   # docs kept in sync with code ([no-docs] override)
   ```
   (`block-sensitive-paths` and `detect-secrets` already ran as hooks during the work.)

3. **Retro sweep (LLM, on demand).** Run `/retro` to capture this session's learnings before they're lost — the tripwire has been marking candidates the whole time. This is the bounded, you-triggered cost.

4. **Commit + push the branch.** Conventional message. Push to the branch, not main.

5. **Open the PR.** `gh pr create --fill`. This triggers the **independent cross-model review** (`.github/workflows/independent-review.yml`) — a non-Claude model reviews your work because the author doesn't review its own. Read its findings; address any genuine MUST-FIX.

6. **Runtime smoke-test — once it deploys (green CI is NOT proof it works).** Once gates are installed this **fires automatically in CI** (`runtime-smoke.yml`, on GitHub's `deployment_status` event — reads routes from `.shipit-gates/smoke.conf`), so you usually just read its result. To run it locally / on-demand when a preview-or-prod URL exists, hit the *live* artifact directly:
   ```bash
   SHIPIT_DEPLOY_URL="<preview-or-prod-url>" \
   SHIPIT_SMOKE_PATHS="/,/api/health,<your critical routes>" \
   SHIPIT_SMOKE_UI=1 \
   bash gates/runtime-smoke-test.sh        # HTTP non-5xx + the page actually RENDERS (Playwright)
   ```
   This is the gate the 504 taught us we needed — a Hono catch-all passed build/test/deploy/review and still 504'd every route; only a live request caught it. For real user-flow coverage, point tier 3 at your suite: `SHIPIT_SMOKE_E2E_CMD="npx playwright test"` (or `cypress run` / `cucumber-js`) — it runs against the deploy. Override a genuine exception with `[no-smoke]`.

   **The smoke tiers prove liveness/routing/auth, NOT data correctness** — wrong rows returned to an authenticated caller pass every unauth check (FocusBoard's inbox status-filter bug). When the surface has authenticated reads, wire the authed tier: a low-privilege test token as a CI secret (`SHIPIT_SMOKE_AUTH_TOKEN`) + `SHIPIT_SMOKE_AUTH_PATHS`/`SHIPIT_SMOKE_AUTH_CMD` in `smoke.conf`.

   **Hoist credential-gated acceptance checks to FIRST-shippable, not last.** If an acceptance criterion needs a real credential the session doesn't hold (a user's API token, a login), surface the 1-minute manual step — or get a test credential provisioned — at the moment the surface first works, BEFORE building the next layer on top. FocusBoard Phase 1 deferred "capture appears in the inbox, live" to a closing checklist item; it caught a real bug, but only post-merge, forcing a follow-up fix against shipped code. The cheapest correctness gate (a human with a real token, 60 seconds) must not be scheduled last.

7. **Report.** Which gates passed, what the review said, **the runtime smoke result**, the PR link. If a gate is red, say so plainly — do not declare success.

## The rule
v3's gates were prose and got skipped. Here they're hooks + CI, so they fire whether or not `/ship` is called. `/ship` is the one-pass convenience — it does not *replace* the enforcement, and it never licenses skipping a red gate. Use an override token (`[no-docs]`, `[no-test]`) only for a genuine, conscious exception.
