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

# Lint stamp: record successful lint runs for require-lint-before-push gate
if [ "$EXIT_CODE" = "0" ] && echo "$CMD" | grep -qE '\b(eslint|pnpm.*lint|npm.*lint|yarn.*lint)\b'; then
  _LINT_DIR=""
  _TOOL_WD=$(echo "$INPUT" | jq -r '.tool_input.working_dir // ""' 2>/dev/null)
  if [ -n "$_TOOL_WD" ]; then
    _LINT_DIR=$(cd "$_TOOL_WD" 2>/dev/null && pwd)
  elif echo "$CMD" | grep -qE '^[[:space:]]*cd[[:space:]]+'; then
    _CD_TARGET=$(echo "$CMD" | sed -E 's/^[[:space:]]*cd[[:space:]]+//;s/[[:space:]].*//')
    _LINT_DIR=$(cd "$_CD_TARGET" 2>/dev/null && pwd)
  fi
  [ -z "$_LINT_DIR" ] && _LINT_DIR=$(pwd)
  _CHECK="$_LINT_DIR"
  for _ in 1 2 3 4; do
    [ -d "$_CHECK/.git" ] || [ -f "$_CHECK/.git" ] && break
    _CHECK=$(dirname "$_CHECK")
  done
  [ -d "$_CHECK/.git" ] || [ -f "$_CHECK/.git" ] && _LINT_DIR="$_CHECK"
  _DIR_HASH=$(echo "$_LINT_DIR" | shasum 2>/dev/null | cut -c1-12)
  touch "/tmp/lint-passed-${_DIR_HASH}.stamp"
fi

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
