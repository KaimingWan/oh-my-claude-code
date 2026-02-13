#!/bin/bash
# block-sed-json.sh — PreToolUse[Bash] (Kiro + CC)
# Blocks sed/awk/grep used to modify JSON files. Use jq instead.
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  execute_bash|Bash) ;;
  *) exit 0 ;;
esac

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Detect sed/awk modifying .json files (in-place or redirect)
if echo "$CMD" | grep -qE "(sed|awk).*\.json"; then
  hook_block "🚫 BLOCKED: Do not use sed/awk on JSON files.
Command: $CMD

Use jq instead:
- Read:    jq '.key' file.json
- Modify:  jq '.key = \"value\"' file.json > tmp && mv tmp file.json
- In-place (jq 1.7+): jq '.key = \"value\"' --in-place file.json
- Safe string: jq --arg k \"\$val\" '.key = \$k' file.json"
fi

exit 0
