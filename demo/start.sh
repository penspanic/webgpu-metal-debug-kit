#!/bin/bash
# Start demo server
# Usage: bash demo/start.sh [port] [--no-open]

PORT="${1:-8080}"
NO_OPEN=false
for arg in "$@"; do [ "$arg" = "--no-open" ] && NO_OPEN=true; done

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Kill existing server on this port
lsof -ti:"$PORT" 2>/dev/null | xargs kill -9 2>/dev/null
sleep 1

echo "Starting server at http://localhost:$PORT/demo/"

# Start server in background
if command -v npx &>/dev/null; then
  npx -y serve "$DIR" -l "$PORT" --no-clipboard 2>/dev/null &
else
  /usr/bin/python3 -m http.server "$PORT" --directory "$DIR" 2>/dev/null &
fi
SERVER_PID=$!

# Wait until server is ready
for i in $(seq 1 10); do
  if curl -s -o /dev/null -w "" "http://localhost:$PORT/demo/" 2>/dev/null; then
    echo "Server ready: http://localhost:$PORT/demo/"
    echo "Press Ctrl+C to stop."
    [ "$NO_OPEN" = false ] && open "http://localhost:$PORT/demo/"
    wait $SERVER_PID
    exit 0
  fi
  sleep 1
done

echo "Error: Server failed to start on port $PORT"
kill $SERVER_PID 2>/dev/null
exit 1
