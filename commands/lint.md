Run these health checks and report results:

## 1. CLAUDE.md Line Count
```bash
LINES=$(wc -l < CLAUDE.md | tr -d ' ')
[ "$LINES" -lt 500 ] && echo "✅ CLAUDE.md: $LINES lines (< 500)" || echo "❌ CLAUDE.md: $LINES lines (≥ 500 — trim it)"
```

## 2. .claude/rules/ File Sizes
```bash
for f in .claude/rules/*.md; do
  LINES=$(wc -l < "$f" | tr -d ' ')
  NAME=$(basename "$f")
  [ "$LINES" -lt 200 ] && echo "✅ $NAME: $LINES lines" || echo "❌ $NAME: $LINES lines (≥ 200)"
done
```

## 3. Layer Headers
```bash
for f in .claude/rules/*.md; do
  NAME=$(basename "$f")
  grep -q 'Layer: Agent Rule' "$f" && echo "✅ $NAME has header" || echo "❌ $NAME missing Layer header"
done
```

## 4. CLAUDE.md / AGENTS.md Sync
```bash
diff CLAUDE.md AGENTS.md && echo "✅ CLAUDE.md and AGENTS.md in sync" || echo "❌ CLAUDE.md and AGENTS.md out of sync — run: cp CLAUDE.md AGENTS.md"
```

## 5. Duplication Check
```bash
DUPS=0
for f in .claude/rules/*.md; do
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | grep -q '^#' && continue
    if grep -qF "$line" knowledge/rules.md 2>/dev/null; then
      echo "⚠️ Duplicate: $line"
      DUPS=$((DUPS + 1))
    fi
  done < "$f"
done
[ "$DUPS" -eq 0 ] && echo "✅ No verbatim duplication" || echo "❌ $DUPS duplicated lines between .claude/rules/ and knowledge/rules.md"
```

Report all results. If any ❌, list recommended fixes.
