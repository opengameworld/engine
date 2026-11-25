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

const check = (text: string) => checkScript("animation", "Mover", text);

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
  const dir = join(ROOT, "projects", "animation", "scripts");
  const made = !existsSync(dir);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "Zbroken.bend"), HEAD + START + "def update(+s: S.Scene, +dt: F32) -> S.Scene:\n  dt\n");
  writeFileSync(join(dir, "Zgood.bend"), GOOD);
  try {
    const reg = await registryOf(join(ROOT, "projects", "animation"));
    expect(reg.text).toContain("import ./scripts/Zgood.bend as Script0");
    expect(reg.text).not.toContain("Zbroken.bend");
    expect(reg.text).toContain('Pb.Problem{"Zbroken", Pb.kind_of("type"), 8, 3, 2, "expected S.Scene, found F32", ""}');
    expect(reg.problems).toHaveLength(1);
  } finally {
    rmSync(join(dir, "Zbroken.bend"));
    rmSync(join(dir, "Zgood.bend"));
    if (made) rmSync(dir, { recursive: true });
  }
});
