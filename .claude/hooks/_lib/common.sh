#!/bin/bash
# common.sh — Shared functions for all hooks

HOOKS_DRY_RUN="${HOOKS_DRY_RUN:-false}"

hook_block() {
  if [ "$HOOKS_DRY_RUN" = "true" ]; then
    echo "⚠️ DRY RUN — would have blocked: $1" >&2
    exit 0
  fi
  echo "$1" >&2
  exit 2
}

detect_test_command() {
  if [ -f "package.json" ]; then echo "npm test --silent"
  elif [ -f "Cargo.toml" ]; then echo "cargo test 2>&1"
  elif [ -f "go.mod" ]; then echo "go test ./... 2>&1"
  elif [ -f "pom.xml" ]; then echo "mvn test -q 2>&1"
  elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then echo "gradle test 2>&1"
  elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then echo "python -m pytest 2>&1"
  elif [ -f "Makefile" ] && grep -q '^test:' Makefile 2>/dev/null; then echo "make test 2>&1"
  else echo ""; fi
}

get_tool_file() {
  local INPUT="$1"
  local TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
  case "$TOOL_NAME" in
    fs_write|Write) echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null ;;
    Edit)           echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null ;;
    *)              echo "" ;;
  esac
}

is_source_file() {
  echo "$1" | grep -qE '\.(ts|js|py|java|rs|go|rb|swift|kt|sh|bash|zsh|yaml|yml|toml|tf|hcl)$'
}

is_test_file() {
  echo "$1" | grep -qiE '(test|spec|__test__)'
}
