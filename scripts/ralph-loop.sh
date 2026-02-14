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

echo "🔄 Ralph Loop — Plan: $PLAN_FILE"
echo "   Max iterations: $MAX_ITERATIONS"
echo ""

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

  # --- Build prompt with next unchecked items ---
  NEXT_ITEMS=$(grep '^\- \[ \]' "$PLAN_FILE" | head -3)

  PROMPT="You are executing a plan. Read the plan file at $PLAN_FILE.

Next unchecked items:
$NEXT_ITEMS

Implement the FIRST unchecked item above. Verify it works (run tests/typecheck).
Then update the plan file: change that item from '- [ ]' to '- [x]'.
Commit with message: feat: <item description>.
Then continue with the next unchecked item. Do NOT stop while unchecked items remain.
If stuck after 3 attempts on one item, change it to '- [SKIP] <reason>' and move to next."

  # --- Launch fresh Kiro instance ---
  kiro-cli chat --no-interactive --trust-all-tools "$PROMPT" 2>&1 || true

  sleep 2
done

UNCHECKED=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || true)
echo ""
echo "⚠️ Reached max iterations ($MAX_ITERATIONS). $UNCHECKED items still unchecked."
exit 1
