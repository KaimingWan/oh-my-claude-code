#!/bin/bash
# llm-eval.sh — Unified LLM evaluation library (Gemini/Anthropic/OpenAI/Ollama)
# Auto-detects available provider, degrades gracefully when none available

llm_eval() {
  local PROMPT="$1"
  local MAX_TOKENS="${KIRO_EVAL_MAX_TOKENS:-150}"
  local TIMEOUT="${KIRO_EVAL_TIMEOUT:-15}"
  local PROVIDER="${KIRO_EVAL_PROVIDER:-auto}"

  if [ "$PROVIDER" = "auto" ]; then
    if [ -n "$GEMINI_API_KEY" ]; then PROVIDER="gemini"
    elif [ -n "$ANTHROPIC_API_KEY" ]; then PROVIDER="anthropic"
    elif [ -n "$OPENAI_API_KEY" ]; then PROVIDER="openai"
    elif curl -s --max-time 2 http://localhost:11434/api/tags &>/dev/null; then PROVIDER="ollama"
    else PROVIDER="none"; fi
  fi

  case "$PROVIDER" in
    gemini)
      local MODEL="${KIRO_EVAL_MODEL:-gemini-2.0-flash}"
      local BODY=$(jq -n --arg text "$PROMPT" --argjson max "$MAX_TOKENS" \
        '{contents:[{parts:[{text:$text}]}],generationConfig:{maxOutputTokens:$max}}')
      curl -s --max-time "$TIMEOUT" \
        "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
        -H "content-type: application/json" -d "$BODY" \
        2>/dev/null | jq -r '.candidates[0].content.parts[0].text // "EVAL_FAILED"' ;;
    anthropic)
      local MODEL="${KIRO_EVAL_MODEL:-claude-haiku-4}"
      local BODY=$(jq -n --arg model "$MODEL" --argjson max "$MAX_TOKENS" --arg text "$PROMPT" \
        '{model:$model,max_tokens:$max,messages:[{role:"user",content:$text}]}')
      curl -s --max-time "$TIMEOUT" https://api.anthropic.com/v1/messages \
        -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
        -d "$BODY" 2>/dev/null | jq -r '.content[0].text // "EVAL_FAILED"' ;;
    openai)
      local MODEL="${KIRO_EVAL_MODEL:-gpt-4o-mini}"
      local BODY=$(jq -n --arg model "$MODEL" --argjson max "$MAX_TOKENS" --arg text "$PROMPT" \
        '{model:$model,max_tokens:$max,messages:[{role:"user",content:$text}]}')
      curl -s --max-time "$TIMEOUT" https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" -H "content-type: application/json" \
        -d "$BODY" 2>/dev/null | jq -r '.choices[0].message.content // "EVAL_FAILED"' ;;
    ollama)
      local MODEL="${KIRO_EVAL_MODEL:-llama3.2}"
      local BODY=$(jq -n --arg model "$MODEL" --arg text "$PROMPT" \
        '{model:$model,prompt:$text,stream:false}')
      curl -s --max-time "$TIMEOUT" http://localhost:11434/api/generate \
        -d "$BODY" 2>/dev/null | jq -r '.response // "EVAL_FAILED"' ;;
    none) echo "NO_LLM" ;;
  esac
}
