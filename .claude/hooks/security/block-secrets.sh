#!/bin/bash
# block-secrets.sh — PreToolUse[Bash] (Kiro + CC)
# Scans for secrets in: 1) commands themselves 2) staged files before git commit/push
source "$(dirname "$0")/../_lib/common.sh"
source "$(dirname "$0")/../_lib/patterns.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  execute_bash|Bash) ;;
  *) exit 0 ;;
esac

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Check 1: secrets in the command itself (echo "sk-xxx" > file, curl -H "Bearer sk-xxx")
if echo "$CMD" | grep -qiE "$SECRET_PATTERNS"; then
  hook_block "🚫 BLOCKED: Secret pattern detected in command.
Command: $CMD
Never put secrets directly in commands. Use environment variables instead."
fi

# Check 2: git commit/push — scan staged files for secrets
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
