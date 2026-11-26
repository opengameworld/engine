
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
