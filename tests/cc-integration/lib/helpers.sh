#!/bin/bash
# lib/helpers.sh — shared utilities for CC integration tests
# Source this file from each test: source "$(dirname "$0")/lib/helpers.sh"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Compute workspace hash — mirrors post-bash.sh line 17 exactly:
#   WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo "default")
# Using plain shasum (SHA-1, no -a flag) of pwd, NOT sha256sum.
ws_hash() {
  pwd | shasum 2>/dev/null | cut -c1-8 || echo "default"
}

VERIFY_LOG="/tmp/verify-log-$(ws_hash).jsonl"

# Run claude -p with 60s timeout, capture output
# Usage: cc_run "prompt" [extra_args...]
cc_run() {
  local prompt="$1"; shift
  local exit_code=0
  if command -v gtimeout &>/dev/null; then
    gtimeout 60 claude -p "$prompt" --output-format text "$@" 2>&1 || exit_code=$?
  else
    perl -e "alarm 60; exec @ARGV" -- claude -p "$prompt" --output-format text "$@" 2>&1 || exit_code=$?
  fi
  return $exit_code
}

# Clear verify log before test
clear_verify_log() {
  rm -f "$VERIFY_LOG"
}

# Assert directory still exists (hook blocked deletion)
assert_dir_exists() {
  local dir="$1" label="${2:-directory}"
  if [ -d "$dir" ]; then
    echo "PASS: $label still exists (hook blocked deletion)"
    return 0
  else
    echo "FAIL: $label was deleted (hook did not fire)"
    return 1
  fi
}

# Assert file content unchanged
assert_file_unchanged() {
  local file="$1" original="$2" label="${3:-file}"
  local current
  current=$(cat "$file" 2>/dev/null || echo "__MISSING__")
  if [ "$current" = "$original" ]; then
    echo "PASS: $label unchanged (hook blocked modification)"
    return 0
  else
    echo "FAIL: $label was modified (hook did not fire)"
    return 1
  fi
}

# Assert file was NOT created at path
assert_file_not_created() {
  local path="$1" label="${2:-file}"
  if [ ! -e "$path" ]; then
    echo "PASS: $label not created (hook blocked write)"
    return 0
  else
    echo "FAIL: $label was created (hook did not fire)"
    rm -f "$path"
    return 1
  fi
}

# Assert verify-log has at least one entry with exit_code=0
assert_verify_log_written() {
  local label="${1:-command}"
  if [ -f "$VERIFY_LOG" ] && grep -q '"exit_code":0' "$VERIFY_LOG" 2>/dev/null; then
    echo "PASS: verify-log recorded $label (post-bash hook fired)"
    return 0
  else
    echo "FAIL: verify-log missing $label entry (post-bash hook may not have fired)"
    return 1
  fi
}
