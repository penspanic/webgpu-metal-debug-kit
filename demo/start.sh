#!/bin/bash
# Start demo server and open in Chrome
PORT="${1:-8080}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Starting server at http://localhost:$PORT/demo/"
echo "Press Ctrl+C to stop."
echo ""

# Open browser after a short delay
(sleep 1 && open "http://localhost:$PORT/demo/") &

# Try npx serve first (no CORS issues), fall back to python
if command -v npx &>/dev/null; then
  npx -y serve "$DIR" -l "$PORT" --no-clipboard 2>/dev/null
else
  /usr/bin/python3 -m http.server "$PORT" --directory "$DIR" 2>/dev/null || \
  python3 -m http.server "$PORT" --directory "$DIR"
fi
