#!/bin/bash
# block-dangerous-commands.sh — PreToolUse[Bash] (Kiro + CC)
source "$(dirname "$0")/../_lib/common.sh"
source "$(dirname "$0")/../_lib/patterns.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  execute_bash|Bash) ;;
  *) exit 0 ;;
esac

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

for pattern in "${DANGEROUS_BASH_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "$pattern"; then
    hook_block "🚫 BLOCKED: Dangerous command detected.
Command: $CMD
Matched: $pattern

Use safer alternatives:
- rm → mv to ~/.Trash/
- git reset --hard → git stash first
- git clean → list with -n first"
  fi
done

exit 0
