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

mkdir -p "$TARGET"/{.claude,.kiro/rules,.kiro/agents,knowledge/product,docs/{designs,plans,research,decisions},tools,templates}

# Copy core files
for f in CLAUDE.md AGENTS.md; do
  cp "$TEMPLATE_DIR/$f" "$TARGET/$f"
  sed -i '' "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/$f" 2>/dev/null || \
  sed -i "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/$f"
done

# Copy framework files
cp "$TEMPLATE_DIR/.claude/settings.json" "$TARGET/.claude/"
cp "$TEMPLATE_DIR/.kiro/rules/"*.md "$TARGET/.kiro/rules/"
# Copy hooks (preserving subdirectory structure)
cp -r "$TEMPLATE_DIR/hooks" "$TARGET/hooks"
ln -sf ../hooks "$TARGET/.kiro/hooks"
ln -sf ../hooks "$TARGET/.claude/hooks"
cp "$TEMPLATE_DIR/.kiro/agents/"*.json "$TARGET/.kiro/agents/"
cp "$TEMPLATE_DIR/knowledge/"*.md "$TARGET/knowledge/"
cp -r "$TEMPLATE_DIR/knowledge/product" "$TARGET/knowledge/"
cp "$TEMPLATE_DIR/docs/INDEX.md" "$TARGET/docs/"
for d in designs plans research decisions; do
  touch "$TARGET/docs/$d/.gitkeep"
done
cp "$TEMPLATE_DIR/.gitignore" "$TARGET/" 2>/dev/null || true

# Copy skills (preserving structure, symlinked like hooks)
if [ -d "$TEMPLATE_DIR/skills" ]; then
  cp -r "$TEMPLATE_DIR/skills" "$TARGET/skills"
  ln -sf ../skills "$TARGET/.kiro/skills"
  ln -sf ../skills "$TARGET/.claude/skills"
  SKILL_COUNT=$(ls -d "$TARGET/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
  echo "📦 Copied $SKILL_COUNT skills"
fi

# Replace project name in agent config (use jq for JSON)
jq --arg name "$PROJECT_NAME agent" '.description = $name' "$TARGET/.kiro/agents/pilot.json" > "$TARGET/.kiro/agents/pilot.json.tmp" && \
mv "$TARGET/.kiro/agents/pilot.json.tmp" "$TARGET/.kiro/agents/pilot.json"

echo ""
echo "✅ Done! Project initialized at: $TARGET"
echo ""
echo "📁 Structure:"
echo "  CLAUDE.md              — High-frequency recall (Claude Code)"
echo "  AGENTS.md              — High-frequency recall (Kiro CLI)"
echo "  .kiro/rules/           — Enforcement + Reference layers"
echo "  .kiro/hooks/           — Automated guardrails"
echo "  .kiro/skills/          — $SKILL_COUNT pre-installed skills"
echo "  knowledge/INDEX.md     — Knowledge routing (empty, fill it in)"
echo "  knowledge/product/     — Product map (features, constraints)"
echo "  docs/                  — Designs, plans, research, decisions"
echo "  tools/                 — Reusable scripts"
echo ""
echo "👉 Next: Edit CLAUDE.md to define your agent's identity and roles"
