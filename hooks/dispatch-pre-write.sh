#!/bin/bash
# dispatch-pre-write.sh — PreToolUse[fs_write] dispatcher
# Calls sub-hooks in order, fail-fast on first block (exit 2).
# Global output budget: printf '%.200s' (bash 3.2 safe, no ${var:0:200}).
#
# Note: pre-write.sh is already a merged hook (internal functions, not child processes).
# This dispatcher wraps it plus block-outside-workspace.sh and enforce-ralph-loop.sh
# as the outer output-budget layer.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT=$(cat)

HOOKS=(
    "$SCRIPT_DIR/security/block-outside-workspace.sh"
    "$SCRIPT_DIR/gate/pre-write.sh"
    "$SCRIPT_DIR/gate/enforce-ralph-loop.sh"
)

for hook in "${HOOKS[@]}"; do
    [ -f "$hook" ] || continue
    stderr=$(echo "$INPUT" | bash "$hook" 2>&1 >/dev/null)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '%.200s' "$stderr" >&2
        exit "$rc"
    fi
done

exit 0
