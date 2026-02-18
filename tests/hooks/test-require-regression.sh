#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."

PASS=0
FAIL=0

run_test() {
  local name="$1"
  local expected="$2"
  shift 2
  
  set +e
  "$@"
  local actual=$?
  set -e
  
  if [ "$actual" -eq "$expected" ]; then
    echo "✓ $name"
    PASS=$((PASS + 1))
  else
    echo "✗ $name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

test_blocked() {
  TEMP=$(mktemp -d)
  cd "$TEMP"
  git init -q
  mkdir -p scripts
  echo "test" > scripts/ralph_loop.py
  git add scripts/ralph_loop.py
  export HOOKS_DRY_RUN=false
  echo '{"tool_name":"execute_bash","tool_input":{"command":"git commit -m test"}}' | bash "$OLDPWD/hooks/gate/require-regression.sh"
  local result=$?
  cd "$OLDPWD"
  rm -rf "$TEMP"
  return $result
}

test_allowed() {
  TEMP=$(mktemp -d)
  cd "$TEMP"
  git init -q
  mkdir -p scripts tests/ralph-loop/.pytest_cache
  echo "test" > scripts/ralph_loop.py
  git add scripts/ralph_loop.py
  touch tests/ralph-loop/.pytest_cache
  export HOOKS_DRY_RUN=false
  echo '{"tool_name":"execute_bash","tool_input":{"command":"git commit -m test"}}' | bash "$OLDPWD/hooks/gate/require-regression.sh"
  local result=$?
  cd "$OLDPWD"
  rm -rf "$TEMP"
  return $result
}

test_non_ralph() {
  TEMP=$(mktemp -d)
  cd "$TEMP"
  git init -q
  echo "test" > README.md
  git add README.md
  echo '{"tool_name":"execute_bash","tool_input":{"command":"git commit -m test"}}' | bash "$OLDPWD/hooks/gate/require-regression.sh"
  local result=$?
  cd "$OLDPWD"
  rm -rf "$TEMP"
  return $result
}

test_non_commit() {
  echo '{"tool_name":"execute_bash","tool_input":{"command":"echo hello"}}' | bash hooks/gate/require-regression.sh
}

run_test "commit-with-ralph-files blocked without recent pytest" 2 test_blocked
run_test "commit-with-ralph-files allowed after pytest" 0 test_allowed
run_test "non-ralph commit always passes" 0 test_non_ralph
run_test "non-commit command passes through" 0 test_non_commit

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]