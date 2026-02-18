#!/bin/bash
# test-enforcement.sh — Integration tests for enforce-ralph-loop.sh
# Requires: active plan with unchecked items, NO live ralph-loop lock
set -euo pipefail

HOOK="hooks/gate/enforce-ralph-loop.sh"
PLAN_PTR="docs/plans/.active"
LOCK_FILE=".ralph-loop.lock"
TEST_PLAN="docs/plans/.test-plan.md"

PASS=0; FAIL=0; TOTAL=0

# --- Setup / Teardown ---
setup() {
  ORIG_ACTIVE=""
  [ -f "$PLAN_PTR" ] && ORIG_ACTIVE=$(cat "$PLAN_PTR")
  [ -f "$LOCK_FILE" ] && mv "$LOCK_FILE" "${LOCK_FILE}.bak"
  # Create test plan with unchecked items
  printf '# Test Plan\n\n## Checklist\n\n- [ ] item one | `echo ok`\n- [ ] item two | `echo ok`\n' > "$TEST_PLAN"
  echo "$TEST_PLAN" > "$PLAN_PTR"
}

teardown() {
  [ -n "$ORIG_ACTIVE" ] && echo "$ORIG_ACTIVE" > "$PLAN_PTR" || true
  [ -f "${LOCK_FILE}.bak" ] && mv "${LOCK_FILE}.bak" "$LOCK_FILE" || true
  [ -f "$TEST_PLAN" ] && unlink "$TEST_PLAN" || true
  [ -f ".skip-ralph" ] && unlink ".skip-ralph" || true
  [ -f "$LOCK_FILE" ] && unlink "$LOCK_FILE" || true
}

begin_test() {
  TOTAL=$((TOTAL + 1))
  TEST_NAME="$1"
}

assert_exit() {
  local actual="$1" expected="$2"
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $TEST_NAME"
  else
    FAIL=$((FAIL + 1))
    echo "  ❌ $TEST_NAME (expected exit=$expected, got exit=$actual)"
  fi
}

assert_true() {
  if eval "$1"; then
    PASS=$((PASS + 1))
    echo "  ✅ $TEST_NAME"
  else
    FAIL=$((FAIL + 1))
    echo "  ❌ $TEST_NAME (condition failed: $1)"
  fi
}

run_hook() {
  echo "$1" | bash "$HOOK" >/dev/null 2>&1; echo $?
}

trap teardown EXIT
setup

echo "=== enforce-ralph-loop.sh tests ==="

# T1: bash blocked when plan active
begin_test "T1: bash write blocked when plan active"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"python3 -c \"import os\""}}')
assert_exit "$RC" 2

# T2: ralph_loop.py allowed
begin_test "T2: ralph_loop.py command allowed"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"python3 scripts/ralph_loop.py"}}')
assert_exit "$RC" 0

# T3: read-only git status allowed
begin_test "T3: git status allowed"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"git status"}}')
assert_exit "$RC" 0

# T4: chained command blocked
begin_test "T4: chained command (&&) blocked"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"python3 x.py && echo done"}}')
assert_exit "$RC" 2

# T5: fs_write to source blocked
begin_test "T5: fs_write to source file blocked"
RC=$(run_hook '{"tool_name":"fs_write","tool_input":{"file_path":"src/foo.sh","command":"create"}}')
assert_exit "$RC" 2

# T6: fs_write to plan allowed
begin_test "T6: fs_write to plan file allowed"
RC=$(run_hook '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/test.md","command":"str_replace"}}')
assert_exit "$RC" 0

# T7: stale lock cleaned + blocked
begin_test "T7: stale lock (dead PID) cleaned and blocked"
echo "99999999" > "$LOCK_FILE"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"python3 -c \"pass\""}}')
LOCK_GONE=true; [ -f "$LOCK_FILE" ] && LOCK_GONE=false
assert_true "[ $RC -eq 2 ] && [ $LOCK_GONE = true ]"

# T8: live lock allows
begin_test "T8: live lock allows execution"
echo "$$" > "$LOCK_FILE"  # current shell PID is alive
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"mkdir x"}}')
unlink "$LOCK_FILE" 2>/dev/null || true
assert_exit "$RC" 0

# T9: no active plan = no block
begin_test "T9: no active plan allows everything"
unlink "$PLAN_PTR" 2>/dev/null || true
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"mkdir x"}}')
echo "$TEST_PLAN" > "$PLAN_PTR"  # restore for remaining tests
assert_exit "$RC" 0

# T10: all items checked = no block
begin_test "T10: all items checked allows everything"
printf '# Test Plan\n\n## Checklist\n\n- [x] item one | `echo ok`\n- [x] item two | `echo ok`\n' > "$TEST_PLAN"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"mkdir x"}}')
printf '# Test Plan\n\n## Checklist\n\n- [ ] item one | `echo ok`\n- [ ] item two | `echo ok`\n' > "$TEST_PLAN"
assert_exit "$RC" 0

# T11: delete .active blocked
begin_test "T11: rm .active blocked"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"rm docs/plans/.active"}}')
assert_exit "$RC" 2

# T12: knowledge .md write allowed
begin_test "T12: knowledge .md write allowed"
RC=$(run_hook '{"tool_name":"fs_write","tool_input":{"file_path":"knowledge/foo.md","command":"create"}}')
assert_exit "$RC" 0

# T13: path traversal blocked
begin_test "T13: path traversal blocked"
RC=$(run_hook '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/../../evil.sh","command":"create"}}')
assert_exit "$RC" 2

# T14: lock forgery blocked
begin_test "T14: lock forgery blocked"
RC=$(run_hook '{"tool_name":"fs_write","tool_input":{"file_path":".ralph-loop.lock","command":"create"}}')
assert_exit "$RC" 2

# T15: knowledge non-md blocked
begin_test "T15: knowledge non-md blocked"
RC=$(run_hook '{"tool_name":"fs_write","tool_input":{"file_path":"knowledge/evil.sh","command":"create"}}')
assert_exit "$RC" 2

# T16: .skip-ralph bypass works
begin_test "T16: .skip-ralph bypass works"
touch .skip-ralph
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"mkdir x"}}')
unlink .skip-ralph 2>/dev/null || true
assert_exit "$RC" 0

# T17: piped command blocked
begin_test "T17: piped command blocked"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"python3 x.py | tee bar"}}')
assert_exit "$RC" 2

# T18: redirect blocked
begin_test "T18: redirect (>) blocked"
RC=$(run_hook '{"tool_name":"execute_bash","tool_input":{"command":"echo x > file"}}')
assert_exit "$RC" 2

# T19: .completion-criteria.md write allowed
begin_test "T19: .completion-criteria.md write allowed"
RC=$(run_hook '{"tool_name":"fs_write","tool_input":{"file_path":".completion-criteria.md","command":"create"}}')
assert_exit "$RC" 0

# T20: unknown tool passes through
begin_test "T20: unknown tool passes through"
RC=$(run_hook '{"tool_name":"web_search","tool_input":{"query":"test"}}')
assert_exit "$RC" 0

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "全部通过" || echo "有失败"
