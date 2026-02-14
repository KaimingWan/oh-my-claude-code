#!/bin/bash
# require-workflow.sh — PreToolUse[Write|Edit|fs_write] (Kiro + CC)
# Hard gate: blocks creating new source files without an active, reviewed plan.
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  fs_write|Write|Edit) FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null) ;;
  *) exit 0 ;;
esac

# 1. Not a source file → pass
is_source_file "$FILE" || exit 0

# 2. Test file → pass (TDD: tests first)
is_test_file "$FILE" && exit 0

# 3. Small edits (str_replace/Edit) → pass
IS_CREATE=false
case "$TOOL_NAME" in
  fs_write)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
    [ "$COMMAND" = "create" ] && IS_CREATE=true ;;
  Write) IS_CREATE=true ;;
  Edit)  IS_CREATE=false ;;
esac
[ "$IS_CREATE" = false ] && exit 0

# 4. Bypass flag
if [ -f ".skip-plan" ]; then
  echo "⚠️ Plan check skipped (.skip-plan exists). Remove when done." >&2
  exit 0
fi

# 5. Find active plan
PLAN_FILE=$(find_active_plan)

if [ -z "$PLAN_FILE" ]; then
  hook_block "🚫 BLOCKED: Creating new source file without a plan.
   Required: brainstorming → planning → reviewer → then code.
   Create a plan in docs/plans/ first.
   For quick fixes: touch .skip-plan to bypass."
fi

# 6. Check review section
REVIEW_SECTION=$(sed -n '/^## Review/,/^## /p' "$PLAN_FILE" 2>/dev/null | tail -n +2)
REVIEW_LINES=$(echo "$REVIEW_SECTION" | grep -c '[a-zA-Z]' 2>/dev/null || true)
REVIEW_LINES=${REVIEW_LINES:-0}

if [ "$REVIEW_LINES" -lt 3 ]; then
  hook_block "🚫 BLOCKED: Plan exists but not yet reviewed.
   The ## Review section in $PLAN_FILE needs content (≥3 lines).
   Dispatch reviewer subagent to challenge the plan first."
fi

# 7. Check verdict
VERDICT=$(echo "$REVIEW_SECTION" | grep -oiE 'Verdict:\s*(REJECT|CONDITIONAL|APPROVE|REQUEST CHANGES)' | tail -1)
case "$(echo "$VERDICT" | tr '[:lower:]' '[:upper:]')" in
  *REJECT*|*"REQUEST CHANGES"*)
    hook_block "🚫 BLOCKED: Plan was rejected by reviewer.
   Verdict: $VERDICT
   Fix issues in $PLAN_FILE ## Review, then re-review." ;;
  *CONDITIONAL*)
    hook_block "🚫 BLOCKED: Plan has conditional approval.
   Address conditions in $PLAN_FILE ## Review before proceeding." ;;
esac

exit 0
