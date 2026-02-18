#!/bin/bash
# test-cc-compat.sh — Claude Code hook compatibility tests
# Tests all wired hooks from .claude/settings.json with CC-format JSON stdin
# CC differences: tool_name=Bash/Write/Edit, file_path (not path), content (not file_text),
#   hook_event_name=PreToolUse (capitalized), session_id, permission_mode fields
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

PASS=0 FAIL=0

run_test() {
  local name="$1" expected_exit="$2" hook="$3"
  local input
  input=$(cat)
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
# Security hooks — CC format (Bash/Write/Edit tool names)
# ============================================================

# --- block-dangerous ---
run_test "CC-BLOCK block-dangerous rm-rf" 2 hooks/security/block-dangerous.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"rm -rf /","description":"nuke"}}
EOF

run_test "CC-ALLOW block-dangerous ls" 0 hooks/security/block-dangerous.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"ls -la"}}
EOF

# --- block-secrets ---
FAKE_KEY="AKI""AIOSFODNN7EXAMPLE"
run_test "CC-BLOCK block-secrets aws-key" 2 hooks/security/block-secrets.sh <<EOF
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"echo $FAKE_KEY"}}
EOF

run_test "CC-ALLOW block-secrets safe" 0 hooks/security/block-secrets.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"echo hello"}}
EOF

# --- block-sed-json ---
run_test "CC-BLOCK block-sed-json" 2 hooks/security/block-sed-json.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ config.json"}}
EOF

run_test "CC-ALLOW block-sed-json txt" 0 hooks/security/block-sed-json.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ config.txt"}}
EOF

# --- block-outside-workspace (Write) ---
run_test "CC-BLOCK outside-workspace Write" 2 hooks/security/block-outside-workspace.sh <<EOF
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"$PROJECT_DIR","tool_name":"Write","tool_input":{"file_path":"/tmp/evil.txt","content":"x"}}
EOF

run_test "CC-ALLOW outside-workspace Write" 0 hooks/security/block-outside-workspace.sh <<EOF
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"$PROJECT_DIR","tool_name":"Write","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","content":"x"}}
EOF

# --- block-outside-workspace (Edit) ---
run_test "CC-BLOCK outside-workspace Edit" 2 hooks/security/block-outside-workspace.sh <<EOF
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"$PROJECT_DIR","tool_name":"Edit","tool_input":{"file_path":"/tmp/evil.txt","old_string":"a","new_string":"b"}}
EOF

run_test "CC-ALLOW outside-workspace Edit" 0 hooks/security/block-outside-workspace.sh <<EOF
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"$PROJECT_DIR","tool_name":"Edit","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","old_string":"a","new_string":"b"}}
EOF

# --- block-outside-workspace (Bash) ---
run_test "CC-BLOCK outside-workspace Bash" 2 hooks/security/block-outside-workspace.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"echo x > /tmp/evil.txt"}}
EOF

run_test "CC-ALLOW outside-workspace Bash" 0 hooks/security/block-outside-workspace.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"echo hello"}}
EOF

# ============================================================
# Gate hooks — CC format
# ============================================================

# --- pre-write (Write blocks CLAUDE.md) ---
run_test "CC-BLOCK pre-write CLAUDE.md" 2 hooks/gate/pre-write.sh <<EOF
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"$PROJECT_DIR","tool_name":"Write","tool_input":{"file_path":"CLAUDE.md","content":"hijack"}}
EOF

run_test "CC-ALLOW pre-write normal" 0 hooks/gate/pre-write.sh <<EOF
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"$PROJECT_DIR","tool_name":"Write","tool_input":{"file_path":"tests/hooks/.marker","content":"ok"}}
EOF

# --- pre-write (Edit blocks AGENTS.md) ---
run_test "CC-BLOCK pre-write AGENTS.md Edit" 2 hooks/gate/pre-write.sh <<EOF
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"$PROJECT_DIR","tool_name":"Edit","tool_input":{"file_path":"AGENTS.md","old_string":"old","new_string":"new"}}
EOF

# --- enforce-ralph-loop (unknown tool passthrough) ---
run_test "CC-ALLOW enforce-ralph-loop Read" 0 hooks/gate/enforce-ralph-loop.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}
EOF

# --- require-regression (non-commit passthrough) ---
run_test "CC-ALLOW require-regression non-commit" 0 hooks/gate/require-regression.sh <<'EOF'
{"hook_event_name":"PreToolUse","session_id":"s1","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"echo hello"}}
EOF

# ============================================================
# Feedback hooks — CC format (all exit 0)
# ============================================================

run_test "CC-ALLOW correction-detect" 0 hooks/feedback/correction-detect.sh <<'EOF'
{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"hello world"}
EOF

run_test "CC-ALLOW session-init" 0 hooks/feedback/session-init.sh <<'EOF'
{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"start working"}
EOF

run_test "CC-ALLOW context-enrichment" 0 hooks/feedback/context-enrichment.sh <<'EOF'
{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"fix the bug"}
EOF

run_test "CC-ALLOW post-write Write" 0 hooks/feedback/post-write.sh <<EOF
{"hook_event_name":"PostToolUse","session_id":"s1","tool_name":"Write","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","content":"x"}}
EOF

run_test "CC-ALLOW post-write Edit" 0 hooks/feedback/post-write.sh <<EOF
{"hook_event_name":"PostToolUse","session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"$PROJECT_DIR/tests/hooks/.marker","old_string":"a","new_string":"b"}}
EOF

run_test "CC-ALLOW post-bash" 0 hooks/feedback/post-bash.sh <<'EOF'
{"hook_event_name":"PostToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls"},"tool_output":{"stdout":"file.txt","exitCode":0}}
EOF

run_test "CC-ALLOW verify-completion" 0 hooks/feedback/verify-completion.sh <<'EOF'
{"hook_event_name":"Stop","session_id":"s1"}
EOF

run_test "CC-ALLOW verify-completion stop_hook_active" 0 hooks/feedback/verify-completion.sh <<'EOF'
{"hook_event_name":"Stop","session_id":"s1","stop_hook_active":true}
EOF

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== CC Compat Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
