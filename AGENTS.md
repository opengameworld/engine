# Engine: Agent Guidelines

This is the game engine of OpenGame, written in Bend. The game's vision and
the team's rules live in the `opengame` repository's `AGENTS.md`; read it
too. This file repeats the rules that apply to every change here, so an
agent opened in this repository sees them.

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
| `engine/` | The runtime, pure Bend | Yes |
| `platform/web/` | The only JavaScript of the runtime: drawing, input, frames | Yes |
| `editor/` | The editor: a tool | Never |
| `tools/` | dev server, check, tests, importer | Never |
| `projects/` | The engine's own test projects | No |
| `refs/` | Third-party reference characters, for study and tests | Never |

- `platform/web/` imports nothing from `editor/`. The editor imports from
  `platform/web/`.
- Nothing outside `refs/` imports from `refs/`. `bun run check` fails if
  anything does.

## Before a commit

- `bun run check` passes: laws, types, tests, reference laws, fences. It
  finds every `.bend` file by itself.
- A change that must not alter what is seen is measured before and after,
  not judged by eye: the editor's elements with `ui-verify`, and pictures
  of the canvas for the drawing.
- Say what was not tested.
