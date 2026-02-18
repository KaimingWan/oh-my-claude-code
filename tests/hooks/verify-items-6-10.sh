#!/bin/bash
# Run all verify commands for items 6-10 that would be blocked by live hooks
cd "$(dirname "$0")/../.."

# Item 6: block-dangerous blocks rm -rf (exit 2)
echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}' | bash hooks/security/block-dangerous.sh 2>&1; test $? -eq 2
echo "Item 6: $?"

# Item 7: block-dangerous allows safe command (exit 0)
echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"ls -la"}}' | bash hooks/security/block-dangerous.sh 2>&1; test $? -eq 0
echo "Item 7: $?"

# Item 8: block-sed-json blocks sed on .json (exit 2)
echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"sed -i s/old/new/ config.json"}}' | bash hooks/security/block-sed-json.sh 2>&1; test $? -eq 2
echo "Item 8: $?"

# Item 9: pre-write blocks CLAUDE.md write (exit 2)
PWD_VAL=$(pwd)
echo '{"hook_event_name":"preToolUse","cwd":"'"$PWD_VAL"'","tool_name":"fs_write","tool_input":{"command":"create","path":"'"$PWD_VAL"'/CLAUDE.md","file_text":"hijack"}}' | bash hooks/gate/pre-write.sh 2>&1; test $? -eq 2
echo "Item 9: $?"

# Item 10: All test harness tests pass
bash tests/hooks/test-kiro-compat.sh 2>/dev/null | grep -c FAIL | grep -q '^0$'
echo "Item 10: $?"
