#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
PASS=0; FAIL=0
run() {
  local desc="$1" input="$2" expect="$3"
  local rc=0; echo "$input" | bash hooks/gate/pre-write.sh >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq "$expect" ]; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc (got $rc, want $expect)"; FAIL=$((FAIL+1)); fi
}
run "CLAUDE.md blocked" '{"tool_name":"fs_write","tool_input":{"file_path":"CLAUDE.md","command":"str_replace","new_str":"x"}}' 2
run "AGENTS.md blocked" '{"tool_name":"fs_write","tool_input":{"file_path":"AGENTS.md","command":"str_replace","new_str":"x"}}' 2
run "knowledge/rules.md blocked" '{"tool_name":"fs_write","tool_input":{"file_path":"knowledge/rules.md","command":"str_replace","new_str":"x"}}' 2
run ".claude/rules/ blocked" '{"tool_name":"fs_write","tool_input":{"file_path":".claude/rules/security.md","command":"create","new_str":"x"}}' 2
run ".kiro/rules/ blocked" '{"tool_name":"fs_write","tool_input":{"file_path":".kiro/rules/enforcement.md","command":"str_replace","new_str":"x"}}' 2
run "normal file allowed" '{"tool_name":"fs_write","tool_input":{"file_path":"scripts/test.sh","command":"create","new_str":"#!/bin/bash"}}' 0
run "episodes.md allowed" '{"tool_name":"fs_write","tool_input":{"file_path":"knowledge/episodes.md","command":"str_replace","new_str":"x"}}' 0
run "plan file allowed" '{"tool_name":"fs_write","tool_input":{"file_path":"docs/plans/test.md","command":"str_replace","new_str":"x"}}' 0
echo "Results: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
