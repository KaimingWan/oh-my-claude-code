#!/bin/bash
# test-block-output.sh — Verify all hook block outputs are <=3 lines
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
  line_count=$(echo "$output" | grep -c '' || true)
  if [ "$line_count" -le "$max_lines" ]; then
    echo "PASS $name (${line_count} lines <= ${max_lines})"
    PASS=$((PASS + 1))
  else
    echo "FAIL $name (${line_count} lines > ${max_lines})"
    echo "  Output was:"
    echo "$output" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

MAX_LINES=3

# --- block-dangerous.sh ---
check_output_lines "block-dangerous rm-rf output" $MAX_LINES hooks/security/block-dangerous.sh <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"rm -rf /test"}}
EOF

# --- block-secrets.sh ---
FAKE_KEY="AKI""AIOSFODNN7EXAMPLE"
check_output_lines "block-secrets output" $MAX_LINES hooks/security/block-secrets.sh <<EOF
{"tool_name":"Bash","tool_input":{"command":"echo $FAKE_KEY"}}
EOF

# --- block-sed-json.sh ---
check_output_lines "block-sed-json output" $MAX_LINES hooks/security/block-sed-json.sh <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ config.json"}}
EOF

# --- block-outside-workspace.sh (Write) ---
check_output_lines "block-outside-workspace Write output" $MAX_LINES hooks/security/block-outside-workspace.sh <<'EOF'
{"tool_name":"Write","tool_input":{"file_path":"/etc/passwd","content":"x"}}
EOF

# --- block-outside-workspace.sh (Bash) ---
check_output_lines "block-outside-workspace Bash output" $MAX_LINES hooks/security/block-outside-workspace.sh <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"echo x > /etc/hosts"}}
EOF

# --- Verify RETRY counter message is still single line (block-recovery) ---
# Run same command 3 times to get SKIP message
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
COUNT_FILE="/tmp/block-count-${WS_HASH}.jsonl"
# Reset count file
unlink "$COUNT_FILE" 2>/dev/null || true

check_output_lines "block-dangerous retry-1 output" $MAX_LINES hooks/security/block-dangerous.sh <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"rm -rf /test"}}
EOF

check_output_lines "block-dangerous retry-2 output" $MAX_LINES hooks/security/block-dangerous.sh <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"rm -rf /test"}}
EOF

check_output_lines "block-dangerous skip-3 output" $MAX_LINES hooks/security/block-dangerous.sh <<'EOF'
{"tool_name":"Bash","tool_input":{"command":"rm -rf /test"}}
EOF

# Cleanup
unlink "$COUNT_FILE" 2>/dev/null || true

# --- Summary ---
echo ""
echo "=== Block Output Tests: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
