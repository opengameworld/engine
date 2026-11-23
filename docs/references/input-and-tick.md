# References: input and the fixed tick

Read on 2026-11-23 for `engine/input/` and `engine/play/tick.bend`. Godot is master at
commit `02088c365b70`; Unity Input System is the `develop` branch. "UNVERIFIED" marks what no
source read here states.

## Unity Input System (docs 1.11, source `develop`)

- Action types: **Value** (default; the most actuated bound control drives it; an initial
  state check fires for a control already held), **Button** (no initial check), **PassThrough**
  (every change of any bound control). Phases: Disabled, Waiting, Started, Performed, Canceled.
  Polling: `ReadValue<T>()`, `IsPressed()`, `WasPressedThisFrame()`, `WasReleasedThisFrame()`.
  https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/RespondingToActions.html
- Action map: "A named collection of Actions"; enabled or disabled as a whole.
  https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/Actions.html
- Bindings are ordered by complexity (Shift+B before B); "the first Binding that results in the
  Action changing phase will 'consume' the input" (within one map).
  https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/ActionBindings.html
- 2D Vector composite: parts up, down, left, right. `Mode.DigitalNormalized = 0` (default: the
  vector is normalized, a diagonal is about (0.7, 0.7)), `Digital = 1`, `Analog = 2`.
  `Vector2Composite.ReadValue` -> `DpadControl.MakeDpadVector(up, down, left, right, normalize)`.
  https://github.com/Unity-Technologies/InputSystem/blob/develop/Packages/com.unity.inputsystem/InputSystem/Runtime/Actions/Composites/Vector2Composite.cs
- Defaults (`InputSettings.cs`, lines 774-795): hold 0.4 s, tap 0.2 s, press point 0.5,
  release threshold 0.75, deadzone 0.125..0.925, multi-tap delay 0.75 s.
  https://github.com/Unity-Technologies/InputSystem/blob/develop/Packages/com.unity.inputsystem/InputSystem/Runtime/InputSettings.cs

## Unreal Enhanced Input (docs)

- Value types: Boolean, Axis1D, Axis2D, Axis3D. Mapping contexts are added with
  `AddMappingContext(Context, Priority)`; when several map the same action, "the context with
  the highest priority will be considered and the others ignored."
- Modifiers alter raw values, then triggers decide (None, Ongoing, Triggered).
- WASD as Axis2D: W = Swizzle (YXZ), A = Negate, S = Negate + Swizzle, D = nothing.
  https://dev.epicgames.com/documentation/en-us/unreal-engine/enhanced-input-in-unreal-engine
- `InputTriggerPressed`: fires once when the input exceeds the threshold; holding does not fire
  again. `InputTriggerReleased`: fires once when it drops back.
  https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/InputTriggerPressed

## Godot (master)

- `struct ActionState` keeps `pressed_physics_frame` and `released_physics_frame` apart
  (`core/input/input.h`). On a press it stamps `physics_frames + 1`: "As input may come in part
  way through a physics tick, the earliest we can react to it is the next physics tick."
  Because the two stamps are separate, a press and a release inside one frame both show on the
  next tick. https://github.com/godotengine/godot/blob/master/core/input/input.cpp
  (`_parse_input_event_impl`, `is_action_just_pressed`)
- Pressed is the OR over devices, strength the MAX (`_update_action_cache`).
- `release_pressed_events()` releases every key and action when the application loses focus;
  called from `SceneTree::_notification` on `NOTIFICATION_APPLICATION_FOCUS_OUT`.
  https://github.com/godotengine/godot/blob/master/scene/main/scene_tree.cpp
- `get_vector(nx, px, ny, py, deadzone)`: (px - nx, py - ny); length <= deadzone gives zero;
  length > 1 is divided by its length. `InputMap::DEFAULT_DEADZONE = 0.2`.

## Browser (MDN)

- `KeyboardEvent.code` is the physical key, "isn't altered by keyboard layout"; MDN's WASD
  example uses it. https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/code
- `KeyboardEvent.repeat` is true while a held key auto-repeats.
- Window `blur` fires when the window loses focus; `visibilitychange` on tab switch.

## Bend (../bend, read in this session)

- `bend2/base.bend` defines `type Event`: `Key{code, down}`, `Text`, `Press`, `Move`, `Leave`,
  `Lost`, `Look`, `Scroll`, `Focus{on}`, `Close`. "A window losing the focus ... lets go of its
  keys held, then sends Focus{False}."
- Key codes (`bend2/effs/window.c`): a key's character in lower case (Escape, Return, Tab are
  theirs), arrows from 63232, modifiers 65536 + key code. This is the typed character, so it
  depends on the layout. Bend's JS target has no browser keyboard source: the Window effect is
  native. The engine's web adapter therefore translates `KeyboardEvent.code` (physical) into
  Bend's code for that key on a US layout, so W/A/S/D stay in place on AZERTY and the codes are
  the same ones a native build gets on a US keyboard.

## Fixed timestep

- Fiedler, "Fix Your Timestep!": clamp the frame time to 0.25 s, then
  `while (accumulator >= dt) { integrate; accumulator -= dt }`, render with
  `alpha = accumulator / dt`. https://gafferongames.com/post/fix_your_timestep/
- Godot: `physics_ticks_per_second = 60`, `max_physics_steps_per_frame = 8`,
  `physics_jitter_fix = 0.5` (`main/main.cpp`); extra time past the cap is dropped, so the game
  slows down instead of spiralling. https://github.com/godotengine/godot/blob/master/main/main_timer_sync.cpp
- Unity: `Time.maximumDeltaTime` default 0.3333333 s. `Time.fixedDeltaTime` default 0.02:
  UNVERIFIED (only used as an example in the pages read).
  https://docs.unity.com/en-us/engine/current/script-reference/unityengine/time/maximumdeltatime

## What the engine takes

- Events are Bend's own `Event`. Devices are a fold over them, stamping each key's press and
  release tick apart (Godot). Focus lost releases everything (Godot, Bend's own rule).
- Actions are data: a binding is a key plus a direction; a 2D move is Unity's
  DigitalNormalized. Contexts have a priority; the highest one that binds a key consumes it
  (Unreal).
- Tick: 60 per second, at most 8 steps per frame, the rest dropped (Godot's numbers).
