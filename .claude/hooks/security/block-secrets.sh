#!/bin/bash
# block-secrets.sh — PreToolUse[Bash] (Kiro + CC)
source "$(dirname "$0")/../_lib/common.sh"
source "$(dirname "$0")/../_lib/patterns.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  execute_bash|Bash) ;;
  *) exit 0 ;;
esac

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Check git commit/push for secrets in staged files
if echo "$CMD" | grep -qiE '\bgit[[:space:]]+(commit|push)\b'; then
  STAGED=$(git diff --cached --diff-filter=ACM 2>/dev/null)
  if [ -n "$STAGED" ]; then
    if echo "$STAGED" | grep -qiE "$SECRET_PATTERNS"; then
      hook_block "🚫 BLOCKED: Potential secret detected in staged files.
Run 'git diff --cached' to review.
Remove secrets before committing."
    fi
  fi
fi

exit 0
