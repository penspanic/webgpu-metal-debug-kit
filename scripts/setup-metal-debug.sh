#!/bin/bash
set -euo pipefail

# Chrome WebGPU Metal Debug Setup
#
# Launches Chrome with flags that enable Metal debugging and xctrace attach.
# No Chrome copy needed — uses your installed Chrome directly.
#
# Usage:
#   ./setup-metal-debug.sh                    # Launch Chrome for Metal debugging
#   ./setup-metal-debug.sh <url>              # Launch with specific URL
#   ./setup-metal-debug.sh --help
#
# Environment:
#   CHROME_REMOTE_DEBUG_PORT  Remote debugging port (default: 9222)

REMOTE_DEBUG_PORT="${CHROME_REMOTE_DEBUG_PORT:-9222}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILE_DIR="/tmp/chrome-metal-debug-profile"
URL="${1:-}"

case "${URL}" in
  --help|-h)
    cat <<USAGE
Usage: $0 [url]

Launches Chrome with Metal debugging enabled.
xctrace can attach to the GPU process for Metal System Trace capture.

Flags applied:
  --disable-gpu-sandbox          Allow xctrace to access GPU process
  --enable-unsafe-webgpu         Enable WebGPU API
  --enable-dawn-features=use_user_defined_labels_in_backend
                                 Show debug labels in Xcode Metal Debugger
  --use-mock-keychain            Suppress keychain access popups
  MTL_CAPTURE_ENABLED=1          Enable Metal frame capture

Environment:
  CHROME_REMOTE_DEBUG_PORT  Remote debugging port (default: 9222)

Example:
  $0 http://localhost:8080/demo/
  $0  # opens blank tab

After Chrome is running, capture Metal trace:
  ./capture-metal-trace.sh 10
USAGE
    exit 0
    ;;
  --clean)
    echo "Cleaning debug profile..."
    rm -rf "$PROFILE_DIR"
    echo "Done."
    exit 0
    ;;
esac

# Check Chrome exists
if [ ! -f "$CHROME" ]; then
  echo "Error: Chrome not found at $CHROME"
  exit 1
fi

# Check Metal Toolchain
if ! xcrun xctrace list templates 2>/dev/null | grep -q "Metal System Trace"; then
  echo "Warning: 'Metal System Trace' template not found."
  echo "Install Metal Toolchain:"
  echo "  xcodebuild -downloadComponent MetalToolchain"
  echo ""
fi

echo "Launching Chrome for Metal debugging..."
echo "  Remote debugging: port $REMOTE_DEBUG_PORT"
echo "  Profile: $PROFILE_DIR"
[ -n "$URL" ] && echo "  URL: $URL"
echo ""
echo "After Chrome opens, capture Metal trace with:"
echo "  ./scripts/capture-metal-trace.sh 10"
echo ""

MTL_CAPTURE_ENABLED=1 \
"$CHROME" \
  --disable-gpu-sandbox \
  --enable-unsafe-webgpu \
  --enable-dawn-features=use_user_defined_labels_in_backend \
  --disable-dawn-features=disallow_unsafe_apis \
  --remote-debugging-port="$REMOTE_DEBUG_PORT" \
  --user-data-dir="$PROFILE_DIR" \
  --use-mock-keychain \
  --no-first-run \
  --disable-sync \
  ${URL:+"$URL"}
