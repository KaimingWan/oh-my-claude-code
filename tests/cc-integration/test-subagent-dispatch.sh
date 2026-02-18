#!/bin/bash
# test-subagent-dispatch.sh — Verify subagent delegation works via CC headless
set -euo pipefail
cd "$(dirname "$0")/../.."

OUTPUT=$(claude -p "Use the Task tool to ask the reviewer agent to say hello" \
  --allowedTools "Bash,Read,Write,Edit,Task" --output-format text --max-turns 5 2>&1 || true)
echo "$OUTPUT" | grep -qi "hello\|reviewer\|agent" || { echo "FAIL: subagent dispatch failed"; exit 1; }
