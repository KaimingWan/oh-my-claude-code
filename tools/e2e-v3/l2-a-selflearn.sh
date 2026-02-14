#!/bin/bash
# l2-a-selflearn.sh — L2-A: 自进化 + 召回 (8 tests)
GROUP="l2-a-selflearn"; LAYER="2"; source "$(dirname "$0")/lib.sh"
json_report_start
TMPDIR="/tmp/e2e-v3-a"; mkdir -p "$TMPDIR"
HOOK_CE=".claude/hooks/autonomy/context-enrichment.sh"

# A1: 纠正后写入 lessons
begin_test "A1-correction-writes-lessons"
BEFORE=$(wc -l < "$PROJECT_DIR/knowledge/lessons-learned.md")
OUT=$(kiro "你搞错了，应该用 jq 不是 sed 来处理 JSON 文件。记住这个教训写入 knowledge/lessons-learned.md" 90)
AFTER=$(wc -l < "$PROJECT_DIR/knowledge/lessons-learned.md")
[ "$AFTER" -gt "$BEFORE" ] && pass || fail "lessons not updated ($BEFORE→$AFTER)"
record_result "A1" "correction writes lessons"

# A2: Lessons 召回 stat -f
begin_test "A2-recall-stat-f"
OUT=$(kiro "写一个 shell 命令获取 README.md 的最后修改时间，只给我命令不要解释" 60)
if echo "$OUT" | grep -qiE 'stat.*-f'; then pass
elif echo "$OUT" | grep -qiE 'stat' && ! echo "$OUT" | grep -qiE 'stat.*-c'; then pass
else fail "should use stat -f not stat -c"; fi
record_result "A2" "recall stat -f"

# A3: Lessons 召回 jq
begin_test "A3-recall-jq"
OUT=$(kiro "帮我把 package.json 里的 version 字段改成 3.0.0，告诉我用什么命令" 60)
echo "$OUT" | grep -qiE 'jq' && pass || fail "should suggest jq"
record_result "A3" "recall jq"

# A4: 不存在的 lessons 不编造
begin_test "A4-no-fabrication"
OUT=$(kiro "我们之前在 Kubernetes 部署上踩过什么坑？查下 knowledge/lessons-learned.md" 60)
if echo "$OUT" | grep -qiE '(没有|未找到|不确定|no.*found|没有相关|没有记录)'; then pass
elif ! echo "$OUT" | grep -qiE 'kubernetes.*坑|k8s.*问题'; then pass
else fail "fabricated k8s lessons"; fi
record_result "A4" "no fabrication"

# A5: 正面反馈不触发纠正
begin_test "A5-positive-no-correction"
OUT=$(kiro "很好，这个方案不错，继续保持" 30)
echo "$OUT" | grep -qiE 'CORRECTION' && fail "positive triggered correction" || pass
record_result "A5" "positive no correction"

# A6: 纠正后继续原任务
begin_test "A6-correction-continues"
OUT=$(kiro "帮我创建 $TMPDIR/hello.txt 写入 hello world。注意：别用 echo，用 printf" 90)
[ -f "$TMPDIR/hello.txt" ] && pass || fail "file not created"
record_result "A6" "correction continues task"

# A7: 查 lessons 引用具体条目
begin_test "A7-query-lessons"
OUT=$(kiro "查下 knowledge/lessons-learned.md 我们之前犯过什么错，列出 2-3 个具体条目" 60)
echo "$OUT" | grep -qiE '(sed.*json|stat|框架升级|reviewer|纠正)' && pass || fail "should cite real entries"
record_result "A7" "query lessons"

# A8: context-enrichment 纠正检测 [hook-unit]
begin_test "A8-correction-detection"
printf '{"prompt":"你错了，应该用另一种方式"}' > /tmp/e2e-v3-input.json
OUT=$(bash "$PROJECT_DIR/$HOOK_CE" < /tmp/e2e-v3-input.json 2>&1); LAST_RC=$?
assert_contains "$OUT" "CORRECTION DETECTED"
record_result "A8" "correction detection"

rm -rf "$TMPDIR" /tmp/e2e-v3-input.json /tmp/kiro-correction-*.flag
summary "L2-A: 自进化 + 召回"
