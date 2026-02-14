#!/bin/bash
# auto-approve-safe.sh — PermissionRequest[Bash] (Claude Code only)
# Blacklist strategy: block dangerous, auto-approve everything else
source "$(dirname "$0")/../_lib/patterns.sh"

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

for pattern in "${DANGEROUS_BASH_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "$pattern"; then
    exit 0  # Dangerous → don't auto-approve, let user decide
  fi
done

# Safe command → auto-approve
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PermissionRequest",
    decision: { behavior: "allow" }
  }
}'
