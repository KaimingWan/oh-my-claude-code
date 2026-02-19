#!/bin/bash
# test-severity-tracking.sh — Tests for auto-capture severity tracking (Task 2)
GROUP="severity-tracking"; source "$(dirname "$0")/lib.sh"
json_report_start

# ── S1: correction-detect sets flag before auto-capture ──
begin_test "S1-correction-flag-set"
setup_sandbox; cd "$SANDBOX"
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
rm -f /tmp/kb-correction-${WS_HASH}-*.flag
# Run correction-detect with a correction message containing a capturable action
printf '{"prompt":"你错了，别用 sed 处理 YAML，换成 yq"}' | bash "$PROJECT_DIR/hooks/feedback/correction-detect.sh" 2>&1
# After correction-detect runs, auto-capture consumes the flag.
# But the agent-correction flag should exist (set after auto-capture)
[ -f "/tmp/agent-correction-${WS_HASH}.flag" ] && pass || fail "agent-correction flag not set"
rm -f /tmp/agent-correction-${WS_HASH}.flag
teardown_sandbox
record_result "S1" "correction flag set"

# ── S2: auto-capture appends [correction] when flag exists ──
begin_test "S2-correction-marker-appended"
setup_sandbox; cd "$SANDBOX"
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
# Pre-create correction flag
touch "/tmp/kb-correction-${WS_HASH}-12345.flag"
OUT=$(run_auto_capture "别用 sed 处理 YAML，换成 yq"); RC=$?
assert_exit_code 0 "$RC"
# Check that the captured episode has [correction] marker
LAST_LINE=$(tail -1 knowledge/episodes.md)
echo "$LAST_LINE" | grep -q '\[correction\]' && pass || fail "missing [correction] marker in: $LAST_LINE"
teardown_sandbox
record_result "S2" "correction marker appended"

# ── S3: flag cleaned up after capture ──
begin_test "S3-flag-cleanup"
setup_sandbox; cd "$SANDBOX"
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
touch "/tmp/kb-correction-${WS_HASH}-111.flag"
touch "/tmp/kb-correction-${WS_HASH}-222.flag"
run_auto_capture "别用 sed 处理 YAML，换成 yq" >/dev/null
# All correction flags for this workspace should be gone
REMAINING=(/tmp/kb-correction-${WS_HASH}-*.flag)
[ ! -e "${REMAINING[0]}" ] && pass || fail "flags not cleaned up: ${REMAINING[*]}"
teardown_sandbox
record_result "S3" "flag cleanup"

# ── S4: non-correction capture has no marker ──
begin_test "S4-no-marker-without-flag"
setup_sandbox; cd "$SANDBOX"
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
rm -f /tmp/kb-correction-${WS_HASH}-*.flag
OUT=$(run_auto_capture "别用 sed 处理 YAML，换成 yq"); RC=$?
assert_exit_code 0 "$RC"
LAST_LINE=$(tail -1 knowledge/episodes.md)
echo "$LAST_LINE" | grep -q '\[correction\]' && fail "unexpected [correction] marker" || pass
teardown_sandbox
record_result "S4" "no marker without flag"

# ── G1: Gate 4 correctly blocks at capacity 30 ──
begin_test "G1-gate4-status-counting"
setup_sandbox; cd "$SANDBOX"
# Generate 30 episodes with status field (the new counting method)
{
  echo "# Episodes"
  for i in $(seq 1 30); do
    printf '2026-01-%02d | active | uniqueword%d,filler | Entry number %d\n' "$i" "$i" "$i"
  done
} > knowledge/episodes.md
OUT=$(run_auto_capture "换成 pytest 测试框架"); RC=$?
assert_exit_code 0 "$RC"
assert_contains "$OUT" "at capacity"
# Also verify: lines with comments/headers don't count
{
  echo "# Episodes"
  echo ""
  echo "> Some description"
  for i in $(seq 1 29); do
    printf '2026-01-%02d | active | uniqueword%d,filler | Entry number %d\n' "$i" "$i" "$i"
  done
} > knowledge/episodes.md
OUT2=$(run_auto_capture "换成 pytest 测试框架"); RC2=$?
assert_exit_code 0 "$RC2"
assert_not_contains "$OUT2" "at capacity"
teardown_sandbox
record_result "G1" "gate4 status counting"

summary "Severity Tracking"
