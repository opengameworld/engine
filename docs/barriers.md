# Barriers: limits that exist on only one side

The engine runs on two tracks from the same Bend code: **web** (Bend → JS, WebGL2, WebAudio) and
**native** (Bend → C, bend-gpu with OpenGL, sound through Base's runtime). Pure code (rules, laws,
tests) is the same on both. Only the files that call JS or C effects differ, and every limit that
exists on just one side is written here, with what the engine does about it.

Each system gets a web path that works, even if simpler. Native is where the game reaches its
best.

| Side | Barrier | What the engine does | Source |
| --- | --- | --- | --- |
| Web | No parallelism: Bend's JS output runs on one thread, so the forks native code runs on several cores run one after another. | Systems size their web work to one core (fewer bodies, nearer streaming, smaller particle counts) through settings, never through different rules. | Bend's JS target |
| Web | Audio can only start after a click or key press (the browser's autoplay rule). | Sound starts muted and opens on the first input. | Browser rule |
| Native | A file that imports C/JS effects never passes `--check-only` (it exits 1: "N defs rely on unsafe or foreign code"). | Effects live in their own files; pure modules never import them. Effect files are checked by building and running them. | CATCHES T11 |
| Native (Mac) | A large native build can crash Apple clang's backend ("live register clobbered by inserted prologue instructions"). | Build through C with `PRESERVE` turned off (CATCHES T26). | CATCHES T26 |
| Native (GPU compute) | Bend's `!` (GPU) runs only on Linux and macOS; Windows and WSL fall back to the CPU pool. | CPU first; `!` is only a speedup. Graphics go through bend-gpu's OpenGL effect, not `!`. | CATCHES P5 |
| Native (Windows) | Bend has no Windows build: the `.exe` is cross-built in WSL with bend-win. | Not tested on the Mac. Windows builds are checked later on a Windows PC, by the owner or a teammate. | CATCHES T1, T12 |

## What Bend asked of the editor's scenes and scripts (2026-11-23)

Not barriers between web and native: rules of the language met while building scenes and scripts,
and how the engine follows them.

| Rule | What the engine does | Where |
| --- | --- | --- |
| An import path takes plain names (letters, digits, `_`, `-`): `./scenes/Beach.saved.bend` is refused. | A scene's saved file is `scenes/saved/<Scene>.bend`, not `<Scene>.saved.bend`. | `engine/scene/save.bend`, `tools/project/registry.js` |
| A function passed as a template (`~f`) must match its type's copyability: a script `start(+s: S.Scene)` is `@+s: S.Scene -> S.Scene`, not `S.Scene -> S.Scene`. With a plain `s` a script could use the scene only once. | Scripts take `+s` and `+dt`; Play's templates are typed `@+s: ... -> @+dt: ... -> ...`. | `engine/play/game.bend`, `engine/play/play.bend` |
| `Kind`, `where` and `File` are words of the language, not names. | The types are `Sort`, `Prefab` and `Written`; the function is `target`. | `editor/project/`, `projects/prefabs.bend` |
| A Bend import is fixed: a module nobody imports is not compiled (as Bevy needs every system added to its App). | Each project's registry imports its scenes and scripts, written by a tool from the folders, so none is forgotten. | `tools/project/registry.js`, `PROJECT.bend` |

## What Bend asked of scripts attached to things (2026-11-25)

Met while building ids, attached scripts, messages and the World's index (docs/references/object-scripts.md).

| Rule | What the engine does | Where |
| --- | --- | --- |
| No traits, no reflection, no call by name: the engine cannot name a project's types (a script's State, its Message), nor call a script by its name. | A script's fields and a message's body are kept as a Value; each project's registry writes, from the declarations, the functions between them and the typed side, and the `match` that runs a script by name (tools/script/shape.js). | `engine/script/value.bend`, `tools/project/registry.js` |
| Almost no inference: a generic type (`Me<State, Message>`) makes every call name its types. | A script gets its thing (`Me`, not generic) and its State as separate arguments, and gives both back; typed messages go through the project's generated `Mail`. | `engine/script/me.bend` |
| A function or an array is a `Type` (one owner): the scene, a `Data`, holds neither. | Attached scripts' state is data (Value); behavior is the project's code, passed to Play as a template (`~run`). | `engine/script/run.bend` |
| `Kind` and `where` are words of the language (again). | The type is `Fault` (a problem's kind) and `Offer` (a script a project offers); the function is `located`. | `engine/script/problem.bend`, `engine/script/attach.bend`, `editor/code/view.bend` |
| No negative literals. | `(0.0 - x : F32)`, as `engine/scene/save.bend` writes them. | `projects/arena/scenes/Arena.bend` |
| A `match` only on a parameter, never after a `let`, and destructuring only a parameter (not a call's result). | A computed choice goes through its own def (`*_if`, `pick_*`); a pair a function returns is opened by the def it is passed to. | everywhere in `engine/script/` |
| No mutual recursion between defs (each is checked in file order), and a recursive call's first shrinking argument must come first. | One recursive def, choosing between values already computed (`pick`), or matching the list and an index together; the list is the first argument. | `engine/scene/id.bend`, `engine/scene/save.bend` |
| A pair (`A & B`) is not `Data`: it cannot be a `+` (reusable) argument. | Pairs are taken once and opened where they arrive. | `engine/script/run.bend` |
| Base's `Map` takes String keys and gives the map back with what it reads. | The World's index keys ids, names, tags, scripts and cells by text; on the web, building it is most of a tick's cost (measured: docs/references/object-scripts.md). | `engine/script/world.bend` |
