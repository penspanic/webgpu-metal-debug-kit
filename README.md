# webgpu-metal-debug-kit

[![Agent Skill](https://img.shields.io/badge/agent--skill-v1.0-blue)](https://agentskills.io)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)]()
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A toolkit for debugging Chrome WebGPU applications on macOS with AI coding assistants. Combines **Chrome DevTools MCP** for browser-level debugging with **Xcode `xctrace`** for Metal driver-level profiling.

## Why

WebGPU debugging is hard:
- No `printf` in shaders
- GPU timing doesn't show up in JS profilers
- When something renders wrong, you can't tell which stage broke
- Some bottlenecks are invisible from the browser (Dawn/Metal translation overhead)

This kit solves these by giving your AI assistant direct access to browser state (`evaluate_script`) and GPU driver traces (`xctrace`).

## Install

### Claude Code Plugin (recommended)

```bash
# In Claude Code, run:
/plugin install webgpu-metal-debug-kit
```

Or add the marketplace source first:

```bash
/plugin marketplace add penspanic/webgpu-metal-debug-kit
/plugin install webgpu-metal-debug-kit
```

### As Agent Skill (manual)

```bash
git clone https://github.com/penspanic/webgpu-metal-debug-kit.git \
  ~/.claude/skills/webgpu-metal-debug-kit
```

Works with any agent that supports the [Agent Skills](https://agentskills.io) standard (Claude Code, Codex CLI, Cursor, VS Code Copilot, etc.).

## Manual Usage

Even without an AI assistant, the individual tools are useful:

### Debug Helpers

Add `assets/webgpu-debug-helpers.js` to your app:

```javascript
import { initDebugHelpers, frameStart, frameEnd, getDebugMode } from './webgpu-debug-helpers.js';

initDebugHelpers(device);

function render() {
  frameStart();
  // ... pass getDebugMode() to shader uniforms ...
  frameEnd();
  requestAnimationFrame(render);
}
```

Then in the console:

```javascript
__gpu.stats()          // frame timing
__gpu.setDebugMode(2)  // step heatmap
__gpu.textures()       // texture info
```

### Metal Tracing

```bash
# Prepare Chrome (strips code signing for xctrace attach)
bash scripts/setup-metal-debug.sh

# Capture 10 seconds of Metal trace
bash scripts/capture-metal-trace.sh 10

# Analyze
open /tmp/webgpu-metal-trace.trace
```

## Debug Modes

| Mode | Visualization | Use Case |
|------|--------------|----------|
| 0 | Normal | Default rendering |
| 1 | Render path | Which shader path rendered each pixel |
| 2 | Step heatmap | Raymarching performance hotspots |
| 3 | Depth | Depth buffer visualization |
| 4 | Normals | Surface normal visualization |

See [references/debug-modes.md](references/debug-modes.md) for details.

## File Structure

```
webgpu-metal-debug-kit/
├── SKILL.md                              # Agent skill entry point
├── README.md                             # This file
├── LICENSE
├── scripts/
│   ├── setup-metal-debug.sh              # Chrome code-sign removal
│   └── capture-metal-trace.sh            # xctrace capture
├── assets/
│   ├── webgpu-debug-helpers.js           # window.__gpu API
│   ├── debug-shader-snippet.wgsl         # WGSL debug visualization
│   └── mcp-settings.json                 # Chrome DevTools MCP config
├── references/
│   └── debug-modes.md                    # Debug mode reference
└── demo/
    ├── index.html                        # Demo page
    └── demo.js                           # Raymarching + debug helpers
```

## Demo

```bash
bash demo/start.sh
# Opens http://localhost:8080/demo/ in Chrome automatically
```

Or manually:

```bash
python3 -m http.server 8080
# Open http://localhost:8080/demo/ in Chrome
```

> **Note:** Opening `demo/index.html` directly as a file (`file://...`) won't work — ES modules require a server due to CORS. Use the commands above.

## Requirements

- **macOS** (Metal tracing is macOS-only)
- **Chrome 113+** with WebGPU support
- **Xcode** with Metal Toolchain (for `xctrace`)
- **Chrome DevTools MCP** (for AI integration)

## License

MIT
