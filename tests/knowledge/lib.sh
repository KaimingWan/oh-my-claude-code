#!/bin/bash
# lib.sh — Shared test helpers for knowledge system tests
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures" && pwd)"
REPORT_DIR="/tmp/kb-test-reports"
mkdir -p "$REPORT_DIR"

PASS=0; FAIL=0; TOTAL=0; FAILURES=(); LAST_RC=0; _CUR_FAILED=0
GROUP="${GROUP:-unknown}"; T=""
SANDBOX=""

# ── Sandbox ──
setup_sandbox() {
  SANDBOX="/tmp/kb-test-$$"
  rm -rf "$SANDBOX"
  mkdir -p "$SANDBOX/knowledge"
  cp "$FIXTURES_DIR"/rules-healthy.md "$SANDBOX/knowledge/rules.md"
  cp "$FIXTURES_DIR"/episodes-healthy.md "$SANDBOX/knowledge/episodes.md"
}

teardown_sandbox() {
  [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"
}

clear_session_flags() {
  rm -f /tmp/lessons-injected-*.flag /tmp/agent-correction-*.flag /tmp/kb-changed-*.flag
}

# ── Test helpers ──
pass() { echo "  ✅ PASS"; }
fail() { echo "  ❌ FAIL — $1"; _CUR_FAILED=1; FAILURES+=("$T: $1"); }

assert_contains() { echo "$1" | grep -qiE "$2" && pass || fail "missing: $2"; }
assert_not_contains() { echo "$1" | grep -qiE "$2" && fail "should not contain: $2" || pass; }
assert_exit_code() { [ "$2" -eq "$1" ] && pass || fail "exit $2, expected $1"; }

begin_test() { T="$1"; TOTAL=$((TOTAL+1)); _CUR_FAILED=0; echo "[$T]"; }

# ── JSON report ──
FIRST_TEST=true
json_report_start() {
  REPORT_FILE="$REPORT_DIR/${GROUP}.json"
  printf '{"group":"%s","tests":[' "$GROUP" > "$REPORT_FILE"
  FIRST_TEST=true
}

record_result() {
  local id="$1" name="$2"
  [ "$FIRST_TEST" = true ] && FIRST_TEST=false || printf ',' >> "$REPORT_FILE"
  if [ "$_CUR_FAILED" -eq 0 ]; then
    PASS=$((PASS+1))
    jq -nc --arg i "$id" --arg n "$name" '{id:$i,name:$n,status:"PASS"}' >> "$REPORT_FILE"
  else
    FAIL=$((FAIL+1))
    local err="${FAILURES[${#FAILURES[@]}-1]:-unknown}"
    jq -nc --arg i "$id" --arg n "$name" --arg e "$err" '{id:$i,name:$n,status:"FAIL",error:$e}' >> "$REPORT_FILE"
  fi
}

json_report_end() {
  printf '],"summary":{"total":%d,"pass":%d,"fail":%d}}' "$TOTAL" "$PASS" "$FAIL" >> "$REPORT_FILE"
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

# ── Hook runners ──
run_context_enrichment() {
  local prompt="$1"
  printf '{"prompt":"%s"}' "$prompt" | bash "$PROJECT_DIR/hooks/feedback/context-enrichment.sh" 2>&1
}

run_auto_capture() {
  local msg="$1"
  bash "$PROJECT_DIR/hooks/feedback/auto-capture.sh" "$msg" 2>&1
}

run_kb_health_report() {
  # Must be called after cd "$SANDBOX"
  # Create flag using same hash method as the hook (pwd | shasum)
  local hash
  hash=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')
  touch "/tmp/kb-changed-${hash}.flag"
  # Remove cooldown so report runs
  local cooldown="/tmp/kb-report-${hash}.cooldown"
  [ -f "$cooldown" ] && mv "$cooldown" "$cooldown.bak" 2>/dev/null
  local out
  out=$(bash "$PROJECT_DIR/hooks/feedback/kb-health-report.sh" 2>&1)
  local rc=$?
  # Also check the generated report file
  if [ -f "knowledge/.health-report.md" ]; then
    out="$out$(cat knowledge/.health-report.md)"
  fi
  echo "$out"
  return $rc
}

# ── Kiro CLI (L2 only) ──
strip_ansi() { sed 's/\x1B\[[0-9;?]*[a-zA-Z]//g' | sed 's/\r//g' | tr -s '\n'; }

kiro() {
  cd "$PROJECT_DIR"
  perl -e 'alarm shift; exec @ARGV' "${2:-60}" \
    kiro-cli chat -a --no-interactive "$1" 2>&1 | strip_ansi
}

backup_file() { [ -f "$1" ] && cp "$1" "${1}.e2e-bak"; }
restore_file() { [ -f "${1}.e2e-bak" ] && mv "${1}.e2e-bak" "$1"; }
