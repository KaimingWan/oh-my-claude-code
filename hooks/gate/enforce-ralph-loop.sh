#!/bin/bash
# enforce-ralph-loop.sh — PreToolUse[execute_bash] gate
# When an active plan has unchecked items, the FIRST bash command
# must be ralph-loop.sh. Block all other bash commands until ralph-loop starts.
# Once ralph-loop is running (lock file exists), allow everything.
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
case "$TOOL_NAME" in
  execute_bash|Bash) ;;
  *) exit 0 ;;
esac

PLAN_POINTER="docs/plans/.active"
LOCK_FILE=".ralph-loop.lock"

# No active plan → allow
[ ! -f "$PLAN_POINTER" ] && exit 0

PLAN_FILE=$(cat "$PLAN_POINTER" | tr -d '[:space:]')
[ ! -f "$PLAN_FILE" ] && exit 0

# No unchecked items → allow (plan is done)
UNCHECKED=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || true)
[ "${UNCHECKED:-0}" -eq 0 ] && exit 0

# Ralph-loop already running → allow (we're inside the loop)
[ -f "$LOCK_FILE" ] && exit 0

# Check if this command IS ralph-loop.sh
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if echo "$CMD" | grep -q 'ralph-loop'; then
  exit 0
fi

# Block: active plan with unchecked items, not inside ralph-loop
echo "🚫 BLOCKED: Active plan has $UNCHECKED unchecked items."
echo "   Plan: $PLAN_FILE"
echo "   You MUST run: ./scripts/ralph-loop.sh"
echo "   Do NOT execute plan tasks directly. The ralph-loop ensures"
echo "   crash recovery and progress tracking."
exit 2
