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
    # Normalize absolute path to relative (Kiro sends absolute paths)
    WORKSPACE=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
    case "$FILE" in "$WORKSPACE"/*) FILE="${FILE#$WORKSPACE/}" ;; esac
    ;;
  *) exit 0 ;;
esac

# ============================================================
# Phase 0: Instruction File Write Protection
# ============================================================
gate_instruction_files() {
  # Advisory: hook file modification reminder
  case "$FILE" in
    hooks/*.sh|hooks/**/*.sh)
      echo "⚠️ Hook file modified. Remember to update enforcement.md and run generate_configs.py --validate" >&2
      ;;
  esac

  case "$FILE" in
    CLAUDE.md|./CLAUDE.md|AGENTS.md|./AGENTS.md) ;;
    knowledge/rules.md|./knowledge/rules.md) ;;
    .claude/rules/*|.kiro/rules/*) ;;
    *) return 0 ;;
  esac
  # episodes.md is agent-writable
  case "$FILE" in *episodes.md) return 0 ;; esac
  [ -f ".skip-instruction-guard" ] && return 0
  hook_block "🚫 BLOCKED: Cannot modify instruction file: $FILE
Human-maintained only. Use @reflect for learnings → episodes.md."
}

# ============================================================
# Phase 1: Workflow Gate (from require-workflow.sh)
# ============================================================
gate_check() {
  is_source_file "$FILE" || return 0
  is_test_file "$FILE" && return 0

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
# Phase 5: Injection & Secret Scan (from scan-skill-injection.sh)
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
# Phase 6: Plan Context Injection (from inject-plan-context.sh)
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
# Phase 2: Brainstorming Gate
# ============================================================
gate_brainstorm() {
  case "$FILE" in docs/plans/*.md) ;; *) return 0 ;; esac
  [ "$COMMAND" = "create" ] || [ "$TOOL_NAME" = "Write" ] || return 0
  [ -f ".skip-plan" ] && return 0
  [ -f ".brainstorm-confirmed" ] && return 0
  hook_block "🚫 BLOCKED: Creating plan without brainstorming confirmation.
Run brainstorming first and confirm direction with user."
}

# ============================================================
# Phase 3: Plan Structure Static Rubric
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
# Phase 4: Checklist Check-off Gate
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
gate_instruction_files
gate_check
gate_brainstorm
gate_plan_structure
gate_checklist
scan_content
inject_plan_context || true

exit 0
