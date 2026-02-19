#!/bin/bash
# session-init.sh — Session initialization (once per session)
# Cold-start: promoted episode cleanup, promotion reminder
# Rules injection moved to context-enrichment.sh (per-message, keyword-matched)

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

LESSONS_FLAG="/tmp/lessons-injected-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
[ -f "$LESSONS_FLAG" ] && exit 0

# Episode cleanup: remove promoted episodes (cold-start fallback)
if [ -f "knowledge/episodes.md" ]; then
  PROMOTED_COUNT=$(grep -c '| promoted |' "knowledge/episodes.md" 2>/dev/null || true)
  if [ "${PROMOTED_COUNT:-0}" -gt 0 ]; then
    grep -v '| promoted |' "knowledge/episodes.md" > /tmp/episodes-clean.tmp && mv /tmp/episodes-clean.tmp "knowledge/episodes.md"
  fi
fi

# Promotion candidate reminder
if [ -f "knowledge/episodes.md" ]; then
  PROMOTE=$(grep '| active |' "knowledge/episodes.md" 2>/dev/null | cut -d'|' -f3 | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | uniq -c | awk '$1 >= 3' | wc -l | tr -d ' ')
  [ "$PROMOTE" -gt 0 ] && echo "⬆️ $PROMOTE keyword patterns appear ≥3 times in episodes → consider promotion"
fi

touch "$LESSONS_FLAG"
exit 0
