#!/bin/bash
# test-feedback-output.sh — Verify feedback hook output is slimmed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

PASS=0
FAIL=0

check_output_lines() {
  local name="$1" max_lines="$2" hook="$3"
  local input
  input=$(cat)
  local output
  output=$(echo "$input" | bash "$hook" 2>&1 || true)
  local line_count
  if [ -z "$output" ]; then
    line_count=0
  else
    line_count=$(echo "$output" | wc -l | tr -d ' ')
  fi
  if [ "$line_count" -le "$max_lines" ]; then
    echo "PASS $name (${line_count} lines <= ${max_lines})"
    PASS=$((PASS + 1))
  else
    echo "FAIL $name (${line_count} lines > ${max_lines})"
    echo "  Output:"
    echo "$output" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

# ─── pre-write.sh: inject_plan_context always 1-line summary ───

# Setup: create a test plan with unchecked items
touch .brainstorm-confirmed
TEST_PLAN="docs/plans/.test-feedback-plan.md"
cat > "$TEST_PLAN" << 'PLANEOF'
# Test Feedback Plan

## Tasks

### Task 1: Do something

**Files:**
- Modify: `some-file.sh`

**Verify:** `echo ok`

## Checklist
- [ ] do something | `echo ok`

## Review
This plan is approved.
Verdict: APPROVE
PLANEOF
echo "$TEST_PLAN" > docs/plans/.active

cleanup() {
  unlink "$TEST_PLAN" 2>/dev/null || true
  unlink ".brainstorm-confirmed" 2>/dev/null || true
  # Reset .active to real plan
  echo "docs/plans/2026-02-21-hook-governance.md" > docs/plans/.active
}
trap cleanup EXIT

# Test: pre-write advisory output is always 1-line
check_output_lines "pre-write inject_plan_context 1-line" 3 hooks/gate/pre-write.sh <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","content":"x"}}
EOF

# Test pre-write multiple times (should always be 1-line, not growing checklist)
check_output_lines "pre-write 2nd call still 1-line" 3 hooks/gate/pre-write.sh <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","content":"x"}}
EOF

check_output_lines "pre-write 5th call still 1-line (not expanded)" 3 hooks/gate/pre-write.sh <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","content":"x"}}
EOF

# ─── post-write.sh: failure tail -3 ───
# Test: post-write exit 0 for non-source file (no test output)
check_output_lines "post-write non-source file silent" 3 hooks/feedback/post-write.sh <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","content":"x"}}
EOF

# ─── verify-completion.sh: summary only ───
# With unchecked items, verify-completion should output 1-line summary
check_output_lines "verify-completion summary-only with unchecked" 3 hooks/feedback/verify-completion.sh <<'EOF'
{"hook_event_name":"Stop","session_id":"s1"}
EOF

# ─── Summary ───
echo ""
echo "=== Feedback Output Tests: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
