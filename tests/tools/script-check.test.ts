// The script checker (tools/script/check.ts): each kind of problem is found, at Bend's place for
// it, and a script that checks has none. The registry (tools/project/registry.js) leaves a script
// with a problem out, lists it in problems(), and fails as a command.

import { expect, test } from "bun:test";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { checkScript } from "../../tools/script/check.ts";
import { registryOf } from "../../tools/project/registry.js";

const ROOT = join(import.meta.dir, "..", "..");
const HEAD = "import Base\nimport ../../../engine/scene/scene.bend as S\n\n";
const START = "def start(+s: S.Scene) -> S.Scene:\n  s\n\n";
const GOOD = HEAD + START + "def update(+s: S.Scene, +dt: F32) -> S.Scene:\n  s\n";

// A system (systems/): start(s) and update(s, dt) over the whole scene.
const check = (text: string) => checkScript("animation", "Mover", text, "systems");

test("a script that keeps the engine's shape has no problem", async () => {
  expect(await check(GOOD)).toBeNull();
});

test("a type error is found where Bend points: line 8, column 3, two characters (dt)", async () => {
  const p = await check(HEAD + START + "def update(+s: S.Scene, +dt: F32) -> S.Scene:\n  dt\n");
  expect(p).toMatchObject({ kind: "type", line: 8, col: 3, len: 2, where: "", text: "expected S.Scene, found F32" });
  expect(p!.text).toContain("F32");
});

test("a syntax error is found where the parser stopped", async () => {
  const p = await check(HEAD + "def start(+s: S.Scene) -> S.Scene:\n  s +\n\n" + "def update(+s: S.Scene, +dt: F32) -> S.Scene:\n  s\n");
  expect(p).toMatchObject({ kind: "syntax", line: 7, col: 1, where: "" });
});

test("a script without update says what the engine calls", async () => {
  const p = await check(HEAD + START);
  expect(p).toMatchObject({ kind: "shape", line: 0 });
  expect(p!.text).toContain("def update(+s: S.Scene, +dt: F32) -> S.Scene");
});

test("an update with the wrong parameters is marked on its def", async () => {
  const p = await check(HEAD + START + "def update(+s: S.Scene) -> S.Scene:\n  s\n");
  expect(p).toMatchObject({ kind: "shape", line: 7, col: 5, len: 6 });
});

test("an import of a file that is not there is an import error, on its line", async () => {
  const p = await check("import Base\nimport ../../../engine/nope.bend as N\n" + GOOD.slice("import Base\n".length));
  expect(p).toMatchObject({ kind: "import", line: 2, text: "no such file: engine/nope.bend" });
});

test("the draft folder is gone after a check", async () => {
  await check(GOOD);
  expect(existsSync(join(ROOT, "projects", "animation", `.checking-${process.pid}`))).toBe(false);
});

test("the registry leaves a script that does not compile out, and lists its problem", async () => {
  const dir = join(ROOT, "projects", "animation", "systems");
  const made = !existsSync(dir);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "Zbroken.bend"), HEAD + START + "def update(+s: S.Scene, +dt: F32) -> S.Scene:\n  dt\n");
  writeFileSync(join(dir, "Zgood.bend"), GOOD);
  try {
    const reg = await registryOf(join(ROOT, "projects", "animation"));
    expect(reg.text).toContain("import ./systems/Zgood.bend as System0");
    expect(reg.text).not.toContain("Zbroken.bend");
    expect(reg.text).toContain('Pb.Problem{"Zbroken", Pb.kind_of("type"), 8, 3, 2, "expected S.Scene, found F32", ""}');
    expect(reg.problems).toHaveLength(1);
  } finally {
    rmSync(join(dir, "Zbroken.bend"));
    rmSync(join(dir, "Zgood.bend"));
    if (made) rmSync(dir, { recursive: true });
  }
});

// A script attached to things (scripts/): its State, initial(), runs(), start(me, s), update(me, s, dt).
const ME = "import Base\nimport ../../../engine/script/me.bend as Me\nimport ../../../engine/core/vec.bend as V\n\n";
const OBJECT = ME + "type State is Data:\n  State{speed: F32}\n\ndef initial() -> State:\n  State{1.0}\n\ndef runs() -> Me.Runs:\n  Me.both()\n\n" +
  "def start(+me: Me.Me, +s: State) -> Me.Me & State:\n  (me, s)\n\ndef update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State:\n  State{v} = s\n  (Me.moved(me, V.V3{(v * dt : F32), 0.0, 0.0}), State{v})\n";
const attached = (text: string) => checkScript("animation", "Mover", text);

test("an attached script that keeps its shape has no problem", async () => {
  expect(await attached(OBJECT)).toBeNull();
});

test("a field of a kind the engine cannot keep is a shape error on the State's line", async () => {
  const p = await attached(OBJECT.replace("State{speed: F32}", "State{speed: List<F32>}"));
  expect(p).toMatchObject({ kind: "shape", line: 6 });
  expect(p!.text).toContain("F32, U32, Bool, String, V.V3 or Id.Id");
});

test("an attached script without runs says what the engine calls", async () => {
  const p = await attached(OBJECT.replace("def runs() -> Me.Runs:\n  Me.both()\n\n", ""));
  expect(p).toMatchObject({ kind: "shape" });
  expect(p!.text).toContain("def runs() -> Me.Runs");
});

test("an update with the old shape (a system's) is marked on its def", async () => {
  const p = await attached(OBJECT.replace("def update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State:\n  State{v} = s\n  (Me.moved(me, V.V3{(v * dt : F32), 0.0, 0.0}), State{v})", "def update(+s: State, +dt: F32) -> State:\n  s"));
  expect(p).toMatchObject({ kind: "shape", line: 17 });
  expect(p!.text).toContain("def update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State");
});
