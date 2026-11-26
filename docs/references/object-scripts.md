# References and proposal: scripts attached to things

Written on 2026-11-25, before any code (AGENTS.md: "show the result before writing the code").
"FROM MEMORY" marks what no page or source read in this session states.

## What the owner asked

A script attached to a thing of the scene is like Unity's MonoBehaviour:
- it sees only its own thing, at first;
- it talks to other scripts through events, direct references and indirect references, as far
  as the language allows;
- the same script attached to two things runs as two instances, each with its own state.

## What the engine has today (read in this repository)

- A thing is `Thing{name, place, look}` (engine/scene/scene.bend). It has no id: the editor tells
  things apart by their place in the list, and two things may share a name (its Limits now).
- A script (projects/<p>/scripts/) is a system of the whole project: `update(s, dt)` gets the whole
  scene, every script runs every tick, in file-name order (engine/play/game.bend's tick_with), and
  the registry imports them all (tools/project/registry.js), because a Bend import is fixed.
- A rule (engine/script/rule.bend) is the only thing attached to a thing, by its name: a trigger
  (Clicked, Started) and a response (Move, Turn, Play). Add Component offers only Rule. Rules are
  saved with the scene (engine/scene/save.bend).
- Play keeps the edited scene and runs a copy (engine/play/play.bend); a scene is a Bend value.

## 1. Unity and Unreal

Unity (docs.unity.com, read by an agent this session):
- "MonoBehaviours always exist as a Component of a GameObject, and can be instantiated with
  GameObject.AddComponent." Each attachment is its own object with its own fields (implied, not
  stated on the page read).
  https://docs.unity.com/en-us/engine/current/script-reference/unityengine/monobehaviour
- "Start is called on the frame when a script is enabled just before any of the Update methods
  are called the first time."
- Order: "you can't rely on the order in which the same event function is invoked for different
  GameObjects"; "You can't specify the order in which an event function is called for different
  instances of the same MonoBehaviour script." Script Execution Order sets an order per script
  class, lowest first.
  https://docs.unity.com/en-us/engine/current/manual/scripting/managing-update-order/execution-order
  https://docs.unity.com/en-us/engine/current/manual/unity-editor/editor-settings-reference/comp-manager-group/class-mono-manager
- Serialized fields: "Unity only serializes public fields by default. To serialize private fields,
  add the [SerializeField] attribute." They are what the Inspector shows and the scene saves
  (FROM MEMORY for the Inspector part).
  https://docs.unity.com/en-us/engine/current/script-reference/unityengine/serializefield
- Events: UnityEvents "are serializable, meaning you can configure them in the Inspector window";
  "you can use the object selector or drag and drop an object into the field" (a direct reference).
  https://docs.unity.com/en-us/engine/current/manual/scripting/managing-update-order/unity-events
- A destroyed object: "If your application tries to access the destroyed object again, Unity
  treats it as null", even when the C# reference is still there.
  https://docs.unity.com/en-us/engine/current/manual/scripting/get-started/fundamental-unity-types/class-object
- FROM MEMORY: GetComponent (the same object), GameObject.Find / FindWithTag (indirect, slow:
  cache the result), SendMessage (by method name), C# events.

Unreal (dev.epicgames.com, UE 5, read by an agent this session):
- Components tick with their actor (`TickComponent`); tick groups run in order, "each tick group
  will finish ticking every actor and component assigned to it before the next tick group
  begins"; `AddTickPrerequisiteActor/Component` orders two of them.
  https://dev.epicgames.com/documentation/en-us/unreal-engine/actor-ticking-in-unreal-engine
- FROM MEMORY: direct references (UPROPERTY pointers set in Details, soft references), event
  dispatchers (multicast delegates), Blueprint interfaces, Gameplay Tags, GetAllActorsOfClass
  (documented as slow).

## 2. The approaches, mapped

| | Unity / Unreal / Stride / Godot | Bevy (ECS) |
| --- | --- | --- |
| What runs | one instance per attachment, Update per instance | one system per kind, over every entity that has a component |
| State | the instance's fields | the entity's components |
| Sees | anything it holds a pointer to, at any time | what its query asks for |
| Order | not promised (Unity), priorities (Stride, Godot), tick groups (Unreal) | the schedule's order, explicit |
| Events | immediate calls: signals, UnityEvents, delegates | messages, read by systems later |
| References | object pointers; a destroyed one reads as null | Entity = index + generation; a stale one is an error |

The trade-off: the object model is how people think about a character ("this script, on this
thing"), and is what was asked; the ECS model is what a pure language can run without shared
mutable objects, in any order and in parallel. The proposal below takes the object model's surface
(a script on a thing, one instance each, its own fields in the Inspector) over the ECS model's
mechanics (data, pure functions, messages, ids).

## 3. Game Engine Architecture, Jason Gregory (FROM MEMORY, 3rd ed., chapter 16, "Runtime
Gameplay Foundation Systems")

- Component-based object models: a game object is an aggregate of components; this is Unity's.
- Object references: raw pointers dangle when an object dies; handles (an index into a handle
  table plus a unique id) do not, and a stale handle is detected. Bevy's Entity is one.
- Updating objects: when one object reads another during the same update, the result depends on
  who updated first ("one-frame-off" bugs). The fixes are phased updates (buckets) and reading the
  state of the previous frame.
- Events: an event as an object; queued events, delivered later, decouple sender and receiver and
  let the engine choose when they are handled.

The proposal follows each point: things get ids (handles); a script reads the others as they were
at the start of the tick (the previous state), so the order of scripts never matters; messages
are queued and delivered on the next tick.

## 4. Open-source references (source read by an agent this session)

- Stride (C#, the closest to Unity): `ScriptComponent` is an `EntityComponent` with
  `[AllowMultipleComponents]`, so each script is an instance with its own fields; `Priority`
  ("Lower values mean earlier execution"); `ScriptSystem.Add` initializes and queues Start;
  `SyncScript.Update` batches run by priority; removal calls `Cancel()`. Events: `EventKey<T>.
  Broadcast`, received through a buffered `EventReceiver`, which "we don't want to receive old
  events" clears on creation.
  https://raw.githubusercontent.com/stride3d/stride/master/sources/engine/Stride.Engine/Engine/ScriptComponent.cs
  https://raw.githubusercontent.com/stride3d/stride/master/sources/engine/Stride.Engine/Engine/Processors/ScriptSystem.cs
  https://raw.githubusercontent.com/stride3d/stride/master/sources/engine/Stride.Engine/Engine/Events/EventReceiverBase.cs
- Bevy: `Entity { index, generation }`; a despawned id gives `EntityNotSpawnedError`.
  `Messages<M>` keeps two buffers, `messages_a` and `messages_b`: a message lives across two
  `update`s, a reader that reads once per update never misses one, unread ones are "dropped
  silently".
  https://raw.githubusercontent.com/bevyengine/bevy/main/crates/bevy_ecs/src/entity/mod.rs
  https://raw.githubusercontent.com/bevyengine/bevy/main/crates/bevy_ecs/src/message/messages.rs
- Godot: each `Object` holds its own `ScriptInstance *`; indirect references by path
  (`get_node(NodePath)`) and by group (`add_to_group`, `get_nodes_in_group`, `call_group`, immediate
  since 4.0); signals (`connect`, `emit_signal`); `set_process_priority`.
  https://raw.githubusercontent.com/godotengine/godot/master/scene/main/node.h
  https://raw.githubusercontent.com/godotengine/godot/master/scene/main/scene_tree.h
  https://raw.githubusercontent.com/godotengine/godot/master/core/object/object.h

## 5. Bend, 2.0.40 (read: ../bend/guide/GUIDE.md, bend2/base.bend, CHANGELOG.md)

What decides the design:
- No traits, no interfaces, no reflection, no call by name at run time. Generic types exist
  (`type D<a, -A: Kind(a)>`), templates are compile-time (`~f`), and dependent pairs exist
  (`&x:A -> B`).
- A function or an array is a `Type` (one owner, never copied); the scene is `Data`. So a thing
  cannot hold a closure or an object: its script's state must be data.
- Imports are fixed: the engine cannot name a script it did not import, so the project's
  generated registry must dispatch to each script by a `match` (as PROJECT.bend does for projects).
- Base has `Map<V>` keyed by String, and parallel lets (`a b = f(x) g(y)`).
- Nothing in the CHANGELOG up to 2.0.40 adds traits or records.

## 6. Performance

- A script's update depends only on its own state, the state of the world at the start of the
  tick (shared, never copied: a Bend value is shared by reference count) and its messages. So
  every instance can update in parallel, with Bend's parallel lets: the order is never needed.
- Dispatch is one `match` per instance per tick; messages are lists.
- Finding by name or tag walks the scene: as in Unity, find once in start and keep the id.

## The proposal

### A. Things get ids (references)

- `Thing` gets an `id: U32`, given once when the thing is made and saved with the scene; never
  reused in a scene (a counter is saved with it), so no generation is needed (Bevy needs one
  because it reuses indexes). Fixes the Limits now "a thing has no id but its place in the list".
- A direct reference is a field of type `Ref` (an id) in a script's state, set in the Inspector by
  picking a thing (Unity's drag). Looking one up gives `Maybe`: a thing that is gone is `None`, as
  Unity's destroyed object reads as null.
- Things get `tags: List<String>` (Unity's tags, Godot's groups) for indirect references.

### B. A script attached to a thing

A script module declares its fields and two functions (the probe in tools/script/check.ts checks
this shape):

```bend
import Base
import ../../../engine/script/me.bend as Me

# This script's fields (Unity's serialized fields): one copy per thing it is on, shown and edited
# in the Inspector, saved with the scene.
type State is Data:
  State{speed: F32, target: Me.Ref}

def initial() -> State:
  State{1.0, Me.nobody()}

def start(+me: Me.Me<State>, +world: Me.World) -> Me.Me<State>:
  me

def update(+me: Me.Me<State>, +world: Me.World, +dt: F32) -> Me.Me<State>:
  Me.moved(me, ...)          # its own place; Me.send(me, target, ...) to talk to another
```

- `Me<State>` is the script's own thing (id, name, place, tags), its own fields, and the messages
  it received this tick; it returns them changed, with the messages it sends.
- `World` is a read-only view of the scene as it was at the start of the tick: `place_of(world,
  ref)`, `find_named`, `find_tagged`, `with_script(world, "Walk")` (indirect references). It reads
  others; it never changes them. Only messages change another thing.
- Attaching: an attachment is `Attached{thing: id, slot}` in a list beside the scene's things (a
  component column, the ECS way). The same script on two things is two attachments, each with its
  own `State`. A thing may have several scripts; they run in attachment order.

### C. Messages (events)

- A project declares its messages once (`projects/<p>/messages.bend`: `type Message is Data:
  Hit{power: F32}`, ...), so Bend checks every send and every receive.
- `Me.send(me, ref, msg)` to one thing; `Me.broadcast(me, tag, msg)` to every thing with a tag.
- Delivered at the start of the next tick, to every script on the receiving thing (Bevy's
  messages, Stride's event receivers). Not immediate as Godot's signals: an immediate call needs an
  order between scripts, and a pure update has none. The cost is one tick (1/60 s) of delay.
- Engine happenings (a click on the thing, Play starting) arrive as messages too, so rules become
  scripts the engine brings.

### D. The registry

It reads each script's `type State` and generates, for the project: a sum of every script's state
(`Slot.Walk{Walk.State}`, ...), the dispatch (`update(slot, ...)` by a match), and the Inspector's
view of the fields (their names and values, for the field kinds the Inspector can edit: F32, U32,
Bool, String, V3, Ref). Bend has no reflection, so this generated code is the reflection.

### E. The editor

- Inspector: Add Component > Script (the project's scripts), its fields with their values, a
  Ref field picked from the Hierarchy, Remove.
- Save writes the attachments and their fields with the scene (engine/scene/save.bend).
- A script removed or not compiling: the Inspector says so on the thing; Play and the build wait
  (as now).

### F. What happens to what exists

- Project scripts (systems over the whole scene) stay, for project-wide work, as Bevy's systems.
- Rules become scripts the engine brings (Move, Turn, Play on a message), keeping their editor.

### Order of the work

1. Ids and tags on things (engine/scene/scene.bend, save, editor); laws.
2. Scripts on things: State, start, update with Me and World; attachments; the registry's
   dispatch; Play; the checker's shape; Add Component > Script and Remove.
3. Fields in the Inspector (the generated view), saved; Ref fields picked in the Hierarchy.
4. Messages: the project's Message type, send and broadcast, delivery on the next tick; engine
   happenings as messages; rules as engine scripts.

### Decisions for the owner

1. Messages next tick (deterministic, any order, parallel) rather than immediate calls?
2. Project-wide scripts kept beside the attached ones?
3. One Message type per project (checked by Bend) rather than free-form messages by name?
4. Do the four steps in order, each one tested and shown before the next?


## What was built (2026-11-25)

The owner chose the recommended answers to the four decisions, and, for a networked game on the
web, three changes: ids with a generation, an indexed World, and where each script runs. What
changed from the proposal above while building it:

- Bend's missing inference made a generic `Me<State, Message>` unworkable (every call would name
  its types), so a script gets its thing (`Me.Me`) and its State as two arguments and gives both
  back: `update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State`.
- The engine cannot name a project's types, so an attachment's fields and a message's body are a
  Value (engine/script/value.bend); each project's registry writes the typed side from the
  declarations (tools/script/shape.js). This is also what lets the Inspector show any script's
  fields and the saved scene write them, with no generated editor.
- Messages are typed per project in `projects/<name>/messages.bend`; the registry writes
  `messages_generated.bend` (Mail.send, Mail.broadcast, Mail.received).
- The project's old scripts (over the whole scene) are now systems, in `systems/`; `scripts/` holds
  the attached ones. Create offers both.
- Rules stay as they are; the engine's happenings reach scripts as Me.clicked and start. Turning
  the Rule editor into scripts the engine brings was not done (it works, and nothing needed it).
- A thing's id is the scene's (index and generation): there is no server yet, so no machine in it.

Where each part is:

| Step | Where |
| --- | --- |
| 1. Ids and tags | `engine/scene/id.bend`, `engine/scene/scene.bend` (id, tags, scripts, inbox), the Inspector's Tags (`editor/scene/view.bend`), saved by name (`engine/scene/save.bend`'s tagged) |
| 2. Scripts on things | `engine/script/attach.bend`, `me.bend`, `run.bend`, `value.bend`; `engine/play/game.bend` (the tick runs them after the systems); the registry's dispatch and `tools/script/check.ts`'s shape; the Inspector (`editor/inspector/scripts.bend`) |
| 3. Fields and references | The Inspector's fields by kind (number, switch, text, V3, a menu of things for a reference); saved with references by name (`engine/scene/save.bend`'s attached, settled) |
| 4. Messages | `engine/script/message.bend`, the generated Mail; delivered on the next tick (`run.bend`'s deliver) |
| 5. The World's index | `engine/script/world.bend`: by id, name, tag, script, and the World's ground cells (`near`) |

How it is checked: laws (`engine/scene/LAWS.bend`: ids and generations, a removed thing not found,
an old id never naming a new thing; `engine/script/LAWS.bend`: fields, messages to an id and to a
tag, things with no script unchanged; `engine/play/LAWS.bend`), the Arena's tests on real ticks
(`tests/script/attached.bend`: two instances of one script, a reference followed and a removed one
not, a message on the next tick and once, order not mattering, the World's lookups), the save's tests
(`tests/scene/save.bend`), the checker's tests (`tests/tools/script-check.test.ts`), and the editor
in a browser (the Arena: fields shown, a speed changed and saved and read back, Play running it,
Stop giving the scene back).

## What a tick costs (measured, `bun tools/bench/scripts.ts`, WSL on this machine)

n things, each with the Arena's Walker, 60 ticks, in JavaScript (the browser's lane):

| n | ms per tick | of a 1/60 s tick | the World's index alone | with no script attached |
| --- | --- | --- | --- | --- |
| 10 | 0.34 | 2% | | 0.01 ms |
| 100 | 2.8 | 17% | 1.7–2.1 ms | 0.02 ms |
| 1000 | 24 | 145% | 21 ms | 0.1–0.2 ms |
| 10000 | 470 | 2800% | | |

Compiled for this machine (`bend tools/bench/scripts.bend -o ...`): 1000 things, 60 ticks in 0.535 s
including starting the program and making the scene, so at most 8.9 ms a tick.

What this says:
- The scripts themselves (their code, their fields to and from a Value, the dispatch) cost about
  3 µs a script in JavaScript. Nearly all the rest (about 87% at 1000) is making the World's index
  again every tick, with Base's String-keyed `Map`.
- On the web, one core runs a few hundred attached scripts within a tick; a thousand do not fit.
  Natively they fit in about half a tick, before using more cores.
- The next step for speed is to keep the index from tick to tick (updated as things move, made
  only once), and to index by number (an id's index) instead of by text.
