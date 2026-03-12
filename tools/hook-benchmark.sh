#!/bin/bash
# hook-benchmark.sh — Measure individual hook execution time
# Usage: bash tools/hook-benchmark.sh [baseline|optimized]
set -euo pipefail

LABEL="${1:-baseline}"
RESULTS_FILE=".omc/plans/hook-perf-${LABEL}.txt"
mkdir -p .omc/plans

# Simulated inputs
PROMPT_INPUT='{"prompt":"帮我看看 automqbox 的部署架构"}'
BASH_INPUT='{"tool_name":"execute_bash","tool_input":{"command":"ls -la"}}'
WRITE_INPUT='{"tool_name":"fs_write","tool_input":{"file_path":"test.md","content":"hello"}}'

echo "=== Hook Performance Benchmark: $LABEL ===" > "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

total_ms=0

bench() {
  local name="$1" cmd="$2" input="$3"
  local start end elapsed
  start=$(python3 -c 'import time; print(int(time.time()*1000))')
  echo "$input" | bash -c "$cmd" >/dev/null 2>&1 || true
  end=$(python3 -c 'import time; print(int(time.time()*1000))')
  elapsed=$((end - start))
  total_ms=$((total_ms + elapsed))
  printf "%-45s %6d ms\n" "$name" "$elapsed" | tee -a "$RESULTS_FILE"
}

echo "── UserPromptSubmit (7 hooks, sequential) ──" | tee -a "$RESULTS_FILE"
bench "correction-detect.sh"      'bash hooks/feedback/correction-detect.sh'       "$PROMPT_INPUT"
bench "session-init.sh"           'bash hooks/feedback/session-init.sh'            "$PROMPT_INPUT"
bench "context-enrichment.sh"     'bash hooks/feedback/context-enrichment.sh'      "$PROMPT_INPUT"
bench "three-rules-check.sh"      'bash hooks/project/three-rules-check.sh'       "$PROMPT_INPUT"
bench "enforce-research.sh"       'bash hooks/project/enforce-research.sh'         "$PROMPT_INPUT"
bench "customer-context-loader.sh" 'bash hooks/project/customer-context-loader.sh' "$PROMPT_INPUT"
bench "context-enrichment-ext.sh" 'bash hooks/project/context-enrichment-ext.sh'   "$PROMPT_INPUT"

echo "" | tee -a "$RESULTS_FILE"
echo "── PreToolUse[Bash] (2 hooks) ──" | tee -a "$RESULTS_FILE"
bench "block-hubspot-danger.sh"   'bash hooks/project/block-hubspot-danger.sh'     "$BASH_INPUT"
bench "block-submodule-bash.sh"   'bash hooks/project/block-submodule-bash.sh'     "$BASH_INPUT"

echo "" | tee -a "$RESULTS_FILE"
echo "── PreToolUse[Write|Edit] (4 hooks) ──" | tee -a "$RESULTS_FILE"
bench "scan-write-content.sh"     'bash hooks/project/scan-write-content.sh'       "$WRITE_INPUT"
bench "pre-write-ext.sh"          'bash hooks/project/pre-write-ext.sh'            "$WRITE_INPUT"
bench "block-email-send.sh"       'bash hooks/project/block-email-send.sh'         "$WRITE_INPUT"
bench "block-submodule-direct.sh" 'bash hooks/project/block-submodule-direct.sh'   "$WRITE_INPUT"

echo "" | tee -a "$RESULTS_FILE"
echo "── Simulate: 1 message + 3 Bash + 2 Write calls ──" | tee -a "$RESULTS_FILE"
# Typical interaction: UserPromptSubmit once + 3 Bash tool calls + 2 Write tool calls
sim_total=$total_ms
# Add 3x Bash hooks + 2x Write hooks (already measured above, multiply)
# Read from results
bash_per=$(grep 'block-hubspot-danger.sh\|block-submodule-bash.sh' "$RESULTS_FILE" | awk '{sum+=$(NF-1)} END{print sum}')
write_per=$(grep 'scan-write-content.sh\|pre-write-ext.sh\|block-email-send.sh\|block-submodule-direct.sh' "$RESULTS_FILE" | awk '{sum+=$(NF-1)} END{print sum}')
sim_total=$((total_ms + bash_per * 2 + write_per * 1))
printf "%-45s %6d ms\n" "TOTAL (simulated interaction)" "$sim_total" | tee -a "$RESULTS_FILE"

echo "" | tee -a "$RESULTS_FILE"
printf "%-45s %6d ms\n" "TOTAL (all hooks once)" "$total_ms" | tee -a "$RESULTS_FILE"

echo ""
echo "Results saved to $RESULTS_FILE"
