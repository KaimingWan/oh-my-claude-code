#!/bin/bash
# test-kiro-compat.sh — Kiro CLI hook compatibility tests
# Tests all 12 wired hooks with Kiro-format JSON stdin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

PASS=0 FAIL=0

run_test() {
  local name="$1" expected_exit="$2" hook="$3"
  local input
  input=$(cat)  # read from heredoc
  local actual_exit=0
  echo "$input" | bash "$hook" >/dev/null 2>&1 || actual_exit=$?
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "PASS $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL $name (expected exit $expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
# Security hooks — BLOCK + ALLOW tests
# ============================================================

# --- block-dangerous ---
run_test "BLOCK block-dangerous rm-rf" 2 hooks/security/block-dangerous.sh <<'EOF'
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}
EOF

run_test "ALLOW block-dangerous ls" 0 hooks/security/block-dangerous.sh <<'EOF'
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"ls -la"}}
EOF

# --- block-secrets ---
FAKE_KEY="AKI""AIOSFODNN7EXAMPLE"
run_test "BLOCK block-secrets aws-key" 2 hooks/security/block-secrets.sh <<EOF
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"echo $FAKE_KEY"}}
EOF

run_test "ALLOW block-secrets safe-cmd" 0 hooks/security/block-secrets.sh <<'EOF'
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"echo hello"}}
EOF

# --- block-sed-json ---
run_test "BLOCK block-sed-json sed-on-json" 2 hooks/security/block-sed-json.sh <<'EOF'
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"sed -i s/old/new/ config.json"}}
EOF

run_test "ALLOW block-sed-json sed-on-txt" 0 hooks/security/block-sed-json.sh <<'EOF'
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"sed -i s/old/new/ config.txt"}}
EOF

# --- block-outside-workspace ---
run_test "BLOCK block-outside-workspace external-write" 2 hooks/security/block-outside-workspace.sh <<EOF
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"fs_write","tool_input":{"command":"create","path":"/tmp/evil.txt","file_text":"x"}}
EOF

run_test "ALLOW block-outside-workspace internal-write" 0 hooks/security/block-outside-workspace.sh <<EOF
{"hook_event_name":"preToolUse","cwd":"$PROJECT_DIR","tool_name":"fs_write","tool_input":{"command":"create","path":"$PROJECT_DIR/tests/hooks/.marker","file_text":"x"}}
EOF

# ============================================================
# Gate hooks — BLOCK + ALLOW tests
# ============================================================

# --- pre-write (blocks CLAUDE.md write) ---
run_test "BLOCK pre-write claude-md" 2 hooks/gate/pre-write.sh <<EOF
{"hook_event_name":"preToolUse","cwd":"$PROJECT_DIR","tool_name":"fs_write","tool_input":{"command":"create","path":"CLAUDE.md","file_text":"hijack"}}
EOF

run_test "ALLOW pre-write normal-file" 0 hooks/gate/pre-write.sh <<EOF
{"hook_event_name":"preToolUse","cwd":"$PROJECT_DIR","tool_name":"fs_write","tool_input":{"command":"str_replace","path":"tests/hooks/.marker","new_str":"ok"}}
EOF

# --- enforce-ralph-loop (skip tool_name gate only) ---
run_test "ALLOW enforce-ralph-loop unknown-tool" 0 hooks/gate/enforce-ralph-loop.sh <<'EOF'
{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"fs_read","tool_input":{"path":"/tmp/x"}}
EOF

# ============================================================
# Feedback hooks — exit 0 tests
# ============================================================

# --- correction-detect ---
run_test "ALLOW correction-detect normal" 0 hooks/feedback/correction-detect.sh <<'EOF'
{"hook_event_name":"userPromptSubmit","prompt":"hello world"}
EOF

# --- session-init ---
run_test "ALLOW session-init normal" 0 hooks/feedback/session-init.sh <<'EOF'
{"hook_event_name":"userPromptSubmit","prompt":"start working"}
EOF

# --- context-enrichment ---
run_test "ALLOW context-enrichment normal" 0 hooks/feedback/context-enrichment.sh <<'EOF'
{"hook_event_name":"userPromptSubmit","prompt":"fix the bug"}
EOF

# --- post-write ---
run_test "ALLOW post-write normal" 0 hooks/feedback/post-write.sh <<EOF
{"hook_event_name":"postToolUse","tool_name":"fs_write","tool_input":{"command":"create","path":"$PROJECT_DIR/tests/hooks/.marker","file_text":"x"}}
EOF

# --- post-bash ---
run_test "ALLOW post-bash normal" 0 hooks/feedback/post-bash.sh <<'EOF'
{"hook_event_name":"postToolUse","tool_name":"execute_bash","tool_input":{"command":"ls"},"tool_output":{"exit_code":0}}
EOF

# --- post-bash verify-log write ---
WS_HASH=$(pwd | shasum | cut -c1-8)
LOG_FILE="/tmp/verify-log-${WS_HASH}.jsonl"
BEFORE=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
echo '{"hook_event_name":"postToolUse","tool_name":"execute_bash","tool_input":{"command":"echo test-verify-log"},"tool_output":{"exit_code":0}}' | bash hooks/feedback/post-bash.sh >/dev/null 2>&1
AFTER=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
LAST_LINE=$(tail -1 "$LOG_FILE")
CMD_HASH_EXPECTED=$(echo "echo test-verify-log" | shasum | cut -c1-40)
CMD_HASH_ACTUAL=$(echo "$LAST_LINE" | jq -r '.cmd_hash')
HAS_FIELDS=$(echo "$LAST_LINE" | jq -r 'has("cmd_hash") and has("cmd") and has("exit_code") and has("ts")')
if [ "$AFTER" -gt "$BEFORE" ] && [ "$HAS_FIELDS" = "true" ] && [ "$CMD_HASH_ACTUAL" = "$CMD_HASH_EXPECTED" ]; then
  echo "PASS post-bash verify-log write"
  PASS=$((PASS + 1))
else
  echo "FAIL post-bash verify-log write (after=$AFTER before=$BEFORE fields=$HAS_FIELDS hash_match=$([ "$CMD_HASH_ACTUAL" = "$CMD_HASH_EXPECTED" ] && echo yes || echo no))"
  FAIL=$((FAIL + 1))
fi

# --- verify-completion ---
run_test "ALLOW verify-completion normal" 0 hooks/feedback/verify-completion.sh <<'EOF'
{"hook_event_name":"stop"}
EOF

# --- verify-completion stop_hook_active ---
run_test "ALLOW verify-completion stop_hook_active" 0 hooks/feedback/verify-completion.sh <<'EOF'
{"stop_hook_active":true}
EOF

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
