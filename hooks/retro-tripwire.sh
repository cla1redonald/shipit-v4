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
