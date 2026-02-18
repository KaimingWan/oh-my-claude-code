#!/bin/bash
# verify-completion.sh — Stop hook
# Check active plan's checklist + re-run all verify commands.
source "$(dirname "$0")/../_lib/common.sh"

# CC stop hook loop prevention: if already continuing from a stop hook, exit immediately
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Check active plan checklist
ACTIVE_PLAN=$(find_active_plan)

if [ -n "$ACTIVE_PLAN" ] && [ -f "$ACTIVE_PLAN" ]; then
  UNCHECKED=$(grep -c '^\- \[ \]' "$ACTIVE_PLAN" 2>/dev/null || true)
  CHECKED=$(grep -c '^\- \[x\]' "$ACTIVE_PLAN" 2>/dev/null || true)
  if [ "${UNCHECKED:-0}" -gt 0 ]; then
    echo ""
    echo "🚫 ═══════════════════════════════════════"
    echo "🚫 INCOMPLETE: $UNCHECKED/$((CHECKED + UNCHECKED)) checklist items remaining in $ACTIVE_PLAN"
    echo "🚫 ═══════════════════════════════════════"
    grep '^\- \[ \]' "$ACTIVE_PLAN"
    exit 0
  fi

  # Re-run all verify commands from checked items
  FAILED=0
  TOTAL=0
  while IFS= read -r line; do
    VERIFY_CMD=$(echo "$line" | sed -n 's/.*| `\(.*\)`$/\1/p')
    [ -z "$VERIFY_CMD" ] && continue
    TOTAL=$((TOTAL + 1))
    if ! timeout 30 bash -c "$VERIFY_CMD" > /dev/null 2>&1; then
      FAILED=$((FAILED + 1))
      echo "❌ VERIFY FAILED: $VERIFY_CMD"
      echo "   Item: $line"
    fi
  done < <(sed -n '/^## Checklist/,/^## /p' "$ACTIVE_PLAN" | grep '^\- \[x\]')

  [ "$FAILED" -gt 0 ] && echo "🚫 $FAILED/$TOTAL verify commands failed. Work is NOT complete."

  # Cleanup verify log
  WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
  [ -f "/tmp/verify-log-${WS_HASH}.jsonl" ] && : > "/tmp/verify-log-${WS_HASH}.jsonl"
fi

# Run tests if available
TEST_CMD=$(detect_test_command)
if [ -n "$TEST_CMD" ]; then
  eval "$TEST_CMD" 2>/dev/null || { echo "⚠️ INCOMPLETE: Tests failing"; exit 0; }
fi

# KB health report (only if knowledge changed this session)
bash "$(dirname "$0")/kb-health-report.sh" 2>/dev/null

exit 0
