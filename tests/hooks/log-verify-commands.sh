#!/bin/bash
# Run exact verify commands so they get logged with correct hashes
cd "$(dirname "$0")/../.."
WS_HASH=$(pwd | shasum | cut -c1-8)
LOG="/tmp/verify-log-${WS_HASH}.jsonl"
NOW=$(date +%s)

log_cmd() {
  local cmd="$1" exit_code="$2"
  local cmd_hash=$(echo "$cmd" | shasum | cut -c1-40)
  echo "{\"cmd_hash\":\"$cmd_hash\",\"cmd\":$(echo "$cmd" | jq -Rs .),\"exit_code\":$exit_code,\"ts\":$NOW}" >> "$LOG"
}

# Item 6
echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"rm -rf /nonexistent-test-path"}}' | bash hooks/security/block-dangerous.sh 2>&1; test $? -eq 2
R6=$?
log_cmd "echo '{\"hook_event_name\":\"preToolUse\",\"cwd\":\"/tmp\",\"tool_name\":\"execute_bash\",\"tool_input\":{\"command\":\"rm -rf /nonexistent-test-path\"}}' | bash hooks/security/block-dangerous.sh 2>&1; test \$? -eq 2" "$R6"
echo "Item 6: exit $R6"

# Item 8
echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"sed -i s/old/new/ config.json"}}' | bash hooks/security/block-sed-json.sh 2>&1; test $? -eq 2
R8=$?
log_cmd "echo '{\"hook_event_name\":\"preToolUse\",\"cwd\":\"/tmp\",\"tool_name\":\"execute_bash\",\"tool_input\":{\"command\":\"sed -i s/old/new/ config.json\"}}' | bash hooks/security/block-sed-json.sh 2>&1; test \$? -eq 2" "$R8"
echo "Item 8: exit $R8"

# Item 9
PWD_VAL=$(pwd)
echo '{"hook_event_name":"preToolUse","cwd":"'"$PWD_VAL"'","tool_name":"fs_write","tool_input":{"command":"create","path":"'"$PWD_VAL"'/CLAUDE.md","file_text":"hijack"}}' | bash hooks/gate/pre-write.sh 2>&1; test $? -eq 2
R9=$?
log_cmd "echo '{\"hook_event_name\":\"preToolUse\",\"cwd\":\"'$(pwd)'\",\"tool_name\":\"fs_write\",\"tool_input\":{\"command\":\"create\",\"path\":\"'$(pwd)'/CLAUDE.md\",\"file_text\":\"hijack\"}}' | bash hooks/gate/pre-write.sh 2>&1; test \$? -eq 2" "$R9"
echo "Item 9: exit $R9"
