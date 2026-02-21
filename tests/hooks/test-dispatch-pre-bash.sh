#!/bin/bash
# test-dispatch-pre-bash.sh — Tests for dispatch-pre-bash.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

PASS=0
FAIL=0

run_test() {
    local name="$1" expected_exit="$2"
    local input
    input=$(cat)
    local actual_exit=0
    echo "$input" | bash hooks/dispatch-pre-bash.sh >/dev/null 2>&1 || actual_exit=$?
    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "PASS $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL $name (expected exit $expected_exit, got $actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

run_test_with_env() {
    local name="$1" expected_exit="$2"
    local env_var="$3"
    local input
    input=$(cat)
    local actual_exit=0
    echo "$input" | env "$env_var" bash hooks/dispatch-pre-bash.sh >/dev/null 2>&1 || actual_exit=$?
    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "PASS $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL $name (expected exit $expected_exit, got $actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

# ── Security pass-through ─────────────────────────────────────────────────

# Safe command should pass
run_test "ALLOW safe ls command" 0 <<'EOF'
{"hook_event_name":"preToolUse","tool_name":"execute_bash","tool_input":{"command":"ls -la"}}
EOF

# ── Security blocks ───────────────────────────────────────────────────────

# Dangerous command blocked
run_test "BLOCK dangerous rm-rf" 2 <<'EOF'
{"hook_event_name":"preToolUse","tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}
EOF

# sed on JSON blocked
run_test "BLOCK sed-json" 2 <<'EOF'
{"hook_event_name":"preToolUse","tool_name":"execute_bash","tool_input":{"command":"sed -i s/a/b/ config.json"}}
EOF

# ── Output budget test ────────────────────────────────────────────────────

# Block output must be <= 200 chars (printf truncation)
stderr_output=$(echo '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /test"}}' \
    | bash hooks/dispatch-pre-bash.sh 2>&1 >/dev/null || true)
char_count=${#stderr_output}
if [ "$char_count" -le 200 ]; then
    echo "PASS output-budget (${char_count} chars <= 200)"
    PASS=$((PASS + 1))
else
    echo "FAIL output-budget (${char_count} chars > 200)"
    FAIL=$((FAIL + 1))
fi

# ── SKIP_GATE=1 bypasses gate hooks but not security ─────────────────────

# With SKIP_GATE=1, dangerous command still blocked (security not skipped)
run_test_with_env "BLOCK dangerous with SKIP_GATE=1" 2 "SKIP_GATE=1" <<'EOF'
{"hook_event_name":"preToolUse","tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent"}}
EOF

# ── Non-bash tool_name: dispatcher exits 0 (security hooks skip non-bash) ─

run_test "ALLOW non-bash tool" 0 <<'EOF'
{"hook_event_name":"preToolUse","tool_name":"fs_read","tool_input":{"path":"/tmp/x"}}
EOF

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
