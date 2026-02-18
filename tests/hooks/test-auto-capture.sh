#!/bin/bash

HOOK="hooks/feedback/auto-capture.sh"
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
mkdir -p knowledge
cp "$OLDPWD/$HOOK" .

# Test 1: Gate 1 — question filtered
echo "knowledge/episodes.md" > knowledge/episodes.md
bash auto-capture.sh "what is this?"
[ $? -eq 1 ] && echo "✓ Test 1 passed" || echo "✗ Test 1 failed"

# Test 2: Gate 1 — no action keyword filtered
bash auto-capture.sh "hello world good morning"
[ $? -eq 1 ] && echo "✓ Test 2 passed" || echo "✗ Test 2 failed"

# Test 3: Gate 2 — no English keywords filtered
bash auto-capture.sh "必须这样做"
[ $? -eq 1 ] && echo "✓ Test 3 passed" || echo "✗ Test 3 failed"

# Test 4: Happy path — capture written
echo "knowledge/episodes.md" > knowledge/episodes.md
echo "knowledge/rules.md" > knowledge/rules.md
BEFORE=$(wc -l < knowledge/episodes.md)
bash auto-capture.sh "don't use subprocess always use pathlib"
[ $? -eq 0 ] && AFTER=$(wc -l < knowledge/episodes.md) && [ $AFTER -gt $BEFORE ] && grep -q "$(date +%Y-%m-%d)" knowledge/episodes.md && echo "✓ Test 4 passed" || echo "✗ Test 4 failed"

# Test 5: Gate 3 — duplicate skipped
echo "2024-01-01 | active | subprocess | test" >> knowledge/episodes.md
BEFORE=$(wc -l < knowledge/episodes.md)
bash auto-capture.sh "don't use subprocess always use pathlib"
[ $? -eq 0 ] && AFTER=$(wc -l < knowledge/episodes.md) && [ $AFTER -eq $BEFORE ] && echo "✓ Test 5 passed" || echo "✗ Test 5 failed"

# Test 6: Gate 4 — capacity check
echo "knowledge/episodes.md" > knowledge/episodes.md
for i in {1..30}; do echo "2024-01-0$((i%9+1)) | active | test$i | test" >> knowledge/episodes.md; done
BEFORE=$(wc -l < knowledge/episodes.md)
bash auto-capture.sh "never use eval always use literal"
[ $? -eq 0 ] && AFTER=$(wc -l < knowledge/episodes.md) && [ $AFTER -eq $BEFORE ] && echo "✓ Test 6 passed" || echo "✗ Test 6 failed"

cd "$OLDPWD"
rm -rf "$TEMP_DIR"