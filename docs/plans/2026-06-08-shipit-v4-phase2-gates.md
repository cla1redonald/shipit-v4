# ShipIt V4 — Phase 2: Gates as Hooks + CI

**Date:** 2026-06-08
**Status:** Proposed — build plan
**Depends on:** Phase 1b (Retro v4) — done. Builds on the same hooks/CI substrate.

---

## The point of Phase 2

Phase 1b made *learning* fire by itself. Phase 2 makes the *gates* fire by itself — so "I commit and the checks just happen" becomes literally true.

v3 had 12 gates written as prose ("NEVER SKIP"). They got skipped — twice on retro alone. **The entire job of Phase 2 is to convert prose into mechanism.** Model judges where judgment is needed (review); code enforces everything mechanical.

> **Done means done.** This phase is complete only when *every* gate fires automatically, *each* is proven to bite with a deliberate-failure test, the override path works, and the kit is dogfooded into ShipIt V4 itself. A gate that exists but was never proven to block is not done.

---

## Two delivery mechanisms

A Claude Code plugin can only do some of this globally; the rest has to be installed into each repo. Phase 2 ships both:

1. **Global plugin hooks** (`hooks/hooks.json`) — fire in *every* session the moment the plugin is loaded, zero per-repo setup. For the cheap, universal guards: **no-push-to-main, secret detection, sensitive-path blocking, the docs-sync commit reminder,** and the existing retro tripwire.
2. **Per-repo gate kit + installer** — reusable scripts in `gates/` plus `scripts/install-gates.sh <repo>` that wires the repo-specific backstops into a target repo: **CI workflows** (`.github/workflows/`), a **git `pre-push` hook**, and repo-level `.claude/settings.json` hook entries. For the things a plugin can't do globally — running *this repo's* test/build, and CI that can't be skipped locally.

## Two enforcement layers (defense in depth)

Every mechanical gate gets **both**:

- **In-session hook** — catches it early, before the bad thing lands. Great UX (you find out at commit/push time, not after a failed CI run). Skippable (`--no-verify`) — which is fine, because:
- **CI backstop** — runs on GitHub, cannot be skipped locally, blocks the *merge*. This is what makes "NEVER SKIP" actually true.

The local hook is the helpful nudge; CI is the wall. v3 only had the nudge (and as prose, not even that).

## Override pattern (conscious opt-out, not a silent skip)

Genuine exceptions use a commit-message token, consistent across gates: **`[no-docs]`, `[no-test]`, `[no-retro]`**. The gate enforces by default and allows a *deliberate, recorded* bypass. (Proven already for `[no-docs]` in ProveIt.) Some gates have no override by design — see below.

---

## Gate-by-gate spec

| Gate | Auto mechanism(s) | Layers | Port source | Override | Proof it bites |
|---|---|---|---|---|---|
| **no-push-to-main** | global PreToolUse(Bash) guard + remote branch protection | hook + CI/remote | new (MANDATORY #2) | none (push the branch instead) | `git push origin main` → blocked; `git push origin feat` → allowed |
| **secret detection** | global PostToolUse warn + pre-push/CI scan | hook + CI | v3 `detect-secrets.js` | none | write a file w/ a fake AWS key → warned; committed key → CI red |
| **sensitive-path block** | global PreToolUse(Write) block | hook | v3 `block-sensitive-paths.js` | none | write to `~/.ssh/…` / `.env` outside repo → blocked |
| **docs-in-sync** | PreToolUse(Bash) commit reminder + CI | hook + CI | ProveIt `check-docs-sync.sh` + `docs-check.yml` (generalize: configurable code/doc globs) | `[no-docs]` | stage code w/o docs → CI red; add `[no-docs]` → green |
| **test / typecheck / build** | PreToolUse(Bash) on `git push` runs repo scripts + CI | hook + CI | v3 `pre-push-check.js` + ProveIt `ci.yml` | `[no-test]` / `--no-verify` (local only; CI still enforces) | break a test → push blocked + CI red; fix → green |
| **review (`@reviewer`)** | on-demand via `/ship` (LLM → not auto, by cost design); optional opt-in PR Action | skill / PR | v3 `agents/reviewer.md` | findings advisory unless Must-Fix | run on a diff with a planted bug → flagged |
| **retro** | tripwire (auto) + sweep (`/retro`) | — | Phase 1b ✅ | `[no-retro]` | done |

**Detection (test/typecheck/build):** read `package.json` scripts (`test`, `typecheck`, `build`); pyproject/Makefile later. If none exist, **skip with a warning, don't block** — never punish a repo for having no tests yet.

**docs-sync generalization:** ProveIt's script hardcodes `scripts/|agents/|commands/` ↔ `README|CLAUDE|AGENTS|docs`. Make the two globs configurable (env or `.shipit.json`), defaulting to V4's layout (add `hooks/`).

---

## The installer — `scripts/install-gates.sh <repo>`

Wires the per-repo half into a target repo. Must be **idempotent** and support `--dry-run`.

1. Copy `gates/*.sh` into `<repo>/.shipit-gates/` (copy, not symlink — stable if the plugin moves; stamp with a version line so drift is detectable).
2. Drop applicable `.github/workflows/` templates (`ci.yml`, `docs-check.yml`) — skip ones that don't apply (no test script → no ci.yml test job).
3. Merge `.claude/settings.json` hook entries (the docs-sync commit reminder) — a careful JSON merge that never clobbers existing hooks.
4. Install `.git/hooks/pre-push` calling the bundled test/build + no-push checks.
5. Optionally set remote branch protection on `main` via `gh api` (needs admin; offer, don't assume).

**Proof:** install into a throwaway repo, trip each gate, confirm wired; re-run → no duplicate entries (idempotent).

## `/ship` skill — the human-facing "run all gates now"

A slim port of v3's `commands/shipit.md` gate sequence: test/typecheck/build → docs-sync → secrets → `@reviewer` → retro sweep → push/PR. **But the hooks fire even when `/ship` is never called** — that's the v3 fix. `/ship` is the convenience that also triggers the two LLM gates (`@reviewer`, retro sweep) you wouldn't auto-run on cost grounds.

---

## Build order — smallest-first, each proven to bite before the next

| # | Step | Proof gate (deliberate red → green) |
|---|---|---|
| S1 | **no-push-to-main** global hook | block `git push origin main`, allow a branch push |
| S2 | **secrets + sensitive-paths** global hooks (port v3) | fake key → warned; `~/.ssh` write → blocked |
| S3 | **docs-sync kit** (script + CI template + commit-reminder hook), generalized | code w/o docs → red; `[no-docs]` → green |
| S4 | **test/typecheck/build kit** (pre-push script + CI template), with detection + graceful skip | failing test → blocked; no-test repo → skipped cleanly |
| S5 | **installer** wiring S3+S4 into a repo, idempotent | install into sandbox, trip gates, re-run clean |
| S6 | **review gate** — port `@reviewer` as on-demand subagent | planted bug → flagged |
| S7 | **`/ship`** orchestrating the full sequence + push/PR | runs in order; hooks still fire with `/ship` skipped |
| S8 | **dogfood** the full kit into shipit-v4 + its own CI + docs | the gate-set bites on a real shipit-v4 commit |

Each step lands behind a deliberate-failure test — prove it goes **red**, then green. That discipline is the whole point (it's the lesson from `feedback_checklist_before_work`: a test-harness/gate change must prove it bites).

---

## Cost (MANDATORY rule #1)

- **Building Phase 2 ≈ $0 API.** S1–S5, S7, S8 are pure bash / git hooks / GitHub Actions — no LLM. My build work runs on the Max subscription.
- **The only LLM-billed gate is `@reviewer`** (S6), and it's **on-demand** via `/ship` — you choose when. Rough order: a diff review is ~10–40k tokens depending on diff size. Not recurring.
- **The one recurring-spend option** is an *opt-in* auto-PR-review GitHub Action (Claude reviews every PR). It is **off by default**; turning it on bills the API wallet per PR and needs an explicit estimate + your go-ahead first. The default posture (cheap gates auto, LLM gates on-demand) mirrors the Phase 1b tripwire/sweep split.

---

## Open decisions (confirm before/within the build — defaults proposed)

1. **In-session test-on-push: hard-block or warn?** Running the full test suite on every `git push` can be slow/annoying. *Recommend:* warn locally if it's slow, **hard-block in CI** (the wall is CI, the nudge is local). 
2. **Review gate: on-demand only, or also the opt-in PR Action?** *Recommend:* ship on-demand (`/ship`) now; leave the recurring-cost PR Action as a documented opt-in for later.
3. **Installer: copy vs symlink gate scripts into repos?** *Recommend:* **copy + version stamp** (stable, drift detectable) over symlink (auto-updates but breaks if the plugin moves).
4. **Branch protection on `main`:** set it automatically via `gh` during install, or just document it? *Recommend:* offer it interactively (needs repo-admin), don't force.

---

## Completion bar (the contract — "not done until all done")

- [ ] Every gate fires via ≥1 automatic mechanism (global hook or installed CI/git-hook).
- [ ] Each blocking gate **proven to bite** (deliberate red → green), not just present.
- [ ] Defense in depth (local hook **and** CI) for no-push, docs-sync, test/build.
- [ ] Override tokens (`[no-docs]`, `[no-test]`, `[no-retro]`) work on every gate that has one.
- [ ] Installer is idempotent, `--dry-run`-able, and **dogfooded into shipit-v4** (plus a sandbox proof).
- [ ] `/ship` runs the full sequence; hooks fire even when `/ship` is skipped.
- [ ] Docs in sync (V4's own docs-sync gate green); `HISTORY.md` + `CLAUDE.md` updated.
- [ ] Cost documented; nothing recurring enabled without explicit approval.
