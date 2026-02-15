#!/bin/bash
# block-recovery.sh — Shared block-with-retry logic for security hooks

hook_block_with_recovery() {
  local msg="$1"
  local cmd_key="$2"

  local WS_HASH
  WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
  local COUNT_FILE="/tmp/block-count-${WS_HASH}.jsonl"

  # Cleanup: remove entries older than 1 day
  if [ -f "$COUNT_FILE" ]; then
    local CUTOFF=$(( $(date +%s) - 86400 ))
    local TMP="${COUNT_FILE}.tmp"
    jq -c --argjson cutoff "$CUTOFF" 'select(.ts > $cutoff)' "$COUNT_FILE" > "$TMP" 2>/dev/null && mv "$TMP" "$COUNT_FILE" || rm -f "$TMP"
  fi

  local KEY_HASH
  KEY_HASH=$(echo "$cmd_key" | shasum 2>/dev/null | cut -c1-40)

  # Read current count
  local COUNT=0
  if [ -f "$COUNT_FILE" ]; then
    COUNT=$(jq -r --arg h "$KEY_HASH" 'select(.key == $h) | .count' "$COUNT_FILE" 2>/dev/null | tail -1)
    COUNT=${COUNT:-0}
  fi
  COUNT=$((COUNT + 1))

  # Append new count
  echo "{\"key\":\"$KEY_HASH\",\"count\":$COUNT,\"ts\":$(date +%s)}" >> "$COUNT_FILE"

  # Append guidance based on count
  if [ "$COUNT" -ge 3 ]; then
    msg="$msg

⛔ SKIP: This item has been blocked $COUNT times. Mark it as '- [SKIP] blocked: security hook' in the plan and move to the next item."
  else
    msg="$msg

⚡ RETRY ($COUNT/3): Use the safe alternative above and try again."
  fi

  echo "$msg" >&2
  exit 2
}
