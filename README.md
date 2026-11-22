
## Run

Needs Bend (`bend`) and a clone of [bendlang/bend](https://github.com/bendlang/bend) at `../bend` (the loader in `bunfig.toml`).

```sh
bun install
bun run dev      # http://localhost:3100
bun run check    # laws, types, tests, the refs/ fence
bun run build    # bundle to dist/
```

### Windows with WSL 2

Install Bun and Bend inside the Linux distribution. Keep the Bend checkout next to this project, so both are visible from WSL. From PowerShell in the project folder, run the dev server using your default WSL distribution.

```powershell
wsl --cd (Get-Location).Path --exec bash -lc 'bun run dev'
```

Open [the editor](http://localhost:3100/) in your Windows browser. On Windows drives mounted in WSL, the dev server checks source files periodically so it can pick up edits from Windows programs. HLSL needs the Linux versions of [DXC](https://github.com/microsoft/DirectXShaderCompiler/releases) and SPIRV-Cross (`sudo apt install spirv-cross` on Ubuntu).

## Shaders and materials

Open `http://localhost:3100/?project=water` and select **Water**. In the **Shaders** tab, in the Shader Library on the left, click **Ripples (GLSL)** or **Bands (HLSL)**. Add fragment shaders and their JSON descriptors to `projects/<project>/shaders/`. The dev server rebuilds the catalog when those files change. HLSL import uses DXC and SPIRV-Cross. See the [shader module guide](docs/shaders.md) for the asset format, supported controls, tools, and architectural decisions.

## Files

| File | What it is |
| --- | --- |
| `PROJECT.bend` | The projects (Water, Character, Mannequin, Animation), which one opens, and its starting camera |
| `library/` | The animation library: `catalog.bend` (the folders, and the clip an entry becomes on a character) and one folder per collection (`quaternius/`: the source files, `clips.json`, the motions `tools/clips.ts` wrote, the credits) |
| `projects/animation/` | The Animation project: the mannequin, to try the library on (the Animation tab) |
| `tools/clips.ts` | The clip importer: the animations of .glb files + clips.json → motions (Bend) |
| `mannequin/` | The standard character: `rig.json`, what the importer wrote (`gen/`), its laws, its scene and its credits |
| `projects/water/` | The Water project: a plane with a material |
| `projects/character/` | The Character project: the hand-written test arm (`arm.bend`) and its scene |
| `engine/world.bend` | The World: origin, axes, units, ground grid, sky, grid fade |
| `engine/camera.bend` | The editor camera: orbit, pan, zoom, view and projection; `close_up()` frames a person |
| `engine/gizmo.bend` | The axis gizmo: handles, hover, click-to-align |
| `engine/vec.bend`, `engine/quat.bend`, `engine/transform.bend` | Vectors, 4x4 matrices, quaternions, position/rotation/scale |
| `engine/scene.bend` | The scene as data: things with a place and a look (Shown, Rigged, Hidden) |
| `engine/mesh.bend`, `engine/material.bend`, `engine/shader/` | Meshes, material graphs, GLSL written by Bend (incl. the skinned shaders) |
| `projects/*/shaders/`, `tools/shaders/`, `editor/shaders/` | Project shader assets, the tool that reads them, and the catalog it writes (as JSON for the GPU and as Bend for the editor; both generated, not tracked) |
| `engine/skeleton.bend` | The rig standard: bones with roles (Root, Deform, Twist, Support, Chain) and slots, and its laws |
| `engine/pose.bend` | Poses: local transforms, model/world matrices in one pass, bones as lines |
| `engine/clip.bend` | Clips: rotation and position keys, sampled with slerp, looping |
| `engine/gait.bend` | A walk and an idle made by code, per slot, baked into clips |
| `engine/blend.bend` | Two poses mixed by one weight |
| `engine/hand.bend` | The fingers close by one grip number |
| `engine/ik.bend` | Two-bone IK (law of cosines) and feet kept on the floor |
| `engine/helpers.bend` | One rule per Twist and Support bone, applied after the clip |
| `engine/skin.bend` | Skinning matrices, and the weight laws (16-bit, sum 65535) |
| `engine/figure.bend` | The character component: skeleton, skin, clips, helpers, parameters (time, speed, grip, bones) |
| `engine/locomotion.bend` | Walking through the World: Run (keys held) and Step (one step per press, for reduce_motion) |
| `platform/web/draw.js`, `gpu.js` | Drawing a scene in the browser (WebGL2): draws what Bend returns. Runtime: a game without the editor uses it too |
| `platform/web/input.js` | Reading the keyboard and the pointer in the browser. Runtime |
| `platform/web/loop.js` | The browser's frames: dt, redraw, the canvas's size. Runtime |
| `editor/app.js` | The editor: puts the pieces together (theme, panels, gizmo, shortcuts, camera), shared by every page |
| `editor/defaults/` | Editor Defaults: gizmo + info, accessibility (`ACCESSIBILITY.bend`). The info button is a page written in Bend (`view.bend`); the gizmo is a canvas (`defaults.js`) |
| `editor/workspace/` | The tabs (Scene, Animation, Shaders) and the screens of the last two: a library on the left, what shows over the viewport, the Details on the right, a transport for Animation. One page written in Bend (`view.bend`), with its own styles; no JS, HTML or CSS of its own |
| `engine/shader/asset.bend` | An imported shader's parameters, what each may be worth, and editing one on a material |
| `editor/panels/` | The Scene and Details panels: what they hold (`panels.bend`) and what is drawn for it (`view.bend`, a page written in Bend). No JS of their own: Bend-UI's driver draws them |
| `tools/gltf.ts` | The importer: a .glb + rig.json → skeleton, rules, weights (Bend) and skin.bin |
| `tools/check.ts` | `bun run check`: laws (the engine's, the editor's, the mannequin's), types (every `.bend` file, found by itself), tests, the refs/ fence |
| `AGENTS.md` | The rules for agents working here; the game's vision is in the `opengame` repository |
| `tests/` | Numerical tests (`checks()` lists), run by `tools/test.ts` |
| `export/contract.bend` | Export's decisions about a game folder: what ships or is refused and why, cache, the code and asset budgets, the credits a game owes, the build machine it needs (laws in `LAWS.bend`, tests in `tests/export.bend`) |
| `not-in-bend.txt` | What the engine's Bend (`../bend`) has that released Bend 2.0.40 does not, why, and how to set it up |
| `KEYS.bend` | The keymap: views 1–4, walking W/A/S/D |
| `SPEC.bend`, `LAWS.bend`, `PROOF.bend` | The engine's laws and their proofs |
| `main.js`, `index.html` | The engine's page: opens the project PROJECT.bend names |

## The mannequin (`mannequin/`)

The engine's standard character, as Manny and Quinn are Unreal's: the
project the engine opens with, the character clips are made on and shown
on, and the rig other characters are checked against. The rig standard is
`engine/skeleton.bend`; the mannequin is the character that keeps it, and
`bun run check` proves it every time (`mannequin/PROOF.bend`,
`tests/mannequin.bend`). It is content: a game may bring its own character
instead. Its mesh and textures are third-party work, credited in
`mannequin/CREDITS.md`; the credit goes wherever the mannequin goes.

Re-import it after changing its `rig.json`:

```sh
bun tools/gltf.ts mannequin/gltf/sora_all.glb mannequin/rig.json mannequin/gen
```

## The animation library (`library/`)

Clips from anywhere are stored once as motions (`engine/motion.bend`): for
each slot of the rig standard, how far it has turned from the T-pose.
`engine/retarget.bend` makes a motion into a clip for one skeleton, so the
same motion plays on any character that keeps the standard. The catalog has
two folders: a third-party collection, with its name and credit on the
folder, and the clips made for this engine.

To try it: open the Animation project (`PROJECT.bend`'s `open()`) and the
Animation tab over the viewport. A click on a clip of the library tries it
on the mannequin, Add keeps it, and the transport under the viewport plays
it, moves it a frame at a time or to any moment. Play works with Reduce
motion on: it is motion asked for, in place, and it stops when asked.

Import a collection again after changing its `clips.json`:

```sh
bun tools/clips.ts library/quaternius/clips.json library/quaternius/gen
```

## Study-only assets (`refs/`, never shipped)

`refs/` is for third-party assets kept only to study. There are none now.
Nothing outside it may import from it (`bun run check` fails if anything
does), and the build never sees it. When it has characters, `bun run dev`
also serves each `refs/<name>/index.html`, and `bun run check` proves each
`refs/<name>/PROOF.bend`.

## Walking

W / S walk ahead and back, A / D turn. With reduce motion on (the default in
`editor/defaults/ACCESSIBILITY.bend`), each press is one step and nothing
moves between presses. With it off, held keys walk continuously.
