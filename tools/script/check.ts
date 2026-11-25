// Checks a script's text with Bend's own checker, and says where the first error is.
//
// A script is checked as the engine will use it. Its text goes to a draft beside a probe, and
// the probe is checked: the probe imports the draft and calls start(s) and update(s, dt) the way
// each project's registry calls them (tools/project/registry.js, engine/play/game.bend). So a
// script that type-checks but does not keep that shape fails here, before the registry would fail
// to compile. The checker is Bend's (../bend/bend2/bend.ts: book_load, then book_valid, as
// `bend <file> --check-only` does). It is called in this process, not run as a command, because
// its error keeps the exact span (Err.spn: the file's text, its namespace, and the offsets where
// the error begins and ends), which the command only prints as text with no file name.
//
// The draft and the probe go in projects/<folder>/.checking-<pid>/, a hidden folder at the depth
// of scripts/. Every relative import of the script (../../../engine/..., ../../prefabs.bend,
// ../<file>.bend) resolves there as it does from scripts/. A name starting with "." is not the
// project's: the registry, the Project window's list, the dev server's watcher and git leave it
// out, as Unity ignores hidden files and folders.
//
//   checkScript(folder, name, text)   the first problem, or null when the text checks
//   checkSaved(folder, name)          the same, for the file on disk
//
// A problem is { kind, line, col, len, text, where }:
//   kind    what sort of error it is, from where Bend stopped (engine/script/problem.bend names
//           each): "syntax" (reading the text), "import" (an import line, or the file it names),
//           "type" (checking the code), "shape" (start or update is missing, or is not what the
//           engine calls), "unfinished" (a ? hole left in the code)
//   line, col   counted from 1 (0: no place); len is how many characters to mark on that line (at
//           least 1, never past its end, as Bend's own underline does)
//   text    what is wrong, in one line: Bend's "expected ..., found ..." with the script's own
//           names (S.Scene, not the module's path), without the list of the names in scope
//   where   "" when the error is in the script, or the repository path of the module it is in
//           (an engine module the script imports)
//
// Limits now:
// - Bend stops at its first error, so there is one problem at a time (Godot lists them all).
// - A column counts UTF-16 units, as JavaScript strings do: on a line with a character past
//   U+FFFF before the error, the mark is one place off per such character.
// - A script that imports another script of its folder (./Other.bend) cannot be checked: the
//   draft's folder has no other scripts.
// - Checks run one at a time in this process: the dev server waits for each.

import { mkdirSync, rmSync, writeFileSync, readFileSync } from "node:fs";
import { join, posix } from "node:path";
import { ROOT } from "../layers";

export type Kind = "syntax" | "import" | "type" | "shape" | "unfinished";
export type Problem = { kind: Kind; line: number; col: number; len: number; text: string; where: string };

const Bend = await import(join(ROOT, "..", "bend", "bend2", "bend.ts"));

// What the engine calls in Play (engine/play/game.bend), as the probe calls it.
const SHAPE: Record<string, string> = {
  start: "def start(+s: S.Scene) -> S.Scene",
  update: "def update(+s: S.Scene, +dt: F32) -> S.Scene",
};

function probeText(name: string): string {
  return [
    "import Base",
    "import ../../../engine/scene/scene.bend as S",
    `import ./${name}.bend as Script`,
    "",
    "def Probe.start(+s: S.Scene) -> S.Scene:",
    "  Script.start(s)",
    "",
    "def Probe.update(+s: S.Scene, +dt: F32) -> S.Scene:",
    "  Script.update(s, dt)",
    "",
  ].join("\n");
}
const PROBE_UPDATE_LINE = 8;   // the line of probeText's def Probe.update

// Line and column (from 1) of an offset in a text, and how much of that line to mark.
function place(str: string, beg: number, end: number) {
  const start = str.lastIndexOf("\n", beg - 1) + 1;
  const stop = str.indexOf("\n", beg);
  const lineEnd = stop < 0 ? str.length : stop;
  return {
    line: str.slice(0, beg).split("\n").length,
    col: beg - start + 1,
    len: Math.max(1, Math.min(end - beg, lineEnd - beg)),
  };
}

// Where `def <name>` is in the script, for a problem the probe found with it.
function defPlace(text: string, def: string) {
  const m = new RegExp(`^def\\s+(${def})\\b`, "m").exec(text);
  if (!m) return { line: 0, col: 0, len: 0 };
  return place(text, m.index + m[0].length - def.length, m.index + m[0].length);
}

// A path on this machine, as a repository path.
const local = (s: string) => s.split(ROOT.replaceAll("\\", "/") + "/").join("");

// What is wrong, in one line: Bend's expected and found (err_show's, without the names in scope
// and the place), written with the names of the file the error is in (its import aliases), and
// Bend's hint for a do-block when it has one. Bend's other notes (Err.nte) are left out: today the
// one there is tells the history of a change in Bend, not what is wrong in the script.
function message(e: any): string {
  const file = e.spn?.file, bnd = Bend.ctx_scope(e.ctx);
  const show = (x: any) => Bend.expr_show(e.bok, x, bnd, file);
  const said = e.obs === undefined ? show(e.exp) : `expected ${show(e.exp)}, found ${show(e.obs)}`;
  const note = e.spn ? Bend.err_lost_type(e) ?? "" : "";
  return local([said, note].filter((x) => x).join(". ").replace(/\s*\n\s*/g, " "));
}

// The kind of an error Bend threw while reading the files (book_load): an import line, or the
// file one names, or else the text itself.
function readKind(e: any): Kind {
  const exp = typeof e?.exp === "string" ? e.exp : "";
  return /^(an import|no such file|a fresh alias)/.test(exp) ? "import" : "syntax";
}

function problemOf(e: any, kind: Kind, name: string, text: string, folder: string): Problem {
  if (!e || e.$ !== "Err") return { kind, line: 0, col: 0, len: 0, text: local(String(e?.message ?? e).replace(/^Error:\s*/, "")), where: "" };
  if (!e.spn) return { kind, line: 0, col: 0, len: 0, text: message(e), where: "" };
  const f = e.spn.file;
  const at = place(f.str, e.spn.beg, e.spn.end);
  if (f.ns === name) return { kind, ...at, text: message(e), where: "" };
  // The probe (the root, namespace ""): the script does not keep the shape the engine calls.
  if (f.ns === "") {
    const def = at.line >= PROBE_UPDATE_LINE ? "update" : "start";
    const there = defPlace(text, def);
    const said = there.line ? `${def} must be ${SHAPE[def]}` : `the script has no ${def}; it must have ${SHAPE[def]}`;
    return { kind: "shape", ...there, text: `${said} (the engine calls it in Play)`, where: "" };
  }
  // A module the script imports: its path in the repository.
  const where = posix.normalize(posix.join("projects", folder, ".checking", f.ns + ".bend"));
  return { kind, ...at, text: message(e), where };
}

let queue: Promise<unknown> = Promise.resolve();

async function checkNow(folder: string, name: string, text: string): Promise<Problem | null> {
  const dir = join(ROOT, "projects", folder, `.checking-${process.pid}`);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `${name}.bend`), text);
  writeFileSync(join(dir, `${name}.probe`), probeText(name));
  const book = Bend.book_nil();
  try {
    try {
      await Bend.book_load(book, join(dir, `${name}.probe`), "", new Map());
    } catch (e) {
      return problemOf(e, readKind(e), name, text, folder);
    }
    try {
      Bend.book_valid(book);
    } catch (e) {
      return problemOf(e, "type", name, text, folder);
    }
    if (book.hols > 0) return { kind: "unfinished", line: 0, col: 0, len: 0, text: `${book.hols} hole${book.hols === 1 ? "" : "s"} (?) left in the code`, where: "" };
    return null;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// One check at a time: they share the draft folder.
export function checkScript(folder: string, name: string, text: string): Promise<Problem | null> {
  const run = queue.then(() => checkNow(folder, name, text));
  queue = run.catch(() => {});
  return run;
}

export function checkSaved(folder: string, name: string): Promise<Problem | null> {
  return checkScript(folder, name, readFileSync(join(ROOT, "projects", folder, "scripts", `${name}.bend`), "utf8"));
}

// `bun tools/script/check.ts <folder> <Name>`: checks the saved script, prints the problem as JSON.
if (import.meta.main) {
  const [folder, name] = process.argv.slice(2);
  const p = await checkSaved(folder!, name!);
  console.log(JSON.stringify(p));
  process.exit(p ? 1 : 0);
}
