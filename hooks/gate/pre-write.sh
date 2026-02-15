#!/bin/bash
# pre-write.sh — Merged preToolUse[fs_write] dispatcher (Kiro + CC)
# Combines: require-workflow (gate) + scan-skill-injection (security) + inject-plan-context (advisory)
# Order: gate check → injection scan → plan context
# gate/scan failures → exit 2 (hard block). plan context → advisory only.
source "$(dirname "$0")/../_lib/common.sh"
source "$(dirname "$0")/../_lib/patterns.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  fs_write|Write|Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.file_text // .tool_input.new_str // ""' 2>/dev/null)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
    ;;
  *) exit 0 ;;
esac

# ============================================================
# Phase 1: Workflow Gate (from require-workflow.sh)
# ============================================================
gate_check() {
  is_source_file "$FILE" || return 0
  is_test_file "$FILE" && return 0

  # Ralph-loop enforcement: if active plan has unchecked items,
  # only allow writes from inside ralph-loop (lock file with live PID)
  local PLAN_PTR="docs/plans/.active"
  local RALPH_LOCK=".ralph-loop.lock"
  if [ -f "$PLAN_PTR" ]; then
    local ACTIVE_PLAN
    ACTIVE_PLAN=$(cat "$PLAN_PTR" | tr -d '[:space:]')
    if [ -f "$ACTIVE_PLAN" ]; then
      local UNCHECKED
      UNCHECKED=$(grep -c '^\- \[ \]' "$ACTIVE_PLAN" 2>/dev/null || true)
      if [ "${UNCHECKED:-0}" -gt 0 ]; then
        local RALPH_OK=false
        if [ -f "$RALPH_LOCK" ]; then
          local LOCK_PID
          LOCK_PID=$(cat "$RALPH_LOCK" 2>/dev/null | tr -d '[:space:]')
          [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null && RALPH_OK=true
        fi
        if [ "$RALPH_OK" = false ]; then
          hook_block "🚫 BLOCKED: Active plan has $UNCHECKED unchecked items.
   You MUST run: ./scripts/ralph-loop.sh
   Do NOT execute plan tasks directly."
        fi
      fi
    fi
  fi

  # Only gate new file creation
  IS_CREATE=false
  case "$TOOL_NAME" in
    fs_write) [ "$COMMAND" = "create" ] && IS_CREATE=true ;;
    Write) IS_CREATE=true ;;
  esac
  [ "$IS_CREATE" = false ] && return 0

  [ -f ".skip-plan" ] && { echo "⚠️ Plan check skipped (.skip-plan exists)." >&2; return 0; }

  PLAN_FILE=$(find_active_plan)
  if [ -z "$PLAN_FILE" ]; then
    hook_block "🚫 BLOCKED: Creating new source file without a plan.
   Required: brainstorming → planning → reviewer → then code.
   Create a plan in docs/plans/ first.
   For quick fixes: touch .skip-plan to bypass."
  fi

  # Check review verdict
  REVIEW_SECTION=$(sed -n '/^## Review/,/^## /p' "$PLAN_FILE" 2>/dev/null | tail -n +2)
  REVIEW_LINES=$(echo "$REVIEW_SECTION" | grep -c '[a-zA-Z]' 2>/dev/null || true)
  if [ "${REVIEW_LINES:-0}" -lt 3 ]; then
    hook_block "🚫 BLOCKED: Plan exists but not yet reviewed.
   The ## Review section in $PLAN_FILE needs content (≥3 lines)."
  fi

  VERDICT=$(echo "$REVIEW_SECTION" | grep -oiE '(Verdict:?\s*|FINAL VERDICT:?\s*|\*\*)(REJECT|CONDITIONAL|APPROVE|REQUEST CHANGES)' | tail -1)
  case "$(echo "$VERDICT" | tr '[:lower:]' '[:upper:]')" in
    *APPROVE*) ;;
    *REJECT*|*"REQUEST CHANGES"*)
      hook_block "🚫 BLOCKED: Plan was rejected. Verdict: $VERDICT" ;;
    *CONDITIONAL*)
      hook_block "🚫 BLOCKED: Plan has conditional approval. Address conditions first." ;;
  esac

  # Advisory: progress reminder
  UNCHECKED=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || true)
  CHECKED=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || true)
  [ "${UNCHECKED:-0}" -gt 0 ] && echo "📋 Progress: ${CHECKED:-0}/$((${CHECKED:-0} + UNCHECKED)) checklist items done" >&2
}

# ============================================================
# Phase 2: Injection & Secret Scan (from scan-skill-injection.sh)
# ============================================================
scan_content() {
  [ -z "$CONTENT" ] && return 0

  # Secret detection (all files, except patterns.sh and test files)
  if echo "$CONTENT" | grep -qiE "$SECRET_PATTERNS"; then
    if ! echo "$FILE" | grep -qiE '(patterns\.sh|test|spec|e2e)'; then
      hook_block "🚫 BLOCKED: Secret pattern detected in: $FILE
Never write secrets directly into files. Use environment variables instead."
    fi
  fi

  # Prompt injection (skill/command files only)
  if echo "$FILE" | grep -qiE '(skills|commands)/.*\.(md|yaml|yml)$'; then
    if echo "$CONTENT" | grep -qiE "$INJECTION_PATTERNS"; then
      hook_block "🚫 BLOCKED: Prompt injection pattern detected in skill: $FILE"
    fi
    # SKILL.md frontmatter check
    if echo "$FILE" | grep -qiE 'SKILL\.md$'; then
      echo "$CONTENT" | head -1 | grep -q '^---' || echo "⚠️ WARNING: SKILL.md missing YAML frontmatter." >&2
    fi
  fi
}

# ============================================================
# Phase 3: Plan Context Injection (from inject-plan-context.sh)
# ============================================================
inject_plan_context() {
  # Anti-loop: skip plan/progress/findings
  case "$FILE" in
    */progress.md|*/findings.md|docs/plans/*) return 0 ;;
  esac

  ACTIVE=""
  [ -f "docs/plans/.active" ] && ACTIVE=$(cat "docs/plans/.active" 2>/dev/null)
  [ -z "$ACTIVE" ] || [ ! -f "$ACTIVE" ] && return 0

  UNCHECKED=$(grep -c '^\- \[ \]' "$ACTIVE" 2>/dev/null || true)
  [ "${UNCHECKED:-0}" -eq 0 ] && return 0

  # Throttle: full checklist every 5 writes, 1-line summary otherwise
  COUNTER_FILE="/tmp/plan-inject-counter-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')"
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
  COUNT=$((COUNT + 1))
  echo "$COUNT" > "$COUNTER_FILE"

  if [ $((COUNT % 5)) -eq 1 ]; then
    CHECKLIST=$(sed -n '/^## Checklist/,/^## /p' "$ACTIVE" 2>/dev/null | head -20)
    echo "📋 Active plan ($ACTIVE):"
    echo "$CHECKLIST"
  else
    echo "📋 $UNCHECKED checklist items remaining in $ACTIVE"
  fi
}

# ============================================================
# Phase 1.5a: Plan Structure Static Rubric
# ============================================================
gate_plan_structure() {
  case "$FILE" in
    docs/plans/*.md) ;;
    *) return 0 ;;
  esac
  # Only check on create (full content available)
  case "$TOOL_NAME" in
    fs_write) [ "$COMMAND" = "create" ] || return 0 ;;
    Write) ;;
    *) return 0 ;;
  esac

  echo "$CONTENT" | grep -q '^## Tasks' || \
    hook_block "🚫 BLOCKED: Plan missing ## Tasks section."
  echo "$CONTENT" | grep -q '^## Checklist' || \
    hook_block "🚫 BLOCKED: Plan missing ## Checklist section."
  echo "$CONTENT" | grep -q '^## Review' || \
    hook_block "🚫 BLOCKED: Plan missing ## Review section."

  TASK_COUNT=$(echo "$CONTENT" | grep -c '^### Task' || true)
  [ "${TASK_COUNT:-0}" -eq 0 ] && \
    hook_block "🚫 BLOCKED: Plan has no ### Task sections."

  VERIFY_COUNT=$(echo "$CONTENT" | grep -c '^\*\*Verify:\*\*' || true)
  [ "${VERIFY_COUNT:-0}" -lt "${TASK_COUNT}" ] && \
    hook_block "🚫 BLOCKED: Not all Tasks have **Verify:** lines. Tasks=$TASK_COUNT, Verify=$VERIFY_COUNT"

  CHECKLIST_TOTAL=$(echo "$CONTENT" | sed -n '/^## Checklist/,/^## /p' | grep -c '^\- \[ \]' || true)
  [ "${CHECKLIST_TOTAL:-0}" -eq 0 ] && \
    hook_block "🚫 BLOCKED: ## Checklist section has no items."

  CHECKLIST_WITH_VERIFY=$(echo "$CONTENT" | sed -n '/^## Checklist/,/^## /p' | grep '^\- \[ \]' | grep -c '| `' || true)
  [ "${CHECKLIST_WITH_VERIFY}" -lt "${CHECKLIST_TOTAL}" ] && \
    hook_block "🚫 BLOCKED: $((CHECKLIST_TOTAL - CHECKLIST_WITH_VERIFY))/$CHECKLIST_TOTAL checklist items missing verify command.
Required format: - [ ] description | \`verify command\`"
}

# ============================================================
# Phase 1.5b: Checklist Check-off Gate
# ============================================================
gate_checklist() {
  case "$FILE" in
    docs/plans/*.md) ;;
    *) return 0 ;;
  esac

  echo "$CONTENT" | grep -q '\- \[x\]' || return 0

  WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
  LOG_FILE="/tmp/verify-log-${WS_HASH}.jsonl"
  NOW=$(date +%s)
  WINDOW=600

  # Use process substitution to avoid subshell from pipe
  while IFS= read -r line; do
    VERIFY_CMD=$(echo "$line" | sed -n 's/.*| `\(.*\)`$/\1/p')

    if [ -z "$VERIFY_CMD" ]; then
      hook_block "🚫 BLOCKED: Checklist item checked without verify command.
Item: $line
Required format: - [ ] description | \`verify command\`"
    fi

    CMD_HASH=$(echo "$VERIFY_CMD" | shasum 2>/dev/null | cut -c1-40)
    if [ ! -f "$LOG_FILE" ]; then
      hook_block "🚫 BLOCKED: No verify execution log found. Run the verify command first.
Item: $line
Command: $VERIFY_CMD"
    fi

    RECENT=$(jq -r --arg h "$CMD_HASH" --argjson now "$NOW" --argjson w "$WINDOW" \
      'select(.cmd_hash == $h and .exit_code == 0 and ($now - .ts) < $w)' \
      "$LOG_FILE" 2>/dev/null | head -1)

    if [ -z "$RECENT" ]; then
      hook_block "🚫 BLOCKED: Verify command not recently executed (or failed).
Item: $line
Command: $VERIFY_CMD
Run the command and confirm it passes before checking off."
    fi
  done < <(echo "$CONTENT" | grep '\- \[x\]')
}

# --- Execute phases in order ---
gate_check
gate_plan_structure
gate_checklist
scan_content
inject_plan_context || true

exit 0
