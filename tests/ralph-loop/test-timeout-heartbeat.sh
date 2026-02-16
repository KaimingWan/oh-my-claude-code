#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0; FAIL=0; TOTAL=0
begin_test() { TOTAL=$((TOTAL + 1)); TEST_NAME="$1"; }
pass_test() { PASS=$((PASS + 1)); echo "  ✅ $TEST_NAME"; }
fail_test() { FAIL=$((FAIL + 1)); echo "  ❌ $TEST_NAME ($1)"; }

echo "=== ralph-loop timeout & heartbeat tests ==="

# --- Setup ---
TDIR=$(mktemp -d)
trap 'rm -rf "$TDIR"' EXIT

PLAN="$TDIR/p.md"
printf '# T\n\n## Checklist\n\n- [ ] x | `echo ok`\n' > "$PLAN"
ACTIVE="$TDIR/.active"
echo "$PLAN" > "$ACTIVE"

FAKE="$TDIR/fk.sh"
printf '#!/bin/bash\nsleep 60\n' > "$FAKE"
chmod +x "$FAKE"

# T1: stuck iteration killed by timeout
begin_test "T1: stuck iteration killed within timeout"
START=$(date +%s)
RALPH_TASK_TIMEOUT=3 RALPH_KIRO_CMD="$FAKE" \
  PLAN_POINTER_OVERRIDE="$ACTIVE" \
  python3 "$REPO_ROOT/scripts/ralph_loop.py" 1 > "$TDIR/t1.txt" 2>&1 || true
ELAPSED=$(( $(date +%s) - START ))
if [ "$ELAPSED" -lt 15 ]; then pass_test; else fail_test "elapsed=${ELAPSED}s"; fi

# T2: timeout message in output
begin_test "T2: timeout message printed"
if grep -q "timed out" "$TDIR/t1.txt"; then pass_test; else fail_test "no 'timed out' in output"; fi

# T3: heartbeat appears
begin_test "T3: heartbeat printed during execution"
# Reset plan for fresh run
printf '# T\n\n## Checklist\n\n- [ ] x | `echo ok`\n' > "$PLAN"
RALPH_TASK_TIMEOUT=6 RALPH_HEARTBEAT_INTERVAL=2 RALPH_KIRO_CMD="$FAKE" \
  PLAN_POINTER_OVERRIDE="$ACTIVE" \
  python3 "$REPO_ROOT/scripts/ralph_loop.py" 1 > "$TDIR/t3.txt" 2>&1 || true
if grep -q "💓" "$TDIR/t3.txt"; then pass_test; else fail_test "no heartbeat in output"; fi

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
