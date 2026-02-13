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
HAS_COMPLEX=$(echo "$USER_MSG" | grep -ciE 'implement|实现|build|构建|refactor|重构|design|设计|migrate|迁移|integrate|集成|architect|oauth|auth|payment|deploy|测试方案|test plan|subagent|并行|parallel|方案|framework|架构|端到端|e2e|end.to.end' 2>/dev/null || true)
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
      CONTEXT="${CONTEXT}🚨 MANDATORY WORKFLOW — This is a complex task. You MUST follow this sequence:\n"
      CONTEXT="${CONTEXT}  Step 1: brainstorming skill — explore intent, requirements, constraints with user\n"
      CONTEXT="${CONTEXT}  Step 2: research skill — gather information needed\n"
      CONTEXT="${CONTEXT}  Step 3: writing-plans skill — write plan to docs/plans/\n"
      CONTEXT="${CONTEXT}  Step 4: spawn reviewer subagent — reviewer MUST challenge the plan before you proceed\n"
      CONTEXT="${CONTEXT}  Step 5: update plan with reviewer feedback, THEN proceed to implementation\n"
      CONTEXT="${CONTEXT}  DO NOT read code, run commands, or start implementation before completing Step 4.\n"
      CONTEXT="${CONTEXT}  DO NOT skip the reviewer. Writing a plan without review is a violation.\n\n"
    elif echo "$EVAL" | grep -qi "NEEDS_RESEARCH"; then
      CONTEXT="${CONTEXT}🚨 MANDATORY: Research first before implementation. Use research skill.\n"
      CONTEXT="${CONTEXT}  DO NOT start coding before research is complete.\n\n"
    elif echo "$EVAL" | grep -qi "NEEDS_PLAN"; then
      CONTEXT="${CONTEXT}🚨 MANDATORY WORKFLOW — This task needs a plan:\n"
      CONTEXT="${CONTEXT}  Step 1: brainstorming skill — explore intent with user\n"
      CONTEXT="${CONTEXT}  Step 2: writing-plans skill — write plan to docs/plans/\n"
      CONTEXT="${CONTEXT}  Step 3: spawn reviewer subagent — reviewer MUST challenge the plan before you proceed\n"
      CONTEXT="${CONTEXT}  Step 4: update plan with reviewer feedback, THEN proceed to implementation\n"
      CONTEXT="${CONTEXT}  DO NOT skip the reviewer. Writing a plan without review is a violation.\n\n"
    elif echo "$EVAL" | grep -qi "SIMPLE"; then
      : # Simple task, no action needed
    else
      # LLM returned unexpected format — fall back to keyword-based detection
      if [ "$HAS_COMPLEX" -ge 2 ]; then
        CONTEXT="${CONTEXT}🚨 MANDATORY WORKFLOW — Complex task detected. You MUST:\n"
        CONTEXT="${CONTEXT}  Step 1: brainstorming skill — explore intent with user\n"
        CONTEXT="${CONTEXT}  Step 2: writing-plans skill — write plan to docs/plans/\n"
        CONTEXT="${CONTEXT}  Step 3: spawn reviewer subagent — reviewer MUST challenge the plan before you proceed\n"
        CONTEXT="${CONTEXT}  DO NOT skip the reviewer. Writing a plan without review is a violation.\n\n"
      else
        CONTEXT="${CONTEXT}📋 Complex task detected. Consider: brainstorming → writing-plans before implementation.\n"
      fi
    fi
    if ! echo "$EVAL" | grep -qi "SIMPLE"; then
      [ -f "knowledge/lessons-learned.md" ] && CONTEXT="${CONTEXT}📚 Check knowledge/lessons-learned.md for past mistakes.\n"
    fi
  else
    # No LLM available — deterministic fallback for complex tasks
    # Multiple complex keywords = likely needs planning
    if [ "$HAS_COMPLEX" -ge 2 ]; then
      CONTEXT="${CONTEXT}🚨 MANDATORY WORKFLOW — Complex task detected (multiple signals). You MUST:\n"
      CONTEXT="${CONTEXT}  Step 1: brainstorming skill — explore intent with user\n"
      CONTEXT="${CONTEXT}  Step 2: writing-plans skill — write plan to docs/plans/\n"
      CONTEXT="${CONTEXT}  Step 3: spawn reviewer subagent — reviewer MUST challenge the plan before you proceed\n"
      CONTEXT="${CONTEXT}  DO NOT skip the reviewer. Writing a plan without review is a violation.\n\n"
    else
      CONTEXT="${CONTEXT}📋 Complex task detected. Consider: brainstorming → writing-plans before implementation.\n"
    fi
    [ -f "knowledge/lessons-learned.md" ] && CONTEXT="${CONTEXT}📚 Check knowledge/lessons-learned.md for past mistakes.\n"
  fi
fi

if [ -n "$CONTEXT" ]; then
  echo -e "$CONTEXT"
fi

exit 0
