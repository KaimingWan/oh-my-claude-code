#!/bin/bash
# verify-completion.sh — Stop hook (Kiro + CC)
# Phase B: deterministic checks, Phase A: LLM eval, Phase C: correction feedback
source "$(dirname "$0")/../_lib/common.sh"
source "$(dirname "$0")/../_lib/llm-eval.sh"

# ===== Phase B: Deterministic checks =====
CRITERIA=".completion-criteria.md"
if [ -f "$CRITERIA" ]; then
  UNCHECKED=$(grep '^\- \[ \]' "$CRITERIA" 2>/dev/null | wc -l | tr -d ' ')
  CHECKED=$(grep '^\- \[x\]' "$CRITERIA" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNCHECKED" -gt 0 ]; then
    echo "⚠️ INCOMPLETE: $UNCHECKED criteria unchecked:"
    grep '^\- \[ \]' "$CRITERIA"
    exit 0
  fi
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

# ===== Phase A: LLM eval (non-trivial changes only) =====
DIFF_LINES=$(git diff HEAD 2>/dev/null | grep '^[+-]' | wc -l | tr -d ' ')
if [ "$DIFF_LINES" -gt 10 ]; then
  DIFF=$(git diff HEAD 2>/dev/null | head -200)
  CHANGED_FILES=$(git diff --name-only 2>/dev/null | tr '\n' ', ')
  PROMPT=$(jq -n --arg diff "$DIFF" --arg files "$CHANGED_FILES" \
    '"Evaluate this work session.\nChanged: " + $files + "\nDiff (first 200 lines):\n" + $diff + "\n\nCheck YES/NO:\n1.COMPLETE 2.TESTED 3.QUALITY 4.GROUNDED\nFormat: N.NAME: YES/NO"' -r)
  EVAL=$(llm_eval "$PROMPT")
  if [ "$EVAL" != "NO_LLM" ]; then
    echo "🔍 LLM Quality Gate:"
    echo "$EVAL"
  fi
fi

# ===== Phase C: Correction feedback =====
CORRECTION_FLAG="/tmp/agent-correction-$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
REFLECT_CHANGED=$(git diff --name-only 2>/dev/null | grep -cE 'lessons-learned|enforcement|AGENTS|reference' 2>/dev/null || true)

if [ -f "$CORRECTION_FLAG" ] && [ "${REFLECT_CHANGED:-0}" -eq 0 ]; then
  echo "🚨 Correction detected this session but no self-reflect target updated."
  echo "   Use self-reflect skill NOW → write to lessons-learned.md / AGENTS.md / rules/"
  mv "$CORRECTION_FLAG" "${CORRECTION_FLAG}.done" 2>/dev/null
fi

if [ "$CHANGED" -gt 0 ]; then
  echo ""
  echo "📝 Before stopping: lessons-learned.md needs updating? Any index changes needed?"
fi

exit 0
