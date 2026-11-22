// `bun run check`: every check the engine has, in order. It stops at the
// first one that fails.
//
// 1. Laws: `bend PROOF.bend` (and the editor's own) must print ALL PROOFS CHECK.
// 2. Types: every .bend file compiles (--check-only). They are found, not listed.
// 3. Tests: the numerical tests in tests/*.bend (tools/test.ts).
// 4. Study-only characters in refs/, when present.
// 5. Fences: nothing outside refs/ imports from refs/, so third-party
//    reference assets can never reach a build.
//
// Limits now:
// - Types are checked in the root and in engine/, projects/, mannequin/,
//   library/, editor/ and tests/. A .bend file in a new top-level folder is not seen until the
//   folder is added to FOLDERS below.

import { $ } from "bun";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

// Every .bend file of the engine: the ones at the root and all under these
// folders. LAWS.bend and PROOF.bend files are left out: laws alone are
// unproved statements, and step 1 checks them with their proofs.
const FOLDERS = ["engine", "projects", "mannequin", "library", "editor", "tests", "export"];
function bendFiles(dir: string, deep: boolean): string[] {
  const out: string[] = [];
  for (const name of readdirSync(dir).sort()) {
    const p = dir === "." ? name : join(dir, name);
    if (statSync(p).isDirectory()) { if (deep) out.push(...bendFiles(p, true)); }
    else if (name.endsWith(".bend") && !/(LAWS|PROOF)\.bend$/.test(name)) out.push(p);
  }
  return out;
}
const typed = [...bendFiles(".", false), ...FOLDERS.flatMap((d) => bendFiles(d, true))];

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

step("fences");
const offenders: string[] = [];
function walk(dir: string) {
  for (const name of readdirSync(dir)) {
    if ([".git", "node_modules", "refs", "dist", "tothinkabout"].includes(name)) continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p);
    else if (/\.(bend|js|ts|html)$/.test(name) && /^\s*import\s[^\n]*refs\/|from\s+["'][^"']*refs\/|src=["'][^"']*refs\//m.test(readFileSync(p, "utf8"))) offenders.push(p);
  }
}
walk(".");
if (offenders.length) { console.error("these files import from refs/:", offenders); process.exit(1); }
console.log("nothing outside refs/ imports from refs/");
console.log("\nALL CHECKS PASS");
