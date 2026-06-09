#!/usr/bin/env bash
# retro-tripwire.sh — the near-zero-cost half of the ShipIt V4 learning loop's Path B.
#
# Fires on every Stop event. NO LLM. It does ONE thing: cheaply decide whether this turn
# *might* contain a learning, and if so append a one-line marker to a per-session scratch
# file. The expensive judgment (the @retro sweep) reads these markers later, at a bounded
# checkpoint — NOT here. This split is what keeps the loop cost-safe:
#   tripwire = free + every turn + over-flags on purpose;  sweep = paid + occasional + filters.
#
# Signals (any → mark):
#   * file edits      — an Edit/Write/NotebookEdit tool_use this turn
#   * tool errors     — a tool_result with "is_error":true
#   * correction-language — the user pushed back ("no", "that's wrong", "actually", "revert"…)
#
# Always exits 0. It never blocks a turn — a tripwire that fails the build would be insane.

set -uo pipefail

MARKER_DIR="${SHIPIT_RETRO_DIR:-$HOME/.claude/shipit-retro}"

# Read the Stop-hook JSON from stdin.
input="$(cat)"
have_jq=1; command -v jq >/dev/null 2>&1 || have_jq=0

get() { # get <jq-path>  (falls back to empty)
  [ "$have_jq" = 1 ] && printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null || true
}

transcript="$(get '.transcript_path')"
session="$(get '.session_id')"
[ -z "$session" ] && session="unknown"
# Avoid doing work in a stop-hook continuation loop.
[ "$(get '.stop_hook_active')" = "true" ] && exit 0
# No transcript to read → nothing to do.
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

mkdir -p "$MARKER_DIR"
cursor_file="$MARKER_DIR/$session.cursor"
marker_file="$MARKER_DIR/$session.markers"

total="$(wc -l < "$transcript" | tr -d ' ')"
last=0; [ -f "$cursor_file" ] && last="$(cat "$cursor_file" 2>/dev/null || echo 0)"
# Nothing new (or transcript rotated/shrank) → resync cursor, done.
if [ "$total" -le "$last" ]; then printf '%s' "$total" > "$cursor_file"; exit 0; fi

slice="$(sed -n "$((last + 1)),${total}p" "$transcript" 2>/dev/null || true)"
printf '%s' "$total" > "$cursor_file"
[ -n "$slice" ] || exit 0

# ── P5b: loop-fired detection (free, no LLM, no agent compliance) ──────────────
# For each routed learning that carries a distinctive ACTION pattern (→ "the rule fired")
# and/or a SURFACE pattern (→ "the situation arose"), grep this turn's tool stream and
# append events to an APPEND-ONLY log. Single-line O_APPEND writes are race-safe across the
# concurrent sessions MANDATORY #6 warns about — we never mutate a shared file in place.
# Counts are derived later by learning-audit.sh. This is the ONLY signal that can prove a
# rule fired *unprompted* (self-report via note-applied.sh is the judgment-rule fallback).
# A no-op until learnings exist (guarded on the registry), so zero cost in the common case.
reg="$MARKER_DIR/learning-index.tsv"
if [ -f "$reg" ]; then
  events="$MARKER_DIR/learning-events.tsv"
  fired="$MARKER_DIR/$session.fired"           # per-session dedup → 1 fire/opp per (session,sig)
  ets="$(date '+%Y-%m-%dT%H:%M:%S')"
  while IFS="$(printf '\t')" read -r sig _repo _date _type amatch smatch; do
    case "$sig" in '#'*|'') continue ;; esac
    if [ -n "${amatch:-}" ] && [ "$amatch" != "-" ] \
         && printf '%s' "$slice" | grep -Eiq -- "$amatch" 2>/dev/null \
         && ! grep -qxF "fire:$sig" "$fired" 2>/dev/null; then
      printf '%s\tfire\t%s\ttripwire\tsession=%s\n' "$ets" "$sig" "$session" >> "$events"
      echo "fire:$sig" >> "$fired"
    fi
    if [ -n "${smatch:-}" ] && [ "$smatch" != "-" ] \
         && printf '%s' "$slice" | grep -Eiq -- "$smatch" 2>/dev/null \
         && ! grep -qxF "opp:$sig" "$fired" 2>/dev/null; then
      printf '%s\topp\t%s\ttripwire\tsession=%s\n' "$ets" "$sig" "$session" >> "$events"
      echo "opp:$sig" >> "$fired"
    fi
  done < "$reg"
fi

signals=""
add() { signals="${signals:+$signals,}$1"; }

# 1. file edits this turn
printf '%s' "$slice" | grep -Eq '"name"[[:space:]]*:[[:space:]]*"(Edit|Write|NotebookEdit)"' && add edit
# 2. tool errors this turn
printf '%s' "$slice" | grep -Eq '"is_error"[[:space:]]*:[[:space:]]*true' && add error
# 3. correction-language (loose on purpose — the sweep filters false positives)
printf '%s' "$slice" | grep -Eiq \
  "(no,|that'?s wrong|that is wrong|actually,|you broke|not what i|that'?s not (it|right)|don'?t do that|do not do that|revert|undo that|wrong\b|incorrect|that'?s incorrect|fix it|broke it|stop doing)" \
  && add correction

[ -n "$signals" ] || exit 0

# Append a single compact marker line. The sweep reconstructs detail from the transcript.
ts="$(date '+%Y-%m-%dT%H:%M:%S')"
printf '%s\tsignals=%s\tlines=%s-%s\ttranscript=%s\n' \
  "$ts" "$signals" "$((last + 1))" "$total" "$transcript" >> "$marker_file"

exit 0
