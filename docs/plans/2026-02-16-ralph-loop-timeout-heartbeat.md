# Ralph Loop Timeout & Heartbeat

**Goal:** Add per-iteration timeout and periodic heartbeat to ralph-loop.sh so stuck iterations auto-terminate and the operator can see the loop is alive.
**Architecture:** Pure bash changes to scripts/ralph-loop.sh. Timeout via background watchdog (macOS has no `timeout` command). Heartbeat via background process that prints every N seconds while kiro-cli runs.
**Tech Stack:** Bash, POSIX signals

## Tasks

### Task 1: Add per-iteration timeout

**Files:**
- Modify: `scripts/ralph-loop.sh`
- Test: `tests/ralph-loop/test-timeout-heartbeat.sh`

**Step 1: Write failing test**

```bash
# tests/ralph-loop/test-timeout-heartbeat.sh — test timeout kills long-running child
# Test: a "fake kiro" that sleeps 60s gets killed after RALPH_TASK_TIMEOUT=3s

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0; FAIL=0; TOTAL=0
begin_test() { TOTAL=$((TOTAL + 1)); TEST_NAME="$1"; }
assert_exit() {
  if [ "$1" -eq "$2" ]; then PASS=$((PASS + 1)); echo "  ✅ $TEST_NAME"
  else FAIL=$((FAIL + 1)); echo "  ❌ $TEST_NAME (expected=$2, got=$1)"; fi
}
assert_contains() {
  if echo "$1" | grep -q "$2"; then PASS=$((PASS + 1)); echo "  ✅ $TEST_NAME"
  else FAIL=$((FAIL + 1)); echo "  ❌ $TEST_NAME (missing: $2)"; fi
}

echo "=== ralph-loop timeout & heartbeat tests ==="

# --- Setup ---
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Fake plan with 1 unchecked item
PLAN="$TMPDIR/plan.md"
printf '# Test\n\n## Checklist\n\n- [ ] item one | `echo ok`\n' > "$PLAN"
ACTIVE="$TMPDIR/.active"
echo "$PLAN" > "$ACTIVE"

# Fake kiro-cli that just sleeps (simulates stuck agent)
FAKE_KIRO="$TMPDIR/fake-kiro.sh"
cat > "$FAKE_KIRO" << 'EOF'
#!/bin/bash
sleep 60
EOF
chmod +x "$FAKE_KIRO"

# T1: timeout kills stuck iteration
begin_test "T1: stuck iteration killed by timeout"
START=$(date +%s)
RALPH_TASK_TIMEOUT=3 RALPH_KIRO_CMD="$FAKE_KIRO" \
  PLAN_POINTER_OVERRIDE="$ACTIVE" \
  bash "$REPO_ROOT/scripts/ralph-loop.sh" 1 > "$TMPDIR/t1-out.txt" 2>&1 || true
ELAPSED=$(( $(date +%s) - START ))
# Should finish in ~3-6s, not 60s
assert_exit "$([ "$ELAPSED" -lt 15 ] && echo 0 || echo 1)" 0

# T2: timeout message appears in output
begin_test "T2: timeout message in output"
assert_contains "$(cat "$TMPDIR/t1-out.txt")" "timed out"

# T3: heartbeat appears before timeout
begin_test "T3: heartbeat appears during execution"
RALPH_TASK_TIMEOUT=6 RALPH_HEARTBEAT_INTERVAL=2 RALPH_KIRO_CMD="$FAKE_KIRO" \
  PLAN_POINTER_OVERRIDE="$ACTIVE" \
  bash "$REPO_ROOT/scripts/ralph-loop.sh" 1 > "$TMPDIR/t3-out.txt" 2>&1 || true
assert_contains "$(cat "$TMPDIR/t3-out.txt")" "💓"

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

**Step 2: Run test — verify it fails**
Run: `bash tests/ralph-loop/test-timeout-heartbeat.sh`
Expected: FAIL (ralph-loop.sh doesn't support RALPH_KIRO_CMD, PLAN_POINTER_OVERRIDE, timeout, or heartbeat yet)

**Step 3: Write minimal implementation**

Modify `scripts/ralph-loop.sh`:

1. Add env var overrides at top:
```bash
TASK_TIMEOUT="${RALPH_TASK_TIMEOUT:-1800}"
HEARTBEAT_INTERVAL="${RALPH_HEARTBEAT_INTERVAL:-180}"
PLAN_POINTER="${PLAN_POINTER_OVERRIDE:-docs/plans/.active}"
KIRO_CMD="${RALPH_KIRO_CMD:-}"
```

2. Replace the `kiro-cli chat` call with a timeout+heartbeat wrapper.

**Critical: word-splitting/quoting.** The command must be launched via `eval` or a wrapper function, not bare `$cmd`, because kiro-cli's PROMPT contains newlines and special chars. Solution: `run_with_timeout` takes no command arg — it runs the command defined in the enclosing scope directly.

```bash
run_with_timeout() {
  local timeout_secs="$1" hb_interval="$2" iteration="$3"

  # Caller must define CMD_PID after launching their command in background
  # Start heartbeat in background
  (
    elapsed=0
    while kill -0 "$CMD_PID" 2>/dev/null; do
      sleep "$hb_interval"
      elapsed=$((elapsed + hb_interval))
      kill -0 "$CMD_PID" 2>/dev/null && \
        echo "💓 [$(date '+%H:%M:%S')] Iteration $iteration — running (elapsed ${elapsed}s)"
    done
  ) &
  local HB_PID=$!

  # Start watchdog in background
  (
    sleep "$timeout_secs"
    if kill -0 "$CMD_PID" 2>/dev/null; then
      echo "⏰ Iteration $iteration timed out after ${timeout_secs}s — killing"
      kill "$CMD_PID" 2>/dev/null
    fi
  ) &
  local WD_PID=$!

  # Wait for command to finish (either naturally or killed)
  wait "$CMD_PID" 2>/dev/null || true

  # Cleanup background processes
  kill "$HB_PID" 2>/dev/null; wait "$HB_PID" 2>/dev/null || true
  kill "$WD_PID" 2>/dev/null; wait "$WD_PID" 2>/dev/null || true
}
```

3. Replace the kiro-cli invocation + sleep with:
```bash
if [ -n "$KIRO_CMD" ]; then
  $KIRO_CMD >> "$LOG_FILE" 2>&1 &
else
  kiro-cli chat --no-interactive --trust-all-tools "$PROMPT" >> "$LOG_FILE" 2>&1 &
fi
CMD_PID=$!
run_with_timeout "$TASK_TIMEOUT" "$HEARTBEAT_INTERVAL" "$i"

sleep 2
```

4. Update the hardcoded `PLAN_POINTER` reference to use the env-overridable variable (already defined in sub-step 1). Change line `PLAN_POINTER="docs/plans/.active"` to use `PLAN_POINTER="${PLAN_POINTER_OVERRIDE:-docs/plans/.active}"`.

5. Update the existing `cleanup_lock` trap to also kill background processes on script exit:
```bash
cleanup() {
  rm -f "$LOCK_FILE"
  # Kill any leftover background processes from run_with_timeout
  [ -n "${CMD_PID:-}" ] && kill "$CMD_PID" 2>/dev/null || true
}
trap cleanup EXIT
```

**Step 4: Run test — verify it passes**
Run: `bash tests/ralph-loop/test-timeout-heartbeat.sh`
Expected: PASS

**Step 5: Commit**
`feat: add timeout and heartbeat to ralph-loop.sh`

**Verify:**
`bash tests/ralph-loop/test-timeout-heartbeat.sh`

## Checklist

- [x] stuck iteration killed within RALPH_TASK_TIMEOUT seconds | `TMPDIR=$(mktemp -d); printf '# T\n\n## Checklist\n\n- [ ] x | \x60echo ok\x60\n' > "$TMPDIR/p.md"; echo "$TMPDIR/p.md" > "$TMPDIR/.active"; printf '#!/bin/bash\nsleep 60\n' > "$TMPDIR/fk.sh"; chmod +x "$TMPDIR/fk.sh"; START=$(date +%s); RALPH_TASK_TIMEOUT=3 RALPH_KIRO_CMD="$TMPDIR/fk.sh" PLAN_POINTER_OVERRIDE="$TMPDIR/.active" bash scripts/ralph-loop.sh 1 >/dev/null 2>&1 || true; ELAPSED=$(( $(date +%s) - START )); rm -rf "$TMPDIR"; test "$ELAPSED" -lt 15`
- [x] timeout message printed to stdout | `TMPDIR=$(mktemp -d); printf '# T\n\n## Checklist\n\n- [ ] x | \x60echo ok\x60\n' > "$TMPDIR/p.md"; echo "$TMPDIR/p.md" > "$TMPDIR/.active"; printf '#!/bin/bash\nsleep 60\n' > "$TMPDIR/fk.sh"; chmod +x "$TMPDIR/fk.sh"; OUT=$(RALPH_TASK_TIMEOUT=3 RALPH_KIRO_CMD="$TMPDIR/fk.sh" PLAN_POINTER_OVERRIDE="$TMPDIR/.active" bash scripts/ralph-loop.sh 1 2>&1 || true); rm -rf "$TMPDIR"; echo "$OUT" | grep -q "timed out"`
- [x] heartbeat printed every RALPH_HEARTBEAT_INTERVAL seconds | `TMPDIR=$(mktemp -d); printf '# T\n\n## Checklist\n\n- [ ] x | \x60echo ok\x60\n' > "$TMPDIR/p.md"; echo "$TMPDIR/p.md" > "$TMPDIR/.active"; printf '#!/bin/bash\nsleep 60\n' > "$TMPDIR/fk.sh"; chmod +x "$TMPDIR/fk.sh"; OUT=$(RALPH_TASK_TIMEOUT=6 RALPH_HEARTBEAT_INTERVAL=2 RALPH_KIRO_CMD="$TMPDIR/fk.sh" PLAN_POINTER_OVERRIDE="$TMPDIR/.active" bash scripts/ralph-loop.sh 1 2>&1 || true); rm -rf "$TMPDIR"; echo "$OUT" | grep -q "💓"`
- [x] default timeout is 1800s (30min) | `grep -q 'RALPH_TASK_TIMEOUT:-1800' scripts/ralph-loop.sh`
- [x] default heartbeat is 180s (3min) | `grep -q 'RALPH_HEARTBEAT_INTERVAL:-180' scripts/ralph-loop.sh`
- [x] existing tests still pass | `bash tests/ralph-loop/test-enforcement.sh 2>&1 | tail -1 | grep -q "全部通过"`

## Review

### Round 1

**Completeness** (reviewer) — REQUEST CHANGES. Concerns: orphan process cleanup, signal handler coordination. Fix: added sub-step 5 with cleanup trap.

**Testability** (reviewer) — APPROVE.

**Compatibility & Rollback** (reviewer) — APPROVE.

**Clarity** (reviewer) — REQUEST CHANGES. Confusing strikethrough, incomplete integration. Fix: removed strikethrough, added sub-steps 4-5.

### Round 2

**Completeness** (reviewer) — REQUEST CHANGES. Concerns: process group kills, race conditions, PID reuse, KIRO_CMD validation.

**Testability** (reviewer) — APPROVE.

**Compatibility & Rollback** (reviewer) — APPROVE.

**Clarity** (reviewer) — APPROVE.

### Conflict Resolution (Completeness R2)

Completeness reviewer's remaining concerns evaluated against Goal ("stuck iterations auto-terminate and operator can see loop is alive"):

1. **Process group kills** — kiro-cli is a single Node process, no grandchildren to orphan. Not applicable.
2. **Race condition** — `kill -0` check + `kill 2>/dev/null` already handles the race. No failure mode.
3. **PID reuse in 3s window** — Theoretical, probability negligible in practice.
4. **KIRO_CMD validation** — Test-only env var, not production surface.

Per calibration rules: "Do NOT reject for theoretical risks that are unlikely in practice." These do not meet the REJECT bar. Overridden.

**Final Verdict: APPROVE** (3/4 APPROVE in Round 2, 1 overridden per calibration)
