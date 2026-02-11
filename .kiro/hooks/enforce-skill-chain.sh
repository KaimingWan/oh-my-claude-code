#!/bin/bash
# Enforce skill chain — userPromptSubmit hook
# Detects intent and reminds agent which skills MUST be applied

INPUT="$*"
USER_MSG=$(cat)

# Detect planning/design intent
PLAN_PATTERNS="方案|设计|plan|design|architect|spec|需求|feature|implement|实现|开发|build"
# Detect code completion intent
DONE_PATTERNS="完成|done|finish|merge|提交|commit|push|PR|pull request|review|检查"
# Detect debugging intent
DEBUG_PATTERNS="bug|error|fail|报错|异常|crash|broken|fix"

if echo "$USER_MSG" | grep -qiE "$PLAN_PATTERNS"; then
  cat << 'EOF'
📋 Planning detected — MANDATORY skill chain:
1. brainstorming → Explore intent & design BEFORE implementation
2. writing-plans → Create bite-sized implementation plan
3. Check knowledge/lessons-learned.md for past mistakes on similar work
EOF
fi

if echo "$USER_MSG" | grep -qiE "$DONE_PATTERNS"; then
  cat << 'EOF'
✅ Completion detected — MANDATORY skill chain:
1. verification-before-completion → Run verification, evidence before claims
2. code-review-expert → Review git changes before merge/commit
3. Check knowledge/lessons-learned.md — Record wins or mistakes
EOF
fi

if echo "$USER_MSG" | grep -qiE "$DEBUG_PATTERNS"; then
  cat << 'EOF'
🐛 Debugging detected — MANDATORY skill chain:
1. systematic-debugging → Hypothesize, verify, fix
2. Check knowledge/lessons-learned.md for known issues
EOF
fi
