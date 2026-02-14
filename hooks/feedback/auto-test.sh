#!/bin/bash
# auto-test.sh — PostToolUse[Write|Edit] (Kiro + CC)
# Runs tests after source file changes with 30s debounce
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
case "$TOOL_NAME" in
  fs_write|Write|Edit) FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null) ;;
  *) exit 0 ;;
esac

is_source_file "$FILE" || exit 0

# Debounce: skip if same file tested within 30s
LOCK="/tmp/auto-test-$(echo "$FILE" | shasum 2>/dev/null | cut -c1-8 || echo "default").lock"
if [ -f "$LOCK" ]; then
  LOCK_AGE=$(( $(date +%s) - $(file_mtime "$LOCK") ))
  [ "$LOCK_AGE" -lt 30 ] && exit 0
fi
touch "$LOCK"

TEST_CMD=$(detect_test_command)
if [ -n "$TEST_CMD" ]; then
  TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1)
  if [ $? -ne 0 ]; then
    echo "⚠️ Tests failed after editing $FILE:" >&2
    echo "$TEST_OUTPUT" | tail -20 >&2
    exit 1
  fi
fi

exit 0
