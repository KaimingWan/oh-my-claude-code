#!/bin/bash
# context-enrichment.sh — Per-prompt enrichment with rules injection + distillation trigger
# Responsibilities: research reminder, unfinished task resume, distillation trigger,
# keyword-based rules injection (🔴 always, 🟡 keyword-matched), episode index hints
# Budget: max 8 lines output, 60s dedup, rules cap 3

INPUT=$(cat)
USER_MSG=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_HASH=$(pwd | shasum 2>/dev/null | cut -c1-8 || echo 'default')

# ── 60s dedup: skip if enrichment ran within last 60s ──
DEDUP_FILE="/tmp/ctx-enrich-${WS_HASH}.ts"
NOW=$(date +%s)
if [ -f "$DEDUP_FILE" ]; then
  LAST=$(cat "$DEDUP_FILE" 2>/dev/null || echo 0)
  if [ $((NOW - LAST)) -lt 60 ]; then
    exit 0
  fi
fi
echo "$NOW" > "$DEDUP_FILE"

# Collect all output into variable, then emit truncated at end
OUTPUT=""
emit() { OUTPUT="${OUTPUT:+$OUTPUT
}$1"; }

# Research skill reminder
if echo "$USER_MSG" | grep -qE '(调研|研究一下|查一下|了解一下|对比.*方案)'; then
  emit "🔍 Research detected → read skills/research/SKILL.md for search level strategy (L0→L1→L2)."
elif echo "$USER_MSG" | grep -qiE '(research|investigate|look into|compare.*options|find out)'; then
  emit "🔍 Research detected → read skills/research/SKILL.md for search level strategy (L0→L1→L2)."
fi

# Debugging skill reminder
if echo "$USER_MSG" | grep -qE '(报错|\bbug\b|调试|修复.*错误|测试失败|不工作了)'; then
  emit "🐛 Debug detected → read skills/debugging/SKILL.md. Use LSP tools (get_diagnostics, search_symbols, find_references) BEFORE attempting fixes."
elif echo "$USER_MSG" | grep -qiE '(\btest.*(fail|brok)|traceback|exception.*thrown|crash|not working|fix.*bug|\bis broken\b|\bbug\b)'; then
  emit "🐛 Debug detected → read skills/debugging/SKILL.md. Use LSP tools (get_diagnostics, search_symbols, find_references) BEFORE attempting fixes."
fi

# Planning intent — force planning skill workflow
if echo "$USER_MSG" | grep -qE '(plan|计划|整理|梳理|沉淀|规划|方案|设计.*方案|重构.*plan)' && ! echo "$USER_MSG" | grep -qE '^@execute|^/execute'; then
  if [ ! -f ".brainstorm-confirmed" ]; then
    emit "📋 Planning intent detected → Read skills/planning/SKILL.md and follow the FULL workflow: Phase 0 (Deep Understanding) → Phase 1 (Write Plan to docs/plans/) → Phase 1.5 (Dispatch 4 reviewer subagents) → Phase 2 (Execute via ralph loop). Do NOT skip phases. Plan file MUST have ## Tasks, ## Checklist, ## Review sections."
  fi
fi

# @execute command — force ralph loop
if echo "$USER_MSG" | grep -qE '^@execute|^/execute'; then
  PLAN_POINTER="docs/plans/.active"
  WORK_DIR=""
  if [ -f "$PLAN_POINTER" ]; then
    PLAN_FILE=$(cat "$PLAN_POINTER" | tr -d '[:space:]')
    if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
      WORK_DIR=$(grep -oE '^\*\*Work Dir:\*\*\s*.+' "$PLAN_FILE" 2>/dev/null | sed 's/^\*\*Work Dir:\*\*\s*//' | tr -d '[:space:]')
    fi
  fi
  if [ -n "$WORK_DIR" ]; then
    emit "🚀 Execute detected → Plan has Work Dir: $WORK_DIR. Create worktree if needed, then run: PLAN_POINTER_OVERRIDE=$PLAN_FILE RALPH_WORK_DIR=$WORK_DIR python3 scripts/ralph_loop.py"
  else
    emit "🚀 Execute detected → Run \`python3 scripts/ralph_loop.py\` immediately. Do NOT read the plan or implement tasks yourself."
  fi
fi

# Unfinished task resume
if [ -f ".completion-criteria.md" ]; then
  UNCHECKED=$(grep '^\- \[ \]' ".completion-criteria.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$UNCHECKED" -gt 0 ] && emit "⚠️ Unfinished task: .completion-criteria.md has $UNCHECKED unchecked items. Read it to resume."
fi

# ── Layer 0: Promoted/resolved episode cleanup (always, cheap) ──
DISTILL_LIB="$SCRIPT_DIR/../_lib/distill.sh"
EPISODES_FILE="knowledge/episodes.md"
RULES_FILE="knowledge/rules.md"
RULES_DIR=".claude/rules"
ARCHIVE_DIR="knowledge/archive"
if [ -f "$DISTILL_LIB" ] && [ -f "$EPISODES_FILE" ]; then
  source "$DISTILL_LIB"
  archive_promoted
fi

# ── Layer 1: Distillation trigger (kb-changed flag) ──
KB_FLAG="/tmp/kb-changed-${WS_HASH}.flag"
if [ -f "$KB_FLAG" ]; then
  if [ -f "$DISTILL_LIB" ]; then
    source "$DISTILL_LIB" 2>/dev/null  # may already be sourced
    distill_check
    section_cap_enforce
  fi
  rm -f "$KB_FLAG"
fi

# ── Layer 2: Rules injection (cap 3 rules) ──
RULES_FILE="knowledge/rules.md"
MAX_RULES=3
RULES_COUNT=0
if [ -f "$RULES_FILE" ] && grep -q '^## \[' "$RULES_FILE" 2>/dev/null; then
  MSG_LOWER=$(echo "$USER_MSG" | tr '[:upper:]' '[:lower:]')
  INJECTED=0

  # 🔴 CRITICAL rules: always injected regardless of keyword match
  CRITICAL_RULES=$(awk '/^## \[/{next} /^🔴/' "$RULES_FILE")
  if [ -n "$CRITICAL_RULES" ]; then
    emit "📚 AGENT RULES:"
    while IFS= read -r rule; do
      [ "$RULES_COUNT" -ge "$MAX_RULES" ] && break
      emit "⚠️ RULE: ${rule#🔴 }"
      RULES_COUNT=$((RULES_COUNT + 1))
    done <<< "$CRITICAL_RULES"
    INJECTED=1
  fi

  # 🟡 RELEVANT rules: keyword-matched injection
  CURRENT_SECTION="" CURRENT_RULES=""
  while IFS= read -r line; do
    if echo "$line" | grep -q '^## \['; then
      # Process previous section
      if [ -n "$CURRENT_SECTION" ] && [ -n "$CURRENT_RULES" ] && [ "$RULES_COUNT" -lt "$MAX_RULES" ]; then
        KEYWORDS=$(echo "$CURRENT_SECTION" | sed 's/^## \[//;s/\]$//')
        for kw in $(echo "$KEYWORDS" | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
          if echo "$MSG_LOWER" | grep -qiw "$kw"; then
            [ "$INJECTED" -eq 0 ] && emit "📚 AGENT RULES:"
            while IFS= read -r r; do
              [ -z "$r" ] && continue
              [ "$RULES_COUNT" -ge "$MAX_RULES" ] && break
              echo "$r" | grep -q '^🔴' && continue  # already injected
              if echo "$r" | grep -q '^🟡'; then
                emit "📚 Rule: ${r#🟡 }"
              else
                emit "📚 Rule: $r"
              fi
              RULES_COUNT=$((RULES_COUNT + 1))
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
  if [ -n "$CURRENT_SECTION" ] && [ -n "$CURRENT_RULES" ] && [ "$RULES_COUNT" -lt "$MAX_RULES" ]; then
    KEYWORDS=$(echo "$CURRENT_SECTION" | sed 's/^## \[//;s/\]$//')
    for kw in $(echo "$KEYWORDS" | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
      if echo "$MSG_LOWER" | grep -qiw "$kw"; then
        [ "$INJECTED" -eq 0 ] && emit "📚 AGENT RULES:"
        while IFS= read -r r; do
          [ -z "$r" ] && continue
          [ "$RULES_COUNT" -ge "$MAX_RULES" ] && break
          echo "$r" | grep -q '^🔴' && continue
          if echo "$r" | grep -q '^🟡'; then
            emit "📚 Rule: ${r#🟡 }"
          else
            emit "📚 Rule: $r"
          fi
          RULES_COUNT=$((RULES_COUNT + 1))
        done <<< "$CURRENT_RULES"
        INJECTED=1
        break
      fi
    done
  fi

  # Fallback: no keyword match → inject largest section (capped)
  if [ "$INJECTED" -eq 0 ]; then
    emit "📚 Rules (general):"
    BEST_SEC=$(awk '/^## \[/{if(cnt>max){max=cnt;best=sec};sec=$0;cnt=0;next}/^[0-9🔴🟡]/{cnt++}END{if(cnt>max)best=sec;print best}' "$RULES_FILE")
    if [ -n "$BEST_SEC" ]; then
      while IFS= read -r r; do
        [ "$RULES_COUNT" -ge "$MAX_RULES" ] && break
        emit "$r"
        RULES_COUNT=$((RULES_COUNT + 1))
      done < <(awk -v sec="$BEST_SEC" '$0==sec{p=1;next}/^## \[/{p=0}p&&/^[0-9🔴🟡]/' "$RULES_FILE")
    fi
  fi
elif [ -f "$RULES_FILE" ] && [ -s "$RULES_FILE" ]; then
  # Old format fallback (no ## [ headers)
  if grep -q '^[0-9]' "$RULES_FILE" 2>/dev/null; then
    emit "📚 AGENT RULES:"
    RULES_COUNT=0
    while IFS= read -r r; do
      [ "$RULES_COUNT" -ge 3 ] && break
      emit "$r"
      RULES_COUNT=$((RULES_COUNT + 1))
    done < <(grep '^[0-9]' "$RULES_FILE")
  fi
fi

# ── Layer 3: Episode index hints (count only) ──
if [ -f "knowledge/episodes.md" ]; then
  MSG_LOWER=$(echo "$USER_MSG" | tr '[:upper:]' '[:lower:]')
  EP_COUNT=0
  while IFS='|' read -r date status keywords summary; do
    status=$(echo "$status" | tr -d ' ')
    [ "$status" != "active" ] && continue
    for kw in $(echo "$keywords" | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
      if echo "$MSG_LOWER" | grep -qiw "$kw"; then
        EP_COUNT=$((EP_COUNT + 1))
        break
      fi
    done
  done < <(grep '| active |' "knowledge/episodes.md" 2>/dev/null)
  [ "$EP_COUNT" -gt 0 ] && emit "📌 $EP_COUNT related episodes found"
fi

# ── Output: truncate to max 8 lines ──
if [ -n "$OUTPUT" ]; then
  LINE_COUNT=$(echo "$OUTPUT" | wc -l | tr -d ' ')
  if [ "$LINE_COUNT" -gt 8 ]; then
    echo "$OUTPUT" | head -8
    echo "...($((LINE_COUNT - 8)) lines truncated)"
  else
    echo "$OUTPUT"
  fi
fi

run_project_extensions

exit 0
