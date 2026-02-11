#!/bin/bash
# Block dangerous commands — preToolUse hook (Kiro version)
# Uses grep -E (ERE) for macOS compatibility

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null)

if [ "$TOOL_NAME" != "execute_bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

BLOCKED_PATTERNS=(
  '\brm\b'
  '\brmdir\b'
  '\bmkfs\b'
  '\bshred\b'
  '\bgit +clean\b'
  '\bgit +reset +--hard\b'
  '\bgit +stash +drop\b'
  '\bgit +branch +-[dD]\b'
  '\bchmod +-R +777\b'
  '\bchown +-R\b'
  '\bsudo\b'
  'curl.*\| *(ba)?sh'
  'wget.*\| *(ba)?sh'
  '\bkill +-9\b'
  '\bkillall\b'
  '\bpkill\b'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "$pattern"; then
    cat << EOF
🚫 BLOCKED: Dangerous command detected.

Command: $CMD
Matched: $pattern

This command is blocked by security policy. If you truly need this:
1. Explain WHY to the user
2. Ask for explicit confirmation
3. Use the safest possible alternative

Alternatives:
- rm → move to trash (e.g., mv FILE ~/.Trash/)
- git checkout → git stash first, then switch
- git reset --hard → git stash, or git diff to review first
- git clean → list with -n first, never -f directly
EOF
    exit 2
  fi
done

exit 0
