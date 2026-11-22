// `bun run check`: every check the engine has, in order. It stops at the
// first one that fails.
//
// 1. Laws: `bend PROOF.bend` (and the editor's own) must print ALL PROOFS CHECK.
// 2. Types: every .bend file compiles (--check-only). They are found, not listed.
// 3. Tests: the numerical tests in tests/*.bend (tools/test.ts).
// 4. Study-only characters in refs/, when present.
// 5. Layers: every code file belongs to a layer of LAYERS.bend, every import is one its layer
//    may make (or a named debt), and every debt is still used. This includes the old refs/
//    fence: nothing outside refs/ imports from it.
//
// Limits now:
// - LAYERS.bend says which .bend files are type-checked (its places()); a .bend file in a folder
//   it does not name fails step 5 instead of being skipped silently.

import { $ } from "bun";
import { existsSync, readdirSync } from "node:fs";
import { codeFiles, imports, rules } from "./layers";

// LAYERS.bend decides which .bend files are type-checked. LAWS.bend and PROOF.bend files are
// left out: laws alone are unproved statements, and step 1 checks them with their proofs.
const L = await rules();
const files = codeFiles();
const typed = files.filter((f) => f.endsWith(".bend") && L.typed(f) && !/(LAWS|PROOF)\.bend$/.test(f));

function step(title: string) { console.log(`\n== ${title}`); }

// The shader catalog is written first: editor/shaders/catalog_generated.bend is Bend the editor
// imports, made from the projects' shader files.
await $`bun tools/shaders/catalog.js`.quiet();

step("laws");
await $`bend PROOF.bend`;
await $`bend editor/defaults/PROOF.bend`;
await $`bend mannequin/PROOF.bend`;   // the standard character keeps the rig standard

step("types");
for (const f of typed) await $`bend ${f} --check-only`.quiet();
console.log(`${typed.length} files compile`);

step("tests");
await $`bun tools/test.ts`;
await $`bun test tests/shader-catalog.test.js`;

// Study-only characters (refs/): their own laws, when there are any. Each has a PROOF.bend next to its generated skeleton.
if (existsSync("refs")) {
  step("study characters in refs/");
  for (const d of readdirSync("refs")) {
    if (existsSync(`refs/${d}/PROOF.bend`)) { await $`bend refs/${d}/PROOF.bend`.quiet(); console.log(`refs/${d}: laws hold`); }
  }
}

step("layers");
const fails: string[] = [];
const owed = new Map<string, string>();
for (const f of files) {
  if (!L.placed(f)) fails.push(`${f}: no layer; add its folder to LAYERS.bend places()`);
  for (const t of imports(f)) {
    const v: string = L.verdict(f, t);
    if (v.startsWith("blocked")) fails.push(`${f} imports ${t}: ${v.slice(9)}`);
    else if (v.startsWith("owed")) owed.set(`${f} -> ${t}`, v.slice(6));
  }
}
// A debt nothing uses any more fails, so the list cannot rot. Debts from a generated game
// (.export/gen/) are export's to check, on every build.
for (let l = L.debt_lines(); l.$ === "Con"; l = l.tail) {
  const [from, to] = l.head.split("\t");
  if (from.startsWith(".export/")) continue;
  if (![...owed.keys()].some((k) => k.startsWith(from) && k.endsWith(` -> ${to}`))) fails.push(`debt ${from} -> ${to} is paid: remove it from LAYERS.bend debts()`);
}
for (const [edge, why] of owed) console.log(`owed: ${edge} (${why})`);
if (fails.length) { console.error(fails.join("\n")); process.exit(1); }
console.log(`${files.length} files in their layers; every import allowed or owed`);
console.log("\nALL CHECKS PASS");
