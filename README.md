# webgpu-metal-debug-kit

[![Agent Skill](https://img.shields.io/badge/agent--skill-v2.0-blue)](https://agentskills.io)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)]()
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A toolkit for debugging Chrome WebGPU applications on macOS with AI coding assistants. Combines **Chrome DevTools MCP** for browser-level debugging with **Xcode `xctrace`** for Metal driver-level profiling.

## Why

WebGPU debugging is hard:
- No `printf` in shaders
- GPU timing doesn't show up in JS profilers
- When something renders wrong, you can't tell which stage broke
- Some bottlenecks are invisible from the browser (Dawn/Metal translation overhead)

This kit gives your AI assistant direct access to browser state (`evaluate_script`) and GPU driver traces (`xctrace`).

## Install

### Claude Code Plugin (recommended)

```bash
/plugin marketplace add penspanic/webgpu-metal-debug-kit
/plugin install webgpu-metal-debug-kit@webgpu-metal-debug-kit
/reload-plugins
```

### As Agent Skill (manual)

```bash
git clone https://github.com/penspanic/webgpu-metal-debug-kit.git \
  ~/.claude/skills/webgpu-metal-debug-kit
```

Works with any agent that supports [Agent Skills](https://agentskills.io) (Claude Code, Codex CLI, Cursor, VS Code Copilot, etc.).

## How It Works

### With AI (Claude Code + MCP)

The AI uses Chrome DevTools MCP to directly control the browser:

```javascript
// AI runs these via evaluate_script
window.__gpu.stats()          // { fps, avgMs, maxMs, frameGapMs }
window.__gpu.setDebugMode(2)  // step heatmap
window.__gpu.textures()       // texture info
```

When browser-level analysis isn't enough, the AI captures Metal traces:

```bash
# AI finds GPU process and runs xctrace directly
GPU_PID=$(pgrep -f "Google Chrome.*--type=gpu-process" | head -1)
/usr/bin/xcrun xctrace record --template 'Metal System Trace' \
  --attach "$GPU_PID" --time-limit 5s --output /tmp/webgpu-metal-trace.trace
```

### Without AI (manual)

```bash
# Start your app
python3 -m http.server 8080

# Launch Chrome with Metal debug flags
bash scripts/setup-metal-debug.sh http://localhost:8080

# Capture Metal trace
bash scripts/capture-metal-trace.sh 5

# Open in Instruments
open /tmp/webgpu-metal-trace.trace
```

In the Chrome console: `__gpu.stats()`, `__gpu.setDebugMode(2)`, etc.

## Integrate Into Your App

Add `assets/webgpu-debug-helpers.js` to your WebGPU app:

```javascript
import { initDebugHelpers, frameStart, frameEnd, getDebugMode } from './webgpu-debug-helpers.js';

initDebugHelpers(device);

function render() {
  frameStart();
  // pass getDebugMode() to your shader uniforms
  frameEnd();
  requestAnimationFrame(render);
}
```

Add `assets/debug-shader-snippet.wgsl` to your shader for debug visualization modes.

## Debug Modes

| Mode | Visualization | Use Case |
|------|--------------|----------|
| 0 | Normal | Default rendering |
| 1 | Render path | Which shader path rendered each pixel |
| 2 | Step heatmap | Raymarching performance hotspots |
| 3 | Depth | Depth buffer visualization |
| 4 | Normals | Surface normal visualization |

See [references/debug-modes.md](references/debug-modes.md) for details.

## Demo

```bash
bash demo/start.sh
# Opens http://localhost:8080/demo/ in Chrome
```

> **Note:** `file://` URLs won't work due to CORS. Use an HTTP server.

## Requirements

- **macOS** (Metal tracing is macOS-only)
- **Chrome 113+** with WebGPU
- **Xcode** + Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain` if template missing)
- **Chrome DevTools MCP** (for AI integration)

## License

MIT
