#!/bin/bash
# kb-health-report.sh — 生成知识库质量报告
# 触发条件: kb-changed flag 存在 + 本会话未报告过
# 输出: knowledge/.health-report.md (文件), stdout 一行摘要

KB_FLAG="/tmp/kb-changed-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo default).flag"
COOLDOWN="/tmp/kb-report-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo default).cooldown"

# 条件1: 有变更
[ ! -f "$KB_FLAG" ] && exit 0
rm "$KB_FLAG"

# 条件2: 本会话未报告过
[ -f "$COOLDOWN" ] && exit 0

EPISODES="knowledge/episodes.md"
RULES="knowledge/rules.md"
REPORT="knowledge/.health-report.md"
DATE_PATTERN='[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} |'

EPISODE_COUNT=$(grep -c "$DATE_PATTERN" "$EPISODES" 2>/dev/null || echo 0)
RULE_COUNT=$(grep -c '^[0-9]' "$RULES" 2>/dev/null || echo 0)
RULES_SIZE=$(wc -c < "$RULES" 2>/dev/null | tr -d ' ' || echo 0)
ACTIVE_COUNT=$(grep -c '| active |' "$EPISODES" 2>/dev/null || echo 0)
RESOLVED_COUNT=$(grep -c '| resolved |' "$EPISODES" 2>/dev/null || echo 0)
PROMOTED_COUNT=$(grep -c '| promoted |' "$EPISODES" 2>/dev/null || echo 0)

# 晋升候选：实时计算（提取所有 active episode 的 keywords，找出现 ≥3 次的）
PROMOTE_KEYWORDS=""
if [ -f "$EPISODES" ]; then
  PROMOTE_KEYWORDS=$(grep '| active |' "$EPISODES" 2>/dev/null | cut -d'|' -f3 | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | uniq -c | sort -rn | awk '$1 >= 3 {print $2 " (x" $1 ")"}')
fi
PROMOTE_COUNT=0
if [ -n "$PROMOTE_KEYWORDS" ]; then
  PROMOTE_COUNT=$(echo "$PROMOTE_KEYWORDS" | grep -c '.' 2>/dev/null || echo 0)
fi

# 生成报告文件
cat > "$REPORT" << EOF
# KB Health Report (auto-generated)
Updated: $(date '+%Y-%m-%d %H:%M')

## Status
- rules.md: ${RULE_COUNT}/30 (${RULES_SIZE}B/2048B)
- episodes.md: ${EPISODE_COUNT}/30 (active:${ACTIVE_COUNT} resolved:${RESOLVED_COUNT} promoted:${PROMOTED_COUNT})
- promote candidates: ${PROMOTE_COUNT}

## Actions Needed
EOF

ISSUES=0

if [ "$PROMOTE_COUNT" -gt 0 ]; then
  echo "$PROMOTE_KEYWORDS" | while IFS= read -r kw; do
    [ -n "$kw" ] && echo "- ⬆️ Promote: keyword '$kw' appears ≥3 times in active episodes" >> "$REPORT"
  done
  ISSUES=$((ISSUES + PROMOTE_COUNT))
fi

if [ "$EPISODE_COUNT" -ge 25 ]; then
  echo "- ⚠️ episodes.md nearing cap: ${EPISODE_COUNT}/30" >> "$REPORT"
  ISSUES=$((ISSUES + 1))
fi

if [ "$RESOLVED_COUNT" -gt 10 ]; then
  echo "- 🧹 ${RESOLVED_COUNT} resolved episodes — consider purging" >> "$REPORT"
  ISSUES=$((ISSUES + 1))
fi

if [ "$RULES_SIZE" -gt 1800 ]; then
  echo "- 📏 rules.md approaching limit: ${RULES_SIZE}B/2048B" >> "$REPORT"
  ISSUES=$((ISSUES + 1))
fi

if [ "$ISSUES" -eq 0 ]; then
  echo "- ✅ No issues" >> "$REPORT"
fi

# stdout: 只在有问题时输出一行
if [ "$ISSUES" -gt 0 ]; then
  echo "📊 KB health: $ISSUES issues → knowledge/.health-report.md"
fi

touch "$COOLDOWN"
