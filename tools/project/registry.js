// Each project's registry: its scenes and its scripts, as Bend (projects/<name>/project_generated.bend).
//
// A Bend import is fixed: a module nobody imports does not exist for the compiler, so a new scene or
// script must be imported somewhere before it can open or run. Bevy has the same rule ("all systems
// you want to run must be added ... in the App ahead of time") and warns that forgetting one is a
// common mistake. This file removes the mistake: it lists projects/<name>/scenes/*.bend,
// projects/<name>/systems/*.bend and projects/<name>/scripts/*.bend and writes the module that
// imports them all, so a file in one of those folders is in the project. From messages.bend it
// writes messages_generated.bend (tools/script/shape.js). `bun run dev`, `check`, `build` and
// `export` write them; the dev server writes them again after the editor creates a scene or a script.
//
// What the registry gives (PROJECT.bend calls it for each project):
//   scenes()             the scenes' names, by file name
//   opened(name)         the scene as it opens: its code, minus the things deleted in the editor,
//                        plus the things made in it (projects/prefabs.bend), at the places and with
//                        the tags and attached scripts saved, every attachment's fields over its
//                        script's defaults
//   rules(name)          its rules: the saved ones when the editor saved its own, the code's otherwise
//   own_rules, made, removed   what its saved file holds (empty when it has none yet)
//   start(s), update(s, dt)    every system's, in file-name order (engine/play/game.bend runs them)
//   run(name, first, me, v, dt)   one tick of the attached script with that name (engine/script/
//                              run.bend runs it for every attachment), from the code shape.js writes
//   scripts(), defaults(name), runs(name)   the attached scripts, a new attachment's fields, and
//                              where each runs (the Inspector's Add Component > Script)
//   problems()                 every script or system that does not compile, where, and what Bend
//                              said (engine/script/problem.bend)
//
// Every script is checked first (tools/script/check.ts). One that does not compile is left out of
// the imports, so the rest of the project compiles and the editor still opens on it; its problem
// is in problems(), which stops Play (engine/play/play.bend's to_mode_checked) and the Console
// says. Run as a command (`bun run build`, `bun run check`, export), a problem fails it: a game is
// never built without one of its scripts.
//
// Limits now:
// - The scripts run in the order of their file names, as Unity runs scripts in an order it does
//   not promise unless Script Execution Order sets one; here the order is fixed and written.
// - A scene or script whose file name is not a word (letters, digits, _) is left out, with a line
//   in the server's output: its name becomes a Bend name.
// - Every script is checked each time the registry is written (about a second each), as the
//   engine it uses may have changed; nothing is cached.
// - Scenes are not checked here: a scene that does not compile still stops the page.

import { existsSync, readdirSync, readFileSync, renameSync, statSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { checkScript } from "../script/check.ts";
import { fieldsOf, messagesOf, mailText, stateCode } from "../script/shape.js";

// A Bend string literal (Bend's escapes: \n \t \r \0 \\ \' \" \u{...}).
const bendString = (s) => '"' + [...s].map((c) => {
  if (c === "\\") return "\\\\";
  if (c === '"') return '\\"';
  if (c === "\n") return "\\n";
  if (c === "\t") return "\\t";
  if (c === "\r") return "\\r";
  const n = c.codePointAt(0);
  return n < 32 || n === 127 ? `\\u{${n.toString(16)}}` : c;
}).join("") + '"';

const WORD = /^[A-Za-z][A-Za-z0-9_]*$/;

function names(dir, suffix) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => f.endsWith(suffix) && statSync(join(dir, f)).isFile())
    .map((f) => f.slice(0, -suffix.length))
    .filter((n) => { if (WORD.test(n)) return true; console.warn(`[${dir}] ${n}${suffix} is left out: its name must be a word`); return false; })
    .sort();
}

const quote = (s) => JSON.stringify(s);

// One def that picks by the scene's place: case 0 .. n-1, and the default.
function byIndex(name, type, cases, none) {
  let out = `def ${name}(+i: U32) -> ${type}:\n  match i:\n`;
  cases.forEach((c, i) => { out += `    case ${i}:\n      ${c}\n`; });
  return out + `    case _:\n      ${none}\n`;
}

// The project's scripts of one kind, each with its problem (null when it compiles).
async function checked(dir, folder, kind) {
  const out = [];
  for (const n of names(join(dir, kind), ".bend")) {
    const text = readFileSync(join(dir, kind, `${n}.bend`), "utf8");
    out.push({ name: n, kind, text, problem: await checkScript(folder, n, text, kind) });
  }
  return out;
}

function problemText(name, p) {
  return `Pb.Problem{${bendString(name)}, Pb.kind_of(${bendString(p.kind)}), ${p.line}, ${p.col}, ${p.len}, ${bendString(p.text)}, ${bendString(p.where)}}`;
}

// The project's messages_generated.bend (tools/script/shape.js's mailText), from its messages.bend;
// a messages.bend that cannot be read is a problem, as a script's is.
function writeMail(dir) {
  const src = join(dir, "messages.bend"), out = join(dir, "messages_generated.bend");
  if (!existsSync(src)) return null;
  const r = messagesOf(readFileSync(src, "utf8"));
  if (r.error) return { kind: "shape", line: 0, col: 0, len: 0, text: r.error, where: "" };
  const text = mailText(r.messages);
  if (!existsSync(out) || readFileSync(out, "utf8") !== text) writeFileSync(out, text);
  return null;
}

// The registry's text, and the problems of the scripts it left out.
export async function registryOf(dir) {
  const folder = dir.split(/[\\/]/).filter(Boolean).pop();
  const scenes = names(join(dir, "scenes"), ".bend");
  const mailProblem = writeMail(dir);
  const all = [...await checked(dir, folder, "systems"), ...await checked(dir, folder, "scripts")];
  const systems = all.filter((s) => s.kind === "systems" && !s.problem).map((s) => s.name);
  const scripts = all.filter((s) => s.kind === "scripts" && !s.problem).map((s) => ({ name: s.name, fields: fieldsOf(s.text).fields }));
  const broken = [...(mailProblem ? [{ name: "messages", kind: "", problem: mailProblem }] : []), ...all.filter((s) => s.problem)];
  const saved = scenes.map((n) => existsSync(join(dir, "scenes", "saved", `${n}.bend`)));
  const savedHas = (i, def) => saved[i] && readFileSync(join(dir, "scenes", "saved", `${scenes[i]}.bend`), "utf8").includes(`def ${def}()`);
  let t = `# GENERATED by tools/project/registry.js from this project's scenes/, systems/ and scripts/. Do not
# edit: bun run dev, check, build and export write it again. (tools/project/registry.js says what each
# def is.)

import Base
import ../../engine/scene/scene.bend as S
import ../../engine/scene/save.bend as Save
import ../../engine/script/rule.bend as R
import ../../engine/script/problem.bend as Pb
import ../../engine/script/me.bend as Me
import ../../engine/script/value.bend as Val
import ../prefabs.bend as Pre
`;
  scenes.forEach((n, i) => {
    t += `import ./scenes/${n}.bend as Scene${i}\n`;
    if (saved[i]) t += `import ./scenes/saved/${n}.bend as Saved${i}\n`;
  });
  systems.forEach((n, i) => { t += `import ./systems/${n}.bend as System${i}\n`; });
  scripts.forEach((s, k) => { t += `import ./scripts/${s.name}.bend as Script${k}\n`; });
  t += `\ndef scenes() -> List<&2, String>:\n  [${scenes.map(quote).join(", ")}]\n\n`;
  t += `def Reg.pick(c: Bool, +a: U32, +b: U32) -> U32:\n  match c:\n    case True{}:\n      a\n    case False{}:\n      b\n\n`;
  t += `# A scene's place among scenes() (${scenes.length} for a name that is not one).\ndef index(+name: String) -> U32:\n  `;
  t += scenes.map((n, i) => `Reg.pick(String.eq(name, ${quote(n)}), ${i}, `).join("") + `${scenes.length}` + ")".repeat(scenes.length) + "\n\n";
  t += byIndex("code_at", "S.Scene", scenes.map((_, i) => `Scene${i}.start()`), "S.scene([])") + "\n";
  t += byIndex("code_rules_at", "List<&2, R.Rule>", scenes.map((_, i) => `Scene${i}.rules()`), "[]") + "\n";
  t += byIndex("places_at", "List<&2, Save.Placed>", scenes.map((_, i) => saved[i] ? `Saved${i}.places()` : "[]"), "[]") + "\n";
  t += byIndex("made_at", "List<&2, Pre.Made>", scenes.map((_, i) => saved[i] ? `Saved${i}.made()` : "[]"), "[]") + "\n";
  t += byIndex("removed_at", "List<&2, String>", scenes.map((_, i) => saved[i] ? `Saved${i}.removed()` : "[]"), "[]") + "\n";
  t += byIndex("own_rules_at", "Bool", scenes.map((_, i) => saved[i] ? `Saved${i}.has_rules()` : "False{}"), "False{}") + "\n";
  t += byIndex("saved_rules_at", "List<&2, R.Rule>", scenes.map((_, i) => saved[i] ? `Saved${i}.rules()` : "[]"), "[]") + "\n";
  // A file saved before tags or attached scripts were saved has no tagged() or attached(): its
  // things keep the code's.
  t += byIndex("tagged_at", "List<&2, Save.Tagged>", scenes.map((_, i) => savedHas(i, "tagged") ? `Saved${i}.tagged()` : "[]"), "[]") + "\n";
  t += byIndex("own_attached_at", "Bool", scenes.map((_, i) => savedHas(i, "attached") ? "True{}" : "False{}"), "False{}") + "\n";
  t += byIndex("attached_at", "List<&2, Save.Attachment>", scenes.map((_, i) => savedHas(i, "attached") ? `Saved${i}.attached()` : "[]"), "[]") + "\n";
  t += `# ---------- Scripts attached to things (scripts/) ----------
# Each script's State to a Value and back, and one tick of it (tools/script/shape.js wrote them).

`;
  scripts.forEach((s, k) => { t += stateCode(`Script${k}`, k, s.fields) + "\n"; });
  t += `# The scripts things may carry, by name.
def scripts() -> List<&2, String>:
  [${scripts.map((s) => quote(s.name)).join(", ")}]

# A script's place among scripts() (${scripts.length} for a name that is not one).
def Reg.script_index(+name: String) -> U32:
  ${scripts.map((s, k) => `Reg.pick(String.eq(name, ${quote(s.name)}), ${k}, `).join("")}${scripts.length}${")".repeat(scripts.length)}

def Reg.run_at(i: U32, +first: Bool, +me: Me.Me, +v: Val.Value, +dt: F32) -> Me.Me & Val.Value:
  match i:
${scripts.map((_, k) => `    case ${k}:\n      S${k}.go(first, me, v, dt)\n`).join("")}    case _:
      (me, v)

# One tick of the script with this name (engine/script/run.bend calls it); a name that is not a
# script runs nothing.
def run(+name: String, +first: Bool, +me: Me.Me, +v: Val.Value, +dt: F32) -> Me.Me & Val.Value:
  Reg.run_at(Reg.script_index(name), first, me, v, dt)

`;
  t += byIndex("Reg.defaults_at", "Val.Value", scripts.map((_, k) => `S${k}.defaults()`), "Val.Value.Rec{[], []}") + "\n";
  t += `# The fields a new attachment of this script has (its initial()).
def defaults(+name: String) -> Val.Value:
  Reg.defaults_at(Reg.script_index(name))

`;
  t += byIndex("Reg.runs_at", "Me.Runs", scripts.map((_, k) => `Script${k}.runs()`), "Me.both()") + "\n";
  t += `# Where this script runs in a networked game (its runs()).
def runs(+name: String) -> Me.Runs:
  Reg.runs_at(Reg.script_index(name))

# ---------- The scene ----------

# The scene as it opens: its code, minus what was deleted, plus what was made, at the places, with
# the tags and the attached scripts saved; every attachment's fields are its script's defaults with
# its own values put in, and its references (by name) are the things' ids.
def opened(+name: String) -> S.Scene:
  Save.settled(~defaults, Save.attach(Save.tag(Save.apply(Pre.add(Save.without(code_at(index(name)), removed_at(index(name))), made_at(index(name))), places_at(index(name))), tagged_at(index(name))), own_attached_at(index(name)), attached_at(index(name))))

def code(+name: String) -> S.Scene:
  Save.settled(~defaults, code_at(index(name)))

def rules(+name: String) -> List<&2, R.Rule>:
  Save.rules(own_rules_at(index(name)), saved_rules_at(index(name)), code_rules_at(index(name)))

def own_rules(+name: String) -> Bool:
  own_rules_at(index(name))

def made(+name: String) -> List<&2, Pre.Made>:
  made_at(index(name))

def removed(+name: String) -> List<&2, String>:
  removed_at(index(name))

# ---------- Systems (systems/): over the whole scene, in file-name order ----------

def start(+s: S.Scene) -> S.Scene:
  ${systems.reduce((acc, _, i) => `System${i}.start(${acc})`, "s")}

def update(+s: S.Scene, +dt: F32) -> S.Scene:
  ${systems.reduce((acc, _, i) => `System${i}.update(${acc}, dt)`, "s")}

# The scripts and systems left out above: each does not compile (tools/script/check.ts says where,
# and why).
def problems() -> List<&2, Pb.Problem>:
  [${broken.map((s) => problemText(s.name, s.problem)).join(",\n   ")}]
`;
  return { text: t, problems: broken.map((s) => ({ folder, name: s.name, dir: s.kind, ...s.problem })) };
}

// One problem, as the dev server's output and a failed build say it: the script, the kind of error
// (engine/script/problem.bend's kind_name says the same words), its line, and what is wrong.
const KIND = { syntax: "Syntax error", import: "Import error", type: "Type error", shape: "Wrong shape", unfinished: "Unfinished code" };
export function said(p) {
  const at = p.line ? ` on line ${p.line}, column ${p.col}` : "";
  const file = p.dir ? `projects/${p.folder}/${p.dir}/${p.name}.bend` : `projects/${p.folder}/${p.name}.bend`;
  return `${file} — ${KIND[p.kind] ?? "Type error"}${p.where ? ` in ${p.where}` : ""}${at}: ${p.text}`;
}

// Writes every project's registry. Says whether any changed (a scene, script or saved file came
// or went, or a script began or stopped compiling), so the dev server knows the page's code must
// be compiled again, and every script's problem.
export async function writeRegistries(root = resolve("projects")) {
  let changed = false;
  const problems = [];
  for (const p of readdirSync(root).filter((d) => !d.startsWith(".") && statSync(join(root, d)).isDirectory()).sort()) {
    const out = join(root, p, "project_generated.bend");
    const reg = await registryOf(join(root, p));
    problems.push(...reg.problems);
    if (existsSync(out) && readFileSync(out, "utf8") === reg.text) continue;
    changed = true;
    writeFileSync(`${out}.${process.pid}.tmp`, reg.text);
    renameSync(`${out}.${process.pid}.tmp`, out);
  }
  for (const p of problems) console.error(`error: ${said(p)}`);
  return { changed, problems };
}

// As a command: a script that does not compile fails it (the build and the export stop).
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const { problems } = await writeRegistries();
  if (problems.length) {
    console.error(`${problems.length} script${problems.length === 1 ? " does" : "s do"} not compile: fix ${problems.length === 1 ? "it" : "them"} before building.`);
    process.exit(1);
  }
}
