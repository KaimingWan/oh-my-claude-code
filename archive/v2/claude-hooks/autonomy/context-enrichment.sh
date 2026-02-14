#!/bin/bash
# context-enrichment.sh — UserPromptSubmit (Kiro + CC)
# Correction detection (with flag for stop hook) + resume detection + high-freq lessons

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
CONTEXT=""

# ===== Correction detection (has stop hook backstop via flag file) =====
CORRECTION_DETECTED=0
if echo "$USER_MSG" | grep -qE '你.{0,5}(错了|不对|不是|忘了|应该)'; then
  CORRECTION_DETECTED=1
elif echo "$USER_MSG" | grep -qE '(别用|不要用|换成|改成|用错了|不是这样|这样不行|重新来|换个方式|不是我要的)'; then
  CORRECTION_DETECTED=1
elif echo "$USER_MSG" | grep -qiE '(you (are|were|got it) wrong|you missed|I told you|you should have|that.s (wrong|incorrect)|no,? (use|do)|not what I|try again|wrong approach)'; then
  CORRECTION_DETECTED=1
fi

if [ "$CORRECTION_DETECTED" -eq 1 ]; then
  CONTEXT="${CONTEXT}🚨 CORRECTION DETECTED. You MUST use the self-reflect skill NOW:\n"
  CONTEXT="${CONTEXT}  1. Identify what was wrong\n"
  CONTEXT="${CONTEXT}  2. Write to correct target file (enforcement.md / AGENTS.md / lessons-learned.md)\n"
  CONTEXT="${CONTEXT}  3. Output: 📝 Learning captured: '[preview]' → [target file]\n\n"
  touch "/tmp/kiro-correction-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
fi

# ===== Resume detection (low cost, occasionally useful) =====
if [ -f ".completion-criteria.md" ]; then
  UNCHECKED=$(grep -c '^\- \[ \]' ".completion-criteria.md" 2>/dev/null || true)
  UNCHECKED=${UNCHECKED:-0}
  if [ "$UNCHECKED" -gt 0 ]; then
    CONTEXT="${CONTEXT}⚠️ Unfinished task: .completion-criteria.md has $UNCHECKED unchecked items. Read it to resume.\n"
  fi
fi

if [ -n "$CONTEXT" ]; then
  echo -e "$CONTEXT"
fi

# ===== High-frequency lessons (has hard hook backstops: block-sed-json etc.) =====
cat << 'LESSONS'
📚 HIGH-FREQ LESSONS (from knowledge/lessons-learned.md):
  • JSON = jq, 无条件无例外。禁止 sed/awk/grep 修改 JSON。
  • macOS 用 stat -f, 禁止 stat -c (GNU-only)。
  • shell 脚本考虑跨平台: BSD vs GNU 工具链差异。
  • grep -c 无匹配时 exit 1 但仍输出 0, 不要和 || echo 0 组合。
LESSONS

exit 0
