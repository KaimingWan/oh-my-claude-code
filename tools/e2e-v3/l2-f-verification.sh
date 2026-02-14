#!/bin/bash
# l2-f-verification.sh — L2-F: Verification + 沉淀 (8 tests)
GROUP="l2-f-verification"; LAYER="2"; source "$(dirname "$0")/lib.sh"
json_report_start
TMPDIR="/tmp/e2e-v3-f"; mkdir -p "$TMPDIR"
HOOK_VC=".claude/hooks/quality/verify-completion.sh"

# F1: 创建文件后验证
begin_test "F1-create-and-verify"
OUT=$(kiro "创建 $TMPDIR/hello.txt 写入 hello world，然后验证文件确实存在且内容正确" 90)
[ -f "$TMPDIR/hello.txt" ] && pass || fail "file not created"
record_result "F1" "create and verify"

# F2: 修改 JSON 用 jq
begin_test "F2-json-use-jq"
echo '{"version":"1.0.0","name":"test"}' > "$TMPDIR/data.json"
OUT=$(kiro "帮我把 $TMPDIR/data.json 的 version 改成 2.0.0" 90)
if [ -f "$TMPDIR/data.json" ]; then
  VER=$(jq -r '.version' "$TMPDIR/data.json" 2>/dev/null)
  [ "$VER" = "2.0.0" ] && pass || fail "version=$VER, expected 2.0.0"
else fail "json file missing"; fi
record_result "F2" "json use jq"

# F3: verify-completion criteria 未完成 → INCOMPLETE [hook-unit]
begin_test "F3-criteria-incomplete"
ORIG_CRITERIA=""
[ -f "$PROJECT_DIR/.completion-criteria.md" ] && ORIG_CRITERIA=$(cat "$PROJECT_DIR/.completion-criteria.md")
cat > "$PROJECT_DIR/.completion-criteria.md" << 'EOF'
# Test
- [x] Done item
- [ ] Undone item
EOF
OUT=$(bash "$PROJECT_DIR/$HOOK_VC" 2>&1); LAST_RC=$?
assert_contains "$OUT" "INCOMPLETE"
# Restore original or remove
if [ -n "$ORIG_CRITERIA" ]; then
  echo "$ORIG_CRITERIA" > "$PROJECT_DIR/.completion-criteria.md"
else
  mv "$PROJECT_DIR/.completion-criteria.md" ~/.Trash/ 2>/dev/null
fi
record_result "F3" "criteria incomplete"

# F4: verify-completion 有源码变更 → 提醒 code review [hook-unit]
# Note: temporarily override npm test to pass, so hook reaches Phase C
begin_test "F4-code-review-reminder"
[ -f "$PROJECT_DIR/.completion-criteria.md" ] && mv "$PROJECT_DIR/.completion-criteria.md" "$TMPDIR/criteria-f4.bak"
backup_file "$PROJECT_DIR/package.json"
jq '.scripts.test = "echo ok"' "$PROJECT_DIR/package.json" > "$TMPDIR/pkg.json" && mv "$TMPDIR/pkg.json" "$PROJECT_DIR/package.json"
OUT=$(bash "$PROJECT_DIR/$HOOK_VC" 2>&1); LAST_RC=$?
restore_file "$PROJECT_DIR/package.json"
[ -f "$TMPDIR/criteria-f4.bak" ] && mv "$TMPDIR/criteria-f4.bak" "$PROJECT_DIR/.completion-criteria.md"
echo "$OUT" | grep -qiE '(code review|review|Feedback)' && pass || fail "should remind code review"
record_result "F4" "code review reminder"

# F5: verify-completion 纠正 flag + lessons 未变更 → MANDATORY [hook-unit]
# Must stash so REFLECT_CHANGED=0 (git diff has lessons-learned/AGENTS changes)
# and also so CHANGED=0 → hook skips Phase C entirely. So we need at least 1 changed file.
# Strategy: stash, create a dummy source change, set flag, run hook, restore.
begin_test "F5-correction-mandatory"
[ -f "$PROJECT_DIR/.completion-criteria.md" ] && mv "$PROJECT_DIR/.completion-criteria.md" "$TMPDIR/criteria-f5.bak"
cd "$PROJECT_DIR" && git stash -q 2>/dev/null; STASHED=$?
# After stash, make npm test pass and create a dummy source change
jq '.scripts.test = "echo ok"' "$PROJECT_DIR/package.json" > "$TMPDIR/pkg.json" && mv "$TMPDIR/pkg.json" "$PROJECT_DIR/package.json"
echo "// dummy" >> "$PROJECT_DIR/tools/e2e-v3/lib.sh"
FLAG="/tmp/kiro-correction-$(cd "$PROJECT_DIR" && pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default').flag"
touch "$FLAG"
OUT=$(bash "$PROJECT_DIR/$HOOK_VC" 2>&1); LAST_RC=$?
rm -f "$FLAG"
git checkout -- "$PROJECT_DIR/package.json" "$PROJECT_DIR/tools/e2e-v3/lib.sh" 2>/dev/null
[ "$STASHED" -eq 0 ] && git stash pop -q 2>/dev/null
[ -f "$TMPDIR/criteria-f5.bak" ] && mv "$TMPDIR/criteria-f5.bak" "$PROJECT_DIR/.completion-criteria.md"
echo "$OUT" | grep -qiE 'MANDATORY' && pass || fail "should show MANDATORY"
record_result "F5" "correction mandatory"

# F6: 大需求先确认拆分
begin_test "F6-large-request-split"
OUT=$(kiro "帮我做以下 5 个需求：1.用户注册 2.用户登录 3.密码重置 4.邮箱验证 5.OAuth集成。你觉得应该怎么安排？" 60)
echo "$OUT" | grep -qiE '(拆分|优先|顺序|phase|priority|split|先.*后|步骤)' && pass || fail "should suggest splitting"
record_result "F6" "large request split"

# F7: 实现函数提到测试
begin_test "F7-mention-tests"
OUT=$(kiro "帮我实现一个 add(a,b) 函数，用 Python 写。你会怎么确保它是正确的？" 60)
echo "$OUT" | grep -qiE '(test|测试|pytest|unittest|assert|verify|验证)' && pass || fail "should mention tests"
record_result "F7" "mention tests"

# F8: 模糊 bug 先追问
begin_test "F8-vague-bug-ask"
OUT=$(kiro "页面有时候白屏，帮我看看" 60)
echo "$OUT" | grep -qiE '(什么时候|哪个页面|复现|频率|浏览器|日志|console|when|which|reproduce|log|more info|详细)' && pass || fail "should ask for more info"
record_result "F8" "vague bug ask"

rm -rf "$TMPDIR" /tmp/kiro-correction-*.flag
summary "L2-F: Verification + 沉淀"
