#!/bin/bash
# test-posttooluse.sh — Verify post-bash.sh writes to verify-log after Bash tool use
# This distinguishes "hook fires" from "Claude refuses naturally":
# for a safe echo command, Claude WILL call Bash; if verify-log empty after, post-bash.sh did not fire.
set -euo pipefail
cd "$(dirname "$0")/../.."
source tests/cc-integration/lib/helpers.sh

PASS=0 FAIL=0

# Clear log to start fresh
clear_verify_log

# Run a safe, unambiguous command — Claude WILL call Bash for this
cc_run "Run the command: echo cc_integration_posttooluse_marker" \
  --allowedTools "Bash" --max-turns 1 >/dev/null 2>&1 || true

# post-bash.sh must have written an entry with exit_code:0
if assert_verify_log_written "echo command"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== post-tooluse: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
