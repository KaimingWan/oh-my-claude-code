#!/bin/bash
# require-regression.sh — PreToolUse[execute_bash] gate
# When committing ralph-related files, require recent pytest execution.
source "$(dirname "$0")/../_lib/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Only intercept execute_bash
[ "$TOOL_NAME" != "execute_bash" ] && [ "$TOOL_NAME" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Only intercept git commit
echo "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+commit' || exit 0

# Check if staged files include ralph-related code
RALPH_FILES=$(git diff --cached --name-only 2>/dev/null | grep -E '^scripts/(ralph_loop\.py|lib/(plan|scheduler|lock)\.py)$')
[ -z "$RALPH_FILES" ] && exit 0

# Ralph files staged — check for recent pytest execution
# Look for .pytest_cache last-run timestamp
CACHE="tests/ralph-loop/.pytest_cache/v/cache/lastfailed"
CACHE2=".pytest_cache/v/cache/stepwise"
WINDOW=600  # 10 minutes

NOW=$(date +%s)
FOUND=false

# Check pytest_cache directory mtime
for d in "tests/ralph-loop/.pytest_cache" ".pytest_cache"; do
  if [ -d "$d" ]; then
    MTIME=$(file_mtime "$d")
    AGE=$((NOW - MTIME))
    if [ "$AGE" -lt "$WINDOW" ]; then
      FOUND=true
      break
    fi
  fi
done

if [ "$FOUND" = "false" ]; then
  echo "🚫 BLOCKED: Committing ralph-related files without recent test run." >&2
  echo "   Staged ralph files: $RALPH_FILES" >&2
  echo "   Run: python3 -m pytest tests/ralph-loop/ -v" >&2
  echo "   Then commit again." >&2
  exit 2
fi

exit 0
