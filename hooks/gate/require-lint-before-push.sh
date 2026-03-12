#!/bin/bash
# require-lint-before-push.sh — PreToolUse[execute_bash] gate
# Blocks `git push` in repos that have lint scripts, unless lint has passed.
# Uses stamp file /tmp/lint-passed-<hash>.stamp to track lint success.
# Latency: <5ms (file stat only)
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Only intercept git push commands
echo "$CMD" | grep -qE '\bgit[[:space:]]+push\b' || exit 0

# Extract working directory
WORK_DIR=""
if echo "$CMD" | grep -qE '^[[:space:]]*cd[[:space:]]+'; then
  WORK_DIR=$(echo "$CMD" | sed -E 's/^[[:space:]]*cd[[:space:]]+//;s/[[:space:]].*//')
fi
TOOL_WORK_DIR=$(echo "$INPUT" | jq -r '.tool_input.working_dir // ""' 2>/dev/null)
[ -n "$TOOL_WORK_DIR" ] && WORK_DIR="$TOOL_WORK_DIR"

if [ -n "$WORK_DIR" ]; then
  WORK_DIR=$(cd "$WORK_DIR" 2>/dev/null && pwd) || exit 0
else
  WORK_DIR=$(pwd)
fi

# Walk up to git root
GIT_ROOT="$WORK_DIR"
for _ in 1 2 3 4; do
  [ -d "$GIT_ROOT/.git" ] || [ -f "$GIT_ROOT/.git" ] && break
  GIT_ROOT=$(dirname "$GIT_ROOT")
done
([ -d "$GIT_ROOT/.git" ] || [ -f "$GIT_ROOT/.git" ]) || exit 0

# Detect if repo has lint capability:
# 1) root package.json has lint script, OR
# 2) pnpm-workspace.yaml exists (monorepo — sub-packages have lint)
HAS_LINT=0
if [ -f "$GIT_ROOT/package.json" ]; then
  ROOT_LINT=$(jq -r '.scripts.lint // empty' "$GIT_ROOT/package.json" 2>/dev/null)
  [ -n "$ROOT_LINT" ] && HAS_LINT=1
fi
if [ "$HAS_LINT" -eq 0 ] && [ -f "$GIT_ROOT/pnpm-workspace.yaml" ]; then
  # Monorepo: check if any sub-package has lint
  if find "$GIT_ROOT" -maxdepth 4 -name 'package.json' -not -path '*/node_modules/*' \
    -exec jq -e '.scripts.lint // empty' {} \; 2>/dev/null | grep -q .; then
    HAS_LINT=1
  fi
fi

[ "$HAS_LINT" -eq 0 ] && exit 0

# Check stamp
DIR_HASH=$(echo "$GIT_ROOT" | shasum 2>/dev/null | cut -c1-12)
STAMP="/tmp/lint-passed-${DIR_HASH}.stamp"

if [ -f "$STAMP" ]; then
  STAMP_TIME=$(stat -f %m "$STAMP" 2>/dev/null || echo 0)
  # Find newest source file
  NEWEST=$(find "$GIT_ROOT" \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) \
    -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/.next/*' \
    -newer "$STAMP" 2>/dev/null | head -1)
  [ -z "$NEWEST" ] && exit 0  # No files changed since lint passed
fi

hook_block "🚫 BLOCKED: git push requires lint to pass first. Run: pnpm -r lint (in $GIT_ROOT) and verify exit 0, then retry push."
