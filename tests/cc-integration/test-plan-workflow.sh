#!/bin/bash
# test-plan-workflow.sh — Verify plan awareness via CC headless
set -euo pipefail
cd "$(dirname "$0")/../.."

OUTPUT=$(claude -p "Check if there is an active plan in docs/plans/.active and report its status" \
  --output-format text --max-turns 3 2>&1 || true)
echo "$OUTPUT" | grep -qi "plan\|active\|checklist" || { echo "FAIL: plan workflow not working"; exit 1; }
