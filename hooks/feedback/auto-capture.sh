#!/bin/bash
# auto-capture.sh — 自动落库 pipeline
# 输入: $1 = 用户消息
# 输出: stdout 给 context-enrichment 转发给 agent
# Exit codes: 0 = 已捕获或已存在(不需要self-reflect), 1 = 被过滤(可能需要self-reflect)

USER_MSG="$1"
EPISODES="knowledge/episodes.md"
RULES="knowledge/rules.md"
DATE=$(date +%Y-%m-%d)
DATE_PATTERN='[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} |'

# ── Pre-check: episodes.md must exist (Task 1 creates it) ──
[ ! -f "$EPISODES" ] && exit 1

# ── Gate 1: 过滤低价值 ──
# 问句 → 丢弃
echo "$USER_MSG" | grep -qE '[？?][[:space:]]*$' && exit 1
# 无明确动作 → 丢弃
HAS_ACTION=$(echo "$USER_MSG" | grep -cE '(别用|不要用|换成|改成|禁止|必须|用.{1,10}不要|always|never|don.t|must|use .+ not|stop using)' || true)
[ "$HAS_ACTION" -eq 0 ] && exit 1
# 有明确动作的不受长度限制（Gate 1 只过滤无动作和问句）

# ── Gate 2: 提取关键词（英文技术术语 + 中文动作词 fallback）──
# head -3 取消息中最先出现的3个术语（出现越早越可能是核心词）
KEYWORDS=$(echo "$USER_MSG" | grep -oE '[a-zA-Z_][a-zA-Z0-9_-]{3,}' | grep -viE '^(this|that|with|from|have|been|your|what|when|should|always|never|dont|must|stop|using|every|about|just|like|make|more|than|them|they|these|those|very|will|would|could|also|into|only|some|such|each|other|after|before|because|between|during|without)$' | awk '!seen[$0]++' | head -3 | tr '\n' ',' | sed 's/,$//')
# 无英文关键词 → 尝试提取中文动作词作为 fallback
if [ -z "$KEYWORDS" ]; then
  KEYWORDS=$(echo "$USER_MSG" | grep -oE '(别用|不要用|换成|改成|禁止|必须)[^，。,.\s]{1,10}' | head -2 | tr '\n' ',' | sed 's/,$//')
fi
# 仍无关键词 → 丢弃
[ -z "$KEYWORDS" ] && exit 1

# ── Gate 3: 去重 ──
KEYWORD_PATTERN=$(echo "$KEYWORDS" | tr ',' '|')

# 已在 rules.md → 跳过（已有规则覆盖）
if grep -qiwE "$KEYWORD_PATTERN" "$RULES" 2>/dev/null; then
  exit 0
fi

# 已在 episodes.md → 跳过写入，检查晋升（实时计数，不存储 promote_candidate）
MATCH_COUNT=$(grep -ciwE "$KEYWORD_PATTERN" "$EPISODES" 2>/dev/null | tail -1 || echo 0)
MATCH_COUNT=${MATCH_COUNT:-0}
if [ "$MATCH_COUNT" -gt 0 ]; then
  if [ "$MATCH_COUNT" -ge 2 ]; then
    echo "📚 Similar episode ×$((MATCH_COUNT+1))"
  else
    : # duplicate, skip silently
  fi
  exit 0
fi

# ── Gate 4: 容量检查 ──
EPISODE_COUNT=$(grep -cE '\| (active|resolved|promoted) \|' "$EPISODES" 2>/dev/null || echo 0)
if [ "$EPISODE_COUNT" -ge 30 ]; then
  echo "⚠️ episodes.md at capacity (30/30). New episode NOT captured. Review .health-report.md."
  exit 0
fi

# ── 写入 ──
SUMMARY=$(echo "$USER_MSG" | head -c 80 | tr '|' '/' | tr '\n' ' ')

# Check for correction flag (PID-scoped, glob match any session)
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
CORRECTION_FLAGS=(/tmp/kb-correction-${WS_HASH}-*.flag)
if [ -e "${CORRECTION_FLAGS[0]}" ]; then
  KEYWORDS="${KEYWORDS} [correction]"
  rm -f /tmp/kb-correction-${WS_HASH}-*.flag
fi

echo "$DATE | active | $KEYWORDS | $SUMMARY" >> "$EPISODES"
echo "📝 Auto-captured → episodes.md: '$SUMMARY'"

# ── 标记知识库变更（供 Stop hook 质量报告用）──
# ── OV indexing ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OV_LIB="$SCRIPT_DIR/../_lib/ov-init.sh"
if [ -f "$OV_LIB" ]; then
  source "$OV_LIB"
  if ov_init 2>/dev/null; then
    ov_add "$EPISODES" "episode: $SUMMARY" >/dev/null 2>&1
  fi
fi

touch "/tmp/kb-changed-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo default).flag"
exit 0
