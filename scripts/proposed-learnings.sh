#!/usr/bin/env bash
# proposed-learnings.sh — lifecycle for PROPOSED-LEARNINGS.md (P5c).
#
# The fix for the rot the improvement plan flagged: the file accumulated entries and never
# cleared — several were applied to ~/.claude this session yet still read "awaiting review."
# Each entry now carries a **Status:** line (pending | applied | archived). This lists by
# status and stamps an entry applied/archived (by the number shown in --list). No LLM.
#
# Usage:
#   scripts/proposed-learnings.sh                 # = --list (pending only)
#   scripts/proposed-learnings.sh --applied       # list applied
#   scripts/proposed-learnings.sh --archived      # list archived
#   scripts/proposed-learnings.sh --apply   <n> [where]   # mark entry n applied (with a note)
#   scripts/proposed-learnings.sh --archive <n> [reason]  # mark entry n archived
#
# Entry numbers are the [n] from --list / a full listing; they are file order (each entry has
# exactly one **Status:** line). Override the file with SHIPIT_PROPOSED=/path.
set -uo pipefail

FILE="${SHIPIT_PROPOSED:-$( { git rev-parse --show-toplevel 2>/dev/null || echo .; } )/PROPOSED-LEARNINGS.md}"
[ -f "$FILE" ] || { echo "proposed-learnings: no file at $FILE" >&2; exit 1; }

cmd="${1:-list}"; cmd="${cmd#--}"

list() { # $1 = status filter, or "all"
  awk -v want="$1" '
    /^## / { n++; heads[n]=$0; stat[n]=""; ln[n]=""; next }
    /^\*\*Status:\*\*/ && stat[n]=="" { s=$0; sub(/^\*\*Status:\*\* /,"",s); stat[n]=s; next }
    /^\*\*Learning:\*\*/ && ln[n]=="" { l=$0; sub(/^\*\*Learning:\*\* /,"",l); ln[n]=l; next }
    END {
      shown=0
      for(i=1;i<=n;i++){
        s=stat[i]; if(s=="") s="pending"
        key=s; sub(/[ .].*/,"",key)
        if(want=="all" || key==want){ printf "[%d] %s\n      status: %s\n      %.110s\n\n", i, heads[i], s, ln[i]; shown++ }
      }
      if(shown==0) printf "  (none %s)\n", (want=="all"?"":want)
    }' "$FILE"
}

case "$cmd" in
  list|pending) echo "Pending proposals in $FILE:"; list pending ;;
  applied)      echo "Applied:";  list applied ;;
  archived)     echo "Archived:"; list archived ;;
  all)          list all ;;
  apply|archive)
    n="${2:-}"; note="${3:-}"
    printf '%s' "$n" | grep -qE '^[0-9]+$' || { echo "usage: $0 --$cmd <entry-number> [note]  (number from --list)" >&2; exit 1; }
    verb="$([ "$cmd" = apply ] && echo applied || echo archived)"
    ns="$verb — $(date +%Y-%m-%d)${note:+ — $note}"
    total="$(grep -c '^\*\*Status:\*\*' "$FILE" || echo 0)"
    [ "$n" -ge 1 ] && [ "$n" -le "$total" ] || { echo "no entry #$n (file has $total)" >&2; exit 1; }
    tmp="$(mktemp)"
    awk -v target="$n" -v ns="$ns" '
      /^\*\*Status:\*\*/ { c++; if(c==target){ print "**Status:** " ns; next } }
      { print }' "$FILE" > "$tmp" && mv "$tmp" "$FILE"
    echo "entry #$n → **Status:** $ns"
    ;;
  *) echo "usage: $0 [--list|--applied|--archived|--all] | --apply <n> [note] | --archive <n> [reason]" >&2; exit 1 ;;
esac
