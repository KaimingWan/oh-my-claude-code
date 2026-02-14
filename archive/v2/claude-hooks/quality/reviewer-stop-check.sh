#!/bin/bash
# reviewer-stop-check.sh — Stop hook for reviewer subagent
# Ensures reviewer actually did review work and didn't modify files

CHANGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
if [ "$CHANGED" -gt 0 ]; then
  echo "⚠️ REVIEWER: You are read-only but files were changed. This is a violation." >&2
fi
echo "📋 Review checklist: Did you check correctness, security, edge cases, test coverage?"
exit 0
