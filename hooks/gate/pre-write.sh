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

# --- Execute phases in order ---
gate_check
scan_content
inject_plan_context || true

exit 0
