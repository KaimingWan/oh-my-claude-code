#!/bin/bash
# Tavily Research API script
# Usage: ./research.sh '{"input": "your query", ...}' [output_file]

set -e

JSON_INPUT="$1"
OUTPUT_FILE="$2"

if [ -z "$JSON_INPUT" ]; then
    echo "Usage: ./research.sh '<json>' [output_file]"
    echo ""
    echo "Required: input (string)"
    echo "Optional: model (mini|pro|auto), citation_format (numbered|mla|apa|chicago)"
    echo ""
    echo "Example: ./research.sh '{\"input\": \"AI frameworks comparison\", \"model\": \"pro\"}'"
    exit 1
fi

if [ -z "$TAVILY_API_KEY" ]; then
    echo "Error: TAVILY_API_KEY not set. Get one at https://tavily.com"
    exit 1
fi

if ! echo "$JSON_INPUT" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON input"
    exit 1
fi

if ! echo "$JSON_INPUT" | jq -e '.input' >/dev/null 2>&1; then
    echo "Error: 'input' field is required"
    exit 1
fi

JSON_INPUT=$(echo "$JSON_INPUT" | jq '. + {stream: false} | if .citation_format == null then . + {citation_format: "numbered"} else . end')

INPUT=$(echo "$JSON_INPUT" | jq -r '.input')
MODEL=$(echo "$JSON_INPUT" | jq -r '.model // "auto"')

echo "Researching: $INPUT (model: $MODEL)"
echo "This may take 30-120 seconds..."

RESPONSE=$(curl -sN --request POST \
    --url https://api.tavily.com/research \
    --header "Authorization: Bearer $TAVILY_API_KEY" \
    --header 'Content-Type: application/json' \
    --data "$JSON_INPUT" 2>&1)

if [ -n "$OUTPUT_FILE" ]; then
    echo "$RESPONSE" > "$OUTPUT_FILE"
    echo "Results saved to: $OUTPUT_FILE"
else
    echo "$RESPONSE"
fi
