#!/usr/bin/env bash
# install-gates.sh — wire ShipIt V4's per-repo gates into a target repo. IDEMPOTENT.
#
# Usage: scripts/install-gates.sh <repo> [--dry-run] [--protect]
#   <repo>      target git repo
#   --dry-run   print the actions, change nothing
#   --protect   also enable branch protection on main via gh (needs repo admin)
#
# Installs (copy + version stamp — stable if the plugin moves; drift is detectable):
#   <repo>/.shipit-gates/         copies of the gate scripts + .version
#   <repo>/.github/workflows/     ci.yml + docs-check.yml (paths rewritten to .shipit-gates/)
#   <repo>/.git/hooks/pre-push    → runs .shipit-gates/pre-push-checks.sh
#   <repo>/.claude/settings.json  PreToolUse docs-sync commit reminder (jq-merged, idempotent)
#
# The global guards (no-push-to-main, secrets, sensitive-paths) need NO install — they
# fire from the plugin's hooks.json in every session. This installer is only the
# repo-specific backstops.

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO=""; DRY=0; PROTECT=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --protect) PROTECT=1 ;;
    -*) echo "install-gates: unknown flag '$a'" >&2; exit 1 ;;
    *)  REPO="$a" ;;
  esac
done
[ -n "$REPO" ] || { echo "usage: install-gates.sh <repo> [--dry-run] [--protect]" >&2; exit 1; }
REPO="$(cd "$REPO" 2>/dev/null && pwd)" || { echo "install-gates: no such dir '$REPO'" >&2; exit 1; }
[ -d "$REPO/.git" ] || { echo "install-gates: '$REPO' is not a git repo" >&2; exit 1; }

VERSION="$(jq -r '.version // "0.0.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo 0.0.0)"
note() { echo "  $*"; }
act()  { if [ "$DRY" = 1 ]; then echo "  [dry-run] $1"; return 0; fi; return 1; }   # act "desc" && return-from-dry

echo "Installing ShipIt V4 gates v$VERSION → $REPO$([ "$DRY" = 1 ] && echo '  (dry-run)')"

# 1. gate scripts → .shipit-gates/
if ! act "copy gates/*.sh → .shipit-gates/"; then
  mkdir -p "$REPO/.shipit-gates"
  cp "$PLUGIN_ROOT"/gates/*.sh "$REPO/.shipit-gates/"
  chmod +x "$REPO/.shipit-gates/"*.sh
  printf 'shipit-v4 gates v%s\n' "$VERSION" > "$REPO/.shipit-gates/.version"
  note ".shipit-gates/ ✓"
fi

# 2. CI workflows (rewrite gates/ path → .shipit-gates/)
if ! act "install .github/workflows/{ci,docs-check}.yml"; then
  mkdir -p "$REPO/.github/workflows"
  for t in "$PLUGIN_ROOT"/gates/ci-templates/*.yml; do
    sed 's#gates/#.shipit-gates/#g' "$t" > "$REPO/.github/workflows/$(basename "$t")"
  done
  note ".github/workflows/ (ci.yml, docs-check.yml) ✓"
fi

# 3. pre-push git hook (back up a pre-existing non-ShipIt hook)
HOOK="$REPO/.git/hooks/pre-push"
if ! act "install .git/hooks/pre-push"; then
  if [ -f "$HOOK" ] && ! grep -q 'shipit-gates' "$HOOK" 2>/dev/null; then
    cp "$HOOK" "$HOOK.pre-shipit.bak"
    note "backed up existing pre-push → pre-push.pre-shipit.bak"
  fi
  cat > "$HOOK" <<'HK'
#!/usr/bin/env bash
# ShipIt V4 pre-push gate (test/typecheck/build + conflict markers)
exec bash "$(git rev-parse --show-toplevel)/.shipit-gates/pre-push-checks.sh"
HK
  chmod +x "$HOOK"
  note ".git/hooks/pre-push ✓"
fi

# 4. docs-sync commit reminder → .claude/settings.json (idempotent jq merge)
SET="$REPO/.claude/settings.json"
if ! act "merge docs-sync reminder → .claude/settings.json"; then
  mkdir -p "$REPO/.claude"
  [ -f "$SET" ] || echo '{}' > "$SET"
  if grep -q 'docs-sync-reminder' "$SET" 2>/dev/null; then
    note ".claude/settings.json reminder already present ✓ (idempotent)"
  else
    cmd='bash "$(git rev-parse --show-toplevel)/.shipit-gates/docs-sync-reminder.sh"'
    tmp="$(mktemp)"
    if jq --arg cmd "$cmd" '
          .hooks //= {} |
          .hooks.PreToolUse //= [] |
          .hooks.PreToolUse += [ { "matcher":"Bash", "hooks":[ { "type":"command", "command":$cmd, "timeout":5 } ] } ]
        ' "$SET" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$SET"; note ".claude/settings.json reminder added ✓"
    else
      rm -f "$tmp"; echo "  ! could not merge $SET (invalid JSON?) — add the reminder by hand" >&2
    fi
  fi
fi

# 5. optional branch protection on main
if [ "$PROTECT" = 1 ]; then
  if ! act "enable branch protection on main (gh)"; then
    if command -v gh >/dev/null 2>&1; then
      slug="$(git -C "$REPO" remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')"
      if [ -n "$slug" ]; then
        gh api -X PUT "repos/$slug/branches/main/protection" -f 'required_pull_request_reviews.required_approving_review_count=0' \
          -F 'enforce_admins=false' -F 'restrictions=' -F 'required_status_checks=' >/dev/null 2>&1 \
          && note "branch protection on main enabled ✓" \
          || echo "  ! could not set branch protection (needs admin) — set it in repo settings" >&2
      fi
    fi
  fi
fi

echo "Done. Review + commit the new files in $REPO to activate the CI gates."
