/**
 * WebGPU Debug Helpers
 *
 * 이 파일을 WebGPU 앱에 import하면 AI(Claude Code + Chrome DevTools MCP)가
 * evaluate_script로 GPU 상태를 조회하고 디버그 모드를 전환할 수 있다.
 *
 * Usage:
 *   import { initDebugHelpers } from './webgpu-debug-helpers.js';
 *   initDebugHelpers(device, context);
 *
 * AI가 사용하는 방법 (evaluate_script):
 *   window.__gpu.stats()           // 프레임 통계
 *   window.__gpu.setDebugMode(1)   // 디버그 뷰 전환
 *   window.__gpu.timings()         // GPU 타이밍 (timestamp query 사용 시)
 *   window.__gpu.textures()        // 텍스처 목록 + 크기
 */

const state = {
  device: null,
  debugMode: 0,
  frameCount: 0,
  lastFrameTime: 0,
  frameTimes: [],
  gpuTimings: {},
  textures: new Map(),
  customStats: {},
};

/**
 * 초기화. WebGPU device 생성 후 호출한다.
 */
export function initDebugHelpers(device, options = {}) {
  state.device = device;

  window.__gpu = {
    /** 프레임 통계 반환 */
    stats() {
      const times = state.frameTimes.slice(-60);
      const avg = times.length ? times.reduce((a, b) => a + b, 0) / times.length : 0;
      const max = times.length ? Math.max(...times) : 0;
      const min = times.length ? Math.min(...times) : 0;
      return {
        frameCount: state.frameCount,
        fps: avg > 0 ? (1000 / avg).toFixed(1) : 0,
        avgMs: avg.toFixed(2),
        maxMs: max.toFixed(2),
        minMs: min.toFixed(2),
        debugMode: state.debugMode,
        ...state.customStats,
      };
    },

    /** 디버그 렌더 모드 전환 (0=normal, 1=render path, 2=step heatmap, 3=depth, 4=normals) */
    setDebugMode(mode) {
      state.debugMode = mode;
      return `debugMode set to ${mode}`;
    },

    /** 현재 디버그 모드 */
    getDebugMode() {
      return state.debugMode;
    },

    /** GPU 타이밍 조회 (timestamp query 등록 시) */
    timings() {
      return { ...state.gpuTimings };
    },

    /** 등록된 텍스처 목록 */
    textures() {
      const result = {};
      for (const [name, tex] of state.textures) {
        result[name] = {
          width: tex.width,
          height: tex.height,
          depthOrArrayLayers: tex.depthOrArrayLayers,
          format: tex.format,
          usage: tex.usage,
        };
      }
      return result;
    },

    /** 커스텀 stat 설정 (앱 코드에서 호출) */
    setStat(key, value) {
      state.customStats[key] = value;
    },

    /** raw state 접근 (advanced) */
    _state: state,
  };

  console.log('[webgpu-debug] Helpers initialized. Access via window.__gpu');
}

/**
 * 매 프레임 호출하여 타이밍을 기록한다.
 * requestAnimationFrame 콜백 시작 부분에서 호출.
 */
export function frameStart() {
  state._frameStartTime = performance.now();
}

/**
 * 매 프레임 끝에서 호출.
 */
export function frameEnd() {
  const now = performance.now();
  if (state._frameStartTime) {
    const dt = now - state._frameStartTime;
    state.frameTimes.push(dt);
    if (state.frameTimes.length > 300) state.frameTimes.shift();
  }
  if (state.lastFrameTime > 0) {
    state.customStats.frameGapMs = (now - state.lastFrameTime).toFixed(2);
  }
  state.lastFrameTime = now;
  state.frameCount++;
}

/**
 * 텍스처를 디버그 추적에 등록한다.
 */
export function trackTexture(name, texture) {
  state.textures.set(name, texture);
}

/**
 * GPU 타이밍 기록 (수동).
 */
export function recordTiming(name, ms) {
  state.gpuTimings[name] = ms;
}

/**
 * 현재 디버그 모드를 반환한다. 셰이더 uniform에 넘기기 위해 사용.
 */
export function getDebugMode() {
  return state.debugMode;
}
