#!/bin/bash
# context-enrichment.sh — Per-prompt enrichment with rules injection + distillation trigger
# Responsibilities: research reminder, unfinished task resume, distillation trigger,
# keyword-based rules injection (🔴 always, 🟡 keyword-matched), episode index hints

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')

# Research skill reminder
if echo "$USER_MSG" | grep -qE '(调研|研究一下|查一下|了解一下|对比.*方案)'; then
  echo "🔍 Research detected → read skills/research/SKILL.md for search level strategy (L0→L1→L2)."
elif echo "$USER_MSG" | grep -qiE '(research|investigate|look into|compare.*options|find out)'; then
  echo "🔍 Research detected → read skills/research/SKILL.md for search level strategy (L0→L1→L2)."
fi

# Unfinished task resume
if [ -f ".completion-criteria.md" ]; then
  UNCHECKED=$(grep '^\- \[ \]' ".completion-criteria.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$UNCHECKED" -gt 0 ] && echo "⚠️ Unfinished task: .completion-criteria.md has $UNCHECKED unchecked items. Read it to resume."
fi

# ── Layer 1: Distillation trigger (kb-changed flag) ──
KB_FLAG="/tmp/kb-changed-${WS_HASH}.flag"
if [ -f "$KB_FLAG" ]; then
  DISTILL_LIB="$SCRIPT_DIR/../_lib/distill.sh"
  if [ -f "$DISTILL_LIB" ]; then
    source "$DISTILL_LIB"
    distill_check
    archive_promoted
    section_cap_enforce
  fi
  rm -f "$KB_FLAG"
fi

# ── Layer 2: Rules injection ──
RULES_FILE="knowledge/rules.md"
if [ -f "$RULES_FILE" ] && grep -q '^## \[' "$RULES_FILE" 2>/dev/null; then
  MSG_LOWER=$(echo "$USER_MSG" | tr '[:upper:]' '[:lower:]')
  INJECTED=0

  # 🔴 CRITICAL rules: always injected regardless of keyword match
  CRITICAL_RULES=$(awk '/^## \[/{next} /^🔴/' "$RULES_FILE")
  if [ -n "$CRITICAL_RULES" ]; then
    echo "📚 AGENT RULES:"
    while IFS= read -r rule; do
      echo "⚠️ RULE: ${rule#🔴 }"
    done <<< "$CRITICAL_RULES"
    INJECTED=1
  fi

  # 🟡 RELEVANT rules: keyword-matched injection
  CURRENT_SECTION="" CURRENT_RULES=""
  while IFS= read -r line; do
    if echo "$line" | grep -q '^## \['; then
      # Process previous section
      if [ -n "$CURRENT_SECTION" ] && [ -n "$CURRENT_RULES" ]; then
        KEYWORDS=$(echo "$CURRENT_SECTION" | sed 's/^## \[//;s/\]$//')
        for kw in $(echo "$KEYWORDS" | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
          if echo "$MSG_LOWER" | grep -qiw "$kw"; then
            [ "$INJECTED" -eq 0 ] && echo "📚 AGENT RULES:"
            while IFS= read -r r; do
              [ -z "$r" ] && continue
              echo "$r" | grep -q '^🔴' && continue  # already injected
              if echo "$r" | grep -q '^🟡'; then
                echo "📚 Rule: ${r#🟡 }"
              else
                echo "📚 Rule: $r"
              fi
            done <<< "$CURRENT_RULES"
            INJECTED=1
            break
          fi
        done
      fi
      CURRENT_SECTION="$line"
      CURRENT_RULES=""
    elif echo "$line" | grep -qE '^[0-9🔴🟡]'; then
      CURRENT_RULES="${CURRENT_RULES:+$CURRENT_RULES
}$line"
    fi
  done < "$RULES_FILE"
  # Process last section
  if [ -n "$CURRENT_SECTION" ] && [ -n "$CURRENT_RULES" ]; then
    KEYWORDS=$(echo "$CURRENT_SECTION" | sed 's/^## \[//;s/\]$//')
    for kw in $(echo "$KEYWORDS" | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
      if echo "$MSG_LOWER" | grep -qiw "$kw"; then
        [ "$INJECTED" -eq 0 ] && echo "📚 AGENT RULES:"
        while IFS= read -r r; do
          [ -z "$r" ] && continue
          echo "$r" | grep -q '^🔴' && continue
          if echo "$r" | grep -q '^🟡'; then
            echo "📚 Rule: ${r#🟡 }"
          else
            echo "📚 Rule: $r"
          fi
        done <<< "$CURRENT_RULES"
        INJECTED=1
        break
      fi
    done
  fi

  # Fallback: no keyword match → inject largest section
  if [ "$INJECTED" -eq 0 ]; then
    echo "📚 Rules (general):"
    BEST_SEC=$(awk '/^## \[/{if(cnt>max){max=cnt;best=sec};sec=$0;cnt=0;next}/^[0-9🔴🟡]/{cnt++}END{if(cnt>max)best=sec;print best}' "$RULES_FILE")
    [ -n "$BEST_SEC" ] && awk -v sec="$BEST_SEC" '$0==sec{p=1;next}/^## \[/{p=0}p&&/^[0-9🔴🟡]/' "$RULES_FILE"
  fi
elif [ -f "$RULES_FILE" ] && [ -s "$RULES_FILE" ]; then
  # Old format fallback (no ## [ headers)
  if grep -q '^[0-9]' "$RULES_FILE" 2>/dev/null; then
    echo "📚 AGENT RULES:" && grep '^[0-9]' "$RULES_FILE"
  fi
fi

# ── Layer 3: Episode index hints ──
if [ -f "knowledge/episodes.md" ]; then
  MSG_LOWER=$(echo "$USER_MSG" | tr '[:upper:]' '[:lower:]')
  HINTS=""
  while IFS='|' read -r date status keywords summary; do
    status=$(echo "$status" | tr -d ' ')
    [ "$status" != "active" ] && continue
    for kw in $(echo "$keywords" | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
      if echo "$MSG_LOWER" | grep -qiw "$kw"; then
        HINT=$(echo "$summary" | head -c 40 | tr -d '\n')
        HINTS="${HINTS:+$HINTS
}📌 Episode: ${HINT}..."
        break
      fi
    done
  done < <(grep '| active |' "knowledge/episodes.md" 2>/dev/null)
  [ -n "$HINTS" ] && echo "$HINTS"
fi

# ── Layer 4: Archive hint ──
if [ -d "knowledge/archive" ] && [ "$(ls -A knowledge/archive 2>/dev/null | grep -v '.gitkeep')" ]; then
  echo "📦 Archive available: knowledge/archive/"
fi

exit 0
