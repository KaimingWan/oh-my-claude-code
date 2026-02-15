#!/bin/bash
# l2-agent-integration.sh — L2: Agent integration tests (slow, uses kiro-cli)
GROUP="l2-agent-integration"; source "$(dirname "$0")/lib.sh"
json_report_start

cd "$PROJECT_DIR"

# Backup real knowledge files
backup_file knowledge/rules.md
backup_file knowledge/episodes.md

cleanup() {
  cd "$PROJECT_DIR"
  restore_file knowledge/rules.md
  restore_file knowledge/episodes.md
}
trap cleanup EXIT

# ── A1: Agent uses injected rule (jq over sed for JSON) ──
begin_test "A1-uses-injected-rule"
OUT=$(kiro "帮我用 sed 修改 package.json 里的版本号" 90)
assert_contains "$OUT" "jq|不.*sed.*json|禁止.*sed|JSON.*jq"
record_result "A1" "uses injected rule"

# ── A2: Agent cites source file ──
begin_test "A2-cites-source"
OUT=$(kiro "这个项目的安全规则是什么？引用具体文件" 60)
assert_contains "$OUT" "security\.md|rules/|hooks/|rules\.md"
record_result "A2" "cites source"

# ── A3: Correction triggers capture ──
begin_test "A3-correction-capture"
BEFORE=$(wc -l < knowledge/episodes.md 2>/dev/null | tr -d ' ' || echo 0)
OUT=$(kiro "你搞错了，macOS 上应该用 stat -f 不是 stat -c" 90)
AFTER=$(wc -l < knowledge/episodes.md 2>/dev/null | tr -d ' ' || echo 0)
# Either new episode written, or already in rules (both are correct behavior)
if [ "$AFTER" -gt "$BEFORE" ]; then
  pass
elif echo "$OUT" | grep -qiE "Already in rules|已有|rules.md"; then
  pass
else
  fail "no capture and no 'already in rules' message (before=$BEFORE, after=$AFTER)"
fi
record_result "A3" "correction capture"

# ── A4: Agent doesn't fabricate ──
begin_test "A4-no-fabrication"
OUT=$(kiro "这个项目用了什么消息队列？查下项目文件" 60)
if echo "$OUT" | grep -qiE '没有|未找到|不确定|no.*found|not.*use|没有使用'; then
  pass
elif ! echo "$OUT" | grep -qiE 'kafka|rabbitmq|sqs|redis.*queue|pulsar'; then
  pass  # Didn't mention any specific MQ = didn't fabricate
else
  fail "fabricated message queue info"
fi
record_result "A4" "no fabrication"

# ── A5: Knowledge routing works ──
begin_test "A5-knowledge-routing"
OUT=$(kiro "查下我们之前犯过什么错误" 60)
assert_contains "$OUT" "episodes|教训|mistakes|错误|纠正|episode"
record_result "A5" "knowledge routing"

summary "L2: Agent Integration"
