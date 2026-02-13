#!/bin/bash
# context-enrichment.sh — UserPromptSubmit (Kiro + CC)
# Smart context injection: correction detection + complexity assessment + debug detection + resume
source "$(dirname "$0")/../_lib/llm-eval.sh"

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
CONTEXT=""

# ===== Correction detection =====
CORRECTION_DETECTED=0
if echo "$USER_MSG" | grep -qE '你.{0,5}(错了|不对|不是|忘了|应该)'; then
  CORRECTION_DETECTED=1
elif echo "$USER_MSG" | grep -qE '(别用|不要用|换成|改成|用错了)'; then
  CORRECTION_DETECTED=1
elif echo "$USER_MSG" | grep -qiE '(you (are|were|got it) wrong|you missed|I told you|you should have|that.s (wrong|incorrect)|no,? (use|do))'; then
  CORRECTION_DETECTED=1
fi

if [ "$CORRECTION_DETECTED" -eq 1 ]; then
  CONTEXT="${CONTEXT}🚨 CORRECTION DETECTED. You MUST use the self-reflect skill NOW:\n"
  CONTEXT="${CONTEXT}  1. Identify what was wrong\n"
  CONTEXT="${CONTEXT}  2. Write to correct target file (enforcement.md / AGENTS.md / lessons-learned.md)\n"
  CONTEXT="${CONTEXT}  3. Output: 📝 Learning captured: '[preview]' → [target file]\n\n"
  touch "/tmp/kiro-correction-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
fi

# ===== Resume detection =====
if [ -f ".completion-criteria.md" ]; then
  UNCHECKED=$(grep -c '^\- \[ \]' ".completion-criteria.md" 2>/dev/null || true)
  UNCHECKED=${UNCHECKED:-0}
  if [ "$UNCHECKED" -gt 0 ]; then
    CONTEXT="${CONTEXT}⚠️ Unfinished task: .completion-criteria.md has $UNCHECKED unchecked items. Read it to resume.\n"
  fi
fi

# ===== Debug detection (deterministic) =====
if echo "$USER_MSG" | grep -qiE 'bug|error|fail|报错|异常|crash|fix|debug|broken|not working|挂了|出错'; then
  CONTEXT="${CONTEXT}🐛 PRE-CHECK: Bug/error detected. Use systematic-debugging skill (NO fixes without root cause).\n"
  [ -f "knowledge/lessons-learned.md" ] && CONTEXT="${CONTEXT}📚 Check knowledge/lessons-learned.md for known issues.\n"
fi

# ===== Complexity assessment (LLM, only for complex non-correction non-debug) =====
HAS_COMPLEX=$(echo "$USER_MSG" | grep -ciE 'implement|实现|build|构建|refactor|重构|design|设计|migrate|迁移|integrate|集成|architect|oauth|auth|payment|deploy' 2>/dev/null || true)
HAS_COMPLEX=${HAS_COMPLEX:-0}
HAS_DEBUG=$(echo "$USER_MSG" | grep -ciE 'bug|error|fail|报错|异常|crash|fix|debug|broken|not working|挂了|出错' 2>/dev/null || true)
HAS_DEBUG=${HAS_DEBUG:-0}

if [ "$HAS_COMPLEX" -gt 0 ] && [ "$CORRECTION_DETECTED" -eq 0 ] && [ "$HAS_DEBUG" -eq 0 ]; then
  MSG_HEAD=$(echo "$USER_MSG" | head -5)
  EVAL=$(llm_eval "User request: ${MSG_HEAD}

Does this task need research or planning before implementation?
Answer ONE word: SIMPLE / NEEDS_RESEARCH / NEEDS_PLAN / NEEDS_BOTH")

  if [ "$EVAL" != "NO_LLM" ]; then
    if echo "$EVAL" | grep -qi "NEEDS_BOTH"; then
      CONTEXT="${CONTEXT}🔬📋 PRE-CHECK: Research AND plan needed.\n"
    elif echo "$EVAL" | grep -qi "NEEDS_RESEARCH"; then
      CONTEXT="${CONTEXT}🔬 PRE-CHECK: Research first. Use research skill.\n"
    elif echo "$EVAL" | grep -qi "NEEDS_PLAN"; then
      CONTEXT="${CONTEXT}📋 PRE-CHECK: Plan needed. Use brainstorming → writing-plans.\n"
    fi
    if ! echo "$EVAL" | grep -qi "SIMPLE"; then
      [ -f "knowledge/lessons-learned.md" ] && CONTEXT="${CONTEXT}📚 Check knowledge/lessons-learned.md for past mistakes.\n"
    fi
  fi
fi

if [ -n "$CONTEXT" ]; then
  echo -e "$CONTEXT"
fi

exit 0
