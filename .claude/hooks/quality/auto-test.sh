#!/bin/bash
# auto-test.sh — PostToolUse[Write|Edit] (Kiro + CC)
# Runs tests after source file changes with 30s debounce
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
FILE=$(get_tool_file "$INPUT")

is_source_file "$FILE" || exit 0

# Debounce: skip if same file tested within 30s
LOCK="/tmp/auto-test-$(echo "$FILE" | shasum 2>/dev/null | cut -c1-8 || echo "default").lock"
if [ -f "$LOCK" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
  [ "$LOCK_AGE" -lt 30 ] && exit 0
fi
touch "$LOCK"

TEST_CMD=$(detect_test_command)
if [ -n "$TEST_CMD" ] && ! eval "$TEST_CMD" 2>/dev/null; then
  echo "⚠️ Tests failed after editing $FILE. Fix before continuing." >&2
  exit 1
fi

exit 0
