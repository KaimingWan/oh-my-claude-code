#!/bin/bash
# ralph-loop.sh — Kiro CLI wrapper with Ralph Loop discipline
# Keeps restarting Kiro until all checklist items in the active plan are checked off.
# Usage: ./scripts/ralph-loop.sh [max_iterations]
set -euo pipefail

MAX_ITERATIONS="${1:-10}"
PLAN_POINTER="docs/plans/.active"
STALE_ROUNDS=0
MAX_STALE=3

# --- Resolve active plan ---
if [ ! -f "$PLAN_POINTER" ]; then
  echo "❌ No active plan. Run @plan first to set docs/plans/.active"
  exit 1
fi

PLAN_FILE=$(cat "$PLAN_POINTER")
if [ ! -f "$PLAN_FILE" ]; then
  echo "❌ Plan file not found: $PLAN_FILE"
  exit 1
fi

# --- Verify checklist exists ---
TOTAL=$(grep -c '^\- \[[ x]\]' "$PLAN_FILE" 2>/dev/null || true)
if [ "${TOTAL:-0}" -eq 0 ]; then
  echo "❌ Plan has no checklist items. Add a ## Checklist section first."
  exit 1
fi

SUMMARY_FILE="docs/plans/.ralph-result"

LOG_FILE=".ralph-loop.log"

echo "🔄 Ralph Loop — Plan: $PLAN_FILE"
echo "   Max iterations: $MAX_ITERATIONS"
echo "   Log: $LOG_FILE"
echo ""

# --- Write summary on exit ---
write_summary() {
  local exit_code=$?
  local checked unchecked
  checked=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || true)
  unchecked=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || true)
  local skipped
  skipped=$(grep -c '^\- \[SKIP\]' "$PLAN_FILE" 2>/dev/null || true)

  local status="❌ FAILED"
  [ "$exit_code" -eq 0 ] && status="✅ SUCCESS"

  # Build summary content
  local summary
  summary="$(cat <<EOF
# Ralph Loop Result

- **Status:** $status (exit $exit_code)
- **Plan:** $PLAN_FILE
- **Completed:** $checked
- **Remaining:** $unchecked
- **Skipped:** $skipped
- **Finished at:** $(date '+%Y-%m-%d %H:%M:%S')

$([ "${unchecked:-0}" -gt 0 ] && echo "## Remaining Items" && grep '^\- \[ \]' "$PLAN_FILE" || true)
$([ "${skipped:-0}" -gt 0 ] && echo "## Skipped Items" && grep '^\- \[SKIP\]' "$PLAN_FILE" || true)
EOF
)"
  # Write to file AND stdout so caller always sees the result
  echo "$summary" > "$SUMMARY_FILE"
  echo ""
  echo "==============================================================="
  echo "$summary"
  echo "==============================================================="
}
trap write_summary EXIT

PREV_CHECKED=0

for i in $(seq 1 "$MAX_ITERATIONS"); do
  UNCHECKED=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || true)
  CHECKED=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || true)

  # --- Done? ---
  if [ "${UNCHECKED:-0}" -eq 0 ]; then
    echo ""
    echo "✅ All $CHECKED checklist items complete!"
    exit 0
  fi

  # --- Circuit breaker: no progress for MAX_STALE rounds ---
  if [ "$CHECKED" -le "$PREV_CHECKED" ] && [ "$i" -gt 1 ]; then
    STALE_ROUNDS=$((STALE_ROUNDS + 1))
    echo "⚠️  No progress this round ($STALE_ROUNDS/$MAX_STALE stale)"
    if [ "$STALE_ROUNDS" -ge "$MAX_STALE" ]; then
      echo "❌ Circuit breaker: $MAX_STALE rounds with no progress. Stopping."
      echo "   Remaining unchecked items:"
      grep '^\- \[ \]' "$PLAN_FILE"
      exit 1
    fi
  else
    STALE_ROUNDS=0
  fi
  PREV_CHECKED="$CHECKED"

  echo "==============================================================="
  echo " Iteration $i/$MAX_ITERATIONS — $UNCHECKED remaining, $CHECKED done"
  echo "==============================================================="

  # --- Stash dirty state ---
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    git stash push -m "ralph-loop-iter-$i" 2>/dev/null || true
  fi

  # --- Derive memory files from plan directory ---
  PLAN_DIR="$(dirname "$PLAN_FILE")"
  PROGRESS_FILE="$PLAN_DIR/progress.md"
  FINDINGS_FILE="$PLAN_DIR/findings.md"

  # --- Build prompt with next unchecked items ---
  NEXT_ITEMS=$(grep '^\- \[ \]' "$PLAN_FILE" | head -3)

  PROMPT="You are executing a plan. Read these files first:
1. Plan: $PLAN_FILE
2. Progress log: $PROGRESS_FILE (if exists — contains learnings from previous iterations)
3. Findings: $FINDINGS_FILE (if exists — contains research discoveries and decisions)

Next unchecked items:
$NEXT_ITEMS

Rules:
1. Implement the FIRST unchecked item. Verify it works (run tests/typecheck).
2. Update the plan: change that item from '- [ ]' to '- [x]'.
3. Append to $PROGRESS_FILE with format:
   ## Iteration $i — \$(date)
   - **Task:** <what you did>
   - **Files changed:** <list>
   - **Learnings:** <gotchas, patterns discovered>
   - **Status:** done / skipped
4. If you discover reusable patterns or make technical decisions, write to $FINDINGS_FILE.
5. Commit: feat: <item description>.
6. Continue with next unchecked item. Do NOT stop while unchecked items remain.
7. If stuck after 3 attempts, change item to '- [SKIP] <reason>' and move to next."

  # --- Launch fresh Kiro instance (output to log, not stdout) ---
  kiro-cli chat --no-interactive --trust-all-tools "$PROMPT" >> "$LOG_FILE" 2>&1 || true

  sleep 2
done

UNCHECKED=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || true)
echo ""
echo "⚠️ Reached max iterations ($MAX_ITERATIONS). $UNCHECKED items still unchecked."
exit 1
