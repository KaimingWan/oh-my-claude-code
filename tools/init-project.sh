#!/bin/bash
# Initialize a new project with oh-my-claude-code framework
# Usage: ./init-project.sh /path/to/project [project-name]

set -e

TARGET="${1:?Usage: $0 /path/to/project [project-name]}"
PROJECT_NAME="${2:-$(basename "$TARGET")}"
TEMPLATE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -f "$TARGET/CLAUDE.md" ] || [ -f "$TARGET/AGENTS.md" ]; then
  echo "⚠️  $TARGET already has CLAUDE.md or AGENTS.md. Aborting to prevent overwrite."
  exit 1
fi

echo "🚀 Initializing: $TARGET ($PROJECT_NAME)"

mkdir -p "$TARGET"/{.claude,.kiro/rules,.kiro/hooks,.kiro/agents,knowledge,plans,tools,templates}

# Copy core files
for f in CLAUDE.md AGENTS.md; do
  cp "$TEMPLATE_DIR/$f" "$TARGET/$f"
  sed -i '' "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/$f" 2>/dev/null || \
  sed -i "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/$f"
done

# Copy framework files
cp "$TEMPLATE_DIR/.claude/settings.json" "$TARGET/.claude/"
cp "$TEMPLATE_DIR/.kiro/rules/"*.md "$TARGET/.kiro/rules/"
cp "$TEMPLATE_DIR/.kiro/hooks/"*.sh "$TARGET/.kiro/hooks/"
cp "$TEMPLATE_DIR/.kiro/agents/default.json" "$TARGET/.kiro/agents/"
cp "$TEMPLATE_DIR/knowledge/"*.md "$TARGET/knowledge/"
cp "$TEMPLATE_DIR/.gitignore" "$TARGET/" 2>/dev/null || true

chmod +x "$TARGET/.kiro/hooks/"*.sh

# Replace project name in agent config
sed -i '' "s/Default agent/$PROJECT_NAME agent/g" "$TARGET/.kiro/agents/default.json" 2>/dev/null || \
sed -i "s/Default agent/$PROJECT_NAME agent/g" "$TARGET/.kiro/agents/default.json"

echo ""
echo "✅ Done! Project initialized at: $TARGET"
echo ""
echo "📁 Structure:"
echo "  CLAUDE.md              — High-frequency recall (Claude Code)"
echo "  AGENTS.md              — High-frequency recall (Kiro CLI)"
echo "  .kiro/rules/           — Enforcement + Reference layers"
echo "  .kiro/hooks/           — Automated guardrails"
echo "  knowledge/INDEX.md     — Knowledge routing (empty, fill it in)"
echo "  plans/                 — Task plans"
echo "  tools/                 — Reusable scripts"
echo ""
echo "👉 Next: Edit CLAUDE.md to define your agent's identity and roles"
