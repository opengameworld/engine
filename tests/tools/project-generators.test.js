import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { SAMPLE, registryText } from "../../tools/project/registry.js";
import { filesText, listFolder } from "../../tools/project/files.js";
import { bendCatalog, scanProject } from "../../tools/shaders/catalog.js";

// A project outside the engine: its registry sits in gen/ and reaches the engine as a Bend package.
const OUTSIDE = { project: "../", engine: "opengame-engine@0.4.0.0/", prefabs: "opengame-engine@0.4.0.0/editor/prefabs.bend" };

function project(t) {
  const dir = mkdtempSync(join(tmpdir(), "bend-project-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  mkdirSync(join(dir, "scenes", "saved"), { recursive: true });
  mkdirSync(join(dir, "scripts"));
  mkdirSync(join(dir, "shaders"));
  writeFileSync(join(dir, "scenes", "Shore.bend"), "");
  writeFileSync(join(dir, "scenes", "saved", "Shore.bend"), "");
  writeFileSync(join(dir, "scripts", "Tide.bend"), "");
  return dir;
}

const imports = (text) => text.split("\n").filter((l) => l.startsWith("import "));

test("a sample's registry imports the engine and its own files by relative path", (t) => {
  assert.deepEqual(imports(registryText(project(t), SAMPLE)), [
    "import Base",
    "import ../../engine/scene/scene.bend as S",
    "import ../../engine/scene/save.bend as Save",
    "import ../../engine/script/rule.bend as R",
    "import ../prefabs.bend as Pre",
    "import ./scenes/Shore.bend as Scene0",
    "import ./scenes/saved/Shore.bend as Saved0",
    "import ./scripts/Tide.bend as Script0",
  ]);
});

test("a registry outside the engine imports the engine by package and the project from gen/", (t) => {
  assert.deepEqual(imports(registryText(project(t), OUTSIDE)), [
    "import Base",
    "import opengame-engine@0.4.0.0/engine/scene/scene.bend as S",
    "import opengame-engine@0.4.0.0/engine/scene/save.bend as Save",
    "import opengame-engine@0.4.0.0/engine/script/rule.bend as R",
    "import opengame-engine@0.4.0.0/editor/prefabs.bend as Pre",
    "import ../scenes/Shore.bend as Scene0",
    "import ../scenes/saved/Shore.bend as Saved0",
    "import ../scripts/Tide.bend as Script0",
  ]);
});

test("any project folder is listed, and its files become a module", (t) => {
  const dir = project(t);
  assert.deepEqual(listFolder(dir), ["scenes/Shore.bend", "scenes/saved/Shore.bend", "scripts/Tide.bend", "shaders/"]);
  const text = filesText([["lake", listFolder(dir)]]);
  assert.match(text, /pick\(String\.eq\(folder, "lake"\), \[\n {4}"scenes\/Shore\.bend",/);
});

test("one project's shaders are scanned, and the catalog's engine import follows the prefix", (t) => {
  const dir = project(t);
  const glsl = "#version 300 es\nprecision highp float;\nout vec4 color;\nvoid main() { color = vec4(1.0); }";
  writeFileSync(join(dir, "shaders", "glow.frag.glsl"), glsl);
  writeFileSync(join(dir, "shaders", "glow.frag.glsl.json"), JSON.stringify({ label: "Glow", stage: "fragment", lighting: "unlit", parameters: [] }));
  const scanned = scanProject(dir, () => { throw new Error("no HLSL here"); });
  assert.deepEqual(scanned.assets.map((a) => a.id), ["glow.frag.glsl"]);
  assert.deepEqual(scanned.diagnostics, []);
  assert.ok(bendCatalog({ lake: scanned }).includes("import ../../engine/render/shader/asset.bend as A"));
  assert.ok(bendCatalog({ lake: scanned }, OUTSIDE.engine).includes("import opengame-engine@0.4.0.0/engine/render/shader/asset.bend as A"));
});
