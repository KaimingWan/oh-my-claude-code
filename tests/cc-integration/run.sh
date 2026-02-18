#!/bin/bash
# run.sh — Claude Code integration test orchestrator
# Requires: claude CLI installed + authenticated
# Skips gracefully if CC not available (CI-safe)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

# Portable timeout: gtimeout (macOS coreutils) or perl fallback
run_with_timeout() {
  local secs="$1"; shift
  if command -v gtimeout &>/dev/null; then
    gtimeout "$secs" "$@"
  else
    perl -e "alarm $secs; exec @ARGV" -- "$@"
  fi
}

# --- Preflight checks ---
if ! command -v claude &>/dev/null; then
  echo "SKIP: claude not in PATH"
  exit 0
fi

if ! run_with_timeout 10 claude -p "ping" --output-format text &>/dev/null; then
  echo "SKIP: claude not authenticated (run 'claude auth login' or set ANTHROPIC_API_KEY)"
  exit 0
fi

echo "=== Claude Code Integration Tests ==="
PASS=0 FAIL=0 SKIP=0

run_integration() {
  local name="$1" script="$2"
  if [ ! -f "$script" ]; then
    echo "SKIP $name (file missing)"
    SKIP=$((SKIP + 1))
    return
  fi
  local exit_code=0
  run_with_timeout 120 bash "$script" >/dev/null 2>&1 || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    echo "PASS $name"
    PASS=$((PASS + 1))
  elif [ "$exit_code" -eq 124 ]; then
    echo "FAIL $name (timeout)"
    FAIL=$((FAIL + 1))
  else
    echo "FAIL $name (exit $exit_code)"
    FAIL=$((FAIL + 1))
  fi
}

run_integration "hooks-fire" "$SCRIPT_DIR/test-hooks-fire.sh"
run_integration "skills-load" "$SCRIPT_DIR/test-skills-load.sh"
run_integration "subagent-dispatch" "$SCRIPT_DIR/test-subagent-dispatch.sh"
run_integration "knowledge-retrieval" "$SCRIPT_DIR/test-knowledge-retrieval.sh"
run_integration "plan-workflow" "$SCRIPT_DIR/test-plan-workflow.sh"
run_integration "workspace-boundary" "$SCRIPT_DIR/test-workspace-boundary.sh"
run_integration "instruction-guard"  "$SCRIPT_DIR/test-instruction-guard.sh"
run_integration "post-tooluse"       "$SCRIPT_DIR/test-posttooluse.sh"

echo ""
echo "=== CC Integration Results: $PASS passed, $FAIL failed, $SKIP skipped ($((PASS+FAIL+SKIP)) total) ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
