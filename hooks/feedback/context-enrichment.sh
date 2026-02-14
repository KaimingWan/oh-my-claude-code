#!/bin/bash
# context-enrichment.sh — UserPromptSubmit (Kiro + CC)
# 3 deterministic functions + auto-capture pipeline.

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

# 1. Correction detection → auto-capture + flag file for stop hook
if echo "$USER_MSG" | grep -qE '你.{0,5}(错了|不对|不是|忘了|应该)'; then
  DETECTED=1
elif echo "$USER_MSG" | grep -qE '(别用|不要用|换成|改成|用错了|不是这样|这样不行|重新来|换个方式|不是我要的)'; then
  DETECTED=1
elif echo "$USER_MSG" | grep -qiE '(you (are|were|got it) wrong|you missed|I told you|you should have|that.s (wrong|incorrect)|no,? (use|do)|not what I|try again|wrong approach)'; then
  DETECTED=1
elif echo "$USER_MSG" | grep -qE '(不是我(想要|要的|期望|需要)|换个(思路|方案|方法)|不够好|差太远|完全不对|跑偏了|方向错了)'; then
  DETECTED=1
elif echo "$USER_MSG" | grep -qiE '(not what I (want|need|expect|asked)|try (a )?(different|another)|start over|that.s not it|off track|missed the point)'; then
  DETECTED=1
else
  DETECTED=0
fi

if [ "$DETECTED" -eq 1 ]; then
  # 自动落库（exit 0=已处理, exit 1=被过滤需要 self-reflect）
  bash "$(dirname "$0")/auto-capture.sh" "$USER_MSG"
  if [ $? -eq 1 ]; then
    # 被过滤 = 复杂洞察，提醒 agent 用 self-reflect 或人用 @reflect
    echo "🚨 CORRECTION DETECTED (complex). Use self-reflect skill or @reflect to capture."
  fi
  touch "/tmp/agent-correction-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
fi

# 2. Unfinished task resume
if [ -f ".completion-criteria.md" ]; then
  UNCHECKED=$(grep '^\- \[ \]' ".completion-criteria.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$UNCHECKED" -gt 0 ] && echo "⚠️ Unfinished task: .completion-criteria.md has $UNCHECKED unchecked items. Read it to resume."
fi

# 3. Rules injection + health check (only once per session)
LESSONS_FLAG="/tmp/lessons-injected-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
if [ ! -f "$LESSONS_FLAG" ]; then
  if [ -f "knowledge/rules.md" ]; then
    echo "📚 AGENT RULES (from knowledge/rules.md):"
    grep '^[0-9]' "knowledge/rules.md" | head -10
  else
    cat << 'FALLBACK'
📚 AGENT RULES (fallback):
  • JSON = jq, 无条件无例外。
  • macOS 用 stat -f, 禁止 stat -c。
FALLBACK
  fi
  # 晋升候选提醒（实时计算，不依赖存储的 promote_candidate 状态）
  if [ -f "knowledge/episodes.md" ]; then
    PROMOTE=$(grep '| active |' "knowledge/episodes.md" 2>/dev/null | cut -d'|' -f3 | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | uniq -c | awk '$1 >= 3' | wc -l | tr -d ' ')
    [ "$PROMOTE" -gt 0 ] && echo "⬆️ $PROMOTE keyword patterns appear ≥3 times in episodes → consider promotion"
  fi
  # 质量报告提醒
  if [ -f "knowledge/.health-report.md" ]; then
    ISSUES=$(grep -cE '⬆️|⚠️|🧹' "knowledge/.health-report.md" 2>/dev/null || true)
    [ "$ISSUES" -gt 0 ] && echo "📊 KB has $ISSUES issues → knowledge/.health-report.md"
  fi
  touch "$LESSONS_FLAG"
fi

exit 0
