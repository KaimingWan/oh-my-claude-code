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
  # 遗忘机制：清除已晋升的 episodes
  if [ -f "knowledge/episodes.md" ]; then
    PROMOTED_COUNT=$(grep -c '| promoted |' "knowledge/episodes.md" 2>/dev/null || true)
    if [ "${PROMOTED_COUNT:-0}" -gt 0 ]; then
      grep -v '| promoted |' "knowledge/episodes.md" > /tmp/episodes-clean.tmp && mv /tmp/episodes-clean.tmp "knowledge/episodes.md"
      echo "🧹 Cleaned $PROMOTED_COUNT promoted episodes (consolidated to rules)"
    fi
  fi

  # 按需注入 rules（keyword section 匹配）
  inject_rules() {
    local RULES_FILE="knowledge/rules.md"
    [ -f "$RULES_FILE" ] || return 0

    # 旧格式 fallback：无 section header 时全量注入
    if ! grep -q '^## \[' "$RULES_FILE" 2>/dev/null; then
      echo "📚 AGENT RULES:" && grep '^[0-9]' "$RULES_FILE"
      return 0
    fi

    local MSG_LOWER=$(echo "$USER_MSG" | tr '[:upper:]' '[:lower:]')
    local INJECTED=0

    # awk 一次解析，输出 "keywords\trules" 行，存到临时变量
    local SECTIONS
    SECTIONS=$(awk '/^## \[/{if(sec) print sec "\t" rules; gsub(/^## \[|\]$/,""); sec=$0; rules=""; next} /^[0-9]/{rules=rules $0 "\\n"} END{if(sec) print sec "\t" rules}' "$RULES_FILE")

    # 遍历 sections 匹配关键词
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

    # 无匹配 → 注入最大 section
    if [ "$INJECTED" -eq 0 ]; then
      echo "📚 Rules (general):"
      local BEST_SEC
      BEST_SEC=$(awk '/^## \[/{if(cnt>max){max=cnt;best=sec};sec=$0;cnt=0;next}/^[0-9]/{cnt++}END{if(cnt>max)best=sec;print best}' "$RULES_FILE")
      [ -n "$BEST_SEC" ] && awk -v sec="$BEST_SEC" '$0==sec{p=1;next}/^## \[/{p=0}p&&/^[0-9]/' "$RULES_FILE"
    fi
  }
  inject_rules

  # 晋升候选提醒
  if [ -f "knowledge/episodes.md" ]; then
    PROMOTE=$(grep '| active |' "knowledge/episodes.md" 2>/dev/null | cut -d'|' -f3 | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | uniq -c | awk '$1 >= 3' | wc -l | tr -d ' ')
    [ "$PROMOTE" -gt 0 ] && echo "⬆️ $PROMOTE keyword patterns appear ≥3 times in episodes → consider promotion"
  fi
  # 委派提醒
  echo "⚡ Delegation: >3 independent tasks → use subagent per task. Never delegate code/grep/web_search tasks."
  # 质量报告提醒
  if [ -f "knowledge/.health-report.md" ]; then
    ISSUES=$(grep -cE '⬆️|⚠️|🧹' "knowledge/.health-report.md" 2>/dev/null || true)
    [ "$ISSUES" -gt 0 ] && echo "📊 KB has $ISSUES issues → knowledge/.health-report.md"
  fi
  touch "$LESSONS_FLAG"
fi

exit 0
