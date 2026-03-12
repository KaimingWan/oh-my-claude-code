#!/bin/bash
# check-scripts-symlinks.sh — Verify framework scripts are symlinks to oh-my-kiro
# Warns if any framework file has been replaced with a regular file (fork risk).

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

FRAMEWORK_FILES=(
  scripts/ralph_loop.py
  scripts/generate_configs.py
  scripts/generate-lesson-scenarios.py
  scripts/ov-daemon.py
  scripts/lib/error_context.py
  scripts/lib/plan.py
  scripts/lib/__init__.py
  scripts/lib/cli_detect.py
  scripts/lib/lock.py
  scripts/lib/precheck.py
  scripts/lib/pty_runner.py
)

errors=0
for f in "${FRAMEWORK_FILES[@]}"; do
  path="$REPO_ROOT/$f"
  if [ ! -L "$path" ]; then
    echo "⚠️  $f is NOT a symlink — edit in oh-my-kiro/ instead" >&2
    errors=$((errors + 1))
  fi
done

[ "$errors" -eq 0 ] && exit 0
echo "❌ $errors framework file(s) are not symlinks. Run Task 2 from scripts-upstream-sync plan." >&2
exit 1
