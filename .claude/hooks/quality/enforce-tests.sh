#!/bin/bash
# enforce-tests.sh — TaskCompleted (Claude Code only)
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TASK=$(echo "$INPUT" | jq -r '.task_subject // ""' 2>/dev/null)

TEST_CMD=$(detect_test_command)
if [ -n "$TEST_CMD" ]; then
  if ! eval "$TEST_CMD" 2>&1; then
    echo "Tests not passing. Fix failing tests before completing: $TASK" >&2
    exit 2
  fi
fi

exit 0
