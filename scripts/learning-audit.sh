#!/usr/bin/env bash
# learning-audit.sh — read-time view over the P5b loop-fired signal (free, no LLM).
#
# The loop's first-ever feedback on whether routed learnings actually fire. Two source files
# in ~/.claude/shipit-retro/ (override with SHIPIT_RETRO_DIR):
#   learning-index.tsv   (write-once registry)  SIG⇥REPO⇥DATE⇥TYPE⇥ACTION_MATCH⇥SURFACE_MATCH
#   learning-events.tsv  (append-only log)       TS⇥fire|opp⇥SIG⇥SOURCE⇥META(session=…)
# Counts are DERIVED here as DISTINCT SESSIONS per SIG — never stored, so nothing races.
# Old 4-field registry rows migrate on read (ACTION/SURFACE treated as '-').
#
# FIRES = distinct sessions a rule's ACTION fired in.   OPPS = distinct sessions its SURFACE arose in.
#   genuine dead letter : SURFACE known AND OPPS ≥ k AND FIRES = 0  (the situation came up, the rule never acted)
#   dormant             : OPPS = 0                                   (legit — hasn't come up yet; low priority)
#   low-confidence      : judgment rule (no patterns) AND FIRES = 0 AND older than N days  (eyeball it)
#
# Usage:
#   learning-audit.sh                    # summary
#   learning-audit.sh --dead-letters     # the three buckets above
#   learning-audit.sh --fired [--by-source]
#   learning-audit.sh --list             # the registry
# Env: SHIPIT_DEADLETTER_OPPS (k, default 2), SHIPIT_DEADLETTER_DAYS (N, default 14)
#
# v2 (deferred, per the architect): `--audit` would run a bounded, you-triggered Haiku pass
# over ONLY the judgment-rule dead letters, fed ONLY the tripwire's recorded line-ranges, with
# an estimate-then-approve prompt (MANDATORY #1). Not implemented here — eyeball them for now.
set -uo pipefail
DIR="${SHIPIT_RETRO_DIR:-$HOME/.claude/shipit-retro}"
REG="$DIR/learning-index.tsv"; EVT="$DIR/learning-events.tsv"
K="${SHIPIT_DEADLETTER_OPPS:-2}"; DAYS="${SHIPIT_DEADLETTER_DAYS:-14}"
cmd="${1:-summary}"; cmd="${cmd#--}"; opt="${2:-}"
[ -f "$REG" ] || { echo "learning-audit: no registry yet ($REG) — nothing routed."; exit 0; }
[ -f "$EVT" ] || EVT=/dev/null
# Portable "N days ago" cutoff (BSD date on macOS, GNU date on Linux/CI). YYYY-MM-DD strings
# compare lexically, so no awk mktime (which BWK awk on macOS lacks).
cutoff="$(date -v-"${DAYS}"d +%F 2>/dev/null || date -d "-${DAYS} days" +%F 2>/dev/null || echo 0000-00-00)"

if [ "$cmd" = "audit" ]; then
  echo "learning-audit: --audit (LLM) is the deferred v2 step — not implemented. Eyeball the judgment-rule"
  echo "dead letters from --dead-letters for now. (When built: bounded Haiku, line-ranges only, estimate-first.)"
  exit 0
fi

awk -F'\t' -v cmd="$cmd" -v opt="$opt" -v K="$K" -v cutoff="$cutoff" -v evt="$EVT" '
  FILENAME==evt {
    if ($2=="" ) next
    sig=$3; sess=$5; sub(/^session=/,"",sess); sub(/;.*/,"",sess)
    if ($2=="fire") { if(!((sig,sess) in fseen)){fseen[sig,sess]=1; fires[sig]++} ; if($1>lastfire[sig])lastfire[sig]=$1; src[sig,$4]++; srcs[$4]=1 }
    else if ($2=="opp") { if(!((sig,sess) in oseen)){oseen[sig,sess]=1; opps[sig]++} }
    next
  }
  # registry file
  $1 ~ /^#/ || $1=="" { next }
  {
    sig=$1; reg[sig]=1; order[++n]=sig
    repo[sig]=$2; rdate[sig]=$3; rtype[sig]=$4
    am[sig]=($5==""?"-":$5); sm[sig]=($6==""?"-":$6)
  }
  END {
    dl=0; dorm=0; lowc=0; haveevt=0
    for(i=1;i<=n;i++){ s=order[i]; if(fires[s]>0) haveevt++ }
    if(cmd=="list"){
      printf "Registry — %d routed learning(s):\n\n", n
      for(i=1;i<=n;i++){ s=order[i]
        printf "  %s\n    repo=%s date=%s type=%s\n    action=%s\n    surface=%s\n\n",
          s, repo[s], rdate[s], rtype[s], am[s], sm[s] }
      exit
    }
    if(cmd=="fired"){
      printf "Fired learnings (distinct sessions):\n\n"
      any=0
      for(i=1;i<=n;i++){ s=order[i]; if(fires[s]+opps[s]==0) continue; any=1
        printf "  %s  FIRES=%d OPPS=%d last=%s\n", s, fires[s]+0, opps[s]+0, (lastfire[s]==""?"-":lastfire[s])
        if(opt=="--by-source"||opt=="by-source"){ for(k in src){ split(k,a,SUBSEP); if(a[1]==s) printf "      via %s: %d\n", a[2], src[k] } }
      }
      if(!any) print "  (no fire/opp events yet)"
      exit
    }
    if(cmd=="dead-letters"||cmd=="dead_letters"||cmd=="deadletters"){
      print "Dead-letter audit (routed learnings that never demonstrably fired):"
      print ""
      print "GENUINE MISSES  (surface arose ≥k times, rule never fired — re-route / sharpen / drop):"
      for(i=1;i<=n;i++){ s=order[i]
        if(sm[s]!="-" && opps[s]+0>=K && fires[s]+0==0){ dl++; printf "  ✗ %s   (OPPS=%d, FIRES=0)  surface=%s\n", s, opps[s], sm[s] } }
      if(dl==0) print "  (none)"
      print ""
      print "LOW-CONFIDENCE  (judgment rule, no code-checkable pattern; FIRES=0 and older than the window):"
      for(i=1;i<=n;i++){ s=order[i]
        if(am[s]=="-" && sm[s]=="-" && fires[s]+0==0 && rdate[s] < cutoff){ lowc++; printf "  ? %s   (date=%s — eyeball: applied unlogged, or genuinely unused?)\n", s, rdate[s] } }
      if(lowc==0) print "  (none)"
      print ""
      print "DORMANT  (surface never arose yet — legit waiting, low priority):"
      for(i=1;i<=n;i++){ s=order[i]
        if(sm[s]!="-" && opps[s]+0==0 && fires[s]+0==0){ dorm++; printf "  · %s   surface=%s\n", s, sm[s] } }
      if(dorm==0) print "  (none)"
      exit
    }
    # summary
    printf "Learning-fired summary:  %d routed · %d with fires · ", n, haveevt
    gm=0; for(i=1;i<=n;i++){ s=order[i]; if(sm[s]!="-" && opps[s]+0>=K && fires[s]+0==0) gm++ }
    printf "%d genuine dead-letter(s)\n", gm
    print "  → --dead-letters for the buckets, --fired [--by-source] for the log, --list for the registry."
  }
' "$EVT" "$REG"
