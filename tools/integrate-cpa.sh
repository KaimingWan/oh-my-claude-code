#!/bin/bash
# integrate-cpa.sh — Integrate OMCC framework into a downstream project
# Usage: integrate-cpa.sh [--dry-run] PROJECT_ROOT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OMCC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  shift
fi

PROJECT_ROOT="${1:?Usage: integrate-cpa.sh [--dry-run] PROJECT_ROOT}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

info() { echo "ℹ️  $*"; }
ok() { echo "✅ $*"; }
err() { echo "❌ $*" >&2; exit 1; }
run() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] $*"
  else
    eval "$@"
  fi
}

echo "🚀 Integrating OMCC into: $PROJECT_ROOT"
echo "   OMCC source: $OMCC_ROOT"
[ "$DRY_RUN" = true ] && echo "   Mode: DRY RUN"
echo ""

# ── Step 0: Backup branch ────────────────────────────────────────────────────
if [ "$DRY_RUN" = false ] && [ -d "$PROJECT_ROOT/.git" ]; then
  info "Creating backup branch..."
  (cd "$PROJECT_ROOT" && git checkout -b backup/pre-omcc-integration 2>/dev/null || info "Backup branch already exists, skipping")
  (cd "$PROJECT_ROOT" && git checkout - 2>/dev/null || true)
fi

# ── Step 1: Add OMCC submodule ────────────────────────────────────────────────
info "Step 1: Adding OMCC submodule..."
if [ -d "$PROJECT_ROOT/.omcc" ]; then
  info "Submodule .omcc/ already exists, skipping"
else
  run "cd '$PROJECT_ROOT' && git submodule add '$OMCC_ROOT' .omcc"
fi

# ── Step 2: Create hooks/ directory with symlinks ─────────────────────────────
info "Step 2: Setting up hooks/..."
run "mkdir -p '$PROJECT_ROOT/hooks/project'"

for subdir in security gate feedback _lib; do
  link="$PROJECT_ROOT/hooks/$subdir"
  [ -L "$link" ] && run "unlink '$link'"
  [ -d "$link" ] && run "mv '$link' '$PROJECT_ROOT/hooks/${subdir}.bak'"
  run "ln -sf '../.omcc/hooks/$subdir' '$link'"
done

# Copy dispatcher scripts
for dispatcher in "$OMCC_ROOT"/hooks/dispatch-*.sh; do
  [ -f "$dispatcher" ] || continue
  run "cp '$dispatcher' '$PROJECT_ROOT/hooks/'"
  run "chmod +x '$PROJECT_ROOT/hooks/$(basename "$dispatcher")'"
done

# Move enforce-code-quality.sh to hooks/project/ if it exists in old location
if [ -f "$PROJECT_ROOT/.kiro/hooks/enforce-code-quality.sh" ] && [ ! -f "$PROJECT_ROOT/hooks/project/enforce-code-quality.sh" ]; then
  run "cp '$PROJECT_ROOT/.kiro/hooks/enforce-code-quality.sh' '$PROJECT_ROOT/hooks/project/'"
  run "chmod +x '$PROJECT_ROOT/hooks/project/enforce-code-quality.sh'"
fi

# ── Step 3: Create skills/ directory ──────────────────────────────────────────
info "Step 3: Setting up skills/..."
run "mkdir -p '$PROJECT_ROOT/skills'"

# Symlink OMCC framework skills
for skill_dir in "$OMCC_ROOT"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  link="$PROJECT_ROOT/skills/$skill_name"
  [ -L "$link" ] && run "unlink '$link'"
  run "ln -sf '../.omcc/skills/$skill_name' '$link'"
done

# Move project-specific skills from .agents/skills/
if [ -d "$PROJECT_ROOT/.agents/skills" ]; then
  for skill_dir in "$PROJECT_ROOT/.agents/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    dest="$PROJECT_ROOT/skills/$skill_name"
    # Don't overwrite framework skill symlinks
    if [ -L "$dest" ]; then
      info "Skipping $skill_name (framework skill symlink)"
      continue
    fi
    if [ -d "$dest" ]; then
      info "Skipping $skill_name (already exists)"
      continue
    fi
    run "cp -r '$skill_dir' '$dest'"
  done
fi

# ── Step 4: Create platform symlinks ─────────────────────────────────────────
info "Step 4: Creating platform symlinks..."

for item in hooks skills; do
  for platform_dir in .kiro .claude; do
    link="$PROJECT_ROOT/$platform_dir/$item"
    run "mkdir -p '$PROJECT_ROOT/$platform_dir'"
    [ -L "$link" ] && run "unlink '$link'"
    # Move existing directory to backup if not a symlink
    [ -d "$link" ] && run "mv '$link' '${link}.bak.$(date +%s)'"
    run "ln -sf '../$item' '$link'"
  done
done

# .claude/rules → .omcc/.claude/rules (framework rules)
link="$PROJECT_ROOT/.claude/rules"
[ -L "$link" ] && run "unlink '$link'"
[ -d "$link" ] && run "mv '$link' '${link}.bak.$(date +%s)'"
run "ln -sf '../.omcc/.claude/rules' '$link'"

# ── Step 5: Create .omcc-overlay.json ─────────────────────────────────────────
info "Step 5: Creating .omcc-overlay.json..."
OVERLAY="$PROJECT_ROOT/.omcc-overlay.json"
if [ -f "$OVERLAY" ]; then
  info "Overlay already exists, skipping"
else
  PROJECT_SKILLS=()
  if [ -d "$PROJECT_ROOT/.agents/skills" ]; then
    for skill_dir in "$PROJECT_ROOT/.agents/skills"/*/; do
      [ -d "$skill_dir" ] || continue
      skill_name=$(basename "$skill_dir")
      if [ ! -d "$OMCC_ROOT/skills/$skill_name" ]; then
        PROJECT_SKILLS+=("\"skills/$skill_name\"")
      fi
    done
  fi

  SKILLS_JSON=$(IFS=,; echo "${PROJECT_SKILLS[*]:-}")
  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Write .omcc-overlay.json with skills: [$SKILLS_JSON]"
  else
    cat > "$OVERLAY" << OVERLAY_JSON
{
  "extra_skills": [${SKILLS_JSON}],
  "extra_hooks": {
    "PreToolUse": ["hooks/project/enforce-code-quality.sh"]
  }
}
OVERLAY_JSON
  fi
fi

# ── Step 6: Write AGENTS.md (v3 format) ──────────────────────────────────────
info "Step 6: Writing AGENTS.md..."
TEMPLATE="$SCRIPT_DIR/cpa-agents-template.md"
if [ ! -f "$TEMPLATE" ]; then
  err "Template not found: $TEMPLATE"
fi
run "cp '$TEMPLATE' '$PROJECT_ROOT/AGENTS.md'"
run "cp '$TEMPLATE' '$PROJECT_ROOT/CLAUDE.md'"

# ── Step 7: Run sync to fill OMCC sections + generate configs ─────────────────
info "Step 7: Running sync-omcc.sh..."
SYNC_SCRIPT="$OMCC_ROOT/tools/sync-omcc.sh"
if [ ! -f "$SYNC_SCRIPT" ]; then
  err "sync-omcc.sh not found: $SYNC_SCRIPT"
fi
run "bash '$SYNC_SCRIPT' '$PROJECT_ROOT'"

# ── Step 8: Validate ──────────────────────────────────────────────────────────
info "Step 8: Validating..."
VALIDATE_SCRIPT="$OMCC_ROOT/tools/validate-project.sh"
if [ -f "$VALIDATE_SCRIPT" ]; then
  run "bash '$VALIDATE_SCRIPT' '$PROJECT_ROOT'"
fi

# ── Step 9: Clean up old artifacts ────────────────────────────────────────────
info "Step 9: Cleaning up old artifacts..."

# Old .agents/ directory (contents already migrated to skills/)
if [ -d "$PROJECT_ROOT/.agents" ]; then
  run "mv '$PROJECT_ROOT/.agents' '$PROJECT_ROOT/.agents.bak'"
  info "Moved .agents/ to .agents.bak/"
fi

ok "Integration complete!"
[ "$DRY_RUN" = true ] && echo "✅ dry-run complete"

echo ""
echo "📋 Next steps:"
echo "  1. cd $PROJECT_ROOT"
echo "  2. Verify: python3 -c \"import json; json.load(open('.kiro/agents/default.json'))\""
echo "  3. Verify: grep -q 'MoXun Agent' AGENTS.md"
echo "  4. Verify: git diff --stat -- knowledge/  (should be empty)"
echo "  5. Commit: git add -A && git commit -m 'feat: integrate OMCC framework via submodule'"
