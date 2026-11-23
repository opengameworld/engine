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
