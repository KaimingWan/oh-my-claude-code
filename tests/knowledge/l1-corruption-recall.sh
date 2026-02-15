#!/bin/bash
# l1-corruption-recall.sh — L1: Corruption detection + Recall effectiveness
GROUP="l1-corruption-recall"; source "$(dirname "$0")/lib.sh"
json_report_start

# ═══════════════════════════════════════
# CORRUPTION TESTS
# ═══════════════════════════════════════

# ── D1: Contradictory rules detected ──
begin_test "D1-contradictory-rules"
# rules-corrupted has both "JSON = jq" and "用 sed 处理 JSON"
JQ_COUNT=$(grep -c "jq" "$FIXTURES_DIR/rules-corrupted.md" || true)
SED_JSON=$(grep -c "sed.*JSON" "$FIXTURES_DIR/rules-corrupted.md" || true)
echo "  [jq mentions: $JQ_COUNT, sed+JSON mentions: $SED_JSON]"
[ "$JQ_COUNT" -ge 2 ] && [ "$SED_JSON" -ge 1 ] && pass || fail "contradiction not present in fixture"
record_result "D1" "contradictory rules"

# ── D2: Rules in wrong section ──
begin_test "D2-wrong-section"
# rules-corrupted has "JSON = jq" under [security] section
WRONG=$(awk '/## \[security/{found=1} found && /JSON = jq/{print; exit}' "$FIXTURES_DIR/rules-corrupted.md")
[ -n "$WRONG" ] && pass || fail "misplaced rule not found in fixture"
record_result "D2" "wrong section"

# ── D3: Bloated rules → health report warns ──
begin_test "D3-bloated-rules"
setup_sandbox; cd "$SANDBOX"
cp "$FIXTURES_DIR/rules-corrupted.md" knowledge/rules.md
SIZE=$(wc -c < knowledge/rules.md | tr -d ' ')
echo "  [rules size: ${SIZE}B]"
OUT=$(run_kb_health_report)
assert_contains "$OUT" "approaching limit|issues"
teardown_sandbox
record_result "D3" "bloated rules"

# ── D4: Stale episodes → promote candidates ──
begin_test "D4-stale-promote"
setup_sandbox; cd "$SANDBOX"
# episodes-healthy has testword x3 → should be promote candidate
OUT=$(run_kb_health_report)
assert_contains "$OUT" "Promote|issues"
teardown_sandbox
record_result "D4" "stale promote"

# ── D5: Promoted entries cleaned by context-enrichment ──
begin_test "D5-promoted-cleaned"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
BEFORE=$(grep -c '| promoted |' knowledge/episodes.md || true)
OUT=$(run_context_enrichment "test")
AFTER=$(grep -c '| promoted |' knowledge/episodes.md || true)
echo "  [promoted: $BEFORE → $AFTER]"
[ "$BEFORE" -gt 0 ] && [ "$AFTER" -eq 0 ] && pass || fail "promoted not cleaned"
teardown_sandbox
record_result "D5" "promoted cleaned"

# ═══════════════════════════════════════
# RECALL TESTS
# ═══════════════════════════════════════

# ── E1: Each keyword section recalled correctly ──
begin_test "E1-per-section-recall"
ALL_PASS=1
for kw_expect in "jq:JSON = jq" "security:Skill 文件不得" "plan:review 必须" "subagent:read/write/shell"; do
  KW="${kw_expect%%:*}"
  EXPECT="${kw_expect#*:}"
  setup_sandbox; clear_session_flags; cd "$SANDBOX"
  OUT=$(run_context_enrichment "$KW")
  if ! echo "$OUT" | grep -q "$EXPECT"; then
    echo "  ❌ keyword '$KW' did not recall '$EXPECT'"
    ALL_PASS=0
  fi
  teardown_sandbox
done
[ "$ALL_PASS" -eq 1 ] && pass || fail "some sections not recalled"
record_result "E1" "per-section recall"

# ── E2: Mixed language recall ──
begin_test "E2-mixed-language"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
OUT=$(run_context_enrichment "fix json parsing bug")
assert_contains "$OUT" "JSON = jq"
teardown_sandbox
record_result "E2" "mixed language"

# ── E3: Injection completeness (all rules in section) ──
begin_test "E3-injection-completeness"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
OUT=$(run_context_enrichment "用 jq 处理 JSON")
# Shell section has 2 rules — both should appear
echo "  [check rule 1]"
assert_contains "$OUT" "JSON = jq"
echo "  [check rule 2]"
assert_contains "$OUT" "stat -f"
teardown_sandbox
record_result "E3" "injection completeness"

# ── E4: No false positive on irrelevant prompt ──
begin_test "E4-no-false-positive"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
OUT=$(run_context_enrichment "今天天气怎么样")
assert_contains "$OUT" "Rules .general."
# Should NOT contain security-specific or subagent-specific rules
echo "  [no security leak]"
assert_not_contains "$OUT" "Skill 文件不得"
echo "  [no subagent leak]"
assert_not_contains "$OUT" "read/write/shell/MCP"
teardown_sandbox
record_result "E4" "no false positive"

summary "L1: Corruption + Recall"
