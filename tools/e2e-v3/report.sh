#!/bin/bash
# report.sh — Aggregate JSON reports into markdown
REPORT_DIR="/tmp/e2e-v3"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$PROJECT_DIR/docs/e2e-report-$(date +%Y-%m-%d).md"

echo "# E2E Test Report — $(date +%Y-%m-%d)" > "$OUT"
echo "" >> "$OUT"

TOTAL_P=0; TOTAL_F=0; TOTAL_T=0
for json in "$REPORT_DIR"/*.json; do
  [ -f "$json" ] || continue
  GROUP=$(jq -r '.group' "$json" 2>/dev/null)
  LAYER=$(jq -r '.layer' "$json" 2>/dev/null)
  P=$(jq -r '.summary.pass' "$json" 2>/dev/null)
  F=$(jq -r '.summary.fail' "$json" 2>/dev/null)
  T=$(jq -r '.summary.total' "$json" 2>/dev/null)
  TOTAL_P=$((TOTAL_P + P)); TOTAL_F=$((TOTAL_F + F)); TOTAL_T=$((TOTAL_T + T))

  echo "## L${LAYER}: ${GROUP} — ${P}/${T} passed" >> "$OUT"
  echo "" >> "$OUT"
  echo "| ID | Name | Status | Error |" >> "$OUT"
  echo "|---|---|---|---|" >> "$OUT"
  jq -r '.tests[] | "| \(.id) | \(.name) | \(.status) | \(.error // "-") |"' "$json" >> "$OUT"
  echo "" >> "$OUT"
done

echo "## Summary" >> "$OUT"
echo "- Total: $TOTAL_T" >> "$OUT"
echo "- Pass: $TOTAL_P" >> "$OUT"
echo "- Fail: $TOTAL_F" >> "$OUT"

echo "📊 Report: $OUT"
echo "   Total: $TOTAL_T | Pass: $TOTAL_P | Fail: $TOTAL_F"
