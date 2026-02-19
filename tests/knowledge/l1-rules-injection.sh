#!/bin/bash
# l1-rules-injection.sh — L1: Rules injection via context-enrichment.sh
GROUP="l1-rules-injection"; source "$(dirname "$0")/lib.sh"
json_report_start

# ── R1: Exact keyword match (jq → shell section) ──
begin_test "R1-exact-keyword"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
OUT=$(run_context_enrichment "用 jq 处理 JSON")
assert_contains "$OUT" "JSON = jq"
echo "  [negative check]"
assert_not_contains "$OUT" "Skill 文件不得"
teardown_sandbox
record_result "R1" "exact keyword match"

# ── R2: No keyword → fallback to largest section ──
begin_test "R2-no-keyword-fallback"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
OUT=$(run_context_enrichment "帮我写个函数")
assert_contains "$OUT" "Rules .general."
teardown_sandbox
record_result "R2" "no keyword fallback"

# ── R3: English keyword (security) ──
begin_test "R3-english-keyword"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
OUT=$(run_context_enrichment "fix the security hook")
assert_contains "$OUT" "Skill 文件不得"
echo "  [negative check]"
assert_not_contains "$OUT" "JSON = jq"
teardown_sandbox
record_result "R3" "english keyword"

# ── R4: Empty rules file ──
begin_test "R4-empty-rules"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
> "$SANDBOX/knowledge/rules.md"
OUT=$(run_context_enrichment "用 jq"); RC=$?
assert_exit_code 0 "$RC"
echo "  [no injection check]"
assert_not_contains "$OUT" "📚 Rules"
teardown_sandbox
record_result "R4" "empty rules"

# ── R5: Old format fallback (no ## [ headers) ──
begin_test "R5-old-format-fallback"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
cat > "$SANDBOX/knowledge/rules.md" << 'EOF'
# Agent Rules
1. JSON = jq always.
2. No sed for JSON.
EOF
OUT=$(run_context_enrichment "test")
assert_contains "$OUT" "JSON = jq"
teardown_sandbox
record_result "R5" "old format fallback"

# ── R6: Session dedup (flag file prevents re-injection) ──
begin_test "R6-session-dedup"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
OUT1=$(run_context_enrichment "用 jq 处理 JSON")
# Don't clear flags — second run should skip
OUT2=$(run_context_enrichment "用 jq 处理 JSON")
echo "  [first run has injection]"
assert_contains "$OUT1" "JSON = jq"
echo "  [second run skips]"
# Second run should NOT have rules injection (flag exists)
if echo "$OUT2" | grep -q "📚 Rules"; then
  fail "second run should skip injection"
else
  pass
fi
teardown_sandbox
record_result "R6" "session dedup"

# ── R7: Promoted episodes cleaned ──
begin_test "R7-promoted-cleaned"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
# episodes-healthy has 2 promoted entries
BEFORE=$(grep -c '| promoted |' "$SANDBOX/knowledge/episodes.md" || true)
OUT=$(run_context_enrichment "test")
AFTER=$(grep -c '| promoted |' "$SANDBOX/knowledge/episodes.md" || true)
echo "  [before: $BEFORE promoted, after: $AFTER]"
if [ "$BEFORE" -gt 0 ] && [ "$AFTER" -eq 0 ]; then
  pass
else
  fail "promoted entries not cleaned (before=$BEFORE, after=$AFTER)"
fi
assert_contains "$OUT" "📦 Archived"
teardown_sandbox
record_result "R7" "promoted cleaned"

summary "L1: Rules Injection"
