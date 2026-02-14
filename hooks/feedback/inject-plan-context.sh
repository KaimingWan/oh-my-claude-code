#!/bin/bash
# inject-plan-context.sh — PreToolUse[write]
# Read Before Decide: inject plan checklist into context before writes.
# Keeps goals in attention window. Advisory only (exit 0).

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)

# Anti-loop: skip if writing to plan/progress/findings
case "$FILE" in
  */progress.md|*/findings.md|docs/plans/*) exit 0 ;;
esac

# Find active plan
ACTIVE=""
[ -f "docs/plans/.active" ] && ACTIVE=$(cat "docs/plans/.active" 2>/dev/null)
[ -z "$ACTIVE" ] || [ ! -f "$ACTIVE" ] && exit 0

# Extract checklist section
CHECKLIST=$(sed -n '/^## Checklist/,/^## /p' "$ACTIVE" 2>/dev/null | head -20)
[ -z "$CHECKLIST" ] && exit 0

echo "📋 Active plan checklist ($ACTIVE):"
echo "$CHECKLIST"

exit 0
