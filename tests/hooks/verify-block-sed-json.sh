#!/bin/bash
# Wrapper to test block-sed-json without triggering live hooks
cd "$(dirname "$0")/../.."
echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"sed -i s/old/new/ config.json"}}' | bash hooks/security/block-sed-json.sh 2>&1
echo "EXIT: $?"
