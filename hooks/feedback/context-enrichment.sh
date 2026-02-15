#!/bin/bash
# context-enrichment.sh — Lightweight per-prompt enrichment
# Research reminder + unfinished task resume
# Split: correction detection → correction-detect.sh, session init → session-init.sh

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

# Research skill reminder
if echo "$USER_MSG" | grep -qE '(调研|研究一下|查一下|了解一下|对比.*方案)'; then
  echo "🔍 Research detected → read skills/research/SKILL.md for search level strategy (L0→L1→L2)."
elif echo "$USER_MSG" | grep -qiE '(research|investigate|look into|compare.*options|find out)'; then
  echo "🔍 Research detected → read skills/research/SKILL.md for search level strategy (L0→L1→L2)."
fi

# Unfinished task resume
if [ -f ".completion-criteria.md" ]; then
  UNCHECKED=$(grep '^\- \[ \]' ".completion-criteria.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$UNCHECKED" -gt 0 ] && echo "⚠️ Unfinished task: .completion-criteria.md has $UNCHECKED unchecked items. Read it to resume."
fi

exit 0
