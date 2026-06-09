---
name: retro
description: Run the ShipIt V4 retro learning loop. With an argument, capture that specific learning (Path A). With no argument, run the bounded sweep over this session's tripwire markers (Path B). Either way — evaluate against the rubric, then route so the lesson fires in future sessions.
---

# /retro — run the learning loop

You are running the ShipIt V4 retro loop. There are two paths; pick by whether `$ARGUMENTS` is present.

## Path A — invoked capture (an argument was given)

`$ARGUMENTS` is a specific learning ("this keeps happening: …"). Hand it straight to the **retro agent** (`agents/retro.md`): produce the structured rubric block, run the verify-the-working pass, then route each `keep` with `scripts/route-learning.sh`. Report what fired where.

## Path B — the sweep (no argument)

Run the bounded, retrospective sweep over what the tripwire flagged this session.

1. **Gather (deterministic, free):**
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-candidates.sh
   ```
   This prints each marked candidate with its transcript slice. If it says "nothing to sweep," stop — there's nothing to do.

2. **Cost check before judging.** The sweep invokes an LLM per candidate. This is fine when *you* run `/retro` in-session (Max plan). It is NOT fine to wire to an unattended schedule without an estimate — see `MANDATORY.md` rule #1. If candidates are many, cap them (evaluate the highest-signal first) and say so.

3. **Judge — delegate to the retro agent.** Pass the collected candidates to the **retro agent** (`agents/retro.md`), running it on a cheap model (Haiku) since the sweep is the recurring-cost path. For each candidate it emits the rubric block, runs the verify pass (boilerplate rationale bounces back), and dedups against existing `CLAUDE.md` / memory.

4. **Route survivors.** Each `keep` goes through `scripts/route-learning.sh` (the script forces user-scope and enforcement changes to *propose*, never auto-applying them).

5. **Route survivors — tag the fire signal (P5b).** When routing a `keep` that has a code-checkable *doing*, pass `route-learning.sh` an `--action-match` (the rule's distinctive action, e.g. `git worktree add`) and `--surface-match` (its precondition, e.g. a commit touching `api/`). The tripwire then records whether it actually fires, for free. Pure-judgment rules get no patterns and rely on `note-applied.sh` instead.

6. **Surface the loop-fired feedback.** Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/learning-audit.sh --dead-letters` and report any **genuine misses** (a learning whose situation kept arising but never fired — re-route, sharpen, or drop it). Also note pending items via `scripts/proposed-learnings.sh --list`.

7. **Report.** A short table: candidate → keep/drop → destination (or "proposed, awaiting review"). Note anything that landed in `PROPOSED-LEARNINGS.md`, plus any dead letters surfaced.

## The rule that makes this worth doing
A learning only counts if it **fires by itself next time** — a `CLAUDE.md` rule, an auto-loading memory file, a hook. Routing to a note nobody re-reads is the V3 failure this loop exists to fix. Always end at a mechanism, never at prose. P5b makes this *checkable*: `learning-audit.sh` shows which routed learnings actually fire vs. sit as dead letters.
