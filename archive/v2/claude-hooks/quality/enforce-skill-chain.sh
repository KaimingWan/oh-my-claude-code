#!/bin/bash
# enforce-skill-chain.sh — PreToolUse[Write|Edit] (Kiro + CC)
# Only blocks creating NEW source files without a plan. Edits pass through.
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  fs_write|Write|Edit) FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null) ;;
  *) exit 0 ;;
esac

# Only check source code files
is_source_file "$FILE" || exit 0

# Allow test files (TDD: tests first)
is_test_file "$FILE" && exit 0

# Small changes (str_replace/Edit) pass through — no plan needed for hotfixes
IS_CREATE=false
case "$TOOL_NAME" in
  fs_write)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
    [ "$COMMAND" = "create" ] && IS_CREATE=true ;;
  Write) IS_CREATE=true ;;
  Edit)  IS_CREATE=false ;;
esac
[ "$IS_CREATE" = false ] && exit 0

# User bypass
if [ -f ".skip-plan" ]; then
  echo "⚠️ Plan check skipped (.skip-plan exists). Remove it when done." >&2
  exit 0
fi

# Check: plan file exists and is recent (within 24h)?
PLAN_EXISTS=false
PLAN_FILE=""
if ls docs/plans/*.md &>/dev/null; then
  LATEST_PLAN=$(ls -t docs/plans/*.md 2>/dev/null | head -1)
  PLAN_AGE=$(( $(date +%s) - $(stat -f %m "$LATEST_PLAN" 2>/dev/null || stat -c %Y "$LATEST_PLAN" 2>/dev/null || echo 0) ))
  if [ "$PLAN_AGE" -lt 86400 ]; then
    PLAN_EXISTS=true
    PLAN_FILE="$LATEST_PLAN"
  fi
fi
if [ "$PLAN_EXISTS" = false ] && [ -f ".completion-criteria.md" ]; then
  PLAN_EXISTS=true
  PLAN_FILE=".completion-criteria.md"
fi

if [ "$PLAN_EXISTS" = false ]; then
  hook_block "🚫 BLOCKED: Creating new source file without a plan.
   Required: brainstorming → writing-plans → then code.
   Create a plan in docs/plans/ or .completion-criteria.md first.
   For quick fixes, create .skip-plan to bypass."
fi

# Check: plan has substantive review (≥3 lines in ## Review section)?
if [ -n "$PLAN_FILE" ]; then
  REVIEW_SECTION=$(sed -n '/^## Review/,/^## /p' "$PLAN_FILE" 2>/dev/null | tail -n +2)
  REVIEW_LINES=$(echo "$REVIEW_SECTION" | grep -c '[a-zA-Z]' || true)
  REVIEW_LINES=${REVIEW_LINES:-0}
  if [ "$REVIEW_LINES" -lt 3 ]; then
    hook_block "🚫 BLOCKED: Plan exists but reviewer has not reviewed it yet.
   The ## Review section in $PLAN_FILE needs substantive content (≥3 lines).
   Spawn reviewer subagent to challenge the plan first."
  fi

  # Check verdict: REJECT or CONDITIONAL blocks execution
  VERDICT=$(echo "$REVIEW_SECTION" | grep -oiE 'Verdict:\s*(REJECT|CONDITIONAL|APPROVE|REQUEST CHANGES)' | tail -1 | sed 's/.*: *//')
  case "$(echo "$VERDICT" | tr '[:lower:]' '[:upper:]')" in
    REJECT*|"REQUEST CHANGES"*)
      hook_block "🚫 BLOCKED: Plan was REJECTED by reviewer.
   Verdict: $VERDICT
   Fix the issues noted in $PLAN_FILE ## Review, then re-review before coding." ;;
    CONDITIONAL*)
      hook_block "🚫 BLOCKED: Plan has CONDITIONAL approval.
   Verdict: $VERDICT
   Address the conditions in $PLAN_FILE ## Review before proceeding." ;;
  esac

  # Check: plan references required skills for high-risk patterns?
  PLAN_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null)
  MISSING_SKILL=""

  if echo "$PLAN_CONTENT" | grep -qiE '(parallel|subagent|sub.agent|并行|拆分|分发)'; then
    echo "$PLAN_CONTENT" | grep -qiE 'dispatching-parallel-agents' || MISSING_SKILL="dispatching-parallel-agents"
  fi

  if echo "$PLAN_CONTENT" | grep -qiE '(debug|bug|排查|调试|故障)'; then
    echo "$PLAN_CONTENT" | grep -qiE 'systematic-debugging' || MISSING_SKILL="systematic-debugging"
  fi

  if [ -n "$MISSING_SKILL" ]; then
    hook_block "🚫 BLOCKED: Plan involves high-risk pattern but doesn't reference required skill.
   Missing: $MISSING_SKILL
   Read the skill first, then update the plan to reference it."
  fi
fi

exit 0
