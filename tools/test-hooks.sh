#!/bin/bash
# Test all hooks on macOS
cd /Users/wanshao/project/oh-my-claude-code

echo "=========================================="
echo "  COMPREHENSIVE HOOK TEST SUITE"
echo "=========================================="

# --- TEST 1: three-rules-check ---
echo ""
echo "=== TEST 1: three-rules-check.sh ==="
OUTPUT=$(bash .kiro/hooks/three-rules-check.sh 2>&1)
if echo "$OUTPUT" | grep -q "Iron Rules"; then
  echo "✅ PASS — 3 Iron Rules output detected"
else
  echo "❌ FAIL — no output"
fi

# --- TEST 2: enforce-skill-chain (Kiro) ---
echo ""
echo "=== TEST 2a: Kiro skill chain — planning ==="
OUTPUT=$(echo "帮我设计一个方案" | bash .kiro/hooks/enforce-skill-chain.sh 2>&1)
if echo "$OUTPUT" | grep -q "brainstorming"; then
  echo "✅ PASS — planning chain triggered"
else
  echo "❌ FAIL — planning chain NOT triggered"
fi

echo "=== TEST 2b: Kiro skill chain — completion ==="
OUTPUT=$(echo "done, merge it" | bash .kiro/hooks/enforce-skill-chain.sh 2>&1)
if echo "$OUTPUT" | grep -q "code-review-expert"; then
  echo "✅ PASS — completion chain triggered"
else
  echo "❌ FAIL — completion chain NOT triggered"
fi

echo "=== TEST 2c: Kiro skill chain — debug ==="
OUTPUT=$(echo "this bug is weird" | bash .kiro/hooks/enforce-skill-chain.sh 2>&1)
if echo "$OUTPUT" | grep -q "systematic-debugging"; then
  echo "✅ PASS — debug chain triggered"
else
  echo "❌ FAIL — debug chain NOT triggered"
fi

echo "=== TEST 2d: Kiro skill chain — no match ==="
OUTPUT=$(echo "hello world" | bash .kiro/hooks/enforce-skill-chain.sh 2>&1)
if [ -z "$OUTPUT" ]; then
  echo "✅ PASS — no false trigger"
else
  echo "❌ FAIL — false trigger: $OUTPUT"
fi

# --- TEST 3: enforce-skill-chain-cc (Claude Code) ---
echo ""
echo "=== TEST 3a: CC skill chain — planning ==="
OUTPUT=$(echo '{"prompt":"design a new feature","session_id":"t"}' | bash .kiro/hooks/enforce-skill-chain-cc.sh 2>&1)
if echo "$OUTPUT" | grep -q "brainstorming"; then
  echo "✅ PASS — CC planning chain triggered"
else
  echo "❌ FAIL — CC planning chain NOT triggered"
fi

echo "=== TEST 3b: CC skill chain — completion ==="
OUTPUT=$(echo '{"prompt":"code is done, please review","session_id":"t"}' | bash .kiro/hooks/enforce-skill-chain-cc.sh 2>&1)
if echo "$OUTPUT" | grep -q "code-review-expert"; then
  echo "✅ PASS — CC completion chain triggered"
else
  echo "❌ FAIL — CC completion chain NOT triggered"
fi

echo "=== TEST 3c: CC skill chain — debug ==="
OUTPUT=$(echo '{"prompt":"getting an error in production","session_id":"t"}' | bash .kiro/hooks/enforce-skill-chain-cc.sh 2>&1)
if echo "$OUTPUT" | grep -q "systematic-debugging"; then
  echo "✅ PASS — CC debug chain triggered"
else
  echo "❌ FAIL — CC debug chain NOT triggered"
fi

# --- TEST 4: block-dangerous-commands (Kiro) ---
echo ""
echo "=== TEST 4a: Kiro block rm ==="
OUTPUT=$(echo '{"tool_name":"execute_bash","tool_input":{"command":"rm -rf /tmp"}}' | bash .kiro/hooks/block-dangerous-commands.sh 2>&1)
RC=$?
if [ $RC -eq 2 ] && echo "$OUTPUT" | grep -q "BLOCKED"; then
  echo "✅ PASS — rm blocked (exit $RC)"
else
  echo "❌ FAIL — rm NOT blocked (exit $RC)"
fi

echo "=== TEST 4b: Kiro block git reset --hard ==="
OUTPUT=$(echo '{"tool_name":"execute_bash","tool_input":{"command":"git reset --hard HEAD"}}' | bash .kiro/hooks/block-dangerous-commands.sh 2>&1)
RC=$?
if [ $RC -eq 2 ]; then
  echo "✅ PASS — git reset --hard blocked (exit $RC)"
else
  echo "❌ FAIL — git reset --hard NOT blocked (exit $RC)"
fi

echo "=== TEST 4c: Kiro block sudo ==="
OUTPUT=$(echo '{"tool_name":"execute_bash","tool_input":{"command":"sudo apt install foo"}}' | bash .kiro/hooks/block-dangerous-commands.sh 2>&1)
RC=$?
if [ $RC -eq 2 ]; then
  echo "✅ PASS — sudo blocked (exit $RC)"
else
  echo "❌ FAIL — sudo NOT blocked (exit $RC)"
fi

echo "=== TEST 4d: Kiro allow safe ==="
OUTPUT=$(echo '{"tool_name":"execute_bash","tool_input":{"command":"ls -la"}}' | bash .kiro/hooks/block-dangerous-commands.sh 2>&1)
RC=$?
if [ $RC -eq 0 ]; then
  echo "✅ PASS — safe command allowed (exit $RC)"
else
  echo "❌ FAIL — safe command blocked (exit $RC)"
fi

echo "=== TEST 4e: Kiro skip non-bash ==="
OUTPUT=$(echo '{"tool_name":"fs_write","tool_input":{"command":"rm -rf /"}}' | bash .kiro/hooks/block-dangerous-commands.sh 2>&1)
RC=$?
if [ $RC -eq 0 ]; then
  echo "✅ PASS — non-bash tool skipped (exit $RC)"
else
  echo "❌ FAIL — non-bash tool incorrectly blocked (exit $RC)"
fi

# --- TEST 5: block-dangerous-commands-cc (Claude Code) ---
echo ""
echo "=== TEST 5a: CC block rm ==="
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp"}}' | bash .kiro/hooks/block-dangerous-commands-cc.sh 2>&1)
RC=$?
if [ $RC -eq 2 ]; then
  echo "✅ PASS — CC rm blocked (exit $RC)"
else
  echo "❌ FAIL — CC rm NOT blocked (exit $RC)"
fi

echo "=== TEST 5b: CC allow safe ==="
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' | bash .kiro/hooks/block-dangerous-commands-cc.sh 2>&1)
RC=$?
if [ $RC -eq 0 ]; then
  echo "✅ PASS — CC safe command allowed (exit $RC)"
else
  echo "❌ FAIL — CC safe command blocked (exit $RC)"
fi

# --- TEST 6: enforce-research (anti-hallucination) ---
echo ""
echo "=== TEST 6a: Anti-hallucination — negative claim ==="
OUTPUT=$(echo '{"tool_name":"fs_write","tool_input":{"new_str":"This platform has no mechanism for hooks"}}' | bash .kiro/hooks/enforce-research.sh 2>&1)
if echo "$OUTPUT" | grep -q "Negative claim"; then
  echo "✅ PASS — negative claim caught"
else
  echo "❌ FAIL — negative claim NOT caught"
fi

echo "=== TEST 6b: Anti-hallucination — safe write ==="
OUTPUT=$(echo '{"tool_name":"fs_write","tool_input":{"new_str":"This function returns a list of users"}}' | bash .kiro/hooks/enforce-research.sh 2>&1)
if [ -z "$OUTPUT" ]; then
  echo "✅ PASS — safe write allowed"
else
  echo "⚠️  INFO — output: $OUTPUT"
fi

# --- TEST 7: enforce-lessons (stop hook) ---
echo ""
echo "=== TEST 7: Lessons check ==="
OUTPUT=$(bash .kiro/hooks/enforce-lessons.sh 2>&1)
if echo "$OUTPUT" | grep -q "Lessons Check"; then
  echo "✅ PASS — lessons reminder output"
else
  echo "❌ FAIL — no lessons reminder"
fi

# --- TEST 8: Skills parity ---
echo ""
echo "=== TEST 8: Skills parity ==="
KIRO_COUNT=$(ls .kiro/skills/ | wc -l | tr -d ' ')
CC_COUNT=$(ls .claude/skills/ | wc -l | tr -d ' ')
DIFF=$(diff <(ls .kiro/skills/ | sort) <(ls .claude/skills/ | sort))
if [ "$KIRO_COUNT" = "$CC_COUNT" ] && [ -z "$DIFF" ]; then
  echo "✅ PASS — $KIRO_COUNT skills, identical on both platforms"
else
  echo "❌ FAIL — Kiro: $KIRO_COUNT, CC: $CC_COUNT"
fi

# --- TEST 9: CLAUDE.md = AGENTS.md ---
echo ""
echo "=== TEST 9: CLAUDE.md = AGENTS.md ==="
DIFF=$(diff CLAUDE.md AGENTS.md)
if [ -z "$DIFF" ]; then
  echo "✅ PASS — files identical"
else
  echo "❌ FAIL — files differ"
fi

# --- TEST 10: JSON configs valid ---
echo ""
echo "=== TEST 10: Config validity ==="
if python3 -m json.tool .kiro/agents/default.json > /dev/null 2>&1; then
  echo "✅ PASS — .kiro/agents/default.json valid"
else
  echo "❌ FAIL — .kiro/agents/default.json invalid"
fi
if python3 -m json.tool .claude/settings.json > /dev/null 2>&1; then
  echo "✅ PASS — .claude/settings.json valid"
else
  echo "❌ FAIL — .claude/settings.json invalid"
fi

# --- TEST 11: All hooks executable ---
echo ""
echo "=== TEST 11: Hook permissions ==="
ALL_EXEC=true
for f in .kiro/hooks/*.sh; do
  if [ ! -x "$f" ]; then
    echo "❌ FAIL — $f not executable"
    ALL_EXEC=false
  fi
done
if $ALL_EXEC; then
  echo "✅ PASS — all hooks executable"
fi

# --- TEST 12: Skills have SKILL.md ---
echo ""
echo "=== TEST 12: All skills have SKILL.md ==="
MISSING=0
for d in .kiro/skills/*/; do
  name=$(basename "$d")
  if [ ! -f "$d/SKILL.md" ]; then
    echo "❌ FAIL — $name missing SKILL.md"
    MISSING=$((MISSING+1))
  fi
done
if [ $MISSING -eq 0 ]; then
  echo "✅ PASS — all $KIRO_COUNT skills have SKILL.md"
fi

# --- TEST 13: Layer 2 budget ---
echo ""
echo "=== TEST 13: Layer 2 line budget (≤200) ==="
LINES=$(wc -l < CLAUDE.md | tr -d ' ')
if [ "$LINES" -le 200 ]; then
  echo "✅ PASS — $LINES lines (budget: 200)"
else
  echo "❌ FAIL — $LINES lines exceeds 200 budget"
fi

# --- TEST 14: Knowledge system ---
echo ""
echo "=== TEST 14: Knowledge system ==="
if [ -f knowledge/INDEX.md ] && [ -f knowledge/lessons-learned.md ]; then
  echo "✅ PASS — INDEX.md and lessons-learned.md exist"
else
  echo "❌ FAIL — knowledge files missing"
fi

echo ""
echo "=========================================="
echo "  TEST SUITE COMPLETE"
echo "=========================================="
