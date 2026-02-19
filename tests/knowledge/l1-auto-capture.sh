#!/bin/bash
# l1-auto-capture.sh — L1: Auto-capture pipeline (auto-capture.sh)
GROUP="l1-auto-capture"; source "$(dirname "$0")/lib.sh"
json_report_start

# ── C1: Valid correction captured ──
begin_test "C1-valid-correction"
setup_sandbox; cd "$SANDBOX"
# Use clean episodes (no yq entry) and healthy rules (no yq rule)
BEFORE=$(wc -l < knowledge/episodes.md | tr -d ' ')
OUT=$(run_auto_capture "别用 sed 处理 YAML，用 yq"); RC=$?
AFTER=$(wc -l < knowledge/episodes.md | tr -d ' ')
assert_exit_code 0 "$RC"
assert_contains "$OUT" "Auto-captured"
echo "  [line count: $BEFORE → $AFTER]"
[ "$AFTER" -gt "$BEFORE" ] && pass || fail "episodes not appended (before=$BEFORE, after=$AFTER)"
teardown_sandbox
record_result "C1" "valid correction"

# ── C2: Question filtered ──
begin_test "C2-question-filtered"
setup_sandbox; cd "$SANDBOX"
BEFORE=$(wc -l < knowledge/episodes.md | tr -d ' ')
OUT=$(run_auto_capture "为什么这样做？"); RC=$?
AFTER=$(wc -l < knowledge/episodes.md | tr -d ' ')
assert_exit_code 1 "$RC"
[ "$BEFORE" -eq "$AFTER" ] && pass || fail "episodes modified by question"
teardown_sandbox
record_result "C2" "question filtered"

# ── C3: No action verb filtered ──
begin_test "C3-no-action-verb"
setup_sandbox; cd "$SANDBOX"
BEFORE=$(wc -l < knowledge/episodes.md | tr -d ' ')
OUT=$(run_auto_capture "这个结果不太好看"); RC=$?
AFTER=$(wc -l < knowledge/episodes.md | tr -d ' ')
assert_exit_code 1 "$RC"
[ "$BEFORE" -eq "$AFTER" ] && pass || fail "episodes modified without action verb"
teardown_sandbox
record_result "C3" "no action verb"

# ── C4: Duplicate keyword → skip ──
begin_test "C4-duplicate-skip"
setup_sandbox; cd "$SANDBOX"
# episodes-healthy has a docker entry
BEFORE=$(wc -l < knowledge/episodes.md | tr -d ' ')
OUT=$(run_auto_capture "别用 docker compose v1"); RC=$?
AFTER=$(wc -l < knowledge/episodes.md | tr -d ' ')
assert_exit_code 0 "$RC"
assert_contains "$OUT" "Similar|Already"
[ "$BEFORE" -eq "$AFTER" ] && pass || fail "duplicate was written"
teardown_sandbox
record_result "C4" "duplicate skip"

# ── C5: Already in rules → skip ──
begin_test "C5-already-in-rules"
setup_sandbox; cd "$SANDBOX"
BEFORE=$(wc -l < knowledge/episodes.md | tr -d ' ')
OUT=$(run_auto_capture "必须用 jq 处理 JSON"); RC=$?
AFTER=$(wc -l < knowledge/episodes.md | tr -d ' ')
assert_exit_code 0 "$RC"
# Should silently skip (no output about rules)
[ "$BEFORE" -eq "$AFTER" ] && pass || fail "wrote despite being in rules"
teardown_sandbox
record_result "C5" "already in rules"

# ── C6: Capacity full → reject ──
begin_test "C6-capacity-full"
setup_sandbox; cd "$SANDBOX"
# Generate 30-entry episodes file
{
  echo "# Episodes"
  for i in $(seq 1 30); do
    printf '2026-01-%02d | active | uniqueword%d,filler | Entry number %d\n' "$i" "$i" "$i"
  done
} > knowledge/episodes.md
OUT=$(run_auto_capture "换成 pytest 测试框架"); RC=$?
assert_exit_code 0 "$RC"
assert_contains "$OUT" "at capacity"
teardown_sandbox
record_result "C6" "capacity full"

# ── C7: Garbage — no tech term ──
begin_test "C7-garbage-no-tech"
setup_sandbox; cd "$SANDBOX"
BEFORE=$(wc -l < knowledge/episodes.md | tr -d ' ')
OUT=$(run_auto_capture "不对不对"); RC=$?
AFTER=$(wc -l < knowledge/episodes.md | tr -d ' ')
assert_exit_code 1 "$RC"
[ "$BEFORE" -eq "$AFTER" ] && pass || fail "garbage was captured"
teardown_sandbox
record_result "C7" "garbage filtered"

# ── C8: Promotion hint at threshold ──
begin_test "C8-promotion-hint"
setup_sandbox; cd "$SANDBOX"
# episodes-healthy has testword x3 — adding another mention should trigger hint
OUT=$(run_auto_capture "别用 testword 这个方法"); RC=$?
# Should see "Similar" or promotion hint since testword already appears
assert_contains "$OUT" "Similar|×|pattern"
teardown_sandbox
record_result "C8" "promotion hint"

summary "L1: Auto-capture"
