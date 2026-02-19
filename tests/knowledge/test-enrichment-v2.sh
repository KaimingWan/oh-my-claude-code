#!/bin/bash
# test-enrichment-v2.sh — Tests for context-enrichment expansion (Task 3)
# E1: kb-changed flag triggers distillation
# E2: 🟡 rules injected with 📚 on keyword match
# E3: 🔴 rules always injected with ⚠️
# E4: episode hints for matching keywords
# E5: archive hint when dir exists
# E6: session-init no longer outputs rules
# E7: session-init still does cleanup + health
# E8: no distillation when flag absent
GROUP="enrichment-v2"; source "$(dirname "$0")/lib.sh"
json_report_start

# ── Helper: run session-init ──
run_session_init() {
  local prompt="$1"
  rm -f /tmp/lessons-injected-*.flag
  printf '{"prompt":"%s"}' "$prompt" | bash "$PROJECT_DIR/hooks/feedback/session-init.sh" 2>&1
}

# ── E1: kb-changed flag triggers distillation ──
begin_test "E1-kb-changed-triggers-distill"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
touch "/tmp/kb-changed-${WS_HASH}.flag"
OUT=$(run_context_enrichment "test")
# Flag should be consumed (removed)
if [ -f "/tmp/kb-changed-${WS_HASH}.flag" ]; then
  fail "kb-changed flag not consumed"
else
  pass
fi
teardown_sandbox
record_result "E1" "kb-changed triggers distillation"

# ── E2: 🟡 rules injected with 📚 on keyword match ──
begin_test "E2-yellow-rules-keyword-match"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
cat > knowledge/rules.md << 'EOF'
# Agent Rules — Staging Area
## [shell, json, jq]
🟡 JSON = jq always
🟡 macOS stat -f not -c
## [security, hook]
🟡 No HTML in skills
EOF
OUT=$(run_context_enrichment "fix the jq parser")
assert_contains "$OUT" "📚 Rule: JSON = jq"
teardown_sandbox
record_result "E2" "yellow rules keyword match"

# ── E3: 🔴 rules always injected with ⚠️ ──
begin_test "E3-red-rules-always-injected"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
cat > knowledge/rules.md << 'EOF'
# Agent Rules — Staging Area
## [shell, json, jq]
🔴 Never use sed for JSON
🟡 macOS stat -f not -c
## [security, hook]
🟡 No HTML in skills
EOF
# Message has NO matching keywords — 🔴 should still appear
OUT=$(run_context_enrichment "hello world unrelated topic")
assert_contains "$OUT" "⚠️ RULE: Never use sed for JSON"
teardown_sandbox
record_result "E3" "red rules always injected"

# ── E4: episode hints for matching keywords ──
begin_test "E4-episode-hints"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
cat > knowledge/episodes.md << 'EOF'
# Episodes
2026-02-01 | active | docker,deploy | Docker deployment config issue found
2026-02-02 | active | react,frontend | React rendering problem
2026-02-03 | resolved | python,typing | Python typing resolved
EOF
OUT=$(run_context_enrichment "fix the docker container")
assert_contains "$OUT" "📌 Episode:.*Docker"
echo "  [resolved should not appear]"
assert_not_contains "$OUT" "📌 Episode:.*Python"
teardown_sandbox
record_result "E4" "episode hints"

# ── E5: archive hint when dir exists ──
begin_test "E5-archive-hint"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
mkdir -p knowledge/archive
echo "archived content" > knowledge/archive/episodes-2026-01.md
OUT=$(run_context_enrichment "test")
assert_contains "$OUT" "📦 Archive available"
teardown_sandbox
record_result "E5" "archive hint"

# ── E6: session-init no longer outputs rules ──
begin_test "E6-session-init-no-rules"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
cat > knowledge/rules.md << 'EOF'
# Agent Rules — Staging Area
## [shell, json, jq]
1. JSON = jq always
2. macOS stat -f not -c
EOF
OUT=$(run_session_init "fix jq parser")
assert_not_contains "$OUT" "📚 Rules"
assert_not_contains "$OUT" "JSON = jq"
teardown_sandbox
record_result "E6" "session-init no rules"

# ── E7: session-init still does cleanup + health ──
begin_test "E7-session-init-cleanup-health"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
# Add promoted episodes
cat > knowledge/episodes.md << 'EOF'
# Episodes
2026-02-01 | active | docker,deploy | Docker issue
2026-02-02 | promoted | oldtool,legacy | Old tool promoted
EOF
cat > knowledge/.health-report.md << 'EOF'
⬆️ 3 keywords need promotion
⚠️ rules.md approaching limit
EOF
OUT=$(run_session_init "test")
echo "  [check promoted cleanup]"
assert_contains "$OUT" "🧹 Cleaned"
echo "  [check health report]"
assert_contains "$OUT" "📊 KB has"
# Verify promoted actually removed from file
REMAINING=$(grep -c '| promoted |' knowledge/episodes.md 2>/dev/null || true)
echo "  [promoted remaining: $REMAINING]"
[ "$REMAINING" -eq 0 ] && pass || fail "promoted entries not cleaned"
teardown_sandbox
record_result "E7" "session-init cleanup + health"

# ── E8: no distillation when flag absent ──
begin_test "E8-no-distill-without-flag"
setup_sandbox; clear_session_flags; cd "$SANDBOX"
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
rm -f "/tmp/kb-changed-${WS_HASH}.flag"
# Even if distill.sh exists, it should not be called without flag
OUT=$(run_context_enrichment "test")
# No distillation output expected — just verify no errors
assert_exit_code 0 "$?"
teardown_sandbox
record_result "E8" "no distillation without flag"

summary "Enrichment v2"
