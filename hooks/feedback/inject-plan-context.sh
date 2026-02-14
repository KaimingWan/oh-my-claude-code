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

# Extract checklist unchecked count
UNCHECKED=$(grep -c '^\- \[ \]' "$ACTIVE" 2>/dev/null || true)
[ "${UNCHECKED:-0}" -eq 0 ] && exit 0

# Throttle: full checklist every 5 writes, 1-line summary otherwise
COUNTER_FILE="/tmp/plan-inject-counter-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ $((COUNT % 5)) -eq 1 ]; then
  CHECKLIST=$(sed -n '/^## Checklist/,/^## /p' "$ACTIVE" 2>/dev/null | head -20)
  echo "📋 Active plan ($ACTIVE):"
  echo "$CHECKLIST"
else
  echo "📋 $UNCHECKED checklist items remaining in $ACTIVE"
fi

exit 0
