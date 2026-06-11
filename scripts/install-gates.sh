#!/usr/bin/env bash
# install-gates.sh — wire ShipIt V4's per-repo gates into a target repo. IDEMPOTENT.
#
# Usage: scripts/install-gates.sh <repo> [--update] [--dry-run] [--protect]
#   <repo>      target git repo
#   --update    refresh ONLY the .shipit-gates/ scripts to this plugin version (the propagation
#               path for a gate fix); leaves CI workflows, pre-push, settings.json, smoke.conf
#   --dry-run   print the actions, change nothing
#   --protect   also enable branch protection on main via gh (needs repo admin)
#
# Installs (copy + version stamp — stable if the plugin moves; drift is detectable):
#   <repo>/.shipit-gates/         gate scripts (*.sh) + ui-smoke.mjs + .version + a default smoke.conf
#   <repo>/.github/workflows/     ci.yml + docs-check.yml + independent-review.yml + runtime-smoke.yml
#                                 + security-review.yml (paths rewritten gates/ → .shipit-gates/)
#   <repo>/.git/hooks/pre-push    → runs .shipit-gates/pre-push-checks.sh
#   <repo>/.claude/settings.json  PreToolUse commit reminders — docs-sync + specialist-nudge
#                                 (@architect/@designer summon) (jq-merged, idempotent)
#
# After install, edit <repo>/.shipit-gates/smoke.conf with the repo's critical routes so the
# runtime-smoke workflow (fires on deployment_status) checks the live deploy, not just CI.
#
# The global guards (no-push-to-main, secrets, sensitive-paths) need NO install — they
# fire from the plugin's hooks.json in every session. This installer is only the
# repo-specific backstops.

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO=""; DRY=0; PROTECT=0; UPDATE=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --protect) PROTECT=1 ;;
    # --update: refresh ONLY the .shipit-gates/ scripts (+ ui-smoke.mjs + .version) to this
    # plugin version — leaving CI workflows, the pre-push hook, .claude/settings.json, and
    # smoke.conf untouched. The propagation path for a gate fix: installed repos carry COPIES
    # (frozen at install), so a plugin-side fix never reaches them without this. Idempotent.
    --update) UPDATE=1 ;;
    -*) echo "install-gates: unknown flag '$a'" >&2; exit 1 ;;
    *)  REPO="$a" ;;
  esac
done
[ -n "$REPO" ] || { echo "usage: install-gates.sh <repo> [--update] [--dry-run] [--protect]" >&2; exit 1; }
REPO="$(cd "$REPO" 2>/dev/null && pwd)" || { echo "install-gates: no such dir '$REPO'" >&2; exit 1; }
# Accept a normal clone (.git dir) OR a git WORKTREE (.git is a file). Worktrees are the
# recommended pattern for concurrent sessions (MANDATORY #6), and `--update` is exactly the
# kind of thing you run from one — so `[ -d .git ]` was too strict.
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "install-gates: '$REPO' is not a git repo or worktree" >&2; exit 1; }

VERSION="$(jq -r '.version // "0.0.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo 0.0.0)"
note() { echo "  $*"; }
act()  { if [ "$DRY" = 1 ]; then echo "  [dry-run] $1"; return 0; fi; return 1; }   # act "desc" && return-from-dry

echo "$([ "$UPDATE" = 1 ] && echo 'Updating' || echo 'Installing') ShipIt V4 gates v$VERSION → $REPO$([ "$DRY" = 1 ] && echo '  (dry-run)')"

# 1. gate scripts → .shipit-gates/  (+ ui-smoke.mjs for the UI tier, + a default smoke.conf)
if ! act "copy gates/*.{sh,mjs} → .shipit-gates/ (+ default smoke.conf)"; then
  mkdir -p "$REPO/.shipit-gates"
  if [ "$UPDATE" = 1 ]; then
    # refresh ONLY the gate files the repo ALREADY has — never impose new ones, so a targeted
    # install (a subset of gates) keeps its shape instead of growing the full set.
    for f in "$REPO"/.shipit-gates/*.sh "$REPO"/.shipit-gates/*.mjs; do
      [ -e "$f" ] || continue
      src="$PLUGIN_ROOT/gates/$(basename "$f")"
      [ -f "$src" ] && cp "$src" "$f"
    done
  else
    cp "$PLUGIN_ROOT"/gates/*.sh "$REPO/.shipit-gates/"
    cp "$PLUGIN_ROOT"/gates/*.mjs "$REPO/.shipit-gates/" 2>/dev/null || true   # ui-smoke.mjs (Playwright UI tier)
  fi
  chmod +x "$REPO/.shipit-gates/"*.sh 2>/dev/null || true
  printf 'shipit-v4 gates v%s\n' "$VERSION" > "$REPO/.shipit-gates/.version"
  if [ ! -f "$REPO/.shipit-gates/smoke.conf" ]; then
    cat > "$REPO/.shipit-gates/smoke.conf" <<'CONF'
# ShipIt runtime smoke-test config — read by the runtime-smoke CI workflow + /ship.
# After each deploy the gate hits your DEPLOYED artifact. Set your CRITICAL routes —
# a SPA root often 200s while /api/* 504s (the exact FocusBoard failure a root check misses).
SHIPIT_SMOKE_PATHS=/                 # comma-separated paths to curl (fail on 5xx/timeout)
SHIPIT_SMOKE_UI=0                    # 1 → also load the page in Playwright and assert it renders
SHIPIT_SMOKE_SELECTOR=body           # selector that must be present for the UI check
SHIPIT_SMOKE_E2E_CMD=                # optional full E2E suite, e.g. "npx playwright test"
CONF
    note ".shipit-gates/smoke.conf written (defaults — edit your critical routes)"
  else
    note ".shipit-gates/smoke.conf present (kept)"
  fi
  note ".shipit-gates/ ✓ (gates + ui-smoke.mjs)"
fi

# --update stops here: scripts refreshed, everything else (CI workflows, pre-push hook,
# .claude/settings.json, smoke.conf, branch protection) left exactly as the repo has it.
if [ "$UPDATE" = 1 ]; then
  echo "Done (update). Refreshed .shipit-gates/ scripts to v$VERSION — CI / settings / smoke.conf untouched. Review + commit in $REPO."
  exit 0
fi

# 2. CI workflows (rewrite gates/ path → .shipit-gates/)
if ! act "install .github/workflows/{ci,docs-check}.yml"; then
  mkdir -p "$REPO/.github/workflows"
  for t in "$PLUGIN_ROOT"/gates/ci-templates/*.yml; do
    sed 's#gates/#.shipit-gates/#g' "$t" > "$REPO/.github/workflows/$(basename "$t")"
  done
  note ".github/workflows/ (ci, docs-check, independent-review, runtime-smoke, security-review) ✓"
fi

# 3. pre-push git hook (back up a pre-existing non-ShipIt hook). Resolve the hooks dir via
#    git so it's correct for a worktree too (its .git is a file; hooks live in the COMMON dir).
GITDIR="$(git -C "$REPO" rev-parse --git-common-dir 2>/dev/null || echo "$REPO/.git")"
case "$GITDIR" in /*) ;; *) GITDIR="$REPO/$GITDIR" ;; esac
HOOK="$GITDIR/hooks/pre-push"
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

# 4b. specialist-nudge commit reminder → .claude/settings.json (idempotent jq merge)
#     Nudges you to summon @architect (migrations/*.sql/api/new deps) or @designer
#     (components/*.tsx/*.css) when staged changes touch those surfaces. Never blocks.
if ! act "merge specialist-nudge → .claude/settings.json"; then
  mkdir -p "$REPO/.claude"
  [ -f "$SET" ] || echo '{}' > "$SET"
  if grep -q 'specialist-nudge' "$SET" 2>/dev/null; then
    note ".claude/settings.json specialist-nudge already present ✓ (idempotent)"
  else
    cmd='bash "$(git rev-parse --show-toplevel)/.shipit-gates/specialist-nudge.sh"'
    tmp="$(mktemp)"
    if jq --arg cmd "$cmd" '
          .hooks //= {} |
          .hooks.PreToolUse //= [] |
          .hooks.PreToolUse += [ { "matcher":"Bash", "hooks":[ { "type":"command", "command":$cmd, "timeout":5 } ] } ]
        ' "$SET" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$SET"; note ".claude/settings.json specialist-nudge added ✓"
    else
      rm -f "$tmp"; echo "  ! could not merge $SET (invalid JSON?) — add the specialist-nudge by hand" >&2
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
