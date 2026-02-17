#!/bin/bash
# session-init.sh — Session initialization (once per session)
# Rules injection, episode cleanup, promotion reminder, health report
# Split from context-enrichment.sh (single responsibility)

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

LESSONS_FLAG="/tmp/lessons-injected-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
[ -f "$LESSONS_FLAG" ] && exit 0

# Episode cleanup: remove promoted episodes
if [ -f "knowledge/episodes.md" ]; then
  PROMOTED_COUNT=$(grep -c '| promoted |' "knowledge/episodes.md" 2>/dev/null || true)
  if [ "${PROMOTED_COUNT:-0}" -gt 0 ]; then
    grep -v '| promoted |' "knowledge/episodes.md" > /tmp/episodes-clean.tmp && mv /tmp/episodes-clean.tmp "knowledge/episodes.md"
    echo "🧹 Cleaned $PROMOTED_COUNT promoted episodes (consolidated to rules)"
  fi
fi

# Keyword-based rules injection
inject_rules() {
  local RULES_FILE="knowledge/rules.md"
  [ -f "$RULES_FILE" ] || return 0

  if ! grep -q '^## \[' "$RULES_FILE" 2>/dev/null; then
    echo "📚 AGENT RULES:" && grep '^[0-9]' "$RULES_FILE"
    return 0
  fi

  local MSG_LOWER=$(echo "$USER_MSG" | tr '[:upper:]' '[:lower:]')
  local INJECTED=0
  local SECTIONS
  SECTIONS=$(awk '/^## \[/{if(sec) print sec "\t" rules; gsub(/^## \[|\]$/,""); sec=$0; rules=""; next} /^[0-9]/{rules=rules $0 "\\n"} END{if(sec) print sec "\t" rules}' "$RULES_FILE")

  while IFS=$'\t' read -r keywords rules; do
    [ -z "$keywords" ] && continue
    for kw in $(echo "$keywords" | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
      if echo "$MSG_LOWER" | grep -qiw "$kw"; then
        echo "📚 Rules ($kw...):"
        printf '%b' "$rules"
        INJECTED=1
        break
      fi
    done
  done <<< "$SECTIONS"

  if [ "$INJECTED" -eq 0 ]; then
    echo "📚 Rules (general):"
    local BEST_SEC
    BEST_SEC=$(awk '/^## \[/{if(cnt>max){max=cnt;best=sec};sec=$0;cnt=0;next}/^[0-9]/{cnt++}END{if(cnt>max)best=sec;print best}' "$RULES_FILE")
    [ -n "$BEST_SEC" ] && awk -v sec="$BEST_SEC" '$0==sec{p=1;next}/^## \[/{p=0}p&&/^[0-9]/' "$RULES_FILE"
  fi
}
inject_rules

# Promotion candidate reminder
if [ -f "knowledge/episodes.md" ]; then
  PROMOTE=$(grep '| active |' "knowledge/episodes.md" 2>/dev/null | cut -d'|' -f3 | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | uniq -c | awk '$1 >= 3' | wc -l | tr -d ' ')
  [ "$PROMOTE" -gt 0 ] && echo "⬆️ $PROMOTE keyword patterns appear ≥3 times in episodes → consider promotion"
fi



# KB health report
if [ -f "knowledge/.health-report.md" ]; then
  ISSUES=$(grep -cE '⬆️|⚠️|🧹' "knowledge/.health-report.md" 2>/dev/null || true)
  [ "$ISSUES" -gt 0 ] && echo "📊 KB has $ISSUES issues → knowledge/.health-report.md"
fi

touch "$LESSONS_FLAG"
exit 0
