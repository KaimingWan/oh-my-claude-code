#!/bin/bash
# Enforce skill chain — UserPromptSubmit hook (Claude Code version)
# Reads JSON from stdin, detects intent, outputs context for Claude

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

PLAN_PATTERNS="方案|设计|plan|design|architect|spec|需求|feature|implement|实现|开发|build"
DONE_PATTERNS="完成|done|finish|merge|提交|commit|push|PR|pull request|review|检查"
DEBUG_PATTERNS="bug|error|fail|报错|异常|crash|broken|fix"

OUTPUT=""

if echo "$USER_MSG" | grep -qiE "$PLAN_PATTERNS"; then
  OUTPUT="${OUTPUT}📋 Planning detected — MANDATORY skill chain:
1. brainstorming → Explore intent & design BEFORE implementation
2. writing-plans → Create bite-sized implementation plan
3. Check knowledge/lessons-learned.md for past mistakes on similar work
"
fi

if echo "$USER_MSG" | grep -qiE "$DONE_PATTERNS"; then
  OUTPUT="${OUTPUT}✅ Completion detected — MANDATORY skill chain:
1. verification-before-completion → Run verification, evidence before claims
2. code-review-expert → Review git changes before merge/commit
3. Check knowledge/lessons-learned.md — Record wins or mistakes
"
fi

if echo "$USER_MSG" | grep -qiE "$DEBUG_PATTERNS"; then
  OUTPUT="${OUTPUT}🐛 Debugging detected — MANDATORY skill chain:
1. systematic-debugging → Hypothesize, verify, fix
2. Check knowledge/lessons-learned.md for known issues
"
fi

if [ -n "$OUTPUT" ]; then
  echo "$OUTPUT"
fi

exit 0
