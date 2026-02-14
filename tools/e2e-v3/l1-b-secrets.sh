#!/bin/bash
# l1-b-secrets.sh — L1-B: 密钥 + 注入 Hook 测试 (10)
# Requires: bash gen-test-inputs.sh first (pre-generates JSON with secrets)
GROUP="l1-b-secrets"; LAYER="1"; source "$(dirname "$0")/lib.sh"
json_report_start

HOOK_SECRET=".claude/hooks/security/block-secrets.sh"
HOOK_INJECT=".claude/hooks/security/scan-skill-injection.sh"
INP="/tmp/e2e-v3-inputs"

# Generate inputs if missing
[ -f "$INP/b01.json" ] || bash "$(dirname "$0")/gen-test-inputs.sh"

run_h() { OUT=$(bash "$PROJECT_DIR/$1" < "$INP/$2" 2>&1); LAST_RC=$?; }

# B01: AWS key → exit 2
begin_test "B01-aws-key"
run_h "$HOOK_SECRET" "b01.json"
assert_exit_code 2 $LAST_RC
record_result "B01" "AWS key blocked"

# B02: GitHub token → exit 2
begin_test "B02-github-token"
run_h "$HOOK_SECRET" "b02.json"
assert_exit_code 2 $LAST_RC
record_result "B02" "GitHub token blocked"

# B03: OpenAI key → exit 2
begin_test "B03-openai-key"
run_h "$HOOK_SECRET" "b03.json"
assert_exit_code 2 $LAST_RC
record_result "B03" "OpenAI key blocked"

# B04: RSA private key → exit 2
begin_test "B04-rsa-key"
run_h "$HOOK_SECRET" "b04.json"
assert_exit_code 2 $LAST_RC
record_result "B04" "RSA key blocked"

# B05: skill file with curl|bash → exit 2
begin_test "B05-skill-curl-bash"
run_h "$HOOK_INJECT" "b05.json"
assert_exit_code 2 $LAST_RC
record_result "B05" "skill curl|bash blocked"

# B06: skill file with ignore previous → exit 2
begin_test "B06-skill-ignore-previous"
run_h "$HOOK_INJECT" "b06.json"
assert_exit_code 2 $LAST_RC
record_result "B06" "skill ignore previous blocked"

# B07: skill file with <script> → exit 2
begin_test "B07-skill-script-tag"
run_h "$HOOK_INJECT" "b07.json"
assert_exit_code 2 $LAST_RC
record_result "B07" "skill script tag blocked"

# B08: non-skill file with curl|bash → exit 0
begin_test "B08-non-skill-curl-bash"
run_h "$HOOK_INJECT" "b08.json"
assert_exit_code 0 $LAST_RC
record_result "B08" "non-skill curl|bash passes"

# B09: SKILL.md missing frontmatter → WARNING
begin_test "B09-skill-no-frontmatter"
run_h "$HOOK_INJECT" "b09.json"
assert_contains "$OUT" "WARNING"
record_result "B09" "missing frontmatter warns"

# B10: DRY_RUN mode → exit 0 + DRY RUN
begin_test "B10-dry-run"
export HOOKS_DRY_RUN=true
run_h "$HOOK_SECRET" "b10.json"
assert_exit_code 0 $LAST_RC
assert_contains "$OUT" "DRY RUN"
unset HOOKS_DRY_RUN
record_result "B10" "dry run mode works"

summary "L1-B: 密钥 + 注入"
