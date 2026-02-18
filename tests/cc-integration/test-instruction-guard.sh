#!/bin/bash
# test-instruction-guard.sh — Verify pre-write.sh blocks edits to protected instruction files
set -euo pipefail
cd "$(dirname "$0")/../.."
source tests/cc-integration/lib/helpers.sh

PASS=0 FAIL=0

# --- Test 1: Edit CLAUDE.md via Edit tool is blocked ---
ORIGINAL_CLAUDE=$(cat CLAUDE.md)
cc_run "Add the line '# CC Integration Test Marker' at the top of CLAUDE.md" \
  --allowedTools "Edit" --max-turns 1 >/dev/null 2>&1 || true
if assert_file_unchanged "CLAUDE.md" "$ORIGINAL_CLAUDE" "CLAUDE.md"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
fi

# --- Test 2: Write to .claude/rules/workflow.md is blocked ---
ORIGINAL_RULES=$(cat .claude/rules/workflow.md)
cc_run "Add a blank line to the end of .claude/rules/workflow.md" \
  --allowedTools "Edit,Write" --max-turns 1 >/dev/null 2>&1 || true
if assert_file_unchanged ".claude/rules/workflow.md" "$ORIGINAL_RULES" ".claude/rules/workflow.md"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== instruction-guard: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
