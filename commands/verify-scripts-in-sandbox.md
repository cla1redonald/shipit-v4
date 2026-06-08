---
name: verify-scripts-in-sandbox
description: Verify a ShipIt V4 shell script by running it against a throwaway sandbox repo and a synthetic JSONL transcript — exercise the real signal paths and spot-check actual output, don't trust that it "ran".
---

# Verify scripts in a sandbox

ShipIt V4's learning-loop scripts (`route-learning.sh`, `retro-tripwire.sh`, `collect-candidates.sh`) have no unit-test harness. Before wiring or extending any of them, **prove the behaviour against a throwaway sandbox** — that's how Phase 1b validated them, and it caught routing/idempotency behaviour that "it ran without error" would have missed.

**Why this exists:** these scripts will be extended (new tripwire signals, new routing rows). The risk of a silent behaviour change recurs every time. Run the script; read the actual output values.

## The pattern

```bash
SB=$(mktemp -d); export SHIPIT_RETRO_DIR="$SB/markers"   # isolate state
```

### route-learning.sh — assert each cell of the table + the hard-safety override
```bash
( cd "$SB" && git init -q )
# project rule → must land in <repo>/CLAUDE.md
scripts/route-learning.sh --type rule --scope project --review direct \
  --statement "X" --rationale "Y" --repo "$SB"; cat "$SB/CLAUDE.md"
# user-scope OR type=check with --review direct → must be FORCED to propose
scripts/route-learning.sh --type rule --scope user --review direct \
  --statement "X" --rationale "Y" --repo "$SB"      # expect "forced review=propose"
scripts/route-learning.sh --type wibble ...         # expect exit 1
```

### retro-tripwire.sh — synthetic transcript, then assert markers
```bash
TR="$SB/t.jsonl"
printf '%s\n' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","name":"Write"}]}}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","is_error":true}]}}' \
  '{"message":{"role":"user","content":"no, that'\''s wrong"}}' > "$TR"
J=$(jq -n --arg t "$TR" --arg s sess '{transcript_path:$t,session_id:$s,stop_hook_active:false}')
printf '%s' "$J" | bash hooks/retro-tripwire.sh   # expect signals=edit,error,correction
printf '%s' "$J" | bash hooks/retro-tripwire.sh   # fire again: idempotent, no 2nd marker
```

### collect-candidates.sh — assert it slices the flagged lines
```bash
bash scripts/collect-candidates.sh sess          # expect the transcript slice for the marker
```

## Checklist
- [ ] Every signal path exercised (not just the happy one).
- [ ] **Actual output read**, not just exit code — the verdict is in the values.
- [ ] Idempotency / re-run behaviour checked where state is involved.
- [ ] `rm -rf "$SB"` at the end.
