#!/bin/bash
set -euo pipefail

# webgpu-metal-debug-kit 플러그인 재설치 원커맨드
# 캐시를 삭제하고 marketplace를 다시 등록한다.
#
# Usage: bash scripts/reinstall-plugin.sh

CACHE_DIR="$HOME/.claude/plugins/cache/webgpu-metal-debug-kit"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/penspanic-webgpu-metal-debug-kit"

echo "1. Clearing plugin cache..."
rm -rf "$CACHE_DIR"

echo "2. Clearing marketplace cache..."
rm -rf "$MARKETPLACE_DIR"

echo "3. Done! Now in Claude Code run:"
echo ""
echo "   /plugin marketplace add penspanic/webgpu-metal-debug-kit"
echo "   /plugin install webgpu-metal-debug-kit@webgpu-metal-debug-kit"
echo "   /reload-plugins"
