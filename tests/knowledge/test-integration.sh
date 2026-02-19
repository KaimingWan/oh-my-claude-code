#!/bin/bash
# test-integration.sh — End-to-end: episodes → distill → rules → archive
GROUP="integration"; source "$(dirname "$0")/lib.sh"
json_report_start

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DISTILL_LIB="$PROJECT_DIR/hooks/_lib/distill.sh"

# ── Prerequisite check ──
if [ ! -f "$DISTILL_LIB" ]; then
  echo "⏭️  SKIP: distill.sh not yet created (Task 1 prerequisite)"
  printf '{"group":"integration","tests":[],"summary":{"total":0,"pass":0,"fail":0,"skip":"distill.sh missing"}}' > "$REPORT_DIR/integration.json"
  exit 0
fi

# ── Helper: build sandbox with shared-keyword episodes ──
setup_integration() {
  SANDBOX="/tmp/kb-integration-$$"
  rm -rf "$SANDBOX"
  mkdir -p "$SANDBOX/knowledge/archive" "$SANDBOX/.claude/rules"

  # rules.md — empty staging area with new header
  cat > "$SANDBOX/knowledge/rules.md" << 'HEADER'
# Agent Rules — Staging Area

> Auto-distilled from episodes. Injected by context-enrichment per message.
> 🔴 = CRITICAL (always injected) | 🟡 = RELEVANT (keyword-matched)
> Sections auto-created by distill.sh. Max 5 rules per section.
HEADER

  # episodes with "testkw" appearing 3x (freq ≥2 triggers distill)
  cat > "$SANDBOX/knowledge/episodes.md" << 'EPISODES'
# Episodes (Episodic Memory)

> Timestamped events. ≤30 entries.

2026-02-01 | active | testkw,alpha | 禁止直接修改 testkw 配置文件
2026-02-02 | active | testkw,beta | testkw 第二次出现相同问题
2026-02-03 | active | testkw,gamma | testkw 必须通过 API 修改
2026-02-04 | active | otherkw,delta | otherkw 只出现一次不触发蒸馏
EPISODES

  # Empty .claude/rules/ so distill doesn't skip due to existing coverage
  touch "$SANDBOX/.claude/rules/.gitkeep"
}

teardown_integration() {
  [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"
}

# ── I1: Full pipeline — distill creates rule from freq≥2 episodes ──
begin_test "I1-distill-creates-rule"
setup_integration; cd "$SANDBOX"

# Touch kb-changed flag (same hash method as hooks)
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
touch "/tmp/kb-changed-${WS_HASH}.flag"

# Run context-enrichment (should trigger distill via kb-changed flag)
OUT=$(printf '{"prompt":"testkw config"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" 2>&1)
RC=$?

# Verify: rule written to rules.md
if grep -q 'testkw' "$SANDBOX/knowledge/rules.md" 2>/dev/null; then
  pass
else
  fail "no testkw rule in rules.md after distillation"
fi
teardown_integration
record_result "I1" "distill creates rule"

# ── I2: Distilled rule appears in context-enrichment output ──
begin_test "I2-rule-in-output"
setup_integration; cd "$SANDBOX"

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
touch "/tmp/kb-changed-${WS_HASH}.flag"

OUT=$(printf '{"prompt":"testkw config"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" 2>&1)

# Output should contain the injected rule
if echo "$OUT" | grep -qE '(⚠️|📚).*testkw|testkw.*(RULE|Rule)'; then
  pass
else
  fail "distilled rule not in enrichment output"
fi
teardown_integration
record_result "I2" "rule in output"

# ── I3: Source episodes removed from active after distillation ──
begin_test "I3-episodes-promoted"
setup_integration; cd "$SANDBOX"

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
touch "/tmp/kb-changed-${WS_HASH}.flag"

# Count active testkw episodes before
BEFORE=$(grep '| active |' "$SANDBOX/knowledge/episodes.md" 2>/dev/null | grep -c 'testkw' || true)

printf '{"prompt":"testkw"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" > /dev/null 2>&1

# After distill+archive, testkw episodes should be gone from active
AFTER=$(grep '| active |' "$SANDBOX/knowledge/episodes.md" 2>/dev/null | grep -c 'testkw' || true)
AFTER=$(echo "$AFTER" | tr -d '[:space:]')
BEFORE=$(echo "$BEFORE" | tr -d '[:space:]')
if [ "${AFTER:-0}" -eq 0 ] && [ "${BEFORE:-0}" -gt 0 ]; then
  pass
else
  fail "testkw episodes still active (before=$BEFORE, after=$AFTER)"
fi
teardown_integration
record_result "I3" "episodes promoted"

# ── I4: Session-init archives promoted episodes ──
begin_test "I4-archive-populated"
setup_integration; cd "$SANDBOX"

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
touch "/tmp/kb-changed-${WS_HASH}.flag"
# Clear session flag so session-init runs
rm -f "/tmp/lessons-injected-${WS_HASH}.flag"

# Step 1: context-enrichment triggers distill (promotes episodes)
printf '{"prompt":"testkw"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" > /dev/null 2>&1

# Step 2: session-init should archive promoted episodes
rm -f "/tmp/lessons-injected-${WS_HASH}.flag"
printf '{"prompt":"test"}' | bash "$PROJECT_DIR/hooks/feedback/session-init.sh" > /dev/null 2>&1

ARCHIVE_FILES=$(find "$SANDBOX/knowledge/archive" -name 'episodes-*.md' 2>/dev/null | wc -l | tr -d ' ')
if [ "$ARCHIVE_FILES" -gt 0 ]; then
  pass
else
  fail "no archive files created (found $ARCHIVE_FILES)"
fi
teardown_integration
record_result "I4" "archive populated"

# ── I5: kb-changed flag consumed (no re-distill on next message) ──
begin_test "I5-flag-consumed"
setup_integration; cd "$SANDBOX"

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
touch "/tmp/kb-changed-${WS_HASH}.flag"

printf '{"prompt":"testkw"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" > /dev/null 2>&1

if [ -f "/tmp/kb-changed-${WS_HASH}.flag" ]; then
  fail "kb-changed flag not consumed"
else
  pass
fi
teardown_integration
record_result "I5" "flag consumed"

# ── I6: Single-occurrence keyword NOT distilled ──
begin_test "I6-low-freq-skipped"
setup_integration; cd "$SANDBOX"

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
touch "/tmp/kb-changed-${WS_HASH}.flag"

printf '{"prompt":"otherkw"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" > /dev/null 2>&1

if grep -q 'otherkw' "$SANDBOX/knowledge/rules.md" 2>/dev/null; then
  # Check if it's only in the header (not a distilled rule)
  RULE_LINES=$(grep -c '^[0-9].*otherkw' "$SANDBOX/knowledge/rules.md" 2>/dev/null || echo 0)
  if [ "$RULE_LINES" -gt 0 ]; then
    fail "low-freq keyword 'otherkw' should not be distilled"
  else
    pass
  fi
else
  pass
fi
teardown_integration
record_result "I6" "low freq skipped"

# ── I7: Severity — action words produce 🔴 CRITICAL ──
begin_test "I7-severity-critical"
setup_integration; cd "$SANDBOX"

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
touch "/tmp/kb-changed-${WS_HASH}.flag"

printf '{"prompt":"testkw"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" > /dev/null 2>&1

# Episodes contain "禁止" and "必须" → should produce 🔴
if grep -q '🔴' "$SANDBOX/knowledge/rules.md" 2>/dev/null; then
  pass
else
  fail "action words (禁止/必须) should produce 🔴 severity"
fi
teardown_integration
record_result "I7" "severity critical"

# ── I8: Archive is append-only (second run doesn't overwrite) ──
begin_test "I8-archive-append-only"
setup_integration; cd "$SANDBOX"

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")

# First run: distill + archive
touch "/tmp/kb-changed-${WS_HASH}.flag"
rm -f "/tmp/lessons-injected-${WS_HASH}.flag"
printf '{"prompt":"testkw"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" > /dev/null 2>&1
rm -f "/tmp/lessons-injected-${WS_HASH}.flag"
printf '{"prompt":"test"}' | bash "$PROJECT_DIR/hooks/feedback/session-init.sh" > /dev/null 2>&1

FIRST_SIZE=0
ARCHIVE_FILE=$(find "$SANDBOX/knowledge/archive" -name 'episodes-*.md' 2>/dev/null | head -1)
[ -f "$ARCHIVE_FILE" ] && FIRST_SIZE=$(wc -c < "$ARCHIVE_FILE" | tr -d ' ')

# Add more episodes and run again
cat >> "$SANDBOX/knowledge/episodes.md" << 'MORE'
2026-02-05 | active | testkw,extra1 | testkw 额外条目1
2026-02-06 | active | testkw,extra2 | testkw 额外条目2
MORE

touch "/tmp/kb-changed-${WS_HASH}.flag"
rm -f "/tmp/lessons-injected-${WS_HASH}.flag"
printf '{"prompt":"testkw"}' | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" > /dev/null 2>&1
rm -f "/tmp/lessons-injected-${WS_HASH}.flag"
printf '{"prompt":"test"}' | bash "$PROJECT_DIR/hooks/feedback/session-init.sh" > /dev/null 2>&1

SECOND_SIZE=0
[ -f "$ARCHIVE_FILE" ] && SECOND_SIZE=$(wc -c < "$ARCHIVE_FILE" | tr -d ' ')

echo "  [archive size: $FIRST_SIZE → $SECOND_SIZE]"
if [ "$SECOND_SIZE" -ge "$FIRST_SIZE" ]; then
  pass
else
  fail "archive shrank ($FIRST_SIZE → $SECOND_SIZE) — not append-only"
fi
teardown_integration
record_result "I8" "archive append-only"

summary "Integration: End-to-End Pipeline"
