# References: scenes, scripts and Create

Read on 2026-11-23 for `projects/<name>/scenes/`, `projects/<name>/scripts/`, `engine/play/game.bend`'s
`tick_with`, `tools/project/registry.js`, `projects/prefabs.bend`, and the editor's Create (Project
window and Hierarchy). "UNVERIFIED" marks what no page read here states.

## Unity (docs.unity.com, the 6000.x manual)

- Scripts: created from Assets > Create > Scripting, or the Project window's Create (+). "The file
  name you enter on creation of a script defines the name of the class inside it." A MonoBehaviour
  runs once attached to a GameObject. "Unity creates the script asset and compiles it."
  https://docs.unity.com/en-us/engine/current/manual/scripting/get-started/creating-scripts
  https://docs.unity.com/en-us/engine/current/manual/scripting/get-started/naming-scripts
- What the script template holds (Start, Update): UNVERIFIED on the pages read.
- Scenes: "You can create any number of scenes in a project." Assets > Create > Scene, or right-click
  > Create > Scene in the Project window. "If your current scene contains unsaved changes, Unity
  prompts you to save the scene or discard the changes." A scene opens by a double click.
  https://docs.unity.com/en-us/engine/current/manual/working-with-scenes/creating-scenes
  https://docs.unity.com/en-us/engine/current/manual/working-with-scenes/scenes-working-with
- Project window: Create (+) "Displays a list of Assets and other sub-folders you can add to the
  folder currently selected"; it opens from the toolbar's + or a right click.
  https://docs.unity.com/en-us/engine/current/manual/unity-editor/editor-windows-views-reference/project-view

## Godot (docs.godotengine.org, stable 4.7)

- Script templates live in `res://script_templates/`; the default holds `_ready()` and
  `_process(delta)` ("Called every frame. 'delta' is the elapsed time since the previous frame").
  A script is attached to a node (Attach Script).
  https://docs.godotengine.org/en/stable/tutorials/scripting/creating_script_templates.html
- "A Godot project can contain as many of these scenes as you need. The engine only requires one as
  your application's main scene."
  https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html
- Editor icons: `editor/icons/`, one 16×16 SVG per class, recolored for the light theme.
  https://docs.godotengine.org/en/stable/engine_details/editor/creating_icons.html

## Bevy

- "Systems ... are typically implemented using regular Rust functions", registered with
  `App::add_systems(Startup, ...)` and `add_systems(Update, ...)`. "Schedules cannot (yet) be
  modified at runtime; all systems you want to run must be added/configured in the App ahead of
  time", and forgetting to add one "is a common mistake".
  https://bevy-cheatbook.github.io/programming/systems.html
  https://bevy-cheatbook.github.io/programming/app-builder.html
- Scenes are built in code (`bsn!`); a `.bsn` file format is planned (0.20.1).
  https://docs.rs/bevy/latest/bevy/scene/index.html

## What the engine took

- A scene is a file in `scenes/`, any number per project, one main (Godot's main scene):
  `PROJECT.bend`'s `main()`. Opening another with changes not saved asks Save or Discard (Unity).
- A script is a pure system with `start` (Unity's Start, Godot's _ready, Bevy's Startup) and
  `update(dt)` (Update, _process, Bevy's Update), run after the rules in each 1/60 s tick. Bend
  compiles every import, so registration is generated from the folder (Bevy's rule, without the
  mistake it warns about), and Play gets the scripts as templates.
- Create is in the Project window's bar and on a right click (Unity); a script, scene or shader is
  written from a template in Bend (Godot's templates) and the engine compiles it again (Unity).
- Things made in a scene (Hierarchy's Create: Empty, Plane, Character) are saved by kind, name and
  place beside the scene's code; things of the code deleted are saved by name (Unity's prefab
  overrides, already cited in `docs/references/play-save-undo.md`).
