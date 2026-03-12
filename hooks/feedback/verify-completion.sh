#!/bin/bash
# verify-completion.sh — Stop hook
# Check active plan's checklist + re-run all verify commands.
source "$(dirname "$0")/../_lib/common.sh"

# CC stop hook loop prevention: if already continuing from a stop hook, exit immediately
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Check active plan checklist
ACTIVE_PLAN=$(find_active_plan)

if [ -n "$ACTIVE_PLAN" ] && [ -f "$ACTIVE_PLAN" ]; then
  UNCHECKED=$(grep -c '^\- \[ \]' "$ACTIVE_PLAN" 2>/dev/null || true)
  CHECKED=$(grep -c '^\- \[x\]' "$ACTIVE_PLAN" 2>/dev/null || true)
  if [ "${UNCHECKED:-0}" -gt 0 ]; then
    echo "🚫 INCOMPLETE: $UNCHECKED/$((CHECKED + UNCHECKED)) items remaining in $ACTIVE_PLAN. Read plan to see which."
    exit 0
  fi

  # Cleanup verify log
  WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
  [ -f "/tmp/verify-log-${WS_HASH}.jsonl" ] && : > "/tmp/verify-log-${WS_HASH}.jsonl"
fi

# --- PreCompletion baseline verification ---
# Inject structured verification prompt against user's original request.
WS=$(ws_hash)
BASELINE="/tmp/session-baseline-${WS}.txt"
if [ -f "$BASELINE" ] && [ -s "$BASELINE" ]; then
  ORIGINAL=$(cat "$BASELINE")
  ORIGINAL=$(printf '%.500s' "$ORIGINAL")
  cat <<EOF

🔍 **PreCompletion Verification** — 对照用户原始需求自检:

> 原始需求: ${ORIGINAL}

请逐条回答:
1. 用户要求的每一项是否都已完成？如有遗漏，列出。
2. 交付物是否经过验证（测试通过/实际运行/人工确认）？
3. 是否有引入但用户未要求的额外内容？如有，说明理由。
EOF
  : > "$BASELINE"
fi

# KB health report (only if knowledge changed this session)
bash "$(dirname "$0")/kb-health-report.sh" 2>/dev/null

exit 0
