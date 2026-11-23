# References: Play mode, saving a scene, undo

Read on 2026-11-23 for `engine/play/`, the editor's Play button, `engine/scene/save.bend` and
`editor/history/`. "UNVERIFIED" marks what no source read here states.

## Play mode

- Unity, Configurable Enter Play Mode: options "Reload Domain and Scene", "Reload Scene only"
  (default), "Reload Domain only", "Do not reload". "Any changes you make in the Editor during
  Play Mode reset when you exit Play Mode."
  https://docs.unity3d.com/2022.3/Documentation/Manual/ConfigurableEnterPlayMode.html
- Unity toolbar: Play, Pause, and "Step ... move Play mode forward by one frame."
  https://docs.unity.com/en-us/engine/6000.0/manual/unity-editor/editor-navigating-managing/toolbar
- Unreal, Playing and Simulating: Play starts at the Player Start and possesses the player;
  Simulate "doesn't move the Camera and doesn't spawn a player character". Changes "are not saved
  by default" (Keep Simulation Changes, K, keeps them). That the PIE world is a duplicate of the
  editor world: UNVERIFIED (the source is private).
  https://dev.epicgames.com/documentation/en-us/unreal-engine/playing-and-simulating-in-unreal-engine
- Godot runs the game in another process (`EditorRun::run`, `OS::create_instance`) so "if the
  game crashes, it will not crash the editor."
  https://github.com/godotengine/godot/blob/master/editor/run/editor_run.cpp,
  https://docs.godotengine.org/en/stable/tutorials/editor/game_embedding.html
- Bevy States (v0.20.1): `OnEnter`, `OnExit` run only on entering or leaving a state and
  "ignore identity transitions". https://github.com/bevyengine/bevy/blob/v0.20.1/crates/bevy_state/src/state/transitions.rs

## Saving

- Godot `.tscn`: a header, then `[ext_resource]`, `[sub_resource]`, `[node]`, `[connection]`;
  "properties equal to the default value are not stored".
  https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html
- Bevy v0.20: `DynamicWorld::serialize` writes RON through reflection (`to_string_pretty`).
  https://github.com/bevyengine/bevy/blob/v0.20.1/crates/bevy_world_serialization/src/dynamic_world.rs
- Browser: `showSaveFilePicker` is Chromium only (no Firefox, no Safari), per MDN's compat data.
  A POST to the dev server works everywhere.
  https://developer.mozilla.org/en-US/docs/Web/API/Window/showSaveFilePicker

## Undo

- Godot `UndoRedo` (`core/object/undo_redo.cpp`): `MERGE_ENDS` merges an action into the last one
  when it has the same name and comes less than 800 ms later (keeps the first undo and the last
  do); a new action discards redo; `max_steps = 0` means unlimited.
  https://github.com/godotengine/godot/blob/master/core/object/undo_redo.cpp
- Blender: every undo step is a whole-state memfile; a chunk equal to the previous step's is
  shared, not copied (`BLO_memfile_chunk_add`). Default `undosteps = 32`, range 0-256.
  https://github.com/blender/blender/blob/main/source/blender/blenloader/intern/undofile.cc,
  https://github.com/blender/blender/blob/main/source/blender/makesrna/intern/rna_userdef.cc
- Unity Undo: "Mouse down events split undo groups"; `CollapseUndoOperations` joins a group.
  https://docs.unity.com/en-us/engine/current/script-reference/unityeditor/undo

## What the engine takes

- Play keeps the edited scene as it was and runs a copy; Stop drops the copy (Unity's default,
  Unreal's default). A scene is a Bend value, so the copy is the value itself.
- Pause stops the tick; Step runs exactly one tick (Unity's toolbar).
- Undo is a list of whole scenes (Blender's whole-state steps; Bend shares what did not change).
  One drag is one step (Unity's mouse-down groups); a new edit drops redo (Godot); 32 steps
  (Blender's default).
- A saved scene is Bend source text; the dev server writes it (works in every browser).
