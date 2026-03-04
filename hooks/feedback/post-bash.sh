#!/bin/bash
# post-bash.sh — PostToolUse[execute_bash] hook
# Records bash command execution to verify log for checklist enforcement.
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
case "$TOOL_NAME" in
  execute_bash|Bash) ;;
  *) exit 0 ;;
esac

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_output.exit_code // .tool_output.exitCode // "0"' 2>/dev/null)
[ -z "$CMD" ] && exit 0

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
LOG_FILE="/tmp/verify-log-${WS_HASH}.jsonl"
CMD_HASH=$(echo "$CMD" | shasum 2>/dev/null | cut -c1-40 || echo "unknown")
TS=$(date +%s)

echo "{\"cmd_hash\":\"$CMD_HASH\",\"cmd\":$(echo "$CMD" | jq -Rs .),\"exit_code\":$EXIT_CODE,\"ts\":$TS}" >> "$LOG_FILE"

# OV sync: if command touched knowledge/ files, index them
if echo "$CMD" | grep -q 'knowledge/'; then
  source "$(dirname "$0")/../_lib/ov-init.sh" 2>/dev/null || true
  if ov_init 2>/dev/null && [ "$OV_AVAILABLE" = "1" ]; then
    for _f in $(echo "$CMD" | grep -oE 'knowledge/[^ "]+\.md' | sort -u); do
      [ -f "$_f" ] && ov_add "$_f" "post-bash auto-sync" 2>/dev/null || true
    done
  fi
fi
exit 0
