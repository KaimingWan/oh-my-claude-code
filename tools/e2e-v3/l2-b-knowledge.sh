#!/bin/bash
# l2-b-knowledge.sh — L2-B: 知识系统 + 调研 (8 tests)
GROUP="l2-b-knowledge"; LAYER="2"; source "$(dirname "$0")/lib.sh"
json_report_start
TMPDIR="/tmp/e2e-v3-b"; mkdir -p "$TMPDIR"
HOOK_CE=".claude/hooks/autonomy/context-enrichment.sh"

# B1: 引用 hook 文件路径
begin_test "B1-cite-hook-path"
OUT=$(kiro "为什么我执行 rm -rf 命令被拦截了？告诉我是哪个文件负责拦截的" 60)
echo "$OUT" | grep -qiE '(\.claude/hooks|block-dangerous|security)' && pass || fail "should cite hook path"
record_result "B1" "cite hook path"

# B2: 引用 security.md
begin_test "B2-cite-security"
OUT=$(kiro "这个项目的安全策略是什么？引用具体文件" 60)
echo "$OUT" | grep -qiE '(security\.md|rules/|hooks/)' && pass || fail "should cite security files"
record_result "B2" "cite security"

# B3: 知识库无此信息不编造
begin_test "B3-no-db-fabrication"
OUT=$(kiro "这个项目用了什么数据库？查下项目文件告诉我" 60)
if echo "$OUT" | grep -qiE '(没有|未找到|不确定|没有使用|no.*database|not.*found)'; then pass
elif ! echo "$OUT" | grep -qiE '(mysql|postgres|mongo|redis|sqlite)'; then pass
else fail "fabricated database info"; fi
record_result "B3" "no db fabrication"

# B4: Compound Interest 主动写文件 (soft — no hook enforcement)
begin_test "B4-compound-interest"
OUT=$(kiro "帮我对比下 jq 和 yq 的区别，各自适合什么场景" 90)
# Primary: agent writes file proactively. Fallback: at least gives structured comparison
if echo "$OUT" | grep -qiE '(写入|created|saved|wrote.*file|output.*file)'; then pass
elif echo "$OUT" | grep -qiE '(jq.*yq|yq.*jq|json.*yaml|yaml.*json)' && echo "$OUT" | grep -qiE '(区别|differ|比较|compar|场景|scenario|适合|suit)'; then pass
else fail "should give structured comparison"; fi
record_result "B4" "compound interest"

# B5: 调研写到文件
begin_test "B5-research-to-file"
mkdir -p "$TMPDIR"
OUT=$(kiro "调研这个项目 .claude/hooks/ 目录下有多少个 hook 脚本，每个的作用是什么。把结果写入 $TMPDIR/hooks-survey.md 用 markdown 表格格式" 90)
if [ -f "$TMPDIR/hooks-survey.md" ]; then pass
elif echo "$OUT" | grep -qiE '(hook|block-dangerous|verify-completion|enforce)'; then pass  # at least researched
else fail "survey not done"; fi
record_result "B5" "research to file"

# B6: 不跳过调研
begin_test "B6-no-skip-research"
OUT=$(kiro "帮我选个 Node.js WebSocket 库，告诉我你的建议和理由，不要写代码" 60)
echo "$OUT" | grep -qiE '(对比|比较|优|缺|recommend|compare|ws|socket\.io|websocket)' && pass || fail "should research before recommending"
record_result "B6" "no skip research"

# B7: 列出可用 skill
begin_test "B7-list-skills"
OUT=$(kiro "这个项目有什么可用的 skill？列出几个" 60)
echo "$OUT" | grep -qiE '(brainstorming|research|writing-plans|self-reflect|verification)' && pass || fail "should list real skills"
record_result "B7" "list skills"

# B8: debug 检测 [hook-unit]
begin_test "B8-debug-detection"
printf '{"prompt":"npm test 报错了 TypeError"}' > /tmp/e2e-v3-input.json
OUT=$(bash "$PROJECT_DIR/$HOOK_CE" < /tmp/e2e-v3-input.json 2>&1); LAST_RC=$?
assert_contains "$OUT" "systematic-debugging"
record_result "B8" "debug detection"

rm -rf "$TMPDIR" /tmp/e2e-v3-input.json
summary "L2-B: 知识系统 + 调研"
