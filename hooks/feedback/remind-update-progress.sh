#!/bin/bash
# remind-update-progress.sh — PostToolUse[write]
# Reminds agent to update progress.md after file writes. Advisory only.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)

# Anti-loop: skip if writing to plan/progress/findings/config files
case "$FILE" in
  */progress.md|*/findings.md|docs/plans/*|*.json|*.md) exit 0 ;;
esac

# Only remind if there's an active plan
[ -f "docs/plans/.active" ] || exit 0

echo "📝 File updated. If this completes a checklist item, update the plan and progress.md."

exit 0
