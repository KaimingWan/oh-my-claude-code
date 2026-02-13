#!/bin/bash
# scan-skill-injection.sh — PreToolUse[Write|Edit] (Kiro + CC)
source "$(dirname "$0")/../_lib/common.sh"
source "$(dirname "$0")/../_lib/patterns.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  fs_write|Write) CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.file_text // .tool_input.new_str // ""' 2>/dev/null)
                  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null) ;;
  Edit)           CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_str // .tool_input.new_string // ""' 2>/dev/null)
                  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) ;;
  *)              exit 0 ;;
esac

# Only check skill/command files
echo "$FILE" | grep -qiE '(skills|commands)/.*\.(md|yaml|yml)$' || exit 0

if echo "$CONTENT" | grep -qiE "$INJECTION_PATTERNS"; then
  hook_block "🚫 BLOCKED: Prompt injection pattern detected in skill: $FILE"
fi

# Quality: SKILL.md must have frontmatter
if echo "$FILE" | grep -qiE 'SKILL\.md$'; then
  if ! echo "$CONTENT" | head -1 | grep -q '^---'; then
    echo "⚠️ WARNING: SKILL.md missing YAML frontmatter (---). Add name and description." >&2
  fi
fi

exit 0
