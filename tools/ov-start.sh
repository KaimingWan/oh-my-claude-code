#!/bin/bash
# @desc One-click OpenViking daemon launcher (background, non-blocking)
# @usage ./tools/ov-start.sh [--index-knowledge]
# @arg --index-knowledge  Index all knowledge/ files after daemon starts
TOOL_SCRIPT="${BASH_SOURCE[0]}"
source "$(dirname "$0")/_lib/tool-header.sh" "$@"
set -e
set -- "${TOOL_ARGS[@]}"

SOCKET="/tmp/omk-ov.sock"
PID_FILE="/tmp/omk-ov.pid"
LOG_FILE="/tmp/omk-ov.log"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Already running?
if [ -S "$SOCKET" ]; then
  RESP=$(python3 -c "
import socket,json,sys
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
s.settimeout(2)
try:
  s.connect('$SOCKET')
  s.sendall(json.dumps({'cmd':'health'}).encode())
  print(s.recv(65536).decode())
except: print('{\"ok\":false}')
finally: s.close()
" 2>/dev/null)
  if echo "$RESP" | grep -q '"ok": *true'; then
    echo "✅ OV daemon already running"
    exit 0
  fi
  # Stale socket
  kill "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null || true
  rm -f "$SOCKET"
fi

# Launch in background
cd "$PROJECT_DIR"
# Load API keys from zshrc (non-interactive extract)
eval "$(grep -E '^export (AZURE_OPENAI|OPENAI_|OPENVIKING_|OLLAMA_|OV_EMBEDDING)' ~/.zshrc 2>/dev/null)" || true
nohup python3 scripts/ov-daemon.py > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "🚀 OV daemon starting (PID $(cat "$PID_FILE"), log: $LOG_FILE)"

# Wait for ready (max 15s, non-blocking poll)
for i in $(seq 1 15); do
  sleep 1
  if [ -S "$SOCKET" ]; then
    echo "✅ OV daemon ready (${i}s)"
    # Always index lesson scenarios (lightweight, ~30 files)
    if [ -d "$PROJECT_DIR/knowledge/lesson-scenarios" ]; then
      python3 "$PROJECT_DIR/tools/generate-lesson-scenarios.py" --index-only 2>/dev/null && echo "📚 Lesson scenarios indexed" || true
    fi
    # Optional: index all knowledge
    if [ "$1" = "--index-knowledge" ]; then
      echo "📚 Indexing knowledge/..."
      find "$PROJECT_DIR/knowledge" -type f \( -name "*.md" -o -name "*.pdf" -o -name "*.txt" \) | while read -r f; do
        REL="${f#$PROJECT_DIR/}"
        python3 -c "
import socket,json,sys
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
s.settimeout(30)
s.connect('$SOCKET')
s.sendall(json.dumps({'cmd':'add_resource','path':'$f','reason':'knowledge index'}).encode())
r=s.recv(65536).decode()
s.close()
ok='✓' if '\"ok\": true' in r or '\"ok\":true' in r else '✗ '+r
print(f'{ok} {sys.argv[1]}')
" "$REL" 2>/dev/null
      done
      echo "✅ Knowledge indexing complete"
    fi
    exit 0
  fi
done

echo "⚠️ OV daemon did not start in 15s. Check $LOG_FILE"
exit 1
