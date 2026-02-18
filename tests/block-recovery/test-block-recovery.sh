#!/bin/bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0

# Use a temp dir as working directory to get a unique workspace hash
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
WS_HASH=$(echo "$TEST_DIR" | shasum | cut -c1-8)
COUNT_FILE="/tmp/block-count-${WS_HASH}.jsonl"

cleanup() { [ -f "$COUNT_FILE" ] && unlink "$COUNT_FILE" 2>/dev/null || true; }

assert() {
  local name="$1" expected="$2" output="$3"
  if echo "$output" | grep -q "$expected"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL: $name - expected '$expected' in output"
  fi
}

run_hook() {
  local hook="$1" json="$2"
  (cd "$TEST_DIR" && printf '%s' "$json" | bash "$REPO_ROOT/hooks/security/$hook" 2>&1 || true)
}

# Test 1: block-dangerous first block → RETRY
cleanup
OUTPUT=$(run_hook "block-dangerous.sh" '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}')
assert "dangerous-first-retry" "RETRY (1/3)" "$OUTPUT"

# Test 2: block-dangerous 3rd block → SKIP
cleanup
run_hook "block-dangerous.sh" '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}' >/dev/null
run_hook "block-dangerous.sh" '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}' >/dev/null
OUTPUT=$(run_hook "block-dangerous.sh" '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}')
assert "dangerous-third-skip" "SKIP" "$OUTPUT"

# Test 3: different commands have independent counts
cleanup
run_hook "block-dangerous.sh" '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-a"}}' >/dev/null
run_hook "block-dangerous.sh" '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-a"}}' >/dev/null
OUTPUT=$(run_hook "block-dangerous.sh" '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-b"}}')
assert "independent-counts" "RETRY (1/3)" "$OUTPUT"

# Test 4: block-outside-workspace has recovery
cleanup
OUTPUT=$(run_hook "block-outside-workspace.sh" '{"tool_name":"execute_bash","tool_input":{"command":"tee /etc/passwd"}}')
assert "outside-workspace-retry" "RETRY" "$OUTPUT"

# Test 5: block-sed-json has recovery
cleanup
OUTPUT=$(run_hook "block-sed-json.sh" '{"tool_name":"execute_bash","tool_input":{"command":"sed -i s/a/b/ config.json"}}')
assert "sed-json-retry" "RETRY" "$OUTPUT"

# Test 6: still blocks (BLOCKED message preserved)
cleanup
OUTPUT=$(run_hook "block-dangerous.sh" '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}')
assert "still-blocks" "BLOCKED" "$OUTPUT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
