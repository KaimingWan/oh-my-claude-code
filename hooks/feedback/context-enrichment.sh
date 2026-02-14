#!/bin/bash
# context-enrichment.sh — UserPromptSubmit (Kiro + CC)
# Stripped to 3 deterministic functions only. No soft prompts (proven ineffective).

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

# 1. Correction detection → flag file for stop hook
if echo "$USER_MSG" | grep -qE '你.{0,5}(错了|不对|不是|忘了|应该)'; then
  DETECTED=1
elif echo "$USER_MSG" | grep -qE '(别用|不要用|换成|改成|用错了|不是这样|这样不行|重新来|换个方式|不是我要的)'; then
  DETECTED=1
elif echo "$USER_MSG" | grep -qiE '(you (are|were|got it) wrong|you missed|I told you|you should have|that.s (wrong|incorrect)|no,? (use|do)|not what I|try again|wrong approach)'; then
  DETECTED=1
else
  DETECTED=0
fi

if [ "$DETECTED" -eq 1 ]; then
  echo "🚨 CORRECTION DETECTED. Use self-reflect skill: identify error → write to target file → output 📝 Learning captured."
  touch "/tmp/agent-correction-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
fi

# 2. Unfinished task resume
if [ -f ".completion-criteria.md" ]; then
  UNCHECKED=$(grep '^\- \[ \]' ".completion-criteria.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$UNCHECKED" -gt 0 ] && echo "⚠️ Unfinished task: .completion-criteria.md has $UNCHECKED unchecked items. Read it to resume."
fi

# 3. High-frequency lessons (hardcoded, always injected)
cat << 'LESSONS'
📚 HIGH-FREQ LESSONS (from knowledge/lessons-learned.md):
  • JSON = jq, 无条件无例外。禁止 sed/awk/grep 修改 JSON。
  • macOS 用 stat -f, 禁止 stat -c (GNU-only)。
  • shell 脚本考虑跨平台: BSD vs GNU 工具链差异。
  • grep -c 无匹配时 exit 1 但仍输出 0, 不要和 || echo 0 组合。
LESSONS

exit 0
