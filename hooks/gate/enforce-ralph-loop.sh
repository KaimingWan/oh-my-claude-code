#!/bin/bash
# enforce-ralph-loop.sh — PreToolUse[execute_bash, fs_write] gate
# When an active plan has unchecked items, block direct execution.
# Agent must use ralph_loop.py, not execute tasks directly.
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  execute_bash|Bash) MODE="bash" ;;
  fs_write|Write|Edit) MODE="write" ;;
  *) exit 0 ;;
esac

PLAN_POINTER="docs/plans/.active"
LOCK_FILE=".ralph-loop.lock"

# Guard: block git commit if .active is staged with a plan path that differs from HEAD.
# Catches accidental re-activation (e.g. stale staged change sneaking into an unrelated commit).
# Runs before all other checks so it works even when no active plan exists in the working tree.
if [ "$MODE" = "bash" ]; then
  _CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
  _CMD=$(echo "$_CMD" | sed -E 's|^cd[[:space:]]+[^;&|]*&&[[:space:]]*||')
  if echo "$_CMD" | grep -qE '^git[[:space:]]+commit'; then
    _STAGED=$(git show :docs/plans/.active 2>/dev/null | tr -d '[:space:]')
    if [ -n "$_STAGED" ]; then
      _HEAD=$(git show HEAD:docs/plans/.active 2>/dev/null | tr -d '[:space:]')
      if [ "$_STAGED" != "$_HEAD" ]; then
        echo "🚫 BLOCKED: docs/plans/.active is staged with plan path '$_STAGED'." >&2
        echo "   This looks accidental. Run: git restore --staged docs/plans/.active" >&2
        exit 2
      fi
    fi
  fi
fi

# Emergency bypass
if [ -f ".skip-ralph" ]; then
  echo "⚠️ Ralph-loop check skipped (.skip-ralph exists)." >&2
  exit 0
fi

# Ralph-loop worker process bypass
if [ "$_RALPH_LOOP_RUNNING" = "1" ]; then
  exit 0
fi

# No active plan → allow
[ ! -f "$PLAN_POINTER" ] && exit 0

PLAN_FILE=$(cat "$PLAN_POINTER" | tr -d '[:space:]')
[ ! -f "$PLAN_FILE" ] && exit 0

# No unchecked items in last Checklist section → allow (plan is done)
# awk resets buffer on each ## Checklist, so only the last section survives
UNCHECKED=$(awk '/^## Checklist/{found=1;buf="";next} found && /^## /{found=0} found{buf=buf"\n"$0} END{print buf}' "$PLAN_FILE" 2>/dev/null | grep -c '^\- \[ \]' || true)
[ "${UNCHECKED:-0}" -eq 0 ] && exit 0

# Ralph-loop running (lock file exists AND process alive) → allow
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null | tr -d '[:space:]')
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    # Intentional: allows ANY process (including executor subagents) when ralph-loop is alive.
    # kill -0 checks if ralph-loop PID exists, not if current process IS ralph-loop.
    exit 0
  fi
  # Stale lock — process dead, clean it up
  rm -f "$LOCK_FILE" 2>/dev/null
fi

# --- Active plan, unchecked items, no ralph-loop ---

block_msg() {
  echo "🚫 BLOCKED: Run python3 scripts/ralph_loop.py ($UNCHECKED items remaining${1:+, $1})" >&2
  exit 2
}

if [ "$MODE" = "bash" ]; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

  # Strip leading "cd <path> &&" prefix (kiro-cli prepends this)
  CMD=$(echo "$CMD" | sed -E 's|^cd[[:space:]]+[^;&|]*&&[[:space:]]*||')

  # Allow ralph-loop invocations
  echo "$CMD" | grep -qE 'ralph[-_.]loop|ralph_loop' && exit 0

  # Brainstorm gate: block bash commands that create plan files without brainstorm confirmation
  if echo "$CMD" | grep -qE 'docs/plans/.*\.md' && [ ! -f ".brainstorm-confirmed" ] && [ ! -f ".skip-plan" ]; then
    if echo "$CMD" | grep -qE '(open|write|>|create)'; then
      block_msg "Creating plan via bash without brainstorm confirmation"
    fi
  fi

  # Block commands that delete/overwrite .active
  echo "$CMD" | grep -qE '(rm|>|>>|mv|cp).*\.active' && block_msg "Cannot manipulate .active file"

  # Extract first command (before any pipe/chain) for allowlist checks
  FIRST_CMD=$(echo "$CMD" | sed 's/[|;&].*//' | sed 's/^[[:space:]]*//')

  # Test commands — read-only diagnostics, always allowed
  if echo "$FIRST_CMD" | grep -qE '^python3?[[:space:]]+-m[[:space:]]+pytest[[:space:]]'; then
    exit 0
  fi
  if echo "$FIRST_CMD" | grep -qE '^bash[[:space:]]+tests/'; then
    exit 0
  fi

  # Read-only allowlist — checked BEFORE chaining so pipes between read-only cmds are allowed
  if echo "$FIRST_CMD" | grep -qE '^(git[[:space:]]+(status|log|diff|show|branch|worktree|stash[[:space:]]+list)|ls|cat|head|tail|grep|rg|wc|file|stat|test|md5|shasum|date|pwd|which|type|jq|printf|echo|awk|ps|sed[[:space:]]+-n|find[[:space:]])'; then
    # Allow piping/chaining between read-only commands, but block destructive writes
    # Note: [^0-9]>[^&] avoids matching fd redirects like 2>/dev/null and 2>&1
    if ! echo "$CMD" | grep -qE '([^0-9]>[^&]|^>[^&]|>>|rm |mv |cp |python|bash |sh |curl |wget )'; then
      exit 0
    fi
  fi

  # Safe git operations (save work / restore state, not execute tasks)
  if echo "$FIRST_CMD" | grep -qE '^git[[:space:]]+(add|commit|push|checkout|restore|reset|stash[[:space:]]+(save|push|pop|apply))([[:space:]]|$)'; then
    exit 0
  fi

  # Safe filesystem markers (touch, mkdir, unlink) — allow with stderr redirects like 2>/dev/null
  if echo "$FIRST_CMD" | grep -qE '^(touch|mkdir(-p)?|unlink)[[:space:]]'; then
    if ! echo "$CMD" | grep -qE '(>\s[^&/]|>>|python|bash |sh )'; then
      exit 0
    fi
  fi

  # Reject any command with chaining/piping/subshells (not in allowlists above)
  if echo "$CMD" | grep -qE '(&&|\|\||;|\||>>|>\s|`|\$\()'; then
    block_msg "Chained/piped commands not allowed outside ralph-loop"
  fi

  block_msg "Command not in allowlist"
fi

if [ "$MODE" = "write" ]; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)

  # Normalize absolute path to relative (Kiro sends absolute paths, allowlist uses relative)
  WORKSPACE=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
  case "$FILE" in
    "$WORKSPACE"/*) FILE="${FILE#$WORKSPACE/}" ;;
  esac

  # Path traversal check
  echo "$FILE" | grep -q '\.\.' && block_msg "Path traversal (..) not allowed"

  # Block lock forgery
  case "$FILE" in
    *.ralph-loop.lock|*ralph-loop.lock) block_msg "Cannot write to lock file" ;;
  esac

  # Allowlist for fs_write
  case "$FILE" in
    docs/plans/*.md|docs/plans/.active|docs/plans/.ralph-result) exit 0 ;;
    .completion-criteria.md) exit 0 ;;
  esac

  # knowledge/*.md only (no executables)
  if echo "$FILE" | grep -qE '^knowledge/.*\.md$'; then
    exit 0
  fi

  block_msg "Write to $FILE not allowed outside ralph-loop"
fi
