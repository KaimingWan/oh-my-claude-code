#!/bin/bash
# run.sh — Knowledge test runner
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:---l1-only}"

L1_SCRIPTS=(
  "$DIR/l1-rules-injection.sh"
  "$DIR/l1-auto-capture.sh"
  "$DIR/l1-corruption-recall.sh"
)
L2_SCRIPTS=(
  "$DIR/l2-agent-integration.sh"
)

TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_SCRIPTS=0; FAILED_SCRIPTS=()

run_script() {
  local script="$1"
  local name
  name=$(basename "$script" .sh)
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Running: $name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  TOTAL_SCRIPTS=$((TOTAL_SCRIPTS+1))
  if bash "$script"; then
    TOTAL_PASS=$((TOTAL_PASS+1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL+1))
    FAILED_SCRIPTS+=("$name")
  fi
}

case "$MODE" in
  --l1-only|--l1)
    for s in "${L1_SCRIPTS[@]}"; do run_script "$s"; done
    ;;
  --l2-only|--l2)
    for s in "${L2_SCRIPTS[@]}"; do run_script "$s"; done
    ;;
  --all)
    for s in "${L1_SCRIPTS[@]}"; do run_script "$s"; done
    for s in "${L2_SCRIPTS[@]}"; do run_script "$s"; done
    ;;
  *)
    echo "Usage: $0 [--l1-only|--l2-only|--all]"
    exit 1
    ;;
esac

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         KNOWLEDGE TEST SUMMARY           ║"
echo "╠══════════════════════════════════════════╣"
printf "║  Scripts: %d pass / %d total              ║\n" "$TOTAL_PASS" "$TOTAL_SCRIPTS"
echo "╚══════════════════════════════════════════╝"

if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo ""
  echo "Failed scripts:"
  for f in "${FAILED_SCRIPTS[@]}"; do echo "  ❌ $f"; done
  exit 1
else
  echo "✅ 全部通过！"
  exit 0
fi
