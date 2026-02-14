#!/bin/bash
# lib.sh — Shared test library for E2E v3
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="/tmp/e2e-v3"
mkdir -p "$REPORT_DIR"

PASS=0; FAIL=0; TOTAL=0; FAILURES=(); LAST_RC=0; _CUR_FAILED=0
GROUP="${GROUP:-unknown}"; LAYER="${LAYER:-0}"; T=""

pass() { echo "  ✅ PASS"; }
fail() { echo "  ❌ FAIL — $1"; _CUR_FAILED=1; FAILURES+=("$T: $1"); }

assert_exit_code() { [ "$2" -eq "$1" ] && pass || fail "exit $2, expected $1"; }
assert_contains() { echo "$1" | grep -qiE "$2" && pass || fail "missing: $2"; }
assert_not_contains() { echo "$1" | grep -qiE "$2" && fail "should not contain: $2" || pass; }

run_hook_full() {
  local input_file="/tmp/e2e-v3-hook-input-$$.json"
  printf '%s' "$2" > "$input_file"
  local output
  output=$(bash "$PROJECT_DIR/$1" < "$input_file" 2>&1)
  LAST_RC=$?
  rm -f "$input_file"
  echo "$output"
}

# Run hook from pre-generated input file
run_hook_file() {
  local output
  output=$(bash "$PROJECT_DIR/$1" < "$2" 2>&1)
  LAST_RC=$?
  echo "$output"
}

strip_ansi() { sed 's/\x1B\[[0-9;?]*[a-zA-Z]//g' | sed 's/\r//g' | tr -s '\n'; }

kiro() {
  cd "$PROJECT_DIR"
  perl -e 'alarm shift; exec @ARGV' "${2:-60}" \
    kiro-cli chat -a --no-interactive "$1" 2>&1 | strip_ansi
}

backup_file() { [ -f "$1" ] && cp "$1" "${1}.e2e-bak"; }
restore_file() { [ -f "${1}.e2e-bak" ] && mv "${1}.e2e-bak" "$1"; }

json_report_start() {
  REPORT_FILE="$REPORT_DIR/${GROUP}.json"
  printf '{"layer":"%s","group":"%s","tests":[' "$LAYER" "$GROUP" > "$REPORT_FILE"
  FIRST_TEST=true
}

json_report_add() {
  local id="$1" name="$2" status="$3" error="${4:-}"
  [ "$FIRST_TEST" = true ] && FIRST_TEST=false || printf ',' >> "$REPORT_FILE"
  if [ -n "$error" ]; then
    jq -nc --arg i "$id" --arg n "$name" --arg s "$status" --arg e "$error" '{id:$i,name:$n,status:$s,error:$e}' >> "$REPORT_FILE"
  else
    jq -nc --arg i "$id" --arg n "$name" --arg s "$status" '{id:$i,name:$n,status:$s}' >> "$REPORT_FILE"
  fi
}

json_report_end() {
  printf '],"summary":{"total":%d,"pass":%d,"fail":%d}}' "$TOTAL" "$PASS" "$FAIL" >> "$REPORT_FILE"
}

begin_test() { T="$1"; TOTAL=$((TOTAL+1)); _CUR_FAILED=0; echo "[$T]"; }

record_result() {
  if [ "$_CUR_FAILED" -eq 0 ]; then
    PASS=$((PASS+1))
    json_report_add "$1" "$2" "PASS"
  else
    FAIL=$((FAIL+1))
    json_report_add "$1" "$2" "FAIL" "${FAILURES[${#FAILURES[@]}-1]:-unknown}"
  fi
}

summary() {
  json_report_end
  echo ""
  echo "=========================================="
  echo "  $1"
  echo "=========================================="
  printf "  通过: %d / %d\n" "$PASS" "$TOTAL"
  printf "  失败: %d / %d\n" "$FAIL" "$TOTAL"
  echo "=========================================="
  if [ $FAIL -gt 0 ]; then
    echo ""; echo "失败详情:"
    for f in "${FAILURES[@]}"; do echo "  ❌ $f"; done
    exit 1
  else
    echo "✅ 全部通过！"; exit 0
  fi
}
