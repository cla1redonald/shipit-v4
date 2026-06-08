#!/usr/bin/env bash
# collect-candidates.sh — deterministic prep for the @retro sweep (Path B).
#
# Reads a session's tripwire marker file and, for each marker, prints the marker plus the
# exact transcript slice it flagged. NO LLM — this just gathers; the retro agent judges.
#
# Usage:
#   collect-candidates.sh [session_id]      # default: newest marker file in the marker dir
# Env: SHIPIT_RETRO_DIR (default ~/.claude/shipit-retro)

set -uo pipefail
MARKER_DIR="${SHIPIT_RETRO_DIR:-$HOME/.claude/shipit-retro}"

[ -d "$MARKER_DIR" ] || { echo "no marker dir ($MARKER_DIR) — nothing to sweep."; exit 0; }

session="${1:-}"
if [ -n "$session" ]; then
  mf="$MARKER_DIR/$session.markers"
else
  # newest .markers file
  mf="$(ls -t "$MARKER_DIR"/*.markers 2>/dev/null | head -1 || true)"
fi
[ -n "${mf:-}" ] && [ -f "$mf" ] || { echo "no markers for this session — nothing to sweep."; exit 0; }

echo "# Retro sweep candidates"
echo "# source: $mf"
echo

n=0
while IFS=$'\t' read -r ts sig lines tr_field; do
  [ -n "$ts" ] || continue
  n=$((n + 1))
  # fields look like: signals=edit,error  lines=1-4  transcript=/path
  signals="${sig#signals=}"
  range="${lines#lines=}"; start="${range%-*}"; end="${range#*-}"
  transcript="${tr_field#transcript=}"
  echo "## Candidate $n  ($ts)  signals=$signals"
  if [ -f "$transcript" ] && [ -n "$start" ] && [ -n "$end" ]; then
    echo '```'
    sed -n "${start},${end}p" "$transcript" 2>/dev/null | cut -c1-2000
    echo '```'
  else
    echo "_(transcript slice unavailable: $transcript $range)_"
  fi
  echo
done < "$mf"

echo "# $n candidate(s). Evaluate each against the @retro rubric, then route survivors."
