#!/bin/bash
# l1-c-workflow.sh — L1-C: 流程 + 质量 Hook 测试 (10)
# Hook: enforce-skill-chain.sh + verify-completion.sh + context-enrichment.sh
GROUP="l1-c-workflow"; LAYER="1"; source "$(dirname "$0")/lib.sh"
json_report_start

HOOK_CHAIN=".claude/hooks/quality/enforce-skill-chain.sh"
TMPDIR_C="/tmp/e2e-v3-l1c"
mkdir -p "$TMPDIR_C"

mk_create_json() { jq -nc --arg f "$1" '{"tool_name":"fs_write","tool_input":{"command":"create","file_path":$f,"file_text":"content"}}' > /tmp/e2e-v3-input-c.dat; }
mk_edit_json() { jq -nc --arg f "$1" '{"tool_name":"fs_write","tool_input":{"command":"str_replace","file_path":$f,"old_str":"a","new_str":"b"}}' > /tmp/e2e-v3-input-c.dat; }
run_h() { OUT=$(bash "$PROJECT_DIR/$1" < /tmp/e2e-v3-input-c.dat 2>&1); LAST_RC=$?; }

# C01: no plan, create source file → exit 2
begin_test "C01-no-plan-source"
mv "$PROJECT_DIR/docs/plans" "$TMPDIR_C/plans-bak" 2>/dev/null
mv "$PROJECT_DIR/.skip-plan" "$TMPDIR_C/skip-bak" 2>/dev/null
mv "$PROJECT_DIR/.completion-criteria.md" "$TMPDIR_C/criteria-bak" 2>/dev/null
mk_create_json 'src/new.ts'
run_h "$HOOK_CHAIN"
assert_exit_code 2 $LAST_RC
mv "$TMPDIR_C/plans-bak" "$PROJECT_DIR/docs/plans" 2>/dev/null
mv "$TMPDIR_C/skip-bak" "$PROJECT_DIR/.skip-plan" 2>/dev/null
mv "$TMPDIR_C/criteria-bak" "$PROJECT_DIR/.completion-criteria.md" 2>/dev/null
record_result "C01" "no plan blocks source create"

# C02: test file → exit 0 (TDD whitelist)
begin_test "C02-test-file-allowed"
mk_create_json 'src/new.test.ts'
run_h "$HOOK_CHAIN"
assert_exit_code 0 $LAST_RC
record_result "C02" "test file passes"

# C03: str_replace (edit) → exit 0
begin_test "C03-edit-passes"
mk_edit_json 'src/existing.ts'
run_h "$HOOK_CHAIN"
assert_exit_code 0 $LAST_RC
record_result "C03" "edit passes through"

# C04: .skip-plan exists → exit 0
begin_test "C04-skip-plan"
touch "$PROJECT_DIR/.skip-plan"
mk_create_json 'src/new.ts'
run_h "$HOOK_CHAIN"
assert_exit_code 0 $LAST_RC
rm -f "$PROJECT_DIR/.skip-plan"
record_result "C04" "skip-plan bypasses"

# C05: plan + Review APPROVE → exit 0
begin_test "C05-plan-approve"
PLAN="$PROJECT_DIR/docs/plans/e2e-test-c05.md"
cat > "$PLAN" << 'EOF'
# Test Plan C05
## Review
Reviewed independently.
Found no issues with the plan.
All tasks are well-defined.
**Verdict: APPROVE** — Plan is solid.
EOF
sleep 1  # ensure newest mtime
touch "$PLAN"
mk_create_json 'src/feature.ts'
run_h "$HOOK_CHAIN"
assert_exit_code 0 $LAST_RC
rm -f "$PLAN"
record_result "C05" "plan+approve passes"

# C06: plan + Review REJECT → exit 2
begin_test "C06-plan-reject"
PLAN="$PROJECT_DIR/docs/plans/e2e-test-c06.md"
cat > "$PLAN" << 'EOF'
# Test Plan C06
## Review
Reviewed independently.
Found critical issues.
Missing error handling.
**Verdict: REJECT** — Must fix before proceeding.
EOF
touch "$PLAN"
mk_create_json 'src/feature.ts'
run_h "$HOOK_CHAIN"
assert_exit_code 2 $LAST_RC
assert_contains "$OUT" "REJECT"
rm -f "$PLAN"
record_result "C06" "plan+reject blocks"

# C07: plan + Review CONDITIONAL → exit 2
begin_test "C07-plan-conditional"
PLAN="$PROJECT_DIR/docs/plans/e2e-test-c07.md"
cat > "$PLAN" << 'EOF'
# Test Plan C07
## Review
Reviewed independently.
Some concerns noted.
Needs minor fixes.
**Verdict: CONDITIONAL APPROVE** — Fix issues first.
EOF
touch "$PLAN"
mk_create_json 'src/feature.ts'
run_h "$HOOK_CHAIN"
assert_exit_code 2 $LAST_RC
assert_contains "$OUT" "CONDITIONAL"
rm -f "$PLAN"
record_result "C07" "plan+conditional blocks"

# C08: plan exists but no Review section → exit 2
begin_test "C08-plan-no-review"
PLAN="$PROJECT_DIR/docs/plans/e2e-test-c08.md"
cat > "$PLAN" << 'EOF'
# Test Plan C08
## Tasks
- Task 1: Do something
EOF
touch "$PLAN"
mk_create_json 'src/feature.ts'
run_h "$HOOK_CHAIN"
assert_exit_code 2 $LAST_RC
assert_contains "$OUT" "reviewer has not reviewed"
rm -f "$PLAN"
record_result "C08" "no review blocks"

# C09: create plan file itself → exit 0 (whitelist)
begin_test "C09-plan-file-whitelist"
mk_create_json 'docs/plans/new-plan.md'
run_h "$HOOK_CHAIN"
assert_exit_code 0 $LAST_RC
record_result "C09" "plan file whitelisted"

# C10: create .kiro/prompts/ file → exit 0 (whitelist)
begin_test "C10-prompt-file-whitelist"
mk_create_json '.kiro/prompts/test.md'
run_h "$HOOK_CHAIN"
assert_exit_code 0 $LAST_RC
record_result "C10" "prompt file whitelisted"

rm -f /tmp/e2e-v3-input-c.dat

# Cleanup
rm -rf "$TMPDIR_C"

summary "L1-C: 流程 + 质量"
