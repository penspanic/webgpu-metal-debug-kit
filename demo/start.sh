#!/bin/bash
# Start demo server on an available port
# Usage: bash demo/start.sh [--no-open]

NO_OPEN=false
for arg in "$@"; do [ "$arg" = "--no-open" ] && NO_OPEN=true; done

DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Find an available port
PORT=$(/usr/bin/python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")

echo "Starting server at http://localhost:$PORT/demo/"

# Start server in background
/usr/bin/python3 -m http.server "$PORT" --directory "$DIR" 2>/dev/null &
SERVER_PID=$!

# Wait until server is ready
for i in $(seq 1 10); do
  if curl -s -o /dev/null "http://localhost:$PORT/demo/" 2>/dev/null; then
    echo "Server ready: http://localhost:$PORT/demo/"
    echo "Press Ctrl+C to stop."
    [ "$NO_OPEN" = false ] && open "http://localhost:$PORT/demo/"
    wait $SERVER_PID
    exit 0
  fi
  sleep 1
done

echo "Error: Server failed to start"
kill $SERVER_PID 2>/dev/null
exit 1
