---
name: webgpu-metal-debug-kit
description: "Debug Chrome WebGPU applications on macOS — browser-level via Chrome DevTools MCP, GPU-driver-level via Xcode xctrace Metal System Trace. Use when: WebGPU rendering bugs, GPU performance issues, shader debugging, frame timing analysis, Metal command buffer profiling."
license: MIT
compatibility: "Requires macOS, Chrome 113+, Xcode (for Metal tracing). Chrome DevTools MCP for AI integration."
metadata:
  author: penspanic
  version: "2.1"
  platform: macOS
allowed-tools: Bash Read Grep Glob mcp__chrome-devtools__evaluate_script mcp__chrome-devtools__take_screenshot mcp__chrome-devtools__navigate_page mcp__chrome-devtools__list_console_messages
---

# WebGPU Metal Debug Kit

Debug Chrome WebGPU applications on macOS.

## Environment Check

Metal Toolchain: !`/usr/bin/xcrun xctrace list templates 2>/dev/null | grep -q "Metal System Trace" && echo "installed" || echo "NOT INSTALLED — run: xcodebuild -downloadComponent MetalToolchain"`
Chrome GPU process: !`pgrep -f "Google Chrome.*--type=gpu-process" | head -1 || echo "none"`
Plugin dir: ${CLAUDE_SKILL_DIR}/../..

## Rules

1. **ONE Chrome only.** MCP manages Chrome. Never run `setup-metal-debug.sh`. Never launch Chrome manually.
2. **Wait after navigate.** After `navigate_page`, `sleep 2` then check `window.__gpu`. ES modules need time to load.
3. **`evaluate_script` over `take_screenshot`.** Stats call = few tokens. Screenshot = ~1MB tokens.
4. **Metal trace: direct command only.** Never use `bash scripts/capture-metal-trace.sh` — PATH issues in Claude Code cause false "template not found". Always use `/usr/bin/xcrun xctrace` directly.
5. **404 for favicon.ico is normal.** The demo has no favicon. Ignore it.

## Workflow

### Step 1: Start demo server

```bash
python3 -m http.server 8080 --directory ${CLAUDE_SKILL_DIR}/../..
```

Or for a user's app:
```bash
python3 -m http.server 8080 --directory <app_dir>
```

### Step 2: Open in MCP Chrome + verify

```
navigate_page → http://localhost:8080/demo/
```

Then wait and verify:

```bash
sleep 2
```

```javascript
// evaluate_script — if this returns error, wait and retry
() => window.__gpu ? window.__gpu.stats() : 'loading...'
```

### Step 3: Debug modes

Cycle through all modes, collecting stats and screenshots:

```javascript
window.__gpu.setDebugMode(0)  // normal
window.__gpu.setDebugMode(1)  // render path (blue=hit, dark=miss)
window.__gpu.setDebugMode(2)  // step heatmap (green=few, red=many)
window.__gpu.setDebugMode(3)  // depth (dark=near, bright=far)
window.__gpu.setDebugMode(4)  // normals (RGB)
```

### Step 4: Metal trace (when needed)

When `frameGapMs` >> `avgMs`, there's a driver-level bottleneck.

```bash
GPU_PID=$(pgrep -f "Google Chrome.*--type=gpu-process" | head -1)
echo "GPU PID: $GPU_PID"
/usr/bin/xcrun xctrace record \
  --template 'Metal System Trace' \
  --attach "$GPU_PID" \
  --time-limit 5s \
  --output /tmp/webgpu-metal-trace.trace
```

Export for analysis:

```bash
/usr/bin/xcrun xctrace export --input /tmp/webgpu-metal-trace.trace --toc | grep schema

/usr/bin/xcrun xctrace export --input /tmp/webgpu-metal-trace.trace \
  --xpath '/trace-toc/run/data/table[@schema="metal-application-encoders-list"]'
```

Look for:
- Command buffer count per frame (high = Dawn overhead)
- Encoder durations (long = GPU bottleneck)
- Gaps between GPU executions (stalls)

### Diagnostic Reference

| Symptom | Action |
|---------|--------|
| Artifacts | `setDebugMode(1)` — which path is wrong? |
| Shader error | `list_console_messages` |
| Data missing on GPU | `__gpu.stats()` — check uploadCount |
| Slow, GPU time fine | Metal trace — command buffer count |
| Hot pixels | `setDebugMode(2)` — red = expensive |

## Files

| Path | For |
|------|-----|
| `assets/webgpu-debug-helpers.js` | Add to your app — `window.__gpu` API |
| `assets/debug-shader-snippet.wgsl` | Debug visualization shader code |
| `references/debug-modes.md` | Detailed mode docs |
| `demo/` | Working demo with everything integrated |
| `scripts/setup-metal-debug.sh` | Standalone Chrome launch (NOT for MCP use) |
| `scripts/capture-metal-trace.sh` | Standalone capture (NOT for Claude Code use) |
