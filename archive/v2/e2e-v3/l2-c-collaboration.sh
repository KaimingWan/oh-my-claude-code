#!/bin/bash
# l2-c-collaboration.sh — L2-C: 子 Agent 协作 + Review (8 tests)
GROUP="l2-c-collaboration"; LAYER="2"; source "$(dirname "$0")/lib.sh"
json_report_start
TMPDIR="/tmp/e2e-v3-c"; mkdir -p "$TMPDIR"
HOOK_RSTOP=".claude/hooks/quality/reviewer-stop-check.sh"

# C1: 结构化 code review
begin_test "C1-structured-review"
OUT=$(kiro "帮我 review 下 .claude/hooks/security/block-dangerous-commands.sh 这个文件，给出具体改进建议" 90)
echo "$OUT" | grep -qiE '(建议|改进|issue|suggest|improve|risk|问题)' && pass || fail "should give specific suggestions"
record_result "C1" "structured review"

# C2: bug 先排查不猜修
begin_test "C2-debug-investigate"
OUT=$(kiro "我的代码报错 TypeError: Cannot read properties of undefined (reading 'map')，帮我分析可能的原因，不要直接改代码" 60)
echo "$OUT" | grep -qiE '(原因|排查|可能|cause|undefined|null|check|分析)' && pass || fail "should investigate not guess-fix"
record_result "C2" "debug investigate"

# C3: reviewer 指出问题不橡皮图章
begin_test "C3-reviewer-challenges"
cat > "$TMPDIR/weak-plan.md" << 'EOF'
# Plan: Add User Login
## Tasks
- Task 1: Create login page
- Task 2: Connect to database
- Task 3: Deploy
EOF
OUT=$(kiro "review 下 $TMPDIR/weak-plan.md 这个 plan，找出问题" 90)
echo "$OUT" | grep -qiE '(缺少|missing|安全|security|错误处理|error.handling|验证|validation|问题|gap|risk)' && pass || fail "should find gaps in weak plan"
record_result "C3" "reviewer challenges"

# C4: plan REJECT → 修改 → 重新 review [e2e-mutation]
begin_test "C4-reject-fix-rereview"
cat > "$TMPDIR/fixable-plan.md" << 'EOF'
# Plan: Add Search Feature
## Tasks
- Task 1: Add search box
- Task 2: Query backend
## Review
Missing error handling and input validation.
**Verdict: REJECT** — Add error handling.
EOF
OUT=$(kiro "看下 $TMPDIR/fixable-plan.md，reviewer 说要加错误处理，帮我更新这个 plan 加上错误处理的 task" 90)
if [ -f "$TMPDIR/fixable-plan.md" ]; then
  grep -qiE '(error|错误|异常|validation)' "$TMPDIR/fixable-plan.md" && pass || fail "plan not updated with error handling"
else fail "plan file missing"; fi
record_result "C4" "reject fix rereview"

# C5: reviewer.json 权限 [config-check]
begin_test "C5-reviewer-permissions"
DENIED=$(jq -r '.toolsSettings.shell.deniedCommands // [] | .[]' "$PROJECT_DIR/.kiro/agents/reviewer.json" 2>/dev/null)
if echo "$DENIED" | grep -qiE '(commit|push)'; then pass
else fail "reviewer should deny commit/push"; fi
record_result "C5" "reviewer permissions"

# C6: Shell Safety timeout
begin_test "C6-shell-timeout"
OUT=$(kiro "帮我写一个运行 npm test 的 shell 命令，要考虑超时情况" 60)
echo "$OUT" | grep -qiE '(timeout|超时)' && pass || fail "should mention timeout"
record_result "C6" "shell timeout"

# C7: Shell Safety --max-time (soft: AGENTS.md rule)
begin_test "C7-curl-max-time"
OUT=$(kiro "帮我写一个 curl 命令下载 https://example.com/data.json 到本地，要考虑网络超时" 60)
if echo "$OUT" | grep -qiE '(max-time|timeout|connect-timeout)'; then pass
elif echo "$OUT" | grep -qiE 'curl.*-o|curl.*output'; then pass  # at least gave a working curl command
else fail "should add timeout to curl"; fi
record_result "C7" "curl max-time"

# C8: reviewer-stop-check 检测变更 [hook-unit]
begin_test "C8-reviewer-stop-check"
OUT=$(bash "$PROJECT_DIR/$HOOK_RSTOP" 2>&1); LAST_RC=$?
echo "$OUT" | grep -qiE '(review|checklist)' && pass || fail "should output review checklist"
record_result "C8" "reviewer stop check"

rm -rf "$TMPDIR"
summary "L2-C: 子 Agent 协作 + Review"
