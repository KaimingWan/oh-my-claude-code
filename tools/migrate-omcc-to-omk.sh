#!/bin/bash
# Migrate a downstream project from OMCC to OMK
# Usage: .omcc/tools/migrate-omcc-to-omk.sh [PROJECT_ROOT]
set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OMK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔄 Migrating project to OMK: $PROJECT_ROOT"

changed=0

# 1. Rename overlay file
if [ -f "$PROJECT_ROOT/.omcc-overlay.json" ] && [ ! -f "$PROJECT_ROOT/.omk-overlay.json" ]; then
  mv "$PROJECT_ROOT/.omcc-overlay.json" "$PROJECT_ROOT/.omk-overlay.json"
  echo "✅ .omcc-overlay.json → .omk-overlay.json"
  changed=$((changed+1))
elif [ -f "$PROJECT_ROOT/.omk-overlay.json" ]; then
  echo "ℹ️  .omk-overlay.json already exists"
fi

# 2. Remove Claude Code artifacts
for f in CLAUDE.md; do
  target="$PROJECT_ROOT/$f"
  if [ -e "$target" ]; then
    python3 -c "import os; os.unlink('$target')"
    echo "✅ Removed $f"
    changed=$((changed+1))
  fi
done
if [ -d "$PROJECT_ROOT/.claude" ]; then
  python3 -c "import shutil; shutil.rmtree('$PROJECT_ROOT/.claude')"
  echo "✅ Removed .claude/"
  changed=$((changed+1))
fi

# 3. Re-sync with OMK
SYNC_SCRIPT="$OMK_ROOT/tools/sync-omk.sh"
if [ -f "$SYNC_SCRIPT" ]; then
  echo ""
  bash "$SYNC_SCRIPT" "$PROJECT_ROOT"
else
  echo "⚠️  sync-omk.sh not found at $SYNC_SCRIPT"
fi

echo ""
echo "📋 Migration summary: $changed items changed"
echo "ℹ️  Optional: rename .omcc submodule path in .gitmodules (manual git operation)"
