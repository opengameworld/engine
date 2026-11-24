# Engine: Agent Guidelines

This is the game engine of OpenGame, written in Bend. The game's vision and
the team's rules live in the `opengame` repository's `AGENTS.md`; read it
too. This file repeats the rules that apply to every change here, so an
agent opened in this repository sees them.

## Read first: the game this engine serves

The vision is in `../opengame/AGENTS.md` (the sibling folder of this
repository). Read that file at the start of every session, before answering
a question about what fits the game. In short, so no one has to repeat it:

- A metaverse inspired by Greed Island: one planet, mapped whole, at 1:1
  human scale in meters. No goal and no win condition: walking, riding
  creatures, living in the world.
- It runs on the web, on everything: desktop, phone, VR. The ambition is
  Roblox-like accessibility with Unreal-level graphics.
- The world's seed is fixed from the start; the world evolves without
  breaking what was generated.

## What we are building

- A game engine from scratch, one step at a time. Each version adds what we
  decide it needs, and nothing more (`master.txt`).
- Bend is still in development. Obstacles are expected: understand and
  address them. Do not move work to another language to get it done.
- Right now everyone builds engine modules. The game comes after.

## Before a decision about a tool or the architecture

Follow these steps, in order, and show the result before writing the code:

1. Analyze how Unreal Engine and Unity handle the problem.
2. Map the approaches, with their rationale and trade-offs.
3. Check the analysis against *Game Engine Architecture* by Jason Gregory.
4. Choose open-source projects of the feature's domain and read their
   source for direct, 1:1 implementation references.
5. Check the latest Bend updates and the patterns the Bend team is setting
   (a clone of bendlang/bend sits at `../bend`).
6. Prioritize performance: the game must be playable by as many people as
   possible.

Say which of these you read in this session and which you only remember.

## Rules of the code

- Every rule, every number and every decision lives in `.bend` files.
  JavaScript only reads input and draws what Bend returns.
- The interface uses Bend-UI, and only Bend-UI. Never invent a menu or a
  panel that was not asked for.
- Everything that moves reads `editor/defaults/ACCESSIBILITY.bend`. Nothing
  moves by itself while reduce motion is on.
- Every feature file has a `Limits now:` block that says what it does not
  do yet. Keep it true when you change the file.
- Nothing is added "to have it": a number comes from a rule that already
  exists (the World's units, a Transform, a token), and the code says which.
- Objects are data, the ECS way: a thing is data, and what things do are
  pure functions from a scene to the next one.
- Code, comments and documents are in English.

## Where things live

| Folder | What it is | Ships inside a game |
| --- | --- | --- |
| `engine/` | The runtime, pure Bend: one folder per system (`core/`, `scene/`, `render/`, `anim/`, `input/`, `play/`, `script/`), each with its laws | Yes |
| `platform/web/` | The only JavaScript of the runtime: drawing, input, frames | Yes |
| `editor/` | The editor: a tool | Never |
| `tools/` | dev server, check, tests, importer | Never |
| `projects/` | The engine's own test projects | No |
| `docs/references/` | The sources each system was built from, with links and numbers | Never |
| `mannequin/` | The standard character: its skeleton, helper rules, skin and laws | Yes, with its credit |
| `library/` | The animation library: its catalog and each collection's motions, with credits | Yes, the clips a game uses |
| `refs/` | Third-party assets kept only for study (none now) | Never |

- `platform/web/` imports nothing from `editor/`. The editor imports from
  `platform/web/`.
- Nothing outside `refs/` imports from `refs/`. `bun run check` fails if
  anything does.

## The mannequin

- `mannequin/` is the engine's standard character, as Manny and Quinn are
  Unreal's: the engine opens with it, clips are made on it and shown on it,
  and other characters are checked against it and retargeted to it. This
  was decided by the project's owner; do not propose another one.
- The rig standard is `engine/anim/skeleton.bend` (roles, slots, laws). The
  mannequin is the character that keeps it; its rest pose is the T-pose
  (`tests/mannequin/mannequin.bend`).
- It is content, not engine code: a game may bring its own character, if
  that character keeps the standard.
- Its mesh and textures are third-party work (`mannequin/CREDITS.md`). The
  credit goes wherever the mannequin goes.

## Dependencies from GitHub

A dependency that lives on GitHub (Bend-UI today) is pinned in `package.json`
as the tarball of one full commit, on `codeload.github.com`:

    "bend-ui": "https://codeload.github.com/isabellaherman/Bend-UI/tar.gz/<40-hex commit>"

Never as `github:owner/repo#<sha>` or a `git+https` URL, short or full:

- Bun turns both into `github:owner/repo#<7 hex>` in `bun.lock` and fetches
  `api.github.com/repos/<owner>/<repo>/tarball/<7 hex>` on every clean
  install, whatever `package.json` says.
- On 2026-11-23 that API answered 504 for the short id of Bend-UI's pinned
  commit, for several minutes, while the full commit resolved, so a clean
  `bun install` failed on every machine without a cache (issue #5).
- The codeload URL keeps the full commit in `bun.lock`, never touches the API,
  and records a `sha512` of the package, so a changed tarball fails the install.
- A short id also stops being unique as a repository grows.

To move the pin, change the commit in the URL and run `bun install`.

## Before a commit

- `bun run check` passes: laws (every module's `PROOF.bend`, the mannequin's too),
  types, tests, fences. It finds every `.bend` file and every `PROOF.bend` by itself.
- A change that must not alter what is seen is measured before and after,
  not judged by eye: the editor's elements with `ui-verify`, and pictures
  of the canvas for the drawing.
- Say what was not tested.
