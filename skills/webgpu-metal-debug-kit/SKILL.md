---
name: webgpu-metal-debug-kit
description: "Debug Chrome WebGPU applications on macOS — browser-level via Chrome DevTools MCP, GPU-driver-level via Xcode xctrace Metal System Trace. Use when: WebGPU rendering bugs, GPU performance issues, shader debugging, frame timing analysis, Metal command buffer profiling."
license: MIT
compatibility: "Requires macOS, Chrome 113+, Xcode (for Metal tracing). Chrome DevTools MCP for AI integration."
metadata:
  author: penspanic
  version: "1.1"
  platform: macOS
allowed-tools: Bash(scripts/*) mcp__chrome-devtools__evaluate_script mcp__chrome-devtools__take_screenshot mcp__chrome-devtools__navigate_page mcp__chrome-devtools__list_console_messages
---

# WebGPU Metal Debug Kit

Debug Chrome WebGPU applications on macOS at two levels:

1. **Browser level** — Chrome DevTools MCP (`evaluate_script`, `take_screenshot`)
2. **GPU driver level** — Xcode `xctrace` Metal System Trace

## Important: Chrome and MCP Integration

`setup-metal-debug.sh` launches Chrome with `--remote-debugging-port=9222`.

**To use MCP with this Chrome (single Chrome, recommended for Metal debugging):**
Configure MCP with `--browser-url=http://127.0.0.1:9222` so it attaches to the Metal Debug Chrome instead of launching a new one. See `assets/mcp-settings-metal.json`.

**If MCP is configured without `--browser-url` (default):**
MCP launches its own Chrome. You'll have two Chrome windows — one for MCP (browser debugging) and one for Metal tracing. In this case, launch `setup-metal-debug.sh` separately and use `capture-metal-trace.sh` on that Chrome's GPU process.

## Prerequisites

- Chrome DevTools MCP must be configured.
  - Default (browser debugging only): `assets/mcp-settings.json`
  - Unified (browser + Metal): `assets/mcp-settings-metal.json`
- The WebGPU app should include `assets/webgpu-debug-helpers.js` for the `window.__gpu` API.
- For Metal tracing: Xcode must be installed. If `Metal System Trace` template is missing, run:
  ```bash
  xcodebuild -downloadComponent MetalToolchain
  ```

## Debugging Workflow

### Level 1: Browser — Chrome DevTools MCP

Use `evaluate_script` to query app state and switch debug views:

```javascript
window.__gpu.stats()          // { fps, avgMs, maxMs, debugMode, frameGapMs }
window.__gpu.setDebugMode(N)  // 0=normal, 1=render path, 2=step heatmap, 3=depth, 4=normals
window.__gpu.textures()       // tracked textures with dimensions and format
window.__gpu.timings()        // GPU timing records
window.__gpu.setStat(k, v)    // app can expose custom stats
```

**Debugging loop:**

1. `navigate_page` → open the WebGPU app
2. `evaluate_script` → `window.__gpu.stats()` to check frame timing
3. `evaluate_script` → `window.__gpu.setDebugMode(1)` to visualize render paths
4. `take_screenshot` → visually confirm (use sparingly — prefer evaluate_script for data)
5. `list_console_messages` → check for shader compilation errors or WebGPU warnings
6. Fix code → `navigate_page` reload (ignoreCache: true) → repeat

**Prefer `evaluate_script` over `take_screenshot`.** A stats() call is a few tokens; a screenshot is ~1MB of image tokens.

### Level 2: GPU Driver — Xcode xctrace

When browser-level debugging shows no JS/shader bottleneck but frames are still slow (e.g., GPU time is fast but frame gap is large), go to Metal level.

**Step 1: Launch Chrome with Metal debugging flags**

```bash
bash scripts/setup-metal-debug.sh http://localhost:8080
```

This launches Chrome with `--disable-gpu-sandbox`, `MTL_CAPTURE_ENABLED=1`, `--remote-debugging-port=9222`, and Dawn debug labels.

**Step 2: Capture Metal System Trace**

```bash
bash scripts/capture-metal-trace.sh 5
```

The script automatically finds the Chrome GPU process with `--disable-gpu-sandbox` flag.

**If the script reports "Metal System Trace template not found"** but `xctrace list templates` shows it exists, the PATH may differ in the script's execution environment. Try running directly:

```bash
/usr/bin/xctrace record --template 'Metal System Trace' --attach <GPU_PID> --time-limit 5s --output /tmp/webgpu-metal-trace.trace
```

**Step 3: Export trace data for analysis**

```bash
xctrace export --input /tmp/webgpu-metal-trace.trace --toc
xctrace export --input /tmp/webgpu-metal-trace.trace \
  --xpath '/trace-toc/run/data/table[@schema="metal-gpu-execution-points"]'
```

Read the exported XML to analyze command buffer counts, encoding times, and GPU wait times.

### What to look for at each level

| Symptom | Level | What to check |
|---------|-------|---------------|
| Rendering artifacts | Browser | `setDebugMode(1)` render path, check which pass is wrong |
| Shader compile error | Browser | `list_console_messages`, look for WGSL errors |
| Data not reaching GPU | Browser | `__gpu.stats()` — uploadCount, check texture sizes |
| Slow frames, GPU time is fine | Metal | Command buffer count, Dawn sync barriers |
| Frame gap >> GPU+CPU time | Metal | IPC overhead, driver-level stalls |
| Raymarching hotspots | Browser | `setDebugMode(2)` step heatmap |

## Files

| Path | Description |
|------|-------------|
| `scripts/setup-metal-debug.sh` | Launch Chrome with Metal debug flags (--disable-gpu-sandbox, MTL_CAPTURE_ENABLED) |
| `scripts/capture-metal-trace.sh` | One-command Metal System Trace capture |
| `assets/webgpu-debug-helpers.js` | Drop into your app — exposes `window.__gpu` API |
| `assets/debug-shader-snippet.wgsl` | WGSL debug visualization (render path, heatmap, depth, normals) |
| `assets/mcp-settings.json` | Chrome DevTools MCP config (default — launches new Chrome) |
| `assets/mcp-settings-metal.json` | Chrome DevTools MCP config (attaches to Metal Debug Chrome on port 9222) |
| `references/debug-modes.md` | Detailed debug mode reference |
| `demo/` | Minimal WebGPU raymarching demo with everything integrated |
