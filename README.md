# ShipIt V4

**The native-primitives era of ShipIt.** V4 sheds the orchestration framework (commoditized by dynamic workflows + agent teams) and hardens the two things the platform will never do for you: **gate discipline** and the **learning loop** — rebuilt as hooks + CI so they actually fire.

## Why V4 exists

ShipIt v1 (Feb 2026) built multi-agent coordination from scratch because the platform couldn't do it. ShipIt v3 (Apr 2026) doubled down: 13 agents, `/orchestrate`, a hand-rolled memory system. By June 2026, the platform shipped dynamic workflows, agent teams, native memory, hooks, and CI. The scaffolding was now load-bearing on nothing.

The two things that still mattered — **gate discipline** and the **learning loop** — were both soft-enforced prose in v3. Gates got skipped. The learning loop's write half worked; the re-read half never really did. V4 is small on purpose: it keeps only those two things and rebuilds them so they actually fire.

> **Model judges, code enforces.**

## What's in the box

### Gates (`gates/`)

Automated discipline that fires even when you don't invoke `/ship`:

| Gate | Mechanism |
|---|---|
| `no-push-to-main.sh` | Global PreToolUse — blocks pushes to main |
| `block-sensitive-paths.sh` | Global PreToolUse — blocks writes to `~/.ssh`, `*.pem`, etc. |
| `detect-secrets.sh` | Global PostToolUse — warns on secrets |
| `check-docs-sync.sh` | Per-repo CI + commit reminder; `[no-docs]` escape |
| `pre-push-checks.sh` | Per-repo `pre-push` hook + CI; `[no-test]` escape |
| `runtime-smoke-test.sh` | Auto-fires on `deployment_status` — hits the live artifact (HTTP + Playwright + optional E2E) |
| `independent-review.yml` | Non-Claude model reviews every PR via GitHub Models; advisory by default (`SHIPIT_REVIEW_STRICT=true` to block) |
| `security-review.yml` | OWASP/ASVS-mapped security CI gate; fires only on security-sensitive diffs |
| `specialist-nudge.sh` | Non-blocking commit-time nudge to summon `@architect` or `@designer` when staged diff warrants it |

Install per-repo: `scripts/install-gates.sh <repo-path>`

### Learning loop (`hooks/`, `scripts/`, `agents/retro.md`)

Two capture paths, one shared core:

- **Path A — invoked.** `@retro` inline or `/retro <learning>` to capture a specific learning.
- **Path B — autonomous.** `hooks/retro-tripwire.sh` marks any turn with edits/errors/correction-language (free, no LLM). `/retro` with no argument batch-evaluates those markers later — cost is bounded and on-demand.

Learnings are routed by `scripts/route-learning.sh` to mechanisms that auto-load next session: `CLAUDE.md` rules, memory files, hooks. **Rules as a substrate, not notes nobody re-reads.**

### Subagents & skills

**Agents** (`agents/`): `retro` · `reviewer` · `docs` · `engineer` · `researcher` · `architect` · `designer`

**Skills** (`commands/`): `/spec` · `/gameplan` · `/prd-review` · `/code-review` · `/tdd-build` · `/ship` · `/retro`

## Getting started

```bash
# Install gates on a repo
scripts/install-gates.sh /path/to/your-repo

# Capture a learning
/retro <what you learned>

# Run all gates on demand
/ship

# Sweep accumulated learning markers
/retro
```

## Further reading

- `HISTORY.md` — full provenance and design rationale
- `docs/plans/2026-06-08-shipit-v4-architecture.md` — the architecture plan
- `CLAUDE.md` — agent instructions and component reference
