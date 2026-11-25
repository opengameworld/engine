
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

Open `http://localhost:3100/?project=water` and select **Water** in the Hierarchy. In the Inspector's Material, pick **Ripples (GLSL)** in the Shader menu, or pick a shader in the Project window (`Assets/shaders`) and press Apply. Add fragment shaders and their JSON descriptors to `projects/<project>/shaders/`, or use the Project window's Create > Shader. The dev server rebuilds the catalog when those files change. HLSL import uses DXC and SPIRV-Cross. See the [shader module guide](docs/shaders.md) for the asset format, supported controls, tools, and architectural decisions.

## Files

| File | What it is |
| --- | --- |
| `PROJECT.bend` | The projects (Water, Character, Mannequin, Animation), which one opens, each one's main scene and starting camera, and Play with each project's scripts |
| `library/` | The animation library: `catalog.bend` (the folders, and the clip an entry becomes on a character) and one folder per collection (`quaternius/`: the source files, `clips.json`, the motions `tools/clips.ts` wrote, the credits) |
| `projects/animation/` | The Animation project: the mannequin, to try the library on (Project window: Library/Animations) |
| `tools/clips.ts` | The clip importer: the animations of .glb files + clips.json → motions (Bend) |
| `mannequin/` | The standard character: `rig.json`, what the importer wrote (`gen/`), its laws, its scene and its credits |
| `projects/water/` | The Water project: a plane with a material |
| `projects/character/` | The Character project: the hand-written test arm (`arm.bend`) and its scene |
| `engine/scene/world.bend` | The World: origin, axes, units, ground grid, sky, grid fade |
| `engine/scene/camera.bend` | The camera: orbit, pan, zoom, view and projection, the ray through a pixel; `close_up()` frames a person; `follow()` in Play |
| `engine/scene/place.bend` | Places in an open World: a 1 km cell and a position inside it, so nothing loses precision kilometers from the origin; `delta(a, b)` gives meters around a chosen origin |
| `engine/core/vec.bend`, `engine/core/quat.bend`, `engine/core/transform.bend` | Vectors, 4x4 matrices, quaternions, position/rotation/scale |
| `engine/scene/scene.bend` | The scene as data: things with a place and a look (Shown, Rigged, Hidden) |
| `engine/render/mesh.bend`, `engine/render/material.bend`, `engine/render/shader/` | Meshes, material graphs, GLSL written by Bend (incl. the skinned shaders) |
| `projects/*/shaders/`, `tools/shaders/`, `editor/shaders/` | Project shader assets, the tool that reads them, and the catalog it writes (as JSON for the GPU and as Bend for the editor; both generated, not tracked) |
| `engine/anim/skeleton.bend` | The rig standard: bones with roles (Root, Deform, Twist, Support, Chain) and slots, and its laws |
| `engine/anim/pose.bend` | Poses: local transforms, model/world matrices in one pass, bones as lines |
| `engine/anim/clip.bend` | Clips: rotation and position keys, sampled with slerp, looping |
| `engine/anim/gait.bend` | A walk and an idle made by code, per slot, baked into clips |
| `engine/anim/blend.bend` | Two poses mixed by one weight |
| `engine/anim/hand.bend` | The fingers close by one grip number |
| `engine/anim/ik.bend` | Two-bone IK (law of cosines) and feet kept on the floor |
| `engine/anim/helpers.bend` | One rule per Twist and Support bone, applied after the clip |
| `engine/anim/skin.bend` | Skinning matrices, and the weight laws (16-bit, sum 65535) |
| `engine/anim/figure.bend` | The character component: skeleton, skin, clips, helpers, parameters (time, speed, grip, bones) |
| `engine/anim/locomotion.bend` | Walking through the World in Play: reads the actions Walk and Turn, never keys; `context()` is W/S and A/D |
| `engine/input/` | Input: `keys.bend` (Bend's key codes, and the browser's KeyboardEvent.code for each), `keyboard.bend` (held, pressed, let go: a fold over Bend's events; focus lost lets go of all), `actions.bend` (buttons and axes, contexts with priority), `pointer.bend` (a click is a press let go within 8 px) |
| `engine/play/` | Play mode: `tick.bend` (60 fixed ticks a second, at most 8 a frame), `game.bend` (one tick: input, rules, clocks), `play.bend` (the session: Edit, Playing, Paused, Step; Stop gives back the edited scene; the camera follows the character) |
| `engine/script/` | Scripts as data: `rule.bend` (a thing, a trigger: Clicked or Started, a response: Move, Turn, Play), `respond.bend` (one pure step answering what happened), `problem.bend` (a script that does not compile: where, and what Bend said; Play and the build wait for it) |
| `engine/core/ray.bend`, `engine/scene/pick.bend` | Rays and boxes (the slab method), and which thing is under a pixel |
| `engine/scene/save.bend` | Saving: the places that differ from a scene's code, the things made or deleted in the editor and the rules, written as Bend to `projects/<name>/scenes/saved/<Scene>.bend` |
| `projects/<name>/` | A project: `scenes/` (a `.bend` per scene, and `scenes/saved/` what the editor saved), `scripts/` (start once, update every tick in Play), `shaders/`, and `project_generated.bend`, its registry (generated by `tools/project/registry.js`, not tracked) |
| `projects/prefabs.bend` | What the Hierarchy's Create makes: Empty, Plane, Character |
| `editor/viewport/` | The viewport's editor parts: the axis gizmo, the editor's shortcuts (`keys.bend`, with their laws) and selecting by click (`select.bend`) |
| `editor/hierarchy/`, `editor/inspector/`, `editor/project/`, `editor/console/` | The editor's windows, as Unity's: the scene's things (with Create and Delete), the selection's components or the asset picked, the project's files and the library (with Create: Folder, Scene, Script, Shader), and the editor's messages |
| `editor/code/` | The script editor: a script open over the viewport, in Bend's colors, checked by Bend as it is typed (`tools/script/check.ts`), the place of an error underlined, and Save |
| `editor/scene/`, `editor/animation/`, `editor/shaders/` | What the Inspector and the dock draw for a thing's Transform and Animation, a character's clips and transport, a material and its shader |
| `editor/icons/` | The asset icons: each kind's glyph and Bend-UI color token, drawn at 16 px and as the Project window's tiles |
| `editor/workspace/` | The layout (toolbar, Hierarchy, viewport, Inspector, dock), the state every window shares (`state.bend`) and their shared pieces (`pieces.bend`) |
| `docs/references/` | The sources each system was built from (Unity, Unreal, Godot, Blender, Bevy, MDN), with links and the numbers taken |
| `platform/web/draw.js`, `gpu.js` | Drawing a scene in the browser (WebGL2): draws what Bend returns. Runtime: a game without the editor uses it too |
| `platform/web/input.js` | Reading the keyboard and the pointer in the browser. Runtime |
| `platform/web/loop.js` | The browser's frames: dt, redraw, the canvas's size. Runtime |
| `editor/app.js` | The editor: puts the pieces together (theme, panels, gizmo, shortcuts, camera), shared by every page |
| `editor/defaults/` | Editor Defaults: gizmo + info, accessibility (`ACCESSIBILITY.bend`). The info button is a page written in Bend (`view.bend`); the gizmo is a canvas (`defaults.js`) |
| `engine/render/shader/asset.bend` | An imported shader's parameters, what each may be worth, and editing one on a material |
| `tools/gltf.ts` | The importer: a .glb + rig.json → skeleton, rules, weights (Bend) and skin.bin |
| `tools/check.ts` | `bun run check`: laws (the engine's, the editor's, the mannequin's), types (the `.bend` files `LAYERS.bend` says to check), tests, and the layers: every file in a layer, every import allowed or a named debt, no debt left unused |
| `LAYERS.bend`, `tools/layers.ts` | The engine's layers: the only list of its folders, which may import which, what ships in a game, and the named debts (laws in `LAWS.bend`); `tools/layers.ts` finds the files and imports it judges |
| `AGENTS.md` | The rules for agents working here; the game's vision is in the `opengame` repository |
| `tests/` | Numerical tests (`checks()` lists), run by `tools/test.ts` |
| `export/contract.bend` | Export's decisions about a game folder: what ships or is refused and why, cache, the code and asset budgets, the credits a game owes, the build machine it needs (laws in `LAWS.bend`, tests in `tests/export/export.bend`) |
| `export/needs.bend`, `export/pages.bend`, `export/files.bend` | What a game takes from its scene (skins, shaders, credits); its two pages as Bend-UI trees written as static text; everything export writes and how it reads a build |
| `export/web.ts`, `export/cli.ts` | `bun run export web <game>` builds `.export/web/<game>/` (`game.json` + `site/`: the pages, code in `site/_/`, assets in `site/a/`, both named by hash) or says why not; `bun run export serve <game>` plays it at localhost:3200. Only measures and writes: every decision is the Bend above |
| `platform/web/run.js` | `runGame`: the game without the editor (draws the scene, the editor's frame rule and walking keys), the player's counterpart of `startEditor` |
| `docs/not-in-bend.txt` | What the engine's Bend (`../bend`) has that released Bend 2.0.40 does not, why, and how to set it up |
| `docs/barriers.md` | Limits that exist only on the web or only natively, and what the engine does about each |
| `LAWS.bend`, `PROOF.bend` (in every module) | Each module keeps its laws beside its code; `bun run check` finds and proves every `PROOF.bend`. The root one holds the laws about projects and layers |
| `editor/index.html`, `editor/main.js` | The engine's page: opens the project PROJECT.bend names |

## The mannequin (`mannequin/`)

The engine's standard character, as Manny and Quinn are Unreal's: the
project the engine opens with, the character clips are made on and shown
on, and the rig other characters are checked against. The rig standard is
`engine/anim/skeleton.bend`; the mannequin is the character that keeps it, and
`bun run check` proves it every time (`mannequin/PROOF.bend`,
`tests/mannequin/mannequin.bend`). It is content: a game may bring its own character
instead. Its mesh and textures are third-party work, credited in
`mannequin/CREDITS.md`; the credit goes wherever the mannequin goes.

Re-import it after changing its `rig.json`:

```sh
bun tools/gltf.ts mannequin/gltf/sora_all.glb mannequin/rig.json mannequin/gen
```

## The animation library (`library/`)

Clips from anywhere are stored once as motions (`engine/anim/motion.bend`): for
each slot of the rig standard, how far it has turned from the T-pose.
`engine/anim/retarget.bend` makes a motion into a clip for one skeleton, so the
same motion plays on any character that keeps the standard. The catalog has
two folders: a third-party collection, with its name and credit on the
folder, and the clips made for this engine.

To try it: open the Animation project (`PROJECT.bend`'s `open()`), and in the
Project window open Library/Animations. A click on a clip tries it on the
mannequin, Add (in the Inspector) keeps it, and the dock's Animation tab plays
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

W / S walk ahead and back, A / D turn. Held keys walk continuously, and the
character blends from idle into its walk. With reduce motion on (in
`editor/defaults/ACCESSIBILITY.bend`, off by default, or in the system's
settings), each press is one step and nothing moves between presses.
