#!/bin/bash
# enforce-ralph-loop.sh — PreToolUse[execute_bash] gate
# When an active plan has unchecked items, block direct plan execution.
# Agent must use ralph-loop.sh, not execute tasks directly.
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

# Ralph-loop running (lock file exists AND process alive) → allow
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null | tr -d '[:space:]')
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    exit 0
  fi
  # Stale lock — process dead, clean it up
  rm -f "$LOCK_FILE" 2>/dev/null
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Allow ralph-loop.sh itself
if echo "$CMD" | grep -q 'ralph-loop'; then
  exit 0
fi

# Allow read-only commands (git status, ls, cat, grep, etc.)
if echo "$CMD" | grep -qE '^[[:space:]]*(git (status|log|diff|show|branch)|ls|cat|head|tail|grep|wc|echo|test|md5|shasum|find|awk|sed .* -n|printf)'; then
  exit 0
fi

# Block: active plan with unchecked items, not inside ralph-loop
echo "🚫 BLOCKED: Active plan has $UNCHECKED unchecked items."
echo "   Plan: $PLAN_FILE"
echo "   You MUST run: ./scripts/ralph-loop.sh"
echo "   Do NOT execute plan tasks directly."
exit 2
