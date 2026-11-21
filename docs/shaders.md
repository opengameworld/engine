# Shaders and materials

Run `bun run dev`, open [Water](http://localhost:3100/?project=water), and select **Water** in the Scene panel. In **Details → Material → Shader**, choose **Ripples (GLSL)**, **Bands (HLSL)**, or **Freeze (HLSL)**. Parameter edits update the viewport during the session. **Original graph** restores the Bend graph material. To save a material in a scene, use `Mat.imported("freeze.frag.hlsl")` in the object's material slot and `Mat.instance` for overrides.

## Import

Put shader sources under `projects/<project>/shaders/`. A source's path relative to `shaders/` is its ID. Give it a descriptor with the source filename plus `.json`, such as `freeze.frag.hlsl.json`. The dev server updates the catalog when these files change. Reload the page to pick up the updated catalog. The production build runs the same import.

```json
{
  "label": "Water",
  "stage": "fragment",
  "lighting": "unlit",
  "parameters": [
    { "name": "density", "label": "Density", "control": "slider", "min": 0.5, "max": 8, "step": 0.1, "default": 2 },
    { "name": "highlights", "label": "Highlights", "control": "toggle", "default": true }
  ]
}
```

| Control | GLSL type | HLSL type | Descriptor fields |
| --- | --- | --- | --- |
| `number` | `float` | `float` | Numeric `default` |
| `slider` | `float` | `float` | Numeric `default`, `min`, `max`, `step` |
| `dropdown` | `int` | `int` | `options` with a `label` and integer `value`, and one of those values as `default` |
| `toggle` | `bool` or `int` | `bool`, `int`, or `uint` | Boolean `default` |
| `color` | `vec3` | `float3` | Three RGB values between 0 and 1 as `default` |

- **GLSL.** Use `#version 300 es`, `main()`, a `vec4` color output, and uniforms with the descriptor names. The fixed mesh vertex stage provides `v_local_position` and `v_local_view` as optional `in highp vec3` inputs for object-space position and the vector toward the camera.
- **HLSL.** Use `float4 main(...) : SV_Target0`. The optional inputs are `float3 ... : TEXCOORD0` for local position and `float3 ... : TEXCOORD1` for the local view vector. Declare descriptor parameters in a `cbuffer`. The source is self-contained. Install `dxc` and `spirv-cross` on `PATH`, or set `DXC` and `SPIRV_CROSS` to the executables. The import compiles to SPIR-V and translates it to GLSL ES 3.00. [DXC](https://github.com/microsoft/DirectXShaderCompiler/wiki/SPIR%E2%80%90V-CodeGen) · [SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)
- **Validation.** The importer uses the declared stage and lighting model and also recognizes stage-specific filenames such as `.vert.hlsl` and `.geom`. Unsupported shaders and import errors appear under **Shader warnings**. WebGL2 checks compilation, linking, and active uniform types on first use. All descriptor parameters appear in the inspector, including uniforms optimized out by the driver.

## Architecture

| Location | Responsibility |
| --- | --- |
| `engine/material.bend`, `engine/scene.bend` | Material instances, values, and the object's single material slot |
| `engine/shader/` | Bend shader graphs, GLSL generation, and the fixed mesh vertex stage |
| `platform/web/` | Program cache, uniform binding, and drawing with the same depth rules as the rest of the scene |
| `projects/<project>/shaders/` | Authored shader sources and descriptors |
| `tools/shaders/` | Asset discovery, validation, and HLSL translation before browser load |
| `editor/shaders/` | Generated catalog and the shader controls attached to Bend-UI's Details panel |

The Unity Shader Graph Blackboard exposes properties through a named contract. The descriptor serves that role for both source languages. Keeping the descriptor explicit requires matching its names and types to the source, and lets authors choose editor controls independently of GPU types. [Unity Blackboard](https://docs.unity3d.com/Packages/com.unity.shadergraph@17.0/manual/Blackboard.html)

Unreal Material Instances inherit a shader definition and override parameter values. Here, sliders, dropdowns, and toggles are uniforms, so edits update the instance without recompiling. A dynamic branch can still cost work per fragment. [Unreal Material Instances](https://dev.epicgames.com/documentation/unreal-engine/creating-and-using-material-instances-in-unreal-engine) · [Static switches](https://dev.epicgames.com/documentation/unreal-engine/artist-04-expanded-material-instances)

The catalog and per-context program cache follow the division between resource management and rendering discussed in chapters 7 and 11 of Jason Gregory's book. The first use pays the driver's link cost. Linked programs and uniform locations are then shared, and the renderer binds each instance's values before its draw. [Game Engine Architecture, 3rd edition](https://www.oreilly.com/library/view/game-engine-architecture/9781351974271/)

The module uses Bend for scene and material data. Its WebGL adapter works with the browser loader in Bend 2.0.40. The shader inspector uses Bend-UI fields, dropdowns, and toggles, with a native range element inside the field for sliders. [Bend 2.0.40](https://github.com/bendlang/bend/releases/tag/v2.0.40) · [Bend-UI requests](bend-ui-requests.txt)

## Limits now

The import path supports UNLIT fragments on static meshes. The material instance refers to one shader, each mesh has one material slot, and edits in the inspector are session-local. Skinned characters use their fixed pipeline. Freeze derives surface normals from position derivatives and uses an XZ projection on the horizontal Water mesh.
