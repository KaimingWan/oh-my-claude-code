#!/bin/bash
# auto-lint.sh — PostToolUse[Write|Edit] async (Kiro + CC)
# Runs linter after file changes

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  fs_write|Write|Edit) FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null) ;;
  *) exit 0 ;;
esac

[ -z "$FILE" ] && exit 0

# Detect and run appropriate linter
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx)
    if command -v npx &>/dev/null && [ -f "node_modules/.bin/eslint" ]; then
      npx eslint --fix "$FILE" 2>/dev/null
    fi ;;
  *.py)
    if command -v ruff &>/dev/null; then
      ruff check --fix "$FILE" 2>/dev/null
    elif command -v black &>/dev/null; then
      black -q "$FILE" 2>/dev/null
    fi ;;
  *.rs)
    command -v rustfmt &>/dev/null && rustfmt "$FILE" 2>/dev/null ;;
  *.go)
    command -v gofmt &>/dev/null && gofmt -w "$FILE" 2>/dev/null ;;
esac

exit 0
