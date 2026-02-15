#!/bin/bash
# correction-detect.sh — Correction detection + auto-capture trigger
# Split from context-enrichment.sh (single responsibility)

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

DETECTED=0
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
fi

if [ "$DETECTED" -eq 1 ]; then
  bash "$(dirname "$0")/auto-capture.sh" "$USER_MSG"
  if [ $? -eq 1 ]; then
    echo "🚨 CORRECTION DETECTED (complex). Use self-reflect skill or @reflect to capture."
  fi
  touch "/tmp/agent-correction-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
fi

exit 0
