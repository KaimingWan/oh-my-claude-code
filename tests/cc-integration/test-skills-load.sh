#!/bin/bash
# test-skills-load.sh — Verify skills are discoverable via CC headless
set -euo pipefail
cd "$(dirname "$0")/../.."

OUTPUT=$(claude -p "List available skills from the skills/ directory" --output-format text --max-turns 3 2>&1 || true)
echo "$OUTPUT" | grep -qi "planning\|review\|research\|debug" || { echo "FAIL: skills not discovered"; exit 1; }
