#!/bin/bash
set -euo pipefail

# Capture Metal System Trace from Chrome GPU process
#
# Usage:
#   ./capture-metal-trace.sh              # 10s capture
#   ./capture-metal-trace.sh 5            # 5s capture
#   ./capture-metal-trace.sh 10 out.trace # custom output

DURATION="${1:-10}"
OUTPUT="${2:-/tmp/webgpu-metal-trace.trace}"

echo "Finding Chrome GPU process..."

# Find GPU helper process
GPU_PID=$(pgrep -f "Google Chrome Helper (GPU)" 2>/dev/null | head -1 || true)

if [ -z "$GPU_PID" ]; then
  # Fallback: look for --type=gpu-process
  GPU_PID=$(pgrep -f "Google Chrome.*--type=gpu-process" 2>/dev/null | head -1 || true)
fi

if [ -z "$GPU_PID" ]; then
  echo "Error: Chrome GPU process not found."
  echo ""
  echo "Make sure Chrome is running with a WebGPU page open."
  echo "Launch Chrome with: ./setup-metal-debug.sh <url>"
  exit 1
fi

echo "GPU process PID: $GPU_PID"

# Remove old trace
rm -rf "$OUTPUT"

# Check Metal System Trace template
if ! xcrun xcrun xctrace list templates 2>/dev/null | grep -q "Metal System Trace"; then
  echo ""
  echo "Error: 'Metal System Trace' template not found."
  echo "Install Metal Toolchain:"
  echo "  xcodebuild -downloadComponent MetalToolchain"
  exit 1
fi

echo "Capturing Metal System Trace for ${DURATION}s..."
echo "Output: $OUTPUT"
echo ""

xcrun xcrun xctrace record \
  --template 'Metal System Trace' \
  --attach "$GPU_PID" \
  --time-limit "${DURATION}s" \
  --output "$OUTPUT"

echo ""
echo "Capture complete: $OUTPUT"
echo ""
echo "Open in Instruments:"
echo "  open \"$OUTPUT\""
echo ""
echo "Export for AI analysis:"
echo "  xcrun xcrun xctrace export --input \"$OUTPUT\" --toc"
echo "  xcrun xcrun xctrace export --input \"$OUTPUT\" --xpath '/trace-toc/run/data/table[@schema=\"metal-gpu-event\"]'"
