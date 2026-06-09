#!/usr/bin/env bash
# retro-sweep-session-end.sh — AUTONOMOUS session-end retro sweep (opt-in, user-approved).
#
# The one autonomous-LLM mechanism V4 deliberately deferred (the $24 lesson). Enabled per
# Claire's explicit approval (2026-06-09, "session-end" cadence). This file is only the
# TRIGGER + guards; the actual work is scripts/run-sweep.sh (spawned detached). Safe by
# construction:
#   * OPT-IN   — runs only when ~/.claude/shipit-retro/auto-sweep says "session-end" (no
#                file → off). Disable any time: rm that file, or export SHIPIT_AUTO_SWEEP=off.
#   * ZERO SPEND ON IDLE — exits before spawning anything if the session flagged no markers.
#   * RECURSION-GUARDED — the headless sweep sets SHIPIT_IN_SWEEP=1; its own SessionEnd no-ops.
#   * NON-BLOCKING — the worker runs detached (nohup); session exit is never delayed.
# (Cost/blast-radius caps — Haiku, candidate cap, NO tools for the model — live in run-sweep.sh.)
# Always exits 0.
set -uo pipefail

[ -n "${SHIPIT_IN_SWEEP:-}" ] && exit 0                         # recursion guard
command -v jq >/dev/null 2>&1 || exit 0
command -v claude >/dev/null 2>&1 || exit 0

DIR="${SHIPIT_RETRO_DIR:-$HOME/.claude/shipit-retro}"
mode="${SHIPIT_AUTO_SWEEP:-$(cat "$DIR/auto-sweep" 2>/dev/null || echo off)}"
[ "$mode" = "session-end" ] || exit 0                           # opt-in only

input="$(cat)"
session="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$session" ] || exit 0
mf="$DIR/$session.markers"
[ -f "$mf" ] || exit 0
[ "$(grep -c . "$mf" 2>/dev/null || echo 0)" -ge 1 ] || exit 0  # no markers → no spend, no spawn
swept="$DIR/$session.swept"
[ -f "$swept" ] && exit 0
: > "$swept"                                                    # claim before spawning (no double-fire)

PLUGIN="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"
nohup bash "$PLUGIN/scripts/run-sweep.sh" "$session" "$cwd" >/dev/null 2>&1 </dev/null &
exit 0
