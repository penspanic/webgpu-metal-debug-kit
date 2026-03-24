---
name: webgpu-metal-debug-kit
description: "Debug Chrome WebGPU applications on macOS — browser-level via Chrome DevTools MCP, GPU-driver-level via Xcode xctrace Metal System Trace. Use when: WebGPU rendering bugs, GPU performance issues, shader debugging, frame timing analysis, Metal command buffer profiling."
license: MIT
compatibility: "Requires macOS, Chrome 113+, Xcode (for Metal tracing). Chrome DevTools MCP for AI integration."
metadata:
  author: penspanic
  version: "2.0"
  platform: macOS
allowed-tools: Bash(scripts/*) Bash(/usr/bin/xcrun*) Bash(ps*) Bash(kill*) Bash(lsof*) Bash(curl*) Bash(python3*) Bash(open*) Bash(sleep*) mcp__chrome-devtools__evaluate_script mcp__chrome-devtools__take_screenshot mcp__chrome-devtools__navigate_page mcp__chrome-devtools__list_console_messages
---

# WebGPU Metal Debug Kit

Debug Chrome WebGPU applications on macOS at two levels:

1. **Browser level** — Chrome DevTools MCP (`evaluate_script`, `take_screenshot`)
2. **GPU driver level** — Xcode `xctrace` Metal System Trace

## IMPORTANT: Use Only ONE Chrome

Never launch a separate Chrome with `setup-metal-debug.sh` while MCP Chrome is already running.
MCP manages its own Chrome instance. Use that Chrome for everything.

For Metal tracing, capture from the MCP Chrome's GPU process directly:

```bash
# Find GPU PID and capture — just this, no setup-metal-debug.sh needed
GPU_PID=$(pgrep -f "Google Chrome.*--type=gpu-process" | head -1)
/usr/bin/xcrun xctrace record --template 'Metal System Trace' --attach "$GPU_PID" --time-limit 5s --output /tmp/webgpu-metal-trace.trace
```

`setup-metal-debug.sh` is ONLY for standalone use (no MCP) or when using `mcp-settings-metal.json`.

## Prerequisites

- Chrome DevTools MCP configured (see `assets/mcp-settings.json`)
- WebGPU app includes `assets/webgpu-debug-helpers.js` for `window.__gpu` API
- For Metal tracing: Xcode installed. If `Metal System Trace` template is missing:
  ```bash
  xcodebuild -downloadComponent MetalToolchain
  ```

## Workflow

### Step 1: Start the app server

Start an HTTP server for the WebGPU app:

```bash
python3 -m http.server 8080 --directory <app_dir>
```

For the bundled demo:
```bash
python3 -m http.server 8080 --directory <plugin_dir>
```
Note: `file://` URLs won't work due to CORS. Must use HTTP server.

### Step 2: Open the app in MCP Chrome

```
navigate_page → http://localhost:8080/demo/
```

Wait for the page to load, then verify:

```javascript
// evaluate_script
window.__gpu.stats()
```

If `window.__gpu` is not available, the page hasn't loaded the debug helpers.

### Step 3: Browser-level debugging

Use `evaluate_script` to inspect and control:

```javascript
window.__gpu.stats()          // frame timing: fps, avgMs, maxMs, frameGapMs
window.__gpu.setDebugMode(0)  // normal rendering
window.__gpu.setDebugMode(1)  // render path visualization (hit=blue, miss=dark)
window.__gpu.setDebugMode(2)  // step heatmap (green=few, red=many)
window.__gpu.setDebugMode(3)  // depth buffer (dark=near, bright=far)
window.__gpu.setDebugMode(4)  // surface normals (RGB)
window.__gpu.textures()       // tracked texture info
window.__gpu.timings()        // GPU timing records
```

Use `take_screenshot` sparingly — it consumes many tokens. Prefer `evaluate_script` for data.

Use `list_console_messages` to check for WGSL shader errors or WebGPU warnings.

### Step 4: Metal-level profiling (when needed)

When browser debugging shows no JS/shader issue but performance is bad (e.g., frameGapMs >> avgMs), profile at the Metal driver level.

**Find the Chrome GPU process and capture:**

```bash
GPU_PID=$(pgrep -f "Google Chrome.*--type=gpu-process" | head -1)
echo "GPU PID: $GPU_PID"
/usr/bin/xcrun xctrace record \
  --template 'Metal System Trace' \
  --attach "$GPU_PID" \
  --time-limit 5s \
  --output /tmp/webgpu-metal-trace.trace
```

Do NOT use `bash scripts/capture-metal-trace.sh` from within Claude Code — PATH issues may cause template detection to fail. Use the `/usr/bin/xcrun xctrace` command directly as shown above.

**Export and analyze:**

```bash
/usr/bin/xcrun xctrace export --input /tmp/webgpu-metal-trace.trace --toc

# GPU encoder events
/usr/bin/xcrun xctrace export --input /tmp/webgpu-metal-trace.trace \
  --xpath '/trace-toc/run/data/table[@schema="metal-application-encoders-list"]'

# GPU execution points
/usr/bin/xcrun xctrace export --input /tmp/webgpu-metal-trace.trace \
  --xpath '/trace-toc/run/data/table[@schema="metal-gpu-execution-points"]'
```

Parse the XML output to analyze:
- Command buffer count per frame (high count = Dawn translation overhead)
- Encoder types and durations
- GPU execution gaps

### Diagnostic Reference

| Symptom | Check |
|---------|-------|
| Rendering artifacts | `setDebugMode(1)` — which render path is wrong? |
| Shader errors | `list_console_messages` — WGSL compile errors |
| Data not reaching GPU | `__gpu.stats()` — uploadCount, texture sizes |
| Slow despite low GPU/CPU time | Metal trace — command buffer count, Dawn barriers |
| Raymarching hotspots | `setDebugMode(2)` — red = expensive pixels |

## Files

| Path | Description |
|------|-------------|
| `assets/webgpu-debug-helpers.js` | Drop into your app — exposes `window.__gpu` API |
| `assets/debug-shader-snippet.wgsl` | WGSL debug visualization modes |
| `assets/mcp-settings.json` | Chrome DevTools MCP config (default) |
| `assets/mcp-settings-metal.json` | MCP config that attaches to existing Chrome on port 9222 |
| `scripts/setup-metal-debug.sh` | Launch Chrome with Metal flags (standalone use only, not with MCP) |
| `scripts/capture-metal-trace.sh` | Metal trace capture script (standalone use) |
| `references/debug-modes.md` | Debug mode reference |
| `demo/` | WebGPU raymarching demo |
