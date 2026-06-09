#!/usr/bin/env bash
# run-sweep.sh <session> <cwd> — the worker for the autonomous session-end sweep (Path B).
#
# MODEL JUDGES, CODE ENFORCES — and the model gets NO tools:
#   1. collect-candidates.sh gathers the session's flagged tripwire slices (free, no LLM).
#   2. claude -p (Haiku, no tools) reads them as TEXT and returns structured ROUTE lines only.
#      The autonomous model can execute nothing — no Bash, no edits, no bypass perms.
#   3. THIS script parses the ROUTE lines and runs route-learning.sh deterministically (which
#      forces user-scope / enforcement learnings to PROPOSED-LEARNINGS — never auto-applied).
#
# Cost caps: Haiku only · one bounded call · ≤ SHIPIT_SWEEP_MAX (default 20) routed · candidate
# text truncated. Spawned detached by hooks/retro-sweep-session-end.sh; also runnable by hand
# (e.g. `scripts/run-sweep.sh <session_id> <repo>` to sweep on demand). Logs to the retro dir.
set -uo pipefail

session="${1:-}"; cwd="${2:-$PWD}"
[ -n "$session" ] || { echo "usage: run-sweep.sh <session_id> [cwd]" >&2; exit 1; }
DIR="${SHIPIT_RETRO_DIR:-$HOME/.claude/shipit-retro}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"          # plugin root (scripts/ -> ..)
CAP="${SHIPIT_SWEEP_MAX:-20}"
log="$DIR/sweep-$session.log"
command -v claude >/dev/null 2>&1 || { echo "run-sweep: no claude CLI" >>"$log" 2>/dev/null; exit 0; }

# Portable timeout (macOS ships neither `timeout` nor `gtimeout` by default).
_timeout() { # _timeout <secs> <cmd...>
  if   command -v timeout  >/dev/null 2>&1; then timeout  "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  else
    local secs="$1"; shift
    "$@" & local pid=$!
    ( sleep "$secs"; kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null ) >/dev/null 2>&1 & local wd=$!
    wait "$pid" 2>/dev/null; local rc=$?
    kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
    return $rc
  fi
}

cands="$(bash "$HERE/scripts/collect-candidates.sh" "$session" 2>/dev/null | head -n 1200)"
printf '%s' "$cands" | grep -q '## Candidate' || { echo "[$(date '+%F %T')] $session: no candidates" >>"$log"; exit 0; }
rubric="$(sed -n '1,90p' "$HERE/agents/retro.md" 2>/dev/null)"
tab="$(printf '\t')"

prompt="You are the ShipIt autonomous retro SWEEP — cost-bounded, no tools, judgment only.
Evaluate the flagged candidates below against the RUBRIC. Output NOTHING for a drop. For each
KEEP, output a labelled block in EXACTLY this shape — raw text, NO code fences, no commentary:
@KEEP
type: rule|fact|check|procedure
scope: project|user
review: direct|propose
statement: <one sentence — the durable lesson>
rationale: <why, one sentence, concrete>
action: <a grep -E pattern matching the rule's distinctive ACTION, or a single dash ->
surface: <a grep -E pattern matching its PRECONDITION, or a single dash ->
@END
Evaluate at most ${CAP} candidates. A vague or boilerplate keep is a drop. Emit ONLY @KEEP blocks.

=== RUBRIC ===
${rubric}

=== CANDIDATES ===
${cands}"

echo "[$(date '+%F %T')] sweep start $session (cap=$CAP)" >>"$log"
out="$(SHIPIT_IN_SWEEP=1 _timeout 300 claude -p --model claude-haiku-4-5 "$prompt" 2>>"$log" || true)"

# Parse @KEEP…@END labelled blocks (LLM-robust; tolerant of ``` fences / stray prose). A field
# value is everything after the first colon. route-learning.sh re-enforces propose-for-user.
routed=0; in=0; type=""; scope=""; review=""; stmt=""; rat=""; action=""; surface=""
flush() {
  [ -n "$type" ] && [ -n "$stmt" ] || return 0
  [ "$routed" -ge "$CAP" ] && return 0
  local args=(--type "$type" --scope "${scope:-project}" --review "${review:-propose}" \
              --statement "$stmt" --rationale "${rat:-captured by the autonomous sweep}" --repo "$cwd")
  [ -n "$action" ]  && [ "$action"  != "-" ] && args+=(--action-match "$action")
  [ -n "$surface" ] && [ "$surface" != "-" ] && args+=(--surface-match "$surface")
  bash "$HERE/scripts/route-learning.sh" "${args[@]}" >>"$log" 2>&1 && routed=$((routed + 1))
}
while IFS= read -r line; do
  line="${line%$'\r'}"
  case "$line" in
    '@KEEP'*)  in=1; type=""; scope=""; review=""; stmt=""; rat=""; action=""; surface="" ;;
    '@END'*)   [ "$in" = 1 ] && flush; in=0 ;;
    *) [ "$in" = 1 ] || continue
       key="${line%%:*}"; val="${line#*:}"; val="${val# }"
       case "$key" in
         type) type="$val" ;; scope) scope="$val" ;; review) review="$val" ;;
         statement) stmt="$val" ;; rationale) rat="$val" ;;
         action) action="$val" ;; surface) surface="$val" ;;
       esac ;;
  esac
done <<EOF
$out
EOF
echo "[$(date '+%F %T')] sweep done $session — routed $routed learning(s)" >>"$log"
exit 0
