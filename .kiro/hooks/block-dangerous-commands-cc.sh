#!/bin/bash
# Block dangerous commands — PreToolUse hook (Claude Code version)
# Reads JSON from stdin, checks tool_input.command
# Uses grep -E (ERE) for macOS compatibility

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

if [ -z "$CMD" ]; then
  exit 0
fi

# Each pattern uses ERE (grep -E) for macOS compat
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
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "$pattern"; then
    echo "🚫 BLOCKED: Dangerous command — $CMD (matched: $pattern)" >&2
    exit 2
  fi
done

exit 0
