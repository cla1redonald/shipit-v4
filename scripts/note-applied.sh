#!/usr/bin/env bash
# note-applied.sh — record that a routed learning was consciously APPLIED (P5b fire signal).
#
# This is the FALLBACK signal, for pure-JUDGMENT rules that have no code-checkable
# ACTION_MATCH for the tripwire to catch for free (e.g. "don't over-promise deliverables").
# Action-shaped rules (e.g. "use git worktree per session") fire AUTOMATICALLY via the
# tripwire — you do NOT call this for those. Find the slug in the rule's trailing
# `_(retro <date> · learning:<slug>)_` tag, or via `learning-audit.sh --list`.
#
# Honest limit (stated, not hidden): self-report under-counts — you must remember to call it,
# which is the very compliance weakness the loop exists to reduce. That's why it's the
# fallback, not the primary signal, and why a low fire-count is read as "investigate", not
# "dead". Append-only, single line, no LLM → race-safe across concurrent sessions.
#
# Usage: note-applied.sh <slug> [note]
set -uo pipefail
SLUG="${1:-}"; NOTE="${2:-}"
[ -n "$SLUG" ] || { echo "usage: note-applied.sh <slug> [note]   (slug from the rule's learning:<slug> tag)" >&2; exit 1; }
DIR="${SHIPIT_RETRO_DIR:-$HOME/.claude/shipit-retro}"; mkdir -p "$DIR"
ts="$(date '+%Y-%m-%dT%H:%M:%S')"
# A unique synthetic session per manual call so each conscious application counts distinctly
# (the tripwire dedups per real session; manual notes are each their own event).
sess="${CLAUDE_SESSION_ID:-manual-$ts-$$}"
printf '%s\tfire\t%s\tnote-applied\tsession=%s%s\n' \
  "$ts" "$SLUG" "$sess" "${NOTE:+;note=$NOTE}" >> "$DIR/learning-events.tsv"
echo "note-applied: recorded a fire for '$SLUG'${NOTE:+ ($NOTE)}"
