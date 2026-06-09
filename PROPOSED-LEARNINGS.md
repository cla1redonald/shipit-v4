# Proposed learnings — awaiting human review

These are user-scope or enforcement changes the learning loop will NOT auto-apply.
Review each, then apply by hand (or via PR) to the named target.

## 2026-06-09 — rule/user

**Learning:** Green build + passing tests + green deploy + passing code-review can ALL be true while the deployed code is runtime-broken — only a real HTTP request (curl) or Playwright pass against the deployed artifact proves it works.

**Why:** FocusBoard: 661 tests + build + Vercel deploy + cross-model review all green, yet every route 504'd because hono/vercel handle() returns a Web handler on Vercel's Node runtime and tests called app.fetch() in-process, bypassing the adapter. Sharpens the existing MANDATORY 'verify in a real run' rule. Universal verification stance, applies to any repo.

**Apply to:** `~/.claude/MANDATORY.md`

**Ready-to-apply snippet:**

```
- **Green build + passing tests + green deploy + passing code-review can ALL be true while the deployed code is runtime-broken — only a real HTTP request (curl) or Playwright pass against the deployed artifact proves it works.** — FocusBoard: 661 tests + build + Vercel deploy + cross-model review all green, yet every route 504'd because hono/vercel handle() returns a Web handler on Vercel's Node runtime and tests called app.fetch() in-process, bypassing the adapter. Sharpens the existing MANDATORY 'verify in a real run' rule. Universal verification stance, applies to any repo.
```

## 2026-06-09 — check/project

**Learning:** Add a post-deploy runtime smoke-test gate to ShipIt V4 (/ship step + gates/runtime-smoke-test.sh): when a deploy URL is present, curl the live endpoint (assert non-5xx, non-timeout) and optionally drive one Playwright path before declaring done. [no-smoke] override.

**Why:** FocusBoard incident: S4 (test/typecheck/build) + independent-review gates were ALL green on code where every route 504'd at runtime. The gate suite has no step that hits the DEPLOYED artifact. User asked to update ship hooks. Recommendation: deploy-conditional (gate only when a URL exists), mirroring [no-test]/[no-docs]. Enforcement change to ShipIt's own gates -> propose.

**Apply to:** `repo CI + project hook (<repo>/hooks/)`

**Ready-to-apply snippet:**

```
- **Add a post-deploy runtime smoke-test gate to ShipIt V4 (/ship step + gates/runtime-smoke-test.sh): when a deploy URL is present, curl the live endpoint (assert non-5xx, non-timeout) and optionally drive one Playwright path before declaring done. [no-smoke] override.** — FocusBoard incident: S4 (test/typecheck/build) + independent-review gates were ALL green on code where every route 504'd at runtime. The gate suite has no step that hits the DEPLOYED artifact. User asked to update ship hooks. Recommendation: deploy-conditional (gate only when a URL exists), mirroring [no-test]/[no-docs]. Enforcement change to ShipIt's own gates -> propose.
```

## 2026-06-09 — fact/user

**Learning:** On Vercel projects, local tsc -b / the typecheck script often EXCLUDES the serverless api/ directory — only Vercel's per-function builder type-checks it, so an api/ type error passes local typecheck+build and fails only at deploy. Type-check api/ explicitly (or expect Vercel to catch what local checks miss).

**Why:** FocusBoard: an api/ type error passed local typecheck + build and only failed at the Vercel deploy. General Vercel-toolchain blind spot, true on any repo with a serverless api/ dir. User-scope fact -> lands in ~/.claude/CLAUDE.md (NOT global memory, which doesn't auto-load).

**Apply to:** `~/.claude/CLAUDE.md (NOT global memory — it doesn't auto-load)`

**Ready-to-apply snippet:**

```
- **On Vercel projects, local tsc -b / the typecheck script often EXCLUDES the serverless api/ directory — only Vercel's per-function builder type-checks it, so an api/ type error passes local typecheck+build and fails only at deploy. Type-check api/ explicitly (or expect Vercel to catch what local checks miss).** — FocusBoard: an api/ type error passed local typecheck + build and only failed at the Vercel deploy. General Vercel-toolchain blind spot, true on any repo with a serverless api/ dir. User-scope fact -> lands in ~/.claude/CLAUDE.md (NOT global memory, which doesn't auto-load).
```

## 2026-06-09 — fact/user

**Learning:** Vercel/Hono reference facts: Hobby plan caps at 12 serverless functions per deployment (Fluid Compute does NOT change the count); the fix is one router function per app (a Hono catch-all at api/[...path].ts); hono/vercel handle() 504s on the Node runtime and needs a (req,res)->app.fetch() adapter.

**Why:** These platform facts caused and resolved the FocusBoard incident: the 12-function cap forced the catch-all consolidation; handle()-on-Node was the 504 root cause. Cheap to record, expensive to rediscover. Universal Vercel/Hono knowledge -> ~/.claude/CLAUDE.md.

**Apply to:** `~/.claude/CLAUDE.md (NOT global memory — it doesn't auto-load)`

**Ready-to-apply snippet:**

```
- **Vercel/Hono reference facts: Hobby plan caps at 12 serverless functions per deployment (Fluid Compute does NOT change the count); the fix is one router function per app (a Hono catch-all at api/[...path].ts); hono/vercel handle() 504s on the Node runtime and needs a (req,res)->app.fetch() adapter.** — These platform facts caused and resolved the FocusBoard incident: the 12-function cap forced the catch-all consolidation; handle()-on-Node was the 504 root cause. Cheap to record, expensive to rediscover. Universal Vercel/Hono knowledge -> ~/.claude/CLAUDE.md.
```

## 2026-06-09 — procedure/project

**Learning:** ShipIt's cross-model review is a signal, not a gate: demote it to advisory (off the required-check/branch-protection path), document that it catches diff-level issues (logic/contracts/naming) NOT runtime correctness, replace the prose-grep verdict parser with structured VERDICT parsing, and size-gate it off trivial PRs.

**Why:** In the wild it took ~7 calibration rounds, shipped real bugs (strict-mode matched 'no [MUST-FIX]' prose), and passed GREEN on the FocusBoard PR that 504'd every route. No diff review catches a runtime bug — it was oversold as the headline gate.

**Apply to:** `<repo> (review placement)`

**Ready-to-apply snippet:**

```
- **ShipIt's cross-model review is a signal, not a gate: demote it to advisory (off the required-check/branch-protection path), document that it catches diff-level issues (logic/contracts/naming) NOT runtime correctness, replace the prose-grep verdict parser with structured VERDICT parsing, and size-gate it off trivial PRs.** — In the wild it took ~7 calibration rounds, shipped real bugs (strict-mode matched 'no [MUST-FIX]' prose), and passed GREEN on the FocusBoard PR that 504'd every route. No diff review catches a runtime bug — it was oversold as the headline gate.
```

## 2026-06-09 — check/project

**Learning:** Finish wiring the runtime-smoke gate so it fires by itself: into install-gates.sh + ci-templates/ci.yml (not just /ship prose), with automatic deploy-URL discovery from Vercel/CI output instead of manual SHIPIT_DEPLOY_URL.

**Why:** The runtime-verification gap was V4's real blind spot — every gate green on a dead 504 deploy. The new gate patches it but only runs when a human runs /ship; 'runs by itself' is the V4 thesis.

**Apply to:** `repo CI + project hook (<repo>/hooks/)`

**Ready-to-apply snippet:**

```
- **Finish wiring the runtime-smoke gate so it fires by itself: into install-gates.sh + ci-templates/ci.yml (not just /ship prose), with automatic deploy-URL discovery from Vercel/CI output instead of manual SHIPIT_DEPLOY_URL.** — The runtime-verification gap was V4's real blind spot — every gate green on a dead 504 deploy. The new gate patches it but only runs when a human runs /ship; 'runs by itself' is the V4 thesis.
```

## 2026-06-09 — procedure/project

**Learning:** Make ad-hoc specialist summon (architect/designer) a first-class documented ShipIt pattern: summon the architect for any PR touching architecture/data-model/a new external boundary; the designer for user-facing surfaces.

**Why:** It was the single highest-value output of the session (the architect review prevented a bad FocusBoard build) yet is currently implicit/manual. The cheap parts carried V4; promote them.

**Apply to:** `<repo> (review placement)`

**Ready-to-apply snippet:**

```
- **Make ad-hoc specialist summon (architect/designer) a first-class documented ShipIt pattern: summon the architect for any PR touching architecture/data-model/a new external boundary; the designer for user-facing surfaces.** — It was the single highest-value output of the session (the architect review prevented a bad FocusBoard build) yet is currently implicit/manual. The cheap parts carried V4; promote them.
```

## 2026-06-09 — rule/user — ✅ APPLIED 2026-06-09 (added as MANDATORY.md rule #6, condensed)

**Learning:** When two Claude sessions may touch the same repo, give each its own git worktree (git worktree add, or the Agent tool's isolation:"worktree") — separate context windows are NOT separate working trees: HEAD, the index, and the tree are per-checkout and will race.

**Why:** Two sessions (a ShipIt thread and a FocusBoard thread, kept separate by design to save context) shared ONE checkout at /Users/clairedonald/code/focusboard. The FocusBoard session ran 'git checkout -b phase0.5-hardening' between the ShipIt session's stage and commit, so commit 74c7d76 landed on the wrong branch; 'git push -u origin shipit-gates-install' then created an EMPTY remote branch and 'gh pr create' failed ('No commits between main and shipit-gates-install'). Recovery had to use pointer-only moves (git branch -f to capture 74c7d76 and to restore phase0.5-hardening) and deliberately AVOID 'git reset --hard' because the shared tree held the other session's uncommitted mid-refactor WIP (api/_lib/auth-middleware.ts, token.ts, envelope.ts). The push was then blocked by the pre-push build hook failing on the OTHER session's broken edits, so 'git push --no-verify' was used legitimately (the commit held zero buildable source — only .sh/.yml/.json/.mjs/.conf gate files — and CI re-runs the real build server-side). Root cause: branch state, index, and working tree are per-CHECKOUT, not per-session. Recurs on ANY repo whenever Claire runs the deliberate parallel-session pattern, so user-scope. Recovery corollaries to keep: re-check 'git branch --show-current' immediately before commit in any possibly-shared repo; '--no-verify' is legitimate ONLY when your commit provably has no buildable source AND CI re-verifies; prefer pointer-only moves (git branch -f) over reset --hard when a shared tree holds another session's uncommitted work.

**Apply to:** `~/.claude/MANDATORY.md`

**Ready-to-apply snippet:**

```
- **When two Claude sessions may touch the same repo, give each its own git worktree (git worktree add, or the Agent tool's isolation:"worktree") — separate context windows are NOT separate working trees: HEAD, the index, and the tree are per-checkout and will race.** — Two sessions (a ShipIt thread and a FocusBoard thread, kept separate by design to save context) shared ONE checkout at /Users/clairedonald/code/focusboard. The FocusBoard session ran 'git checkout -b phase0.5-hardening' between the ShipIt session's stage and commit, so commit 74c7d76 landed on the wrong branch; 'git push -u origin shipit-gates-install' then created an EMPTY remote branch and 'gh pr create' failed ('No commits between main and shipit-gates-install'). Recovery had to use pointer-only moves (git branch -f to capture 74c7d76 and to restore phase0.5-hardening) and deliberately AVOID 'git reset --hard' because the shared tree held the other session's uncommitted mid-refactor WIP (api/_lib/auth-middleware.ts, token.ts, envelope.ts). The push was then blocked by the pre-push build hook failing on the OTHER session's broken edits, so 'git push --no-verify' was used legitimately (the commit held zero buildable source — only .sh/.yml/.json/.mjs/.conf gate files — and CI re-runs the real build server-side). Root cause: branch state, index, and working tree are per-CHECKOUT, not per-session. Recurs on ANY repo whenever Claire runs the deliberate parallel-session pattern, so user-scope. Recovery corollaries to keep: re-check 'git branch --show-current' immediately before commit in any possibly-shared repo; '--no-verify' is legitimate ONLY when your commit provably has no buildable source AND CI re-verifies; prefer pointer-only moves (git branch -f) over reset --hard when a shared tree holds another session's uncommitted work.
```
