// WebGPU Debug Shader Snippet
//
// 이 코드를 fragment shader에 삽입하면 디버그 모드에 따라
// 렌더링 경로, step heatmap, depth, normals를 시각화할 수 있다.
//
// uniform에 debugMode: u32를 추가하고,
// JS에서 window.__gpu.setDebugMode(N)으로 전환한다.

// --- Uniform 구조체에 추가 ---
// struct Uniforms {
//     ...
//     debugMode: u32,
// };

// --- Fragment shader 끝부분에 삽입 ---

// 디버그 모드 분기
fn applyDebugMode(
    color: vec4f,        // 원래 렌더링 결과
    debugMode: u32,
    steps: u32,          // 레이마칭 step 수
    maxSteps: u32,       // 최대 step
    depth: f32,          // 정규화된 깊이 (0~1)
    normal: vec3f,       // 월드 노멀
    renderPath: u32,     // 0=sky, 1=DDA, 2=heightmap, 3=entity
) -> vec4f {

    // 0: 일반 렌더링
    if (debugMode == 0u) {
        return color;
    }

    // 1: 렌더 경로 시각화
    if (debugMode == 1u) {
        switch (renderPath) {
            case 0u: { return vec4f(0.1, 0.1, 0.1, 1.0); }  // sky = 어두운 회색
            case 1u: { return vec4f(0.2, 0.5, 1.0, 1.0); }  // DDA = 파랑
            case 2u: { return vec4f(0.2, 1.0, 0.3, 1.0); }  // heightmap = 초록
            case 3u: { return vec4f(1.0, 0.8, 0.2, 1.0); }  // entity = 노랑
            default: { return vec4f(1.0, 0.0, 1.0, 1.0); }  // unknown = 마젠타
        }
    }

    // 2: 레이마칭 step heatmap (초록=적음, 빨강=많음)
    if (debugMode == 2u) {
        let heat = f32(steps) / f32(maxSteps);
        return vec4f(heat, 1.0 - heat, 0.0, 1.0);
    }

    // 3: 깊이 시각화
    if (debugMode == 3u) {
        let d = clamp(depth, 0.0, 1.0);
        return vec4f(d, d, d, 1.0);
    }

    // 4: 노멀 시각화 ([-1,1] → [0,1] 매핑)
    if (debugMode == 4u) {
        let n = normal * 0.5 + 0.5;
        return vec4f(n, 1.0);
    }

    return color;
}
