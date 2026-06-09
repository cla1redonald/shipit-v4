#!/usr/bin/env bash
# route-learning.sh — the deterministic placement half of the ShipIt V4 learning loop.
#
# The @retro agent CLASSIFIES a learning (type × scope × review). This script PLACES and
# FORMATS it at the mechanism that will actually re-surface it in a future session.
# Model judges, code enforces.
#
# Routing table (architecture §1b):
#   type ↓ / scope →   project                          user
#   rule               <repo>/CLAUDE.md                 ~/.claude/MANDATORY.md      (propose)
#   fact               project memory (auto-loads)      ~/.claude/CLAUDE.md         (propose)
#   check              repo CI + project hook           global hook                 (propose)
#   procedure          project/plugin skill             ~/.claude/skills/           (propose)
#
# HARD SAFETY (code-enforced, not just model-asked):
#   * scope=user           → ALWAYS propose. Never write ~/.claude/* directly.
#   * type=check (enforcement) → ALWAYS propose. Adding a gate changes every future run.
# A "propose" never mutates global config; it appends a ready-to-apply entry to
# <repo>/PROPOSED-LEARNINGS.md for a human to review.
#
# Usage:
#   route-learning.sh --type <rule|fact|check|procedure> --scope <project|user> \
#       --review <direct|propose> --statement "<one sentence>" \
#       --rationale "<why, condensed>" [--repo <path>]
#
# Exit: 0 routed/proposed, 1 bad args.

set -uo pipefail

TYPE="" SCOPE="" REVIEW="" STATEMENT="" RATIONALE="" REPO="" SLUG_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --type)      TYPE="${2:-}"; shift 2 ;;
    --scope)     SCOPE="${2:-}"; shift 2 ;;
    --review)    REVIEW="${2:-}"; shift 2 ;;
    --statement) STATEMENT="${2:-}"; shift 2 ;;
    --rationale) RATIONALE="${2:-}"; shift 2 ;;
    --repo)      REPO="${2:-}"; shift 2 ;;
    --slug)      SLUG_ARG="${2:-}"; shift 2 ;;   # optional explicit short filename slug
    *) echo "route-learning: unknown arg '$1'" >&2; exit 1 ;;
  esac
done

# --- validate -------------------------------------------------------------
err() { echo "route-learning: $1" >&2; exit 1; }
# A clean, SHORT slug for filenames: first ~6 words, ≤40 chars (not the whole statement).
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' \
    | sed 's/^-*//; s/-*$//' | cut -d- -f1-6 | cut -c1-40 | sed 's/-*$//'
}
case "$TYPE"   in rule|fact|check|procedure) ;; *) err "bad --type '$TYPE'" ;; esac
case "$SCOPE"  in project|user) ;;             *) err "bad --scope '$SCOPE'" ;; esac
case "$REVIEW" in direct|propose) ;;           *) err "bad --review '$REVIEW'" ;; esac
[ -n "$STATEMENT" ] || err "missing --statement"
[ -n "$RATIONALE" ] || err "missing --rationale"

# default repo = current git toplevel, else cwd
if [ -z "$REPO" ]; then
  REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
[ -d "$REPO" ] || err "--repo '$REPO' is not a directory"

# --- HARD SAFETY: force propose for user-scope and enforcement ------------
ENFORCED=""
if [ "$SCOPE" = "user" ] && [ "$REVIEW" = "direct" ]; then
  REVIEW="propose"; ENFORCED="user-scope"
fi
if [ "$TYPE" = "check" ] && [ "$REVIEW" = "direct" ]; then
  REVIEW="propose"; ENFORCED="enforcement-change"
fi
[ -n "$ENFORCED" ] && echo "route-learning: forced review=propose ($ENFORCED — never auto-applied)" >&2

DATE="$(date +%Y-%m-%d)"
SLUG="${SLUG_ARG:-}"; [ -n "$SLUG" ] || SLUG="$(slugify "$STATEMENT")"; [ -n "$SLUG" ] || SLUG="learning-$DATE"

# --- propose: append a ready-to-apply entry, touch nothing global ---------
if [ "$REVIEW" = "propose" ]; then
  # The human-facing target it WOULD land at, per the table:
  case "${TYPE}:${SCOPE}" in
    rule:user)      TARGET="~/.claude/MANDATORY.md" ;;
    fact:user)      TARGET="~/.claude/CLAUDE.md (NOT global memory — it doesn't auto-load)" ;;
    check:user)     TARGET="global hook (~/.claude/settings.json)" ;;
    procedure:user) TARGET="~/.claude/skills/" ;;
    check:project)  TARGET="repo CI + project hook (<repo>/hooks/)" ;;
    *)              TARGET="<repo> (review placement)" ;;
  esac
  OUT="$REPO/PROPOSED-LEARNINGS.md"
  if [ ! -f "$OUT" ]; then
    printf '# Proposed learnings — awaiting human review\n\nThese are user-scope or enforcement changes the learning loop will NOT auto-apply.\nReview each, then apply by hand (or via PR) to the named target.\n' > "$OUT"
  fi
  {
    printf '\n## %s — %s/%s\n\n' "$DATE" "$TYPE" "$SCOPE"
    printf '**Status:** pending\n\n'
    printf '**Learning:** %s\n\n' "$STATEMENT"
    printf '**Why:** %s\n\n' "$RATIONALE"
    printf '**Apply to:** `%s`\n\n' "$TARGET"
    printf '**Ready-to-apply snippet:**\n\n```\n- **%s** — %s\n```\n' "$STATEMENT" "$RATIONALE"
  } >> "$OUT"
  echo "PROPOSED → $OUT  (target: $TARGET)"
  exit 0
fi

# --- direct: project-scope, non-enforcement only -------------------------
case "$TYPE" in
  rule)
    # project rule → <repo>/CLAUDE.md. CLAUDE.md auto-loads, so this fires by itself.
    OUT="$REPO/CLAUDE.md"
    [ -f "$OUT" ] || printf '# %s — project instructions\n' "$(basename "$REPO")" > "$OUT"
    if ! grep -q '^## Learnings' "$OUT" 2>/dev/null; then
      printf '\n## Learnings\n\nDurable, auto-loaded rules captured by the @retro learning loop.\n' >> "$OUT"
    fi
    printf -- '\n- **%s** — %s _(retro %s)_\n' "$STATEMENT" "$RATIONALE" "$DATE" >> "$OUT"
    echo "ROUTED → $OUT  (project rule, auto-loads)"
    ;;
  fact)
    # project fact → the harness per-project memory that auto-loads via MEMORY.md.
    # harness encodes the repo path: /a/b/c → -a-b-c under ~/.claude/projects/<enc>/memory/
    ENC="$(printf '%s' "$REPO" | sed 's#/#-#g')"
    MEMDIR="$HOME/.claude/projects/$ENC/memory"
    if [ ! -d "$MEMDIR" ]; then
      echo "route-learning: project memory dir not found ($MEMDIR)." >&2
      echo "  Falling back to <repo>/memory/ (commit it so it travels with the repo)." >&2
      MEMDIR="$REPO/memory"
    fi
    mkdir -p "$MEMDIR"
    FILE="$MEMDIR/$SLUG.md"
    {
      printf -- '---\nname: %s\ndescription: %s\nmetadata:\n  type: project\n---\n\n' "$SLUG" "$STATEMENT"
      printf '%s\n\n**Why:** %s\n\n_(retro %s)_\n' "$STATEMENT" "$RATIONALE" "$DATE"
    } > "$FILE"
    IDX="$MEMDIR/MEMORY.md"
    [ -f "$IDX" ] || printf '# Memory Index\n' > "$IDX"
    printf -- '- [%s](%s.md) — %s\n' "$STATEMENT" "$SLUG" "$RATIONALE" >> "$IDX"
    echo "ROUTED → $FILE  (project fact, auto-loads via MEMORY.md)"
    ;;
  procedure)
    # project procedure → a skill scaffold under <repo>/commands/.
    OUTDIR="$REPO/commands"; mkdir -p "$OUTDIR"
    FILE="$OUTDIR/$SLUG.md"
    if [ -f "$FILE" ]; then
      echo "route-learning: skill $FILE already exists — left untouched (edit by hand)." >&2
    else
      {
        printf -- '---\nname: %s\ndescription: %s\n---\n\n' "$SLUG" "$STATEMENT"
        printf '# %s\n\n%s\n\n**Why this exists:** %s\n\n_(scaffolded by retro %s — flesh out the steps.)_\n' \
          "$STATEMENT" "$STATEMENT" "$RATIONALE" "$DATE"
      } > "$FILE"
      echo "ROUTED → $FILE  (project procedure skill — flesh out the steps)"
    fi
    ;;
  *)
    err "type '$TYPE' has no direct project path (should have been proposed)"
    ;;
esac

# --- cross-project scope-promotion ladder ---------------------------------
# A project learning that RECURS in a 2nd repo isn't project-specific any more.
# Record each project learning in a global index keyed by a signature; when the
# same signature appears for a 2nd DISTINCT repo, PROPOSE promoting it to user
# scope (never auto-promote — user scope is always propose).
SIG="$(slugify "$STATEMENT")"
IDXDIR="${SHIPIT_RETRO_DIR:-$HOME/.claude/shipit-retro}"; mkdir -p "$IDXDIR"
LIDX="$IDXDIR/learning-index.tsv"
if ! grep -qF "$(printf '%s\t%s' "$SIG" "$REPO")" "$LIDX" 2>/dev/null; then
  printf '%s\t%s\t%s\t%s\n' "$SIG" "$REPO" "$DATE" "$TYPE" >> "$LIDX"
fi
repos="$(awk -F'\t' -v s="$SIG" '$1==s {print $2}' "$LIDX" 2>/dev/null | sort -u)"
nrepos="$(printf '%s\n' "$repos" | grep -c .)"
if [ "${nrepos:-0}" -ge 2 ]; then
  names="$(printf '%s\n' "$repos" | sed 's#.*/##' | paste -sd, -)"
  echo "route-learning: PROMOTION CANDIDATE — recurred in $nrepos repos ($names); proposing user-scope promotion." >&2
  PROP="$REPO/PROPOSED-LEARNINGS.md"
  [ -f "$PROP" ] || printf '# Proposed learnings — awaiting human review\n' > "$PROP"
  {
    printf '\n## %s — scope promotion (project → user)\n\n' "$DATE"
    printf '**Status:** pending\n\n'
    printf '**Learning:** %s\n\n' "$STATEMENT"
    printf '**Why promote:** recurred across %s projects (%s) — it generalizes beyond one repo.\n\n' "$nrepos" "$names"
    printf '**Apply to:** `~/.claude/CLAUDE.md` or `~/.claude/MANDATORY.md` (user scope — review first).\n'
  } >> "$PROP"
fi
exit 0
