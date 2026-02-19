#!/bin/bash
# test-distill.sh — Unit tests for hooks/_lib/distill.sh
GROUP="test-distill"; source "$(dirname "$0")/lib.sh"
json_report_start

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Helper: set up distill environment in sandbox
setup_distill() {
  setup_sandbox
  mkdir -p "$SANDBOX/.claude/rules" "$SANDBOX/knowledge/archive"
  EPISODES_FILE="$SANDBOX/knowledge/episodes.md"
  RULES_FILE="$SANDBOX/knowledge/rules.md"
  RULES_DIR="$SANDBOX/.claude/rules"
  ARCHIVE_DIR="$SANDBOX/knowledge/archive"
  source "$PROJECT_DIR/hooks/_lib/distill.sh"
}

# ── D1: freq ≥2 triggers distillation with correct severity ──
begin_test "D1-freq-triggers-distill"
setup_distill
cat > "$EPISODES_FILE" << 'EOF'
# Episodes
2026-01-01 | active | foobar,alpha | 第一次 foobar 问题
2026-01-02 | active | foobar,beta | 第二次 foobar 必须修复
EOF
> "$RULES_FILE"
OUT=$(distill_check)
assert_contains "$OUT" "Distilled"
# Rule should be written
assert_contains "$(cat "$RULES_FILE")" "foobar"
# "必须" → 🔴
assert_contains "$(cat "$RULES_FILE")" "🔴"
teardown_sandbox
record_result "D1" "freq ≥2 triggers distillation with severity"

# ── D2: keyword in .claude/rules/ → promoted, no rule written ──
begin_test "D2-covered-by-rules-dir"
setup_distill
cat > "$EPISODES_FILE" << 'EOF'
# Episodes
2026-01-01 | active | shell,test1 | Shell issue one
2026-01-02 | active | shell,test2 | Shell issue two
EOF
> "$RULES_FILE"
# .claude/rules/shell.md exists with "shell" keyword
echo "# Shell Rules" > "$RULES_DIR/shell.md"
echo "1. Use bash." >> "$RULES_DIR/shell.md"
OUT=$(distill_check)
# Episodes should be marked promoted
assert_contains "$(cat "$EPISODES_FILE")" "promoted"
# No rule written to rules.md (covered by .claude/rules/)
RULE_LINES=$(grep '^[0-9]' "$RULES_FILE" 2>/dev/null | wc -l | tr -d ' ')
if [ "$RULE_LINES" -eq 0 ]; then pass; else fail "rule written but keyword covered by .claude/rules/"; fi
teardown_sandbox
record_result "D2" "keyword in .claude/rules/ → promoted, no rule"

# ── D3: keyword in rules.md → no duplicate ──
begin_test "D3-no-duplicate"
setup_distill
cat > "$EPISODES_FILE" << 'EOF'
# Episodes
2026-01-01 | active | mykey,x | Issue one
2026-01-02 | active | mykey,y | Issue two
EOF
cat > "$RULES_FILE" << 'EOF'
# Rules
## [mykey,x]
1. Existing rule
EOF
OUT=$(distill_check)
# Should not add duplicate section
SECTION_COUNT=$(grep -c '## \[mykey' "$RULES_FILE" || true)
if [ "$SECTION_COUNT" -eq 1 ]; then pass; else fail "duplicate section created ($SECTION_COUNT)"; fi
teardown_sandbox
record_result "D3" "keyword in rules.md → no duplicate"

# ── D4: promoted → archive ──
begin_test "D4-promoted-archived"
setup_distill
cat > "$EPISODES_FILE" << 'EOF'
# Episodes
2026-01-01 | promoted | old,stuff | Old promoted entry
2026-01-02 | active | new,stuff | Active entry
EOF
OUT=$(archive_promoted)
assert_contains "$OUT" "Archived 1"
# Promoted removed from episodes
assert_not_contains "$(cat "$EPISODES_FILE")" "promoted"
# Active still there
assert_contains "$(cat "$EPISODES_FILE")" "active"
teardown_sandbox
record_result "D4" "promoted → archive"

# ── D5: resolved → archive ──
begin_test "D5-resolved-archived"
setup_distill
cat > "$EPISODES_FILE" << 'EOF'
# Episodes
2026-01-01 | resolved | done,thing | Resolved entry
2026-01-02 | active | live,thing | Active entry
EOF
OUT=$(archive_promoted)
assert_contains "$OUT" "Archived 1"
assert_not_contains "$(cat "$EPISODES_FILE")" "resolved"
assert_contains "$(cat "$EPISODES_FILE")" "active"
teardown_sandbox
record_result "D5" "resolved → archive"

# ── D6: archive append-only ──
begin_test "D6-archive-append-only"
setup_distill
ARCHIVE_FILE="$ARCHIVE_DIR/episodes-$(date +%Y-%m).md"
echo "2026-01-01 | promoted | pre,existing | Pre-existing" > "$ARCHIVE_FILE"
cat > "$EPISODES_FILE" << 'EOF'
# Episodes
2026-01-02 | promoted | new,entry | New promoted
EOF
archive_promoted
# Both old and new should be in archive
assert_contains "$(cat "$ARCHIVE_FILE")" "pre,existing"
assert_contains "$(cat "$ARCHIVE_FILE")" "new,entry"
teardown_sandbox
record_result "D6" "archive append-only"

# ── D7: section cap (6th evicts 1st) ──
begin_test "D7-section-cap"
setup_distill
cat > "$RULES_FILE" << 'EOF'
# Rules
## [test,cap]
1. Rule one
2. Rule two
3. Rule three
4. Rule four
5. Rule five
6. Rule six
EOF
section_cap_enforce
RULE_COUNT=$(grep -c '^[0-9]' "$RULES_FILE" || true)
if [ "$RULE_COUNT" -eq 5 ]; then pass; else fail "expected 5 rules, got $RULE_COUNT"; fi
# First rule should be evicted, last 5 remain
assert_not_contains "$(cat "$RULES_FILE")" "Rule one"
assert_contains "$(cat "$RULES_FILE")" "Rule six"
teardown_sandbox
record_result "D7" "section cap (6th evicts 1st)"

# ── D8: severity: "禁止" → 🔴, no action words → 🟡 ──
begin_test "D8-severity-detection"
setup_distill
cat > "$EPISODES_FILE" << 'EOF'
# Episodes
2026-01-01 | active | sev1,a | 禁止直接修改
2026-01-02 | active | sev1,b | 另一个 sev1 问题
2026-01-03 | active | sev2,c | 普通问题描述
2026-01-04 | active | sev2,d | 又一个普通问题
EOF
> "$RULES_FILE"
distill_check
RULES_CONTENT=$(cat "$RULES_FILE")
# sev1 has "禁止" → 🔴
if echo "$RULES_CONTENT" | grep -A1 'sev1' | grep -q '🔴'; then pass; else fail "sev1 should be 🔴"; fi
# sev2 has no action words → 🟡
if echo "$RULES_CONTENT" | grep -A1 'sev2' | grep -q '🟡'; then pass; else fail "sev2 should be 🟡"; fi
teardown_sandbox
record_result "D8" "severity detection"

summary "Distillation Engine"
