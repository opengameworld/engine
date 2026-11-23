# References: scripts, behaviors and events

Read on 2026-11-23 for `engine/script/`. Bevy is `main` at `ea06813` (2026-11-22). "UNVERIFIED"
marks what no source read here states.

## Unity

- Order of execution: Awake, OnEnable, Start ("before the first frame update"), FixedUpdate
  ("at fixed intervals of in-game time"), Update, LateUpdate.
  https://docs.unity3d.com/2022.3/Documentation/Manual/ExecutionOrder.html
- `OnMouseDown`: the mouse pressed over the object's Collider. `OnMouseUpAsButton`: "released
  over the same Collider as it was pressed."
- `IPointerClickHandler.OnPointerClick`: "pressed and released on the same object"; 3D objects
  need a `PhysicsRaycaster`.
- UnityEvent, source `Runtime/Export/UnityEvent/UnityEvent.cs`: `PersistentCall` holds
  `m_Target`, `m_MethodName`, `m_Mode` (a closed set: EventDefined, Void, Object, Int, Float,
  String, Bool), `m_Arguments`, `m_CallState` (RuntimeOnly by default). Saved in the scene, set in
  the Inspector, resolved by name through reflection at run time.
  https://github.com/Unity-Technologies/UnityCsReference/blob/master/Runtime/Export/UnityEvent/UnityEvent.cs

## Unreal (docs)

- Tick groups run in order (PrePhysics, DuringPhysics, PostPhysics, PostUpdateWork); each group
  finishes before the next. https://dev.epicgames.com/documentation/en-us/unreal-engine/actor-ticking-in-unreal-engine
- BeginPlay "triggered for all Actors when the game is started"; Tick every frame.
  https://dev.epicgames.com/documentation/en-us/unreal-engine/events-in-unreal-engine
- `bEnableClickEvents`, `NotifyActorOnClicked`, `OnClicked`: UNVERIFIED (only third-party text).

## Godot

- Signals: declare, `connect`, `emit`. https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
- `CollisionObject3D.input_event` and `input_ray_pickable` ("If true, this object is pickable").
- Connections are saved as `[connection signal="..." from="..." to="..." method="..."]` with
  optional `binds` (`ResourceFormatSaverTextInstance::save`,
  https://github.com/godotengine/godot/blob/master/scene/resources/resource_format_text.cpp).

## Bevy

- Messages (`crates/bevy_ecs/src/message/messages.rs`): double-buffered;
  `Messages::update()` swaps the buffers and clears one, so a message lives one frame boundary.
- Observers: `World::trigger` runs them at once; `On<PointerClick>`.
- Picking (`crates/bevy_picking/src/lib.rs`): Input, ProcessInput, Backend (hits per pointer),
  Hover, then `pointer_events` (`events.rs`). `PointerClick` "fires when a pointer sends a
  pointer pressed event followed by a pointer released event, with the same target entity";
  Release and Click are judged against the previous frame's hover.

## What the engine takes

- A behavior is data on a thing: a list of rules (trigger, response). This is UnityEvent's
  `PersistentCall` and Godot's `[connection]` (source, trigger, target, what to do, argument),
  with the "method name" replaced by a closed set of Bend constructors, so it is type-checked,
  saved in the scene, and edited from a menu.
- Triggers: Clicked (press and release on the same thing, Bevy and Unity), Started (once, on
  the first tick of Play, Unity's Start and Unreal's BeginPlay).
- Events are a list made each tick and gone after it (Bevy's messages, without the double
  buffer: a pure step gets them as an argument). A response never fires another event in the
  same tick.
- Rules run in Play only (`RuntimeOnly`), in the scene's order, so the result is deterministic.
- A project's own rules are its own pure function `step(scene, events) -> scene`, run after the
  engine's (Bevy systems, Unreal tick groups).
