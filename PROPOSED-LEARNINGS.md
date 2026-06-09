# Proposed learnings

User-scope or enforcement changes the learning loop will NOT auto-apply — review each, then
apply by hand (or via PR) to the named target.

**Lifecycle (P5c).** Every entry carries a `**Status:**` line — `pending`, `applied — <date> — <where>`,
or `archived — <date> — <reason>`. Manage it with `scripts/proposed-learnings.sh` so the file
stops accumulating "awaiting review" forever (the rot the improvement plan flagged):

- `scripts/proposed-learnings.sh` — list pending (default)
- `scripts/proposed-learnings.sh --applied` / `--archived` / `--all`
- `scripts/proposed-learnings.sh --apply <n> "<where>"` — stamp entry *n* applied
- `scripts/proposed-learnings.sh --archive <n> "<reason>"` — stamp entry *n* archived

`route-learning.sh` writes new entries as `**Status:** pending`. Pending = still owes a human action.

## 2026-06-09 — rule/user

**Status:** applied — 2026-06-09 — MANDATORY.md #4 (runtime-broken corollary)

**Learning:** Green build + passing tests + green deploy + passing code-review can ALL be true while the deployed code is runtime-broken — only a real HTTP request (curl) or Playwright pass against the deployed artifact proves it works.

**Why:** FocusBoard: 661 tests + build + Vercel deploy + cross-model review all green, yet every route 504'd because hono/vercel handle() returns a Web handler on Vercel's Node runtime and tests called app.fetch() in-process, bypassing the adapter. Sharpens the existing MANDATORY 'verify in a real run' rule. Universal verification stance, applies to any repo.

**Apply to:** `~/.claude/MANDATORY.md`

**Ready-to-apply snippet:**

```
- **Green build + passing tests + green deploy + passing code-review can ALL be true while the deployed code is runtime-broken — only a real HTTP request (curl) or Playwright pass against the deployed artifact proves it works.** — FocusBoard: 661 tests + build + Vercel deploy + cross-model review all green, yet every route 504'd because hono/vercel handle() returns a Web handler on Vercel's Node runtime and tests called app.fetch() in-process, bypassing the adapter. Sharpens the existing MANDATORY 'verify in a real run' rule. Universal verification stance, applies to any repo.
```

## 2026-06-09 — check/project

**Status:** applied — 2026-06-09 — P1 — gates/runtime-smoke-test.sh + runtime-smoke.yml

**Learning:** Add a post-deploy runtime smoke-test gate to ShipIt V4 (/ship step + gates/runtime-smoke-test.sh): when a deploy URL is present, curl the live endpoint (assert non-5xx, non-timeout) and optionally drive one Playwright path before declaring done. [no-smoke] override.

**Why:** FocusBoard incident: S4 (test/typecheck/build) + independent-review gates were ALL green on code where every route 504'd at runtime. The gate suite has no step that hits the DEPLOYED artifact. User asked to update ship hooks. Recommendation: deploy-conditional (gate only when a URL exists), mirroring [no-test]/[no-docs]. Enforcement change to ShipIt's own gates -> propose.

**Apply to:** `repo CI + project hook (<repo>/hooks/)`

**Ready-to-apply snippet:**

```
- **Add a post-deploy runtime smoke-test gate to ShipIt V4 (/ship step + gates/runtime-smoke-test.sh): when a deploy URL is present, curl the live endpoint (assert non-5xx, non-timeout) and optionally drive one Playwright path before declaring done. [no-smoke] override.** — FocusBoard incident: S4 (test/typecheck/build) + independent-review gates were ALL green on code where every route 504'd at runtime. The gate suite has no step that hits the DEPLOYED artifact. User asked to update ship hooks. Recommendation: deploy-conditional (gate only when a URL exists), mirroring [no-test]/[no-docs]. Enforcement change to ShipIt's own gates -> propose.
```

## 2026-06-09 — fact/user

**Status:** applied — 2026-06-09 — ~/.claude/CLAUDE.md (Vercel api/ blind spot)

**Learning:** On Vercel projects, local tsc -b / the typecheck script often EXCLUDES the serverless api/ directory — only Vercel's per-function builder type-checks it, so an api/ type error passes local typecheck+build and fails only at deploy. Type-check api/ explicitly (or expect Vercel to catch what local checks miss).

**Why:** FocusBoard: an api/ type error passed local typecheck + build and only failed at the Vercel deploy. General Vercel-toolchain blind spot, true on any repo with a serverless api/ dir. User-scope fact -> lands in ~/.claude/CLAUDE.md (NOT global memory, which doesn't auto-load).

**Apply to:** `~/.claude/CLAUDE.md (NOT global memory — it doesn't auto-load)`

**Ready-to-apply snippet:**

```
- **On Vercel projects, local tsc -b / the typecheck script often EXCLUDES the serverless api/ directory — only Vercel's per-function builder type-checks it, so an api/ type error passes local typecheck+build and fails only at deploy. Type-check api/ explicitly (or expect Vercel to catch what local checks miss).** — FocusBoard: an api/ type error passed local typecheck + build and only failed at the Vercel deploy. General Vercel-toolchain blind spot, true on any repo with a serverless api/ dir. User-scope fact -> lands in ~/.claude/CLAUDE.md (NOT global memory, which doesn't auto-load).
```

## 2026-06-09 — fact/user

**Status:** applied — 2026-06-09 — ~/.claude/CLAUDE.md (Vercel/Hono facts)

**Learning:** Vercel/Hono reference facts: Hobby plan caps at 12 serverless functions per deployment (Fluid Compute does NOT change the count); the fix is one router function per app (a Hono catch-all at api/[...path].ts); hono/vercel handle() 504s on the Node runtime and needs a (req,res)->app.fetch() adapter.

**Why:** These platform facts caused and resolved the FocusBoard incident: the 12-function cap forced the catch-all consolidation; handle()-on-Node was the 504 root cause. Cheap to record, expensive to rediscover. Universal Vercel/Hono knowledge -> ~/.claude/CLAUDE.md.

**Apply to:** `~/.claude/CLAUDE.md (NOT global memory — it doesn't auto-load)`

**Ready-to-apply snippet:**

```
- **Vercel/Hono reference facts: Hobby plan caps at 12 serverless functions per deployment (Fluid Compute does NOT change the count); the fix is one router function per app (a Hono catch-all at api/[...path].ts); hono/vercel handle() 504s on the Node runtime and needs a (req,res)->app.fetch() adapter.** — These platform facts caused and resolved the FocusBoard incident: the 12-function cap forced the catch-all consolidation; handle()-on-Node was the 504 root cause. Cheap to record, expensive to rediscover. Universal Vercel/Hono knowledge -> ~/.claude/CLAUDE.md.
```

## 2026-06-09 — procedure/project

**Status:** applied — 2026-06-09 — P2 — independent-review.yml advisory + size-gated

**Learning:** ShipIt's cross-model review is a signal, not a gate: demote it to advisory (off the required-check/branch-protection path), document that it catches diff-level issues (logic/contracts/naming) NOT runtime correctness, replace the prose-grep verdict parser with structured VERDICT parsing, and size-gate it off trivial PRs.

**Why:** In the wild it took ~7 calibration rounds, shipped real bugs (strict-mode matched 'no [MUST-FIX]' prose), and passed GREEN on the FocusBoard PR that 504'd every route. No diff review catches a runtime bug — it was oversold as the headline gate.

**Apply to:** `<repo> (review placement)`

**Ready-to-apply snippet:**

```
- **ShipIt's cross-model review is a signal, not a gate: demote it to advisory (off the required-check/branch-protection path), document that it catches diff-level issues (logic/contracts/naming) NOT runtime correctness, replace the prose-grep verdict parser with structured VERDICT parsing, and size-gate it off trivial PRs.** — In the wild it took ~7 calibration rounds, shipped real bugs (strict-mode matched 'no [MUST-FIX]' prose), and passed GREEN on the FocusBoard PR that 504'd every route. No diff review catches a runtime bug — it was oversold as the headline gate.
```

## 2026-06-09 — check/project

**Status:** applied — 2026-06-09 — P1 — install-gates.sh + runtime-smoke.yml deployment_status

**Learning:** Finish wiring the runtime-smoke gate so it fires by itself: into install-gates.sh + ci-templates/ci.yml (not just /ship prose), with automatic deploy-URL discovery from Vercel/CI output instead of manual SHIPIT_DEPLOY_URL.

**Why:** The runtime-verification gap was V4's real blind spot — every gate green on a dead 504 deploy. The new gate patches it but only runs when a human runs /ship; 'runs by itself' is the V4 thesis.

**Apply to:** `repo CI + project hook (<repo>/hooks/)`

**Ready-to-apply snippet:**

```
- **Finish wiring the runtime-smoke gate so it fires by itself: into install-gates.sh + ci-templates/ci.yml (not just /ship prose), with automatic deploy-URL discovery from Vercel/CI output instead of manual SHIPIT_DEPLOY_URL.** — The runtime-verification gap was V4's real blind spot — every gate green on a dead 504 deploy. The new gate patches it but only runs when a human runs /ship; 'runs by itself' is the V4 thesis.
```

## 2026-06-09 — procedure/project

**Status:** applied — 2026-06-09 — P3 — gates/specialist-nudge.sh + agents/{architect,designer}.md

**Learning:** Make ad-hoc specialist summon (architect/designer) a first-class documented ShipIt pattern: summon the architect for any PR touching architecture/data-model/a new external boundary; the designer for user-facing surfaces.

**Why:** It was the single highest-value output of the session (the architect review prevented a bad FocusBoard build) yet is currently implicit/manual. The cheap parts carried V4; promote them.

**Apply to:** `<repo> (review placement)`

**Ready-to-apply snippet:**

```
- **Make ad-hoc specialist summon (architect/designer) a first-class documented ShipIt pattern: summon the architect for any PR touching architecture/data-model/a new external boundary; the designer for user-facing surfaces.** — It was the single highest-value output of the session (the architect review prevented a bad FocusBoard build) yet is currently implicit/manual. The cheap parts carried V4; promote them.
```

## 2026-06-09 — rule/user

**Status:** applied — 2026-06-09 — MANDATORY.md #6 (parallel-session worktree)

**Learning:** When two Claude sessions may touch the same repo, give each its own git worktree (git worktree add, or the Agent tool's isolation:"worktree") — separate context windows are NOT separate working trees: HEAD, the index, and the tree are per-checkout and will race.

**Why:** Two sessions (a ShipIt thread and a FocusBoard thread, kept separate by design to save context) shared ONE checkout at /Users/clairedonald/code/focusboard. The FocusBoard session ran 'git checkout -b phase0.5-hardening' between the ShipIt session's stage and commit, so commit 74c7d76 landed on the wrong branch; 'git push -u origin shipit-gates-install' then created an EMPTY remote branch and 'gh pr create' failed ('No commits between main and shipit-gates-install'). Recovery had to use pointer-only moves (git branch -f to capture 74c7d76 and to restore phase0.5-hardening) and deliberately AVOID 'git reset --hard' because the shared tree held the other session's uncommitted mid-refactor WIP (api/_lib/auth-middleware.ts, token.ts, envelope.ts). The push was then blocked by the pre-push build hook failing on the OTHER session's broken edits, so 'git push --no-verify' was used legitimately (the commit held zero buildable source — only .sh/.yml/.json/.mjs/.conf gate files — and CI re-runs the real build server-side). Root cause: branch state, index, and working tree are per-CHECKOUT, not per-session. Recurs on ANY repo whenever Claire runs the deliberate parallel-session pattern, so user-scope. Recovery corollaries to keep: re-check 'git branch --show-current' immediately before commit in any possibly-shared repo; '--no-verify' is legitimate ONLY when your commit provably has no buildable source AND CI re-verifies; prefer pointer-only moves (git branch -f) over reset --hard when a shared tree holds another session's uncommitted work.

**Apply to:** `~/.claude/MANDATORY.md`

**Ready-to-apply snippet:**

```
- **When two Claude sessions may touch the same repo, give each its own git worktree (git worktree add, or the Agent tool's isolation:"worktree") — separate context windows are NOT separate working trees: HEAD, the index, and the tree are per-checkout and will race.** — Two sessions (a ShipIt thread and a FocusBoard thread, kept separate by design to save context) shared ONE checkout at /Users/clairedonald/code/focusboard. The FocusBoard session ran 'git checkout -b phase0.5-hardening' between the ShipIt session's stage and commit, so commit 74c7d76 landed on the wrong branch; 'git push -u origin shipit-gates-install' then created an EMPTY remote branch and 'gh pr create' failed ('No commits between main and shipit-gates-install'). Recovery had to use pointer-only moves (git branch -f to capture 74c7d76 and to restore phase0.5-hardening) and deliberately AVOID 'git reset --hard' because the shared tree held the other session's uncommitted mid-refactor WIP (api/_lib/auth-middleware.ts, token.ts, envelope.ts). The push was then blocked by the pre-push build hook failing on the OTHER session's broken edits, so 'git push --no-verify' was used legitimately (the commit held zero buildable source — only .sh/.yml/.json/.mjs/.conf gate files — and CI re-runs the real build server-side). Root cause: branch state, index, and working tree are per-CHECKOUT, not per-session. Recurs on ANY repo whenever Claire runs the deliberate parallel-session pattern, so user-scope. Recovery corollaries to keep: re-check 'git branch --show-current' immediately before commit in any possibly-shared repo; '--no-verify' is legitimate ONLY when your commit provably has no buildable source AND CI re-verifies; prefer pointer-only moves (git branch -f) over reset --hard when a shared tree holds another session's uncommitted work.
```

## 2026-06-09 — rule/user

**Status:** applied — 2026-06-09 — MANDATORY.md #7 (applied by Claire)

**Learning:** After a state-changing op (merge/deploy/push), VERIFY the end state with a fresh query before claiming it happened — don't infer success from a command that merely didn't error. Corollary to MANDATORY #4. Specifics: `gh pr merge` can be silently BLOCKED by branch protection / pending checks (it prints the `--admin` hint and does NOT merge); never place an unconditional success `echo` after a state-changing command in an `&&` chain (the echo becomes a false claim); beware `git checkout` reverting working-tree files and masking the un-merged state. Re-check with e.g. `gh pr view <n> --json state,mergedAt` and `git show origin/main:<file>`.

**Why:** Shipped PR #16 in shipit-v4 via one chained Bash call: 'gh pr merge 16 --squash --delete-branch ... && git checkout -q main && git pull ... && echo "fix merged"'. The merge was BLOCKED (pending checks + branch protection; gh printed the --admin hint) and did NOT merge, but the chain still ran 'git checkout main' (reverting the working file to pre-fix, masking it) and echoed a success claim I had not verified, then reported 'merged' to the user. Only caught via a later system-reminder showing on-disk old code; 'gh pr view 16 --json state' returned OPEN and 'git show origin/main:<file>' showed the old version. MANDATORY #4 ('verify in a real run before claiming completion') is the parent rule but its general wording did not prevent this — the gh-merge-block + unconditional-echo-in-chain + masking-checkout mechanism is specific and non-obvious, so route as a concrete operational COROLLARY to #4, not a new top-level rule. User-scope (gh/git chaining habit, holds on any repo) -> propose.

**Apply to:** `~/.claude/MANDATORY.md`

**Ready-to-apply snippet:**

```
- **After a state-changing op (merge/deploy/push), VERIFY the end state with a fresh query before claiming it happened — don't infer success from a command that merely didn't error. Corollary to MANDATORY #4. Specifics: `gh pr merge` can be silently BLOCKED by branch protection / pending checks (it prints the `--admin` hint and does NOT merge); never place an unconditional success `echo` after a state-changing command in an `&&` chain (the echo becomes a false claim); beware `git checkout` reverting working-tree files and masking the un-merged state. Re-check with e.g. `gh pr view <n> --json state,mergedAt` and `git show origin/main:<file>`.** — Shipped PR #16 in shipit-v4 via one chained Bash call: 'gh pr merge 16 --squash --delete-branch ... && git checkout -q main && git pull ... && echo "fix merged"'. The merge was BLOCKED (pending checks + branch protection; gh printed the --admin hint) and did NOT merge, but the chain still ran 'git checkout main' (reverting the working file to pre-fix, masking it) and echoed a success claim I had not verified, then reported 'merged' to the user. Only caught via a later system-reminder showing on-disk old code; 'gh pr view 16 --json state' returned OPEN and 'git show origin/main:<file>' showed the old version. MANDATORY #4 ('verify in a real run before claiming completion') is the parent rule but its general wording did not prevent this — the gh-merge-block + unconditional-echo-in-chain + masking-checkout mechanism is specific and non-obvious, so route as a concrete operational COROLLARY to #4, not a new top-level rule. User-scope (gh/git chaining habit, holds on any repo) -> propose.
```

## 2026-06-09 — check/project

**Status:** pending

**Learning:** The runtime-smoke gate's ceiling is liveness/routing/auth, NOT data correctness — document this limit on the gate, and add the next rung: an OPTIONAL authenticated post-deploy smoke that, when a low-privilege test PAT is present as a CI secret, drives one idempotent round-trip (capture -> list shows it -> dismiss) and asserts the row comes back. Deploy-conditional + credential-conditional, mirroring [no-smoke].

**Why:** FocusBoard bug #3: GET /api/capture filtered status='pending' only and returned nothing the moment the AI pipeline promoted pending->ready. 46 mocked-DB tests, lint/typecheck/build, the runtime-smoke gate (unauth status codes only), and cross-model review were ALL green. Caught by Claire's first real-token run (PR #25). Third FocusBoard bug invisible to green CI (1: Hono 504; 2: multi-segment 404 — both led to the smoke gate; 3: this). The smoke gate closed bugs 1+2's class (liveness/routing) but by construction cannot see wrong-rows-to-an-authed-caller. An authed round-trip smoke is the first gate that catches bug #3's class automatically. Enforcement change to ShipIt's own gates -> propose, don't auto-apply.

**Apply to:** `repo CI + project hook (<repo>/hooks/) — extend gates/runtime-smoke-test.sh`

**Ready-to-apply snippet:**

```
- **The runtime-smoke gate proves liveness/routing/auth, NOT data correctness. Add an OPTIONAL authenticated round-trip rung: when a low-privilege test PAT is present as a CI secret, drive one idempotent capture -> list-shows-it -> dismiss and assert the row comes back. Deploy- and credential-conditional, mirroring [no-smoke].** — FocusBoard bug #3: GET /api/capture filtered status='pending' only, returning nothing once the AI pipeline promoted pending->ready. 46 mocked-DB tests + build + runtime-smoke (unauth codes only) + cross-model review ALL green; caught by the first real-token run (PR #25). Third FocusBoard bug invisible to green CI; the smoke gate's ceiling is exactly this blind spot.
```

## 2026-06-09 — procedure/project

**Status:** pending

**Learning:** Manual acceptance steps that gate CORRECTNESS must run before building on top of the surface, not as the closing step. When a real credential is the only thing blocking an e2e correctness check, /ship should surface the 1-minute manual step (or prompt to provision a test credential) at the point the surface is first shippable — not defer it to a final post-merge checklist item.

**Why:** FocusBoard Phase 1's acceptance criterion ("CLI captures into prod; web inbox shows it live") was deferred to Claire as a final 1-minute step. It DID catch bug #3 (the status-filter inbox bug) — but only after merge + deploy, so the fix was a follow-up PR (#25) against already-shipped code rather than a pre-merge correction. The cheapest gate available (a human with a real token, 60 seconds) was scheduled last. Sequencing insight for /ship: a correctness-gating manual step blocked only by a credential should be hoisted to first-shippable, not last.

**Apply to:** `ShipIt /ship step ordering (docs/prose) + acceptance-criteria handling`

**Ready-to-apply snippet:**

```
- **Manual acceptance steps that gate correctness must run before building on top of the surface, not as the closing step — when a real credential is the only thing blocking an e2e correctness check, surface the 1-minute manual step (or provision a test credential) at first-shippable, not in a final post-merge checklist.** — FocusBoard Phase 1 deferred "CLI captures into prod; web inbox shows it live" to a final step; it caught bug #3 but only post-merge, forcing fix PR #25 against shipped code. The cheapest correctness gate (a human with a real token, 60s) was scheduled last.
```
