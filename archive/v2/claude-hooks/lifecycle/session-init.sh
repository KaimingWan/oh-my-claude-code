#!/bin/bash
# session-init.sh — SessionStart (CC only)
# Environment setup at session start

echo "🚀 Session started at $(date '+%Y-%m-%d %H:%M:%S')"

# Check for unfinished tasks
if [ -f ".completion-criteria.md" ]; then
  UNCHECKED=$(grep -c '^\- \[ \]' ".completion-criteria.md" 2>/dev/null || true)
  UNCHECKED=${UNCHECKED:-0}
  [ "$UNCHECKED" -gt 0 ] && echo "⚠️ Unfinished task: .completion-criteria.md has $UNCHECKED unchecked items."
fi

exit 0
