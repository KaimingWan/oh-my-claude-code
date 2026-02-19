#!/bin/bash
# Initialize a new project with oh-my-claude-code framework
# Usage: ./init-project.sh /path/to/project [project-name] [--type coding|gtm]

set -e

# ── Argument parsing ─────────────────────────────────────────────────────────
TARGET=""
PROJECT_NAME=""
PROJECT_TYPE="coding"

while [ $# -gt 0 ]; do
  case "$1" in
    --type)
      PROJECT_TYPE="${2:?--type requires an argument (coding|gtm)}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [ -z "$TARGET" ]; then
        TARGET="$1"
      elif [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME="$1"
      else
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "Usage: $0 /path/to/project [project-name] [--type coding|gtm]" >&2
  exit 1
fi

PROJECT_NAME="${PROJECT_NAME:-$(basename "$TARGET")}"
TEMPLATE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Validate --type value
case "$PROJECT_TYPE" in
  coding|gtm) ;;
  *)
    echo "Unknown --type: $PROJECT_TYPE. Valid values: coding, gtm" >&2
    exit 1
    ;;
esac

if [ -f "$TARGET/CLAUDE.md" ] || [ -f "$TARGET/AGENTS.md" ]; then
  echo "⚠️  $TARGET already has CLAUDE.md or AGENTS.md. Aborting to prevent overwrite."
  exit 1
fi

echo "🚀 Initializing: $TARGET ($PROJECT_NAME) [type=$PROJECT_TYPE]"

mkdir -p "$TARGET"/{.claude,.kiro/rules,.kiro/agents,knowledge/product,docs/{designs,plans,research,decisions},tools,templates}

# ── Copy CLAUDE.md ────────────────────────────────────────────────────────────
cp "$TEMPLATE_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"
sed -i '' "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/CLAUDE.md" 2>/dev/null || \
sed -i "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/CLAUDE.md"

# ── Assemble AGENTS.md ────────────────────────────────────────────────────────
SECTIONS_DIR="$TEMPLATE_DIR/templates/agents-sections"
TYPES_DIR="$TEMPLATE_DIR/templates/agents-types"
TYPE_TEMPLATE="$TYPES_DIR/$PROJECT_TYPE.md"

if [ -d "$SECTIONS_DIR" ] && [ -f "$TYPE_TEMPLATE" ]; then
  # Assemble: type template + each section listed in OMCC SECTIONS comment
  # Parse "<!-- OMCC SECTIONS: a b c -->" from type template
  SECTIONS_LINE=$(grep "OMCC SECTIONS:" "$TYPE_TEMPLATE" | head -1)
  SECTION_NAMES=$(echo "$SECTIONS_LINE" | sed 's/.*OMCC SECTIONS: *//;s/ *-->.*//')

  # Start with type template content (strip the OMCC SECTIONS marker line)
  grep -v "OMCC SECTIONS:" "$TYPE_TEMPLATE" > "$TARGET/AGENTS.md"

  # Append each section
  for section in $SECTION_NAMES; do
    section_file="$SECTIONS_DIR/$section.md"
    if [ -f "$section_file" ]; then
      echo "" >> "$TARGET/AGENTS.md"
      cat "$section_file" >> "$TARGET/AGENTS.md"
    fi
  done

  # Substitute project name
  sed -i '' "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/AGENTS.md" 2>/dev/null || \
  sed -i "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/AGENTS.md"

else
  # Fallback: templates/ not found — copy plain AGENTS.md as before
  cp "$TEMPLATE_DIR/AGENTS.md" "$TARGET/AGENTS.md"
  sed -i '' "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/AGENTS.md" 2>/dev/null || \
  sed -i "s/\[Project Name\]/$PROJECT_NAME/g" "$TARGET/AGENTS.md"
fi

# ── Copy framework files ──────────────────────────────────────────────────────
cp "$TEMPLATE_DIR/.claude/settings.json" "$TARGET/.claude/"
cp "$TEMPLATE_DIR/.kiro/rules/"*.md "$TARGET/.kiro/rules/"
# Copy hooks (preserving subdirectory structure)
cp -r "$TEMPLATE_DIR/hooks" "$TARGET/hooks"
ln -sf ../hooks "$TARGET/.kiro/hooks"
ln -sf ../hooks "$TARGET/.claude/hooks"
cp "$TEMPLATE_DIR/.kiro/agents/"*.json "$TARGET/.kiro/agents/"
cp "$TEMPLATE_DIR/knowledge/"*.md "$TARGET/knowledge/" 2>/dev/null || true
cp -r "$TEMPLATE_DIR/knowledge/product" "$TARGET/knowledge/" 2>/dev/null || true
cp "$TEMPLATE_DIR/docs/INDEX.md" "$TARGET/docs/"
for d in designs plans research decisions; do
  touch "$TARGET/docs/$d/.gitkeep"
done
cp "$TEMPLATE_DIR/.gitignore" "$TARGET/" 2>/dev/null || true

# ── Copy skills (preserving structure, symlinked like hooks) ──────────────────
if [ -d "$TEMPLATE_DIR/skills" ]; then
  cp -r "$TEMPLATE_DIR/skills" "$TARGET/skills"
  ln -sf ../skills "$TARGET/.kiro/skills"
  ln -sf ../skills "$TARGET/.claude/skills"
  SKILL_COUNT=$(ls -d "$TARGET/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
  echo "📦 Copied $SKILL_COUNT skills"
fi

# ── Create overlay scaffolding ────────────────────────────────────────────────
# Empty .omcc-overlay.json for project-specific skill/hook extensions
if [ ! -f "$TARGET/.omcc-overlay.json" ]; then
  printf '{\n  "extra_skills": [],\n  "extra_hooks": {}\n}\n' > "$TARGET/.omcc-overlay.json"
fi

# hooks/project/ directory for project-specific hooks
mkdir -p "$TARGET/hooks/project"

# Copy EXTENSION-GUIDE.md if available
if [ -f "$TEMPLATE_DIR/docs/EXTENSION-GUIDE.md" ]; then
  cp "$TEMPLATE_DIR/docs/EXTENSION-GUIDE.md" "$TARGET/docs/"
fi

# ── Update agent config with project name ────────────────────────────────────
jq --arg name "$PROJECT_NAME agent" '.description = $name' "$TARGET/.kiro/agents/pilot.json" > "$TARGET/.kiro/agents/pilot.json.tmp" && \
mv "$TARGET/.kiro/agents/pilot.json.tmp" "$TARGET/.kiro/agents/pilot.json"

echo ""
echo "✅ Done! Project initialized at: $TARGET"
echo ""
echo "📁 Structure:"
echo "  CLAUDE.md              — High-frequency recall (Claude Code)"
echo "  AGENTS.md              — High-frequency recall (Kiro CLI) [type=$PROJECT_TYPE]"
echo "  .kiro/rules/           — Enforcement + Reference layers"
echo "  .kiro/hooks/           — Automated guardrails"
if [ -n "${SKILL_COUNT:-}" ]; then
echo "  .kiro/skills/          — $SKILL_COUNT pre-installed skills"
fi
echo "  .omcc-overlay.json     — Project extension overlay (skills/hooks)"
echo "  hooks/project/         — Project-specific hooks directory"
echo "  knowledge/INDEX.md     — Knowledge routing (empty, fill it in)"
echo "  knowledge/product/     — Product map (features, constraints)"
echo "  docs/                  — Designs, plans, research, decisions"
echo "  tools/                 — Reusable scripts"
echo ""
echo "👉 Next: Edit AGENTS.md to customize your agent's identity and roles"
