#!/bin/bash
# test-dispatch-pre-write.sh — Tests for dispatch-pre-write.sh
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
    echo "$input" | bash hooks/dispatch-pre-write.sh >/dev/null 2>&1 || actual_exit=$?
    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "PASS $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL $name (expected exit $expected_exit, got $actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

# ── Workspace boundary ────────────────────────────────────────────────────

# Write outside workspace blocked
run_test "BLOCK write outside workspace" 2 <<EOF
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"fs_write","tool_input":{"command":"create","path":"/tmp/evil.txt","file_text":"x"}}
EOF

# Write inside workspace allowed (to a safe non-protected file)
run_test "ALLOW write inside workspace" 0 <<EOF
{"hook_event_name":"preToolUse","cwd":"$PROJECT_DIR","tool_name":"fs_write","tool_input":{"command":"str_replace","path":"$PROJECT_DIR/tests/hooks/.marker","new_str":"ok"}}
EOF

# ── Instruction file protection (via pre-write.sh) ────────────────────────

# CLAUDE.md write blocked
run_test "BLOCK CLAUDE.md write" 2 <<EOF
{"hook_event_name":"preToolUse","cwd":"$PROJECT_DIR","tool_name":"fs_write","tool_input":{"command":"create","path":"CLAUDE.md","file_text":"hijack"}}
EOF

# ── Output budget test ────────────────────────────────────────────────────

# Block output must be <= 200 chars (printf truncation)
stderr_output=$(echo '{"tool_name":"fs_write","tool_input":{"command":"create","path":"/etc/passwd","file_text":"x"}}' \
    | bash hooks/dispatch-pre-write.sh 2>&1 >/dev/null || true)
char_count=${#stderr_output}
if [ "$char_count" -le 200 ]; then
    echo "PASS output-budget (${char_count} chars <= 200)"
    PASS=$((PASS + 1))
else
    echo "FAIL output-budget (${char_count} chars > 200)"
    FAIL=$((FAIL + 1))
fi

# ── Non-write tool_name: passes through (hooks skip non-write tools) ──────

run_test "ALLOW non-write tool" 0 <<'EOF'
{"hook_event_name":"preToolUse","tool_name":"execute_bash","tool_input":{"command":"ls"}}
EOF

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
