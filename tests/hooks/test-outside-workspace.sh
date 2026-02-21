#!/bin/bash
# test-outside-workspace.sh — Tests for block-outside-workspace.sh /tmp/ allowance
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

HOOK="hooks/security/block-outside-workspace.sh"
PASS=0
FAIL=0

run_test() {
  local name="$1" expected_exit="$2"
  local input
  input=$(cat)
  local actual_exit=0
  echo "$input" | bash "$HOOK" >/dev/null 2>&1 || actual_exit=$?
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "PASS $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL $name (expected exit $expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

# --- Bash /tmp/ redirects: now ALLOWED ---
run_test "ALLOW bash redirect to /tmp/" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo hello > /tmp/test-output.txt"}}
EOF

run_test "ALLOW bash redirect to /tmp/subdir/" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo x > /tmp/myapp/config.json"}}
EOF

run_test "ALLOW bash append to /tmp/" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo line >> /tmp/logfile.txt"}}
EOF

# --- Bash /etc/, /usr/, /var/ still blocked ---
run_test "BLOCK bash redirect to /etc/" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo x > /etc/hosts"}}
EOF

run_test "BLOCK bash redirect to /usr/" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo x > /usr/local/bin/mytool"}}
EOF

run_test "BLOCK bash redirect to /var/" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo x > /var/log/app.log"}}
EOF

# --- Home directory: still blocked ---
run_test "BLOCK bash redirect to ~/" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo x > ~/malicious.sh"}}
EOF

# --- Write/Edit tool: /tmp/ is still outside workspace (blocked) ---
run_test "BLOCK Write tool to /tmp/" 2 <<EOF
{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.txt","content":"x"}}
EOF

# --- Write/Edit to workspace: allowed ---
run_test "ALLOW Write to workspace" 0 <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","content":"x"}}
EOF

# --- Safe bash: no write patterns ---
run_test "ALLOW bash ls /tmp/" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"ls /tmp/"}}
EOF

run_test "ALLOW bash echo without redirect" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo hello world"}}
EOF

# --- Summary ---
echo ""
echo "=== Outside-Workspace Tests: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
