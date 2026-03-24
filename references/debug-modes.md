# Debug Modes Reference

## Overview

Debug modes replace normal rendering output with diagnostic visualizations. Switch modes via:

```javascript
window.__gpu.setDebugMode(N)
```

The current mode is available via `getDebugMode()` — pass this to your shader uniforms.

## Mode 0: Normal

Default rendering. No debug visualization.

## Mode 1: Render Path

Each pixel is colored by which rendering path produced it:

| Color | Path | Meaning |
|-------|------|---------|
| Dark gray | Sky | No geometry hit |
| Blue | DDA (3D) | Full 3D voxel raymarching |
| Green | Heightmap (2D) | Distant LOD, 2D height-based |
| Yellow | Entity | Entity/object rendering |
| Magenta | Unknown | Unrecognized path (likely a bug) |

**When to use:** Verify that the correct rendering path is being used at each distance. If the far field shows blue instead of green, your LOD transition isn't working.

## Mode 2: Step Heatmap

Colors pixels by how many raymarching steps were needed:

- **Green** = few steps (hit surface quickly)
- **Red** = many steps (traversed lots of empty space)

**When to use:** Find performance hotspots. Large red areas mean the raymarcher is doing unnecessary work — consider adding acceleration structures (Hi-Z, occupancy mipmaps).

## Mode 3: Depth

Grayscale depth visualization. Black = near, white = far.

**When to use:** Debug depth buffer issues, verify depth precision, check if objects are rendering at unexpected depths.

## Mode 4: Normals

Surface normals mapped to RGB: `normal * 0.5 + 0.5`.

- R = X component
- G = Y component
- B = Z component

**When to use:** Debug lighting artifacts. If normals look wrong, the issue is in your SDF gradient or mesh data, not in your lighting shader.

## Adding Custom Modes

In your shader, add cases after mode 4:

```wgsl
if (uniforms.debugMode == 5u) {
    // Your custom visualization
    return vec4f(...);
}
```

Register the mode name in your app for discoverability:

```javascript
window.__gpu.setStat('debugModes', '0=normal,1=path,2=heatmap,3=depth,4=normals,5=myCustom');
```

## WGSL Implementation

See `assets/debug-shader-snippet.wgsl` for a complete `applyDebugMode()` function that handles all standard modes. Drop it into your fragment shader.
