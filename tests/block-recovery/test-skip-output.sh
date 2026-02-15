#!/bin/bash
# test-skip-output.sh — verify 3rd block outputs SKIP
cd "$(dirname "$0")/../.."
find /tmp -maxdepth 1 -name 'block-count-*.jsonl' -exec unlink {} \; 2>/dev/null

# Trigger 2 blocks first
for i in 1 2; do
  printf '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /tmp/test"}}' | bash hooks/security/block-dangerous.sh 2>&1 || true
done

# 3rd block should output SKIP
OUTPUT=$(printf '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /tmp/test"}}' | bash hooks/security/block-dangerous.sh 2>&1 || true)
echo "$OUTPUT"
echo "$OUTPUT" | grep -q 'SKIP' && echo "PASS: SKIP found" || { echo "FAIL: SKIP not found"; exit 1; }
