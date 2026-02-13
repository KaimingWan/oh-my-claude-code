#!/bin/bash
# verify-completion.sh — Stop hook (Kiro + CC)
# Phase B: deterministic checks, Phase A: LLM 6-dim eval, Phase C: feedback loop
source "$(dirname "$0")/../_lib/common.sh"
source "$(dirname "$0")/../_lib/llm-eval.sh"

# ===== Phase B: Deterministic checks (zero cost, always run) =====
CRITERIA=".completion-criteria.md"
if [ -f "$CRITERIA" ]; then
  UNCHECKED=$(grep -c '^\- \[ \]' "$CRITERIA" 2>/dev/null || true)
  UNCHECKED=${UNCHECKED:-0}
  CHECKED=$(grep -c '^\- \[x\]' "$CRITERIA" 2>/dev/null || true)
  CHECKED=${CHECKED:-0}
  if [ "$UNCHECKED" -gt 0 ]; then
    echo "⚠️ INCOMPLETE: $UNCHECKED criteria unchecked:"
    grep '^\- \[ \]' "$CRITERIA"
    exit 0
  fi
  # All checked — archive
  if [ "$CHECKED" -gt 0 ] && [ "$UNCHECKED" -eq 0 ]; then
    ARCHIVE="docs/completed/$(date +%Y-%m-%d)-$(head -1 "$CRITERIA" | sed 's/^# //;s/ /-/g;s/[^a-zA-Z0-9_-]//g' | head -c 40).md"
    mkdir -p docs/completed
    mv "$CRITERIA" "$ARCHIVE" 2>/dev/null && echo "📦 Criteria archived → $ARCHIVE"
  fi
fi

TEST_CMD=$(detect_test_command)
if [ -n "$TEST_CMD" ]; then
  eval "$TEST_CMD" 2>/dev/null || { echo "⚠️ INCOMPLETE: Tests failing"; exit 0; }
fi

CHANGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
[ "$CHANGED" -eq 0 ] && exit 0

# ===== Phase A: LLM 6-dim quality gate (only for non-trivial changes) =====
DIFF_LINES=$(git diff HEAD 2>/dev/null | grep -c '^[+-]' || true)
DIFF_LINES=${DIFF_LINES:-0}
if [ "$DIFF_LINES" -le 10 ]; then
  echo "📋 Minor change ($DIFF_LINES lines). Skipping LLM eval."
else
  DIFF=$(git diff HEAD 2>/dev/null | head -200)
  CHANGED_FILES=$(git diff --name-only 2>/dev/null | tr '\n' ', ')
  HAS_TESTS=$(git diff --name-only 2>/dev/null | grep -ciE '(test|spec)' || true)
  HAS_TESTS=${HAS_TESTS:-0}
  HAS_PLAN=$(ls docs/plans/*.md .completion-criteria.md 2>/dev/null | head -1)
  SRC_COUNT=$(git diff --name-only 2>/dev/null | grep -cE '\.(ts|js|py|java|rs|go)$' || true)
  SRC_COUNT=${SRC_COUNT:-0}

  PROMPT=$(jq -n --arg diff "$DIFF" --arg files "$CHANGED_FILES" --arg src "$SRC_COUNT" --arg tests "$HAS_TESTS" --arg plan "${HAS_PLAN:-none}" '
    "You are a code review gate. Evaluate this work session.\n\n" +
    "Changed files: " + $files + "\nSource files: " + $src + "\nTest files: " + $tests + "\nPlan: " + $plan + "\n" +
    "Diff (first 200 lines):\n" + $diff + "\n\n" +
    "Check YES/NO:\n1. COMPLETE: Changes complete?\n2. REVIEWED: Evidence of independent review?\n3. TESTED: Logic code has test changes?\n4. RESEARCHED: Informed decisions?\n5. QUALITY: No copy-paste/hardcoded values?\n6. GROUNDED: No hallucinated APIs?\nFormat: 1.COMPLETE: YES/NO"
  ' -r)

  EVAL=$(llm_eval "$PROMPT")
  if [ "$EVAL" = "NO_LLM" ]; then
    echo "📋 Changed: ${CHANGED_FILES} (LLM eval skipped: no API key)"
  else
    echo "🔍 LLM Quality Gate:"
    echo "$EVAL"
  fi
fi

# ===== Phase C: Feedback loop (smart trigger) =====
REFLECT_CHANGED=$(git diff --name-only 2>/dev/null | grep -cE 'lessons-learned|enforcement|AGENTS|reference' || true)
REFLECT_CHANGED=${REFLECT_CHANGED:-0}
CORRECTION_FLAG="/tmp/kiro-correction-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"

SRC_CHANGED=$(git diff --name-only 2>/dev/null | grep -cE '\.(ts|js|py|java|rs|go)$' || true)
SRC_CHANGED=${SRC_CHANGED:-0}
if [ "$SRC_CHANGED" -gt 0 ]; then
  echo "⚠️ $SRC_CHANGED source files changed. Did you run code review? (code-review-expert skill)"
fi

if [ "$REFLECT_CHANGED" -eq 0 ]; then
  if [ -f "$CORRECTION_FLAG" ]; then
    echo "⚠️ MANDATORY: Correction happened but no self-reflect target was updated."
    echo "   Use self-reflect skill: write to the correct target file."
    rm -f "$CORRECTION_FLAG"
  elif [ "$DIFF_LINES" -gt 50 ] 2>/dev/null; then
    echo "💡 Large change ($CHANGED files). Consider recording wins/mistakes via self-reflect skill."
  fi
fi

if [ "$CHANGED" -gt 0 ]; then
  echo ""
  echo "📝 Feedback loop:"
  echo "  1. Update knowledge/lessons-learned.md — mistakes or wins?"
  echo "  2. Any structured output worth saving to a file?"
  echo "  3. Any index (knowledge/INDEX.md, docs/INDEX.md) need updating?"
fi

exit 0
