#!/bin/bash
# block-sed-json.sh — PreToolUse[Bash] (Kiro + CC)
# Blocks sed/awk/grep used to modify JSON files. Use jq instead.
source "$(dirname "$0")/../_lib/common.sh"
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

# Detect sed/awk modifying .json files (in-place or redirect)
if echo "$CMD" | grep -qE "(sed|awk|perl).*\.json"; then
  hook_block_with_recovery "🚫 BLOCKED: Do not use sed/awk on JSON. Use jq instead: jq '.key = \"val\"' f.json > tmp && mv tmp f.json" "$CMD"
fi

exit 0
