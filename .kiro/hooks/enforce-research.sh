#!/bin/bash
# Anti-hallucination guard — preToolUse hook (matcher: fs_write)
# Catches unsupported negative claims before they're written to files

INPUT=$(cat)

DENIAL_PATTERNS="no.*mechanism|doesn't.*support|not.*available|cannot.*implement|impossible|no way to|not possible|doesn't.*exist|currently.*no"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null)

if [ "$TOOL_NAME" = "fs_write" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.file_text // .tool_input.new_str // ""' 2>/dev/null)
  if echo "$CONTENT" | grep -qiE "$DENIAL_PATTERNS"; then
    echo "⚠️ Negative claim detected. Please verify against official docs before writing." >&2
  fi
fi

exit 0
