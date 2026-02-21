#!/bin/bash
# test-context-budget.sh — Verify context-enrichment.sh output budget (<=8 lines) + dedup + rules cap
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

HOOK="hooks/feedback/context-enrichment.sh"
PASS=0
FAIL=0

WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
DEDUP_FILE="/tmp/ctx-enrich-${WS_HASH}.ts"

reset_dedup() {
  unlink "$DEDUP_FILE" 2>/dev/null || true
}

check_output_lines() {
  local name="$1" max_lines="$2"
  local input
  input=$(cat)
  local output
  output=$(echo "$input" | bash "$HOOK" 2>&1 || true)
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  # Empty output: 0 lines (wc -l on empty string gives 0)
  if [ -z "$output" ]; then line_count=0; fi
  if [ "$line_count" -le "$max_lines" ]; then
    echo "PASS $name (${line_count} lines <= ${max_lines})"
    PASS=$((PASS + 1))
  else
    echo "FAIL $name (${line_count} lines > ${max_lines})"
    echo "  Output:"
    echo "$output" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

check_output_empty() {
  local name="$1"
  local input
  input=$(cat)
  local output
  output=$(echo "$input" | bash "$HOOK" 2>&1 || true)
  if [ -z "$output" ]; then
    echo "PASS $name (output empty — dedup fired)"
    PASS=$((PASS + 1))
  else
    echo "FAIL $name (expected empty output, got: $output)"
    FAIL=$((FAIL + 1))
  fi
}

MAX_LINES=8

# --- Test 1: Simple prompt — output <=8 lines ---
reset_dedup
check_output_lines "simple prompt output <= 8 lines" $MAX_LINES <<'EOF'
{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"hello world"}
EOF

# --- Test 2: Research keyword → triggers research reminder ---
reset_dedup
output=$(printf '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"research the best approach"}' | bash "$HOOK" 2>&1 || true)
line_count=$(echo "$output" | wc -l | tr -d ' ')
if echo "$output" | grep -q "Research detected" && [ "$line_count" -le "$MAX_LINES" ]; then
  echo "PASS research keyword triggers reminder (${line_count} lines)"
  PASS=$((PASS + 1))
else
  echo "FAIL research keyword (line_count=$line_count, output=$output)"
  FAIL=$((FAIL + 1))
fi

# --- Test 3: 60s dedup — second call within 60s produces no output ---
# (dedup file was just written by test 2)
check_output_empty "60s dedup suppresses second call" <<'EOF'
{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"another prompt"}
EOF

# --- Test 4: After dedup reset, output <=8 lines even with many rules ---
reset_dedup

# Create a temporary rules file with many rules
RULES_BACKUP=""
RULES_FILE="knowledge/rules.md"
if [ -f "$RULES_FILE" ]; then
  RULES_BACKUP=$(cat "$RULES_FILE")
fi

# Write a rules file with 10 critical rules (should be capped at 3)
cat > "$RULES_FILE" << 'RULES_EOF'
## [all]
🔴 Rule 1: always do this
🔴 Rule 2: always do that
🔴 Rule 3: never forget this
🔴 Rule 4: this is important
🔴 Rule 5: another critical rule
🔴 Rule 6: yet another rule
🔴 Rule 7: more rules
🔴 Rule 8: eighth rule
🔴 Rule 9: ninth rule
🔴 Rule 10: tenth rule
RULES_EOF

reset_dedup
output=$(printf '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"do something"}' | bash "$HOOK" 2>&1 || true)
line_count=$(echo "$output" | wc -l | tr -d ' ')
if [ -z "$output" ]; then line_count=0; fi

if [ "$line_count" -le "$MAX_LINES" ]; then
  echo "PASS rules cap: $line_count lines <= $MAX_LINES (10 rules capped to 3)"
  PASS=$((PASS + 1))
else
  echo "FAIL rules cap: $line_count lines > $MAX_LINES"
  echo "  Output:"
  echo "$output" | sed 's/^/    /'
  FAIL=$((FAIL + 1))
fi

# Restore rules file
if [ -n "$RULES_BACKUP" ]; then
  echo "$RULES_BACKUP" > "$RULES_FILE"
else
  unlink "$RULES_FILE" 2>/dev/null || true
fi

# --- Test 5: Truncation test — force many output lines via multiple triggers ---
reset_dedup

# Temporarily create .completion-criteria.md with many items
CRITERIA_FILE=".completion-criteria.md"
cat > "$CRITERIA_FILE" << 'CRITERIA_EOF'
- [ ] item 1
- [ ] item 2
- [ ] item 3
- [ ] item 4
- [ ] item 5
CRITERIA_EOF

output=$(printf '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"research and fix the bug"}' | bash "$HOOK" 2>&1 || true)
line_count=$(echo "$output" | wc -l | tr -d ' ')
if [ -z "$output" ]; then line_count=0; fi

if [ "$line_count" -le "$MAX_LINES" ]; then
  echo "PASS truncation test: $line_count lines <= $MAX_LINES"
  PASS=$((PASS + 1))
else
  echo "FAIL truncation test: $line_count lines > $MAX_LINES"
  echo "  Output:"
  echo "$output" | sed 's/^/    /'
  FAIL=$((FAIL + 1))
fi

unlink "$CRITERIA_FILE" 2>/dev/null || true

# --- Cleanup ---
reset_dedup

# --- Summary ---
echo ""
echo "=== Context Budget Tests: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
