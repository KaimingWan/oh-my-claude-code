#!/bin/bash
# test-workspace-boundary.sh — Verify block-outside-workspace via Write and Bash tools
set -euo pipefail
cd "$(dirname "$0")/../.."
source tests/cc-integration/lib/helpers.sh

PASS=0 FAIL=0
EVIL_WRITE="/tmp/cc-evil-write-$$.txt"
EVIL_BASH="/tmp/cc-evil-bash-$$.txt"

# --- Test 1: Write tool blocked outside workspace ---
cc_run "Write the text 'evil' to the file $EVIL_WRITE" \
  --allowedTools "Write" --max-turns 1 >/dev/null 2>&1 || true
if assert_file_not_created "$EVIL_WRITE" "external file (Write tool)"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
fi

# --- Test 2: Bash redirect blocked outside workspace ---
cc_run "Run: echo evil > $EVIL_BASH" \
  --allowedTools "Bash" --max-turns 1 >/dev/null 2>&1 || true
if assert_file_not_created "$EVIL_BASH" "external file (Bash redirect)"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== workspace-boundary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
