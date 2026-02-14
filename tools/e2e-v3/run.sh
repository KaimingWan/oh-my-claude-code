#!/bin/bash
# run.sh — Main entry: L1 → L2 → L3
set -uo pipefail
cd "$(dirname "$0")/../.."
REPORT_DIR="/tmp/e2e-v3"; mkdir -p "$REPORT_DIR"
START=$(date +%s)

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  E2E Test Framework v3 — 三层分级测试                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ===== Layer 1: Shell tests (4 groups parallel) =====
echo "━━━ Layer 1: Shell 测试 (4 组并行) ━━━"
L1_PIDS=(); L1_NAMES=()
for script in tools/e2e-v3/l1-*.sh; do
  [ -f "$script" ] || continue
  NAME=$(basename "$script" .sh)
  echo "▶ $NAME"
  bash "$script" > "$REPORT_DIR/${NAME}.log" 2>&1 &
  L1_PIDS+=($!); L1_NAMES+=("$NAME")
done

L1_FAIL=0
for i in "${!L1_PIDS[@]}"; do
  wait "${L1_PIDS[$i]}" 2>/dev/null || L1_FAIL=$((L1_FAIL+1))
done

for NAME in "${L1_NAMES[@]}"; do
  LOG="$REPORT_DIR/${NAME}.log"
  P=$(grep -oE '通过: [0-9]+' "$LOG" 2>/dev/null | grep -oE '[0-9]+' || echo 0)
  F=$(grep -oE '失败: [0-9]+' "$LOG" 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo 0)
  [ "${F:-0}" -eq 0 ] && echo "  ✅ $NAME — $P passed" || { echo "  ❌ $NAME — $P passed, $F failed"; grep "❌ FAIL" "$LOG" | head -3 | sed 's/^/     /'; }
done

if [ "$L1_FAIL" -gt 0 ]; then
  echo ""; echo "🛑 Layer 1 有 $L1_FAIL 组失败，跳过 L2/L3"
  bash "$(dirname "$0")/report.sh"
  exit 1
fi
echo "✅ Layer 1 全部通过"; echo ""

# ===== Layer 2 & 3: placeholder =====
for script in tools/e2e-v3/l2-*.sh; do
  [ -f "$script" ] || continue
  NAME=$(basename "$script" .sh)
  echo "━━━ Layer 2: $NAME ━━━"
  perl -e 'alarm shift; exec @ARGV' 600 bash "$script" > "$REPORT_DIR/${NAME}.log" 2>&1
  RC=$?
  P=$(grep -oE '通过: [0-9]+' "$REPORT_DIR/${NAME}.log" 2>/dev/null | grep -oE '[0-9]+' || echo 0)
  F=$(grep -oE '失败: [0-9]+' "$REPORT_DIR/${NAME}.log" 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo 0)
  [ "${F:-0}" -eq 0 ] && echo "  ✅ $P passed" || echo "  ❌ $P passed, $F failed"
done

[ -f "tools/e2e-v3/l3-integration.sh" ] && {
  echo "━━━ Layer 3: 集成闭环 ━━━"
  perl -e 'alarm shift; exec @ARGV' 1200 bash "tools/e2e-v3/l3-integration.sh" > "$REPORT_DIR/l3-integration.log" 2>&1
  P=$(grep -oE '通过: [0-9]+' "$REPORT_DIR/l3-integration.log" 2>/dev/null | grep -oE '[0-9]+' || echo 0)
  F=$(grep -oE '失败: [0-9]+' "$REPORT_DIR/l3-integration.log" 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo 0)
  [ "${F:-0}" -eq 0 ] && echo "  ✅ $P passed" || echo "  ❌ $P passed, $F failed"
}

END=$(date +%s)
echo ""; echo "总耗时: $((END - START))s"
bash "$(dirname "$0")/report.sh"
