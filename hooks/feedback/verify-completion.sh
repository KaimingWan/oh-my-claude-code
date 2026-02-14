#!/bin/bash
# verify-completion.sh — Stop hook
# Simple: check active plan's checklist. Unchecked items = not done.
source "$(dirname "$0")/../_lib/common.sh"

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
fi

# Run tests if available
TEST_CMD=$(detect_test_command)
if [ -n "$TEST_CMD" ]; then
  eval "$TEST_CMD" 2>/dev/null || { echo "⚠️ INCOMPLETE: Tests failing"; exit 0; }
fi

exit 0
