#!/bin/bash
# Block dangerous commands — preToolUse hook (matcher: execute_bash)
# Intercepts destructive commands before execution

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null)

if [ "$TOOL_NAME" != "execute_bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# === Blocked commands (absolute deny) ===
BLOCKED_PATTERNS=(
  # Destructive file operations
  '\brm\b'
  '\brmdir\b'
  '\bmkfs\b'
  '\bdd\b\s+.*of='
  '\bshred\b'
  '>\s*/dev/sd'
  # Dangerous git operations that discard work
  '\bgit\s+checkout\b(?!.*-b)'   # git checkout (except -b for new branch)
  '\bgit\s+clean\b'
  '\bgit\s+reset\s+--hard\b'
  '\bgit\s+stash\s+drop\b'
  '\bgit\s+branch\s+-[dD]\b'
  # System-level danger
  '\bchmod\s+-R\s+777\b'
  '\bchown\s+-R\b'
  '\bsudo\b'
  '\bcurl\b.*\|\s*(ba)?sh'
  '\bwget\b.*\|\s*(ba)?sh'
  # Kill signals
  '\bkill\s+-9\b'
  '\bkillall\b'
  '\bpkill\b'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qPi "$pattern"; then
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
