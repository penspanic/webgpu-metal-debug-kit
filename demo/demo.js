import { initDebugHelpers, frameStart, frameEnd, trackTexture, getDebugMode } from '../assets/webgpu-debug-helpers.js';

async function main() {
  // --- WebGPU 초기화 ---
  if (!navigator.gpu) {
    document.getElementById('info').innerHTML = '<h2>WebGPU not supported</h2><p>Use Chrome 113+ with --enable-unsafe-webgpu</p>';
    return;
  }

  const adapter = await navigator.gpu.requestAdapter();
  const device = await adapter.requestDevice();
  const canvas = document.getElementById('canvas');
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  const context = canvas.getContext('webgpu');
  const format = navigator.gpu.getPreferredCanvasFormat();
  context.configure({ device, format, alphaMode: 'premultiplied' });

  // --- Debug Helpers 초기화 ---
  initDebugHelpers(device);

  // --- 간단한 Raymarching 셰이더 ---
  const shaderCode = `
    struct Uniforms {
      resolution: vec2f,
      time: f32,
      debugMode: u32,
    };

    @group(0) @binding(0) var<uniform> u: Uniforms;

    @vertex
    fn vs(@builtin(vertex_index) i: u32) -> @builtin(position) vec4f {
      // Full-screen triangle
      let x = f32(i32(i) - 1);
      let y = f32(i32(i & 1u) * 2 - 1);
      return vec4f(x, y, 0.0, 1.0);
    }

    // SDF: 반복되는 구
    fn sceneSDF(p: vec3f) -> f32 {
      let q = fract(p) - 0.5;
      return length(q) - 0.15;
    }

    @fragment
    fn fs(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
      let uv = (fragCoord.xy - u.resolution * 0.5) / u.resolution.y;

      // 카메라
      let ro = vec3f(u.time * 0.3, sin(u.time * 0.2) * 0.5, u.time * 0.5);
      let rd = normalize(vec3f(uv, 1.0));

      // Raymarch
      var t = 0.0;
      var steps = 0u;
      let maxSteps = 64u;
      var hit = false;

      for (var i = 0u; i < maxSteps; i++) {
        let p = ro + rd * t;
        let d = sceneSDF(p);
        if (d < 0.001) { hit = true; break; }
        if (t > 20.0) { break; }
        t += d;
        steps++;
      }

      // 디버그 모드
      if (u.debugMode == 1u) {
        // Render path: hit=파랑, miss=빨강
        if (hit) { return vec4f(0.2, 0.5, 1.0, 1.0); }
        return vec4f(0.1, 0.1, 0.1, 1.0);
      }
      if (u.debugMode == 2u) {
        // Step heatmap
        let heat = f32(steps) / f32(maxSteps);
        return vec4f(heat, 1.0 - heat, 0.0, 1.0);
      }
      if (u.debugMode == 3u) {
        // Depth
        let d = clamp(t / 20.0, 0.0, 1.0);
        return vec4f(d, d, d, 1.0);
      }

      // 일반 렌더링
      if (!hit) {
        let sky = mix(vec3f(0.1, 0.1, 0.2), vec3f(0.3, 0.2, 0.4), uv.y + 0.5);
        return vec4f(sky, 1.0);
      }

      let p = ro + rd * t;
      let e = vec2f(0.001, 0.0);
      let n = normalize(vec3f(
        sceneSDF(p + e.xyy) - sceneSDF(p - e.xyy),
        sceneSDF(p + e.yxy) - sceneSDF(p - e.yxy),
        sceneSDF(p + e.yyx) - sceneSDF(p - e.yyx),
      ));

      if (u.debugMode == 4u) {
        return vec4f(n * 0.5 + 0.5, 1.0);
      }

      let light = normalize(vec3f(1.0, 2.0, -1.0));
      let diff = max(dot(n, light), 0.0);
      let amb = 0.15;
      let col = vec3f(0.4, 0.7, 1.0) * (diff + amb);
      return vec4f(col, 1.0);
    }
  `;

  const shaderModule = device.createShaderModule({ code: shaderCode });

  // --- Uniform Buffer ---
  const uniformBuffer = device.createBuffer({
    size: 16,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });

  // --- Pipeline ---
  const pipeline = device.createRenderPipeline({
    layout: 'auto',
    vertex: { module: shaderModule, entryPoint: 'vs' },
    fragment: {
      module: shaderModule,
      entryPoint: 'fs',
      targets: [{ format }],
    },
    primitive: { topology: 'triangle-list' },
  });

  const bindGroup = device.createBindGroup({
    layout: pipeline.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: uniformBuffer } }],
  });

  // 텍스처 추적 등록 (데모용)
  trackTexture('uniformBuffer', uniformBuffer);

  // --- Render Loop ---
  const startTime = performance.now();
  const fpsEl = document.getElementById('fps');

  function render() {
    frameStart();

    const time = (performance.now() - startTime) / 1000;
    const data = new ArrayBuffer(16);
    const view = new DataView(data);
    view.setFloat32(0, canvas.width, true);
    view.setFloat32(4, canvas.height, true);
    view.setFloat32(8, time, true);
    view.setUint32(12, getDebugMode(), true);
    device.queue.writeBuffer(uniformBuffer, 0, data);

    const commandEncoder = device.createCommandEncoder();
    const textureView = context.getCurrentTexture().createView();
    const pass = commandEncoder.beginRenderPass({
      colorAttachments: [{
        view: textureView,
        clearValue: { r: 0, g: 0, b: 0, a: 1 },
        loadOp: 'clear',
        storeOp: 'store',
      }],
    });

    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.draw(3);
    pass.end();

    device.queue.submit([commandEncoder.finish()]);

    frameEnd();

    // FPS 표시
    if (window.__gpu) {
      const s = window.__gpu.stats();
      fpsEl.textContent = `FPS: ${s.fps} | avg: ${s.avgMs}ms | debug: ${s.debugMode}`;
    }

    requestAnimationFrame(render);
  }

  requestAnimationFrame(render);
}

main().catch(e => {
  document.getElementById('info').innerHTML = `<h2>Error</h2><pre>${e.message}\n${e.stack}</pre>`;
});
