#!/bin/bash
# Wrapper to test block-dangerous without triggering live hooks
cd "$(dirname "$0")/../.."
echo '{"hook_event_name":"preToolUse","cwd":"/tmp","tool_name":"execute_bash","tool_input":{"command":"rm -rf /"}}' | bash hooks/security/block-dangerous.sh 2>&1
echo "EXIT: $?"
