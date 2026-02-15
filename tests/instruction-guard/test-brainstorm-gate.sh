#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
PASS=0; FAIL=0
run_msg() {
  local desc="$1" input="$2" expect_pattern="$3"
  local out; out=$(echo "$input" | bash hooks/gate/pre-write.sh 2>&1) || true
  if echo "$out" | grep -q "$expect_pattern"; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc (output: $out)"; FAIL=$((FAIL+1)); fi
}
run_no_msg() {
  local desc="$1" input="$2" reject_pattern="$3"
  local out; out=$(echo "$input" | bash hooks/gate/pre-write.sh 2>&1) || true
  if ! echo "$out" | grep -q "$reject_pattern"; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc (found: $reject_pattern)"; FAIL=$((FAIL+1)); fi
}
# Clean state
unlink .brainstorm-confirmed 2>/dev/null || true
run_msg "plan create blocked without brainstorm" \
  '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/2026-02-16-test.md","command":"create","new_str":"# Test"}}' \
  "brainstorming confirmation"
touch .brainstorm-confirmed
run_no_msg "plan create passes brainstorm gate with flag" \
  '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/2026-02-16-test.md","command":"create","new_str":"# Test"}}' \
  "brainstorming confirmation"
unlink .brainstorm-confirmed 2>/dev/null || true
run_no_msg "plan update always passes brainstorm gate" \
  '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/2026-02-16-test.md","command":"str_replace","new_str":"x"}}' \
  "brainstorming confirmation"
echo "Results: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
