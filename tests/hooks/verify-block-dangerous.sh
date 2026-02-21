#!/bin/bash
# verify-block-dangerous.sh — Tests for block-dangerous.sh pattern narrowing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

HOOK="hooks/security/block-dangerous.sh"
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

# Helper to make JSON input
bash_input() {
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"
}

# --- rm: still blocked ---
run_test "BLOCK rm -rf" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"rm -rf /nonexistent"}}
EOF

run_test "BLOCK rm -f" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"rm -f somefile"}}
EOF

# --- git branch: only force delete (-D) blocked, soft delete (-d) allowed ---
run_test "BLOCK git branch -D (force delete)" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"git branch -D my-branch"}}
EOF

run_test "ALLOW git branch -d (soft delete)" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"git branch -d merged-branch"}}
EOF

run_test "ALLOW git branch --list" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"git branch --list"}}
EOF

# --- Process signals: kill -9 now allowed, shutdown/reboot still blocked ---
run_test "ALLOW kill -9 (no longer blocked)" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"kill -9 12345"}}
EOF

run_test "ALLOW killall (no longer blocked)" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"killall node"}}
EOF

run_test "ALLOW pkill (no longer blocked)" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"pkill -f myprocess"}}
EOF

run_test "BLOCK shutdown" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"shutdown -h now"}}
EOF

run_test "BLOCK reboot" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"reboot"}}
EOF

# --- find with delete: only system paths blocked, workspace paths allowed ---
run_test "BLOCK find /etc with -delete" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"find /etc/nginx -name '*.conf' -delete"}}
EOF

run_test "BLOCK find /usr with -delete" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"find /usr/local -name '*.tmp' -delete"}}
EOF

run_test "BLOCK find /var with -delete" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"find /var/log -name 'old.log' -delete"}}
EOF

run_test "ALLOW find workspace with -delete" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"find ./tmp -name '*.pyc' -delete"}}
EOF

run_test "ALLOW find /tmp with -delete" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"find /tmp -name 'test-*' -delete"}}
EOF

# --- find exec rm: system paths still blocked ---
run_test "BLOCK find /etc exec rm" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"find /etc -name '*.bak' -exec rm {} +"}}
EOF

run_test "ALLOW find . exec rm (workspace)" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"find . -name '*.pyc' -exec rm {} +"}}
EOF

# --- git commit is always allowed ---
run_test "ALLOW git commit" 0 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"git commit -m 'feat: something'"}}
EOF

# --- non-bash tools: passthrough ---
run_test "ALLOW Write tool passthrough" 0 <<'EOF'
{"tool_name":"Write","tool_input":{"file_path":"test.txt","content":"hello"}}
EOF

# --- still-dangerous: docker rm -f ---
run_test "BLOCK docker rm -f" 2 <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"docker rm -f mycontainer"}}
EOF

# --- Summary ---
echo ""
echo "=== Block-Dangerous Tests: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
