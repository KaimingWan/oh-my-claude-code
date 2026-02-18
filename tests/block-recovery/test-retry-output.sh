#!/bin/bash
# test-retry-output.sh — verify first block outputs RETRY
cd "$(dirname "$0")/../.."
find /tmp -maxdepth 1 -name 'block-count-*.jsonl' -exec unlink {} \; 2>/dev/null
OUTPUT=$(printf '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}' | bash hooks/security/block-dangerous.sh 2>&1 || true)
echo "$OUTPUT"
echo "$OUTPUT" | grep -q 'RETRY' && echo "PASS: RETRY found" || { echo "FAIL: RETRY not found"; exit 1; }
