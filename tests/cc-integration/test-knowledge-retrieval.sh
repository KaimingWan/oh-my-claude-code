#!/bin/bash
# test-knowledge-retrieval.sh — Verify knowledge base is accessible via CC headless
set -euo pipefail
cd "$(dirname "$0")/../.."

OUTPUT=$(claude -p "Read knowledge/INDEX.md and tell me what routing table entries exist" \
  --output-format text --max-turns 3 2>&1 || true)
echo "$OUTPUT" | grep -qi "routing\|shell\|workflow\|security" || { echo "FAIL: knowledge not retrieved"; exit 1; }
