#!/bin/bash
# block-dangerous-commands.sh — PreToolUse[Bash] (Kiro + CC)
source "$(dirname "$0")/../_lib/common.sh"
source "$(dirname "$0")/../_lib/patterns.sh"
if ! source "$(dirname "$0")/../_lib/block-recovery.sh" 2>/dev/null; then
  hook_block_with_recovery() { hook_block "$1"; }
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  execute_bash|Bash) ;;
  *) exit 0 ;;
esac

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# git commit is safe — message content is not executable code
if echo "$CMD" | grep -qE '^\s*git\s+commit\b'; then
  exit 0
fi

for pattern in "${DANGEROUS_BASH_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qE "$pattern"; then
    hook_block_with_recovery "🚫 BLOCKED: Dangerous command (matched: $pattern). Alt: mv to ~/.Trash/ | git stash" "$CMD"
  fi
done

for pattern in "${DANGEROUS_BASH_PATTERNS_NOCASE[@]}"; do
  if echo "$CMD" | grep -qiE "$pattern"; then
    hook_block_with_recovery "🚫 BLOCKED: Dangerous command (matched: $pattern). Alt: mv to ~/.Trash/ | git stash" "$CMD"
  fi
done

exit 0
