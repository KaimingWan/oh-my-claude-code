#!/bin/bash
# l1-d-config.sh — L1-D: 配置一致性测试 (10)
GROUP="l1-d-config"; LAYER="1"; source "$(dirname "$0")/lib.sh"
json_report_start

# D01: CC settings.json valid JSON
begin_test "D01-cc-json-valid"
jq . "$PROJECT_DIR/.claude/settings.json" > /dev/null 2>&1
assert_exit_code 0 $?
record_result "D01" "CC settings.json valid"

# D02: Kiro default.json valid JSON
begin_test "D02-kiro-json-valid"
jq . "$PROJECT_DIR/.kiro/agents/default.json" > /dev/null 2>&1
assert_exit_code 0 $?
record_result "D02" "Kiro default.json valid"

# D03: CC hook entry count = 10
begin_test "D03-cc-hook-count"
COUNT=$(jq '.hooks | to_entries | map(.value | length) | add' "$PROJECT_DIR/.claude/settings.json")
[ "$COUNT" -eq 10 ] && pass || fail "CC hooks=$COUNT, expected 10"
record_result "D03" "CC hook count"

# D04: Kiro hook entry count = 9
begin_test "D04-kiro-hook-count"
COUNT=$(jq '[.hooks | to_entries[] | .value | if type == "array" then length else 0 end] | add' "$PROJECT_DIR/.kiro/agents/default.json")
[ "$COUNT" -eq 9 ] && pass || fail "Kiro hooks=$COUNT, expected 9"
record_result "D04" "Kiro hook count"

# D05: CC/Kiro shared hook script names match
begin_test "D05-shared-hooks"
CC_HOOKS=$(jq -r '[.hooks[][] | .hooks[]? | .command // empty] | map(split("/") | last) | sort | .[]' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null | sort -u)
KIRO_HOOKS=$(jq -r '[.hooks | to_entries[] | .value[] | .command // empty] | map(split("/") | last) | sort | .[]' "$PROJECT_DIR/.kiro/agents/default.json" 2>/dev/null | sort -u)
# Kiro should be subset of CC (CC has extra CC-only hooks)
MISSING=""
for h in $KIRO_HOOKS; do
  echo "$CC_HOOKS" | grep -q "$h" || MISSING="$MISSING $h"
done
[ -z "$MISSING" ] && pass || fail "Kiro hooks not in CC:$MISSING"
record_result "D05" "shared hook names"

# D06: all hook scripts executable
begin_test "D06-hooks-executable"
NON_EXEC=""
for f in "$PROJECT_DIR"/.claude/hooks/**/*.sh; do
  [ -f "$f" ] && [ ! -x "$f" ] && NON_EXEC="$NON_EXEC $(basename "$f")"
done
[ -z "$NON_EXEC" ] && pass || fail "not executable:$NON_EXEC"
record_result "D06" "hooks executable"

# D07: CLAUDE.md = AGENTS.md
begin_test "D07-claude-agents-sync"
diff -q "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/AGENTS.md" > /dev/null 2>&1
assert_exit_code 0 $?
record_result "D07" "CLAUDE.md = AGENTS.md"

# D08: .kiro/hooks symlink → ../.claude/hooks
begin_test "D08-hooks-symlink"
TARGET=$(readlink "$PROJECT_DIR/.kiro/hooks" 2>/dev/null)
[ "$TARGET" = "../.claude/hooks" ] && pass || fail "symlink=$TARGET, expected ../.claude/hooks"
record_result "D08" "hooks symlink"

# D09: .kiro/skills symlink + subagent files complete
begin_test "D09-skills-symlink-subagents"
TARGET=$(readlink "$PROJECT_DIR/.kiro/skills" 2>/dev/null)
OK=true
[ "$TARGET" = "../.claude/skills" ] || OK=false
for f in reviewer researcher implementer debugger; do
  [ -f "$PROJECT_DIR/.kiro/agents/$f.json" ] || OK=false
done
for f in reviewer-prompt implementer-prompt debugger-prompt researcher-prompt; do
  [ -f "$PROJECT_DIR/.kiro/agents/prompts/$f.md" ] || OK=false
done
$OK && pass || fail "symlink or subagent files missing"
record_result "D09" "skills symlink + subagents"

# D10: context-enrichment has NO complexity detection code
begin_test "D10-no-complexity-detection"
CE="$PROJECT_DIR/.claude/hooks/autonomy/context-enrichment.sh"
HAS_OLD=$(grep -cE 'NEEDS_PLAN|NEEDS_BOTH|NEEDS_RESEARCH|HAS_COMPLEX' "$CE" 2>/dev/null || true)
[ "${HAS_OLD:-0}" -eq 0 ] && pass || fail "context-enrichment still has complexity detection ($HAS_OLD matches)"
record_result "D10" "no complexity detection"

summary "L1-D: 配置一致性"
