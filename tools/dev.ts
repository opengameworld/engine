// Bun watches direct imports. Restart the server on Bend dependency and
// project shader changes, then reload the page to see the updated scene.
//
// It also writes what the editor saves: the editor POSTs a project's saved places to
// http://localhost:3101/save, and this file writes them where Bend says
// (engine/scene/save.bend's file), for a project PROJECT.bend knows. A browser page cannot write
// a file in every browser (MDN: showSaveFilePicker is Chromium only), so the dev server does.
//
// For the Project window (editor/project/), it also makes a folder inside a project
// (POST /folder) and answers with the project's files again, reads a project's text file for the
// Inspector (POST /read), and writes the files of a scene, script or shader the editor created
// (POST /create), then the project's registry (tools/project/registry.js). All of them refuse a
// path that leaves the project's folder; Create refuses a file that is there already.
//
// For the script editor (editor/code/): it checks a script's text as it is being typed, with
// Bend's checker (POST /check, tools/script/check.ts; it answers the first problem as JSON, or
// null), and writes a script's text (POST /write: only a script that is there already). Writing
// it changes the project's code, so the engine restarts and the registry checks it again: one
// that does not compile is left out and listed in its problems() (engine/script/problem.bend).
//
// Limits now:
// - Saving, making a folder, reading a file and checking a script work only under `bun run dev`.
// - A check holds this server for about a second; the page asks for one at a time.

import { Glob, spawn, type Subprocess } from "bun";
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, watch, writeFileSync } from "node:fs";
import { writeShaderCatalog } from "./shaders/catalog.js";
import { listProject, writeProjectFiles } from "./project/files.js";
import { writeRegistries } from "./project/registry.js";
import { checkScript } from "./script/check.ts";
import { dirname, join, normalize, resolve, sep } from "node:path";
import { rules, ROOT } from "./layers";

const PORT = "3100";

// Study-only characters' pages (refs/*/index.html), served beside the
// engine's page when they exist. refs/ is never built.
const REFERENCE_PAGES = existsSync("refs")
  ? readdirSync("refs").map((d) => `refs/${d}/index.html`).filter((p) => existsSync(p))
  : [];

let server: Subprocess | null = null;

async function start() {
  writeShaderCatalog();
  writeProjectFiles();
  await writeRegistries();
  server = spawn(["bun", `--port=${PORT}`, "editor/index.html", ...REFERENCE_PAGES], { stdout: "inherit", stderr: "inherit" });
}

// The files this server wrote for the editor's Save: the page that saved already holds what is in
// them, so writing one does not restart the server (a restart reloads the page and drops what the
// page holds that Save does not write).
const written = new Map<string, number>();   // path inside projects/ -> when it was written (ms)
const WRITE_WINDOW = 2000;   // a write raises a few file events; those within this time are its own

// What start() writes itself (watching it would restart forever), and the script checker's drafts
// (tools/script/check.ts: a hidden .checking-<pid> folder in a project), which are not the project's.
function ignored(path: string) {
  return path.endsWith("catalog_generated.bend") || path.endsWith("files_generated.bend") || path.endsWith("project_generated.bend")
    || path.split("/").some((part) => part.startsWith(".checking"));
}

let timer: Timer | undefined;
let revision = 0;
function restart(file: string) {
  const path = file.replaceAll("\\", "/");
  for (const [w, at] of written) if (path.endsWith(w) && Date.now() - at < WRITE_WINDOW) return;
  const pending = ++revision;
  clearTimeout(timer);
  timer = setTimeout(async () => {
    console.log(`\n${file} changed: restarting (reload the page)`);
    server?.kill();
    await server?.exited;
    if (pending === revision) start();
  }, 150);
}

// A restart the editor asked for (a script created or saved): done before the answer, so the page,
// which reloads as soon as the server answers again, never reloads on the server that is going
// away (it would get the code from before the change). The watcher leaves these files to it.
async function restartNow(file: string, files: string[]) {
  for (const f of files) written.set(f.replace(/^projects\//, ""), Date.now());
  ++revision;
  clearTimeout(timer);
  console.log(`\n${file} changed: restarting (reload the page)`);
  server?.kill();
  await server?.exited;
  await start();
}

if (process.env.WSL_DISTRO_NAME && /^\/mnt\/[a-z](?:\/|$)/i.test(process.cwd())) {
  // Edits made by Windows programs on a mounted drive bypass Linux file events.
  const sources = [
    "*.bend", "engine/**/*.{bend,js}",
    "editor/**/*.{bend,js,css}", "platform/web/**/*.js", "projects/**/*.bend", "projects/*/shaders/**/*",
    "mannequin/**/*.bend", "library/**/*.bend",
    ...(existsSync("refs") ? ["refs/**/*.{bend,js,html,css}"] : []),
  ].map((pattern) => new Glob(pattern));
  function snapshot() {
    const files = new Map<string, string>();
    const paths = sources.flatMap((glob) => [...glob.scanSync({ dot: true })]);
    for (const file of paths) {
      if (file.split("/").includes("node_modules") || ignored(file)) continue;
      const stat = statSync(file, { throwIfNoEntry: false });
      if (stat) files.set(file, `${stat.mtimeMs}:${stat.ctimeMs}:${stat.size}`);
    }
    return files;
  }
  let previous = snapshot();
  setInterval(() => {
    const next = snapshot();
    const paths = new Set([...previous.keys(), ...next.keys()]);
    const changed = [...paths].find((file) => previous.get(file) !== next.get(file));
    previous = next;
    if (changed) restart(changed);
  }, 1000);
} else {
  for (const dir of [".", "engine", "projects", "mannequin", "library", "editor", ...(existsSync("refs") ? ["refs"] : [])]) {
    watch(dir, { recursive: dir !== "." }, (_, file) => {
      if (!file) return;
      const path = file.replaceAll("\\", "/");
      if (ignored(path)) return;
      if ((dir === "projects" && /^[^/]+\/shaders(?:\/|$)/.test(path))
        || (path.endsWith(".bend") && !path.includes("node_modules"))) restart(file);
    });
  }
}

// The editor's Save (editor/app.js): a project's folder and the text Bend wrote for it.
// PROJECT.bend imports every project's registry, which a fresh clone does not have yet.
await writeRegistries();
await rules();   // loads Bend's plugin, so the .bend files below can be imported
const Project = (await import(join(ROOT, "PROJECT.bend"))).default;
const Save = (await import(join(ROOT, "engine/scene/save.bend"))).default;
const SAVE_PORT = 3101;
const cors = { "Access-Control-Allow-Origin": `http://localhost:${PORT}`, "Access-Control-Allow-Methods": "POST", "Access-Control-Allow-Headers": "Content-Type" };
// A path inside a project's folder, or null when it would leave it.
function inside(folder: string, path: unknown) {
  if (typeof path !== "string") return null;
  const base = resolve(ROOT, "projects", folder);
  const full = resolve(base, normalize(path));
  return full === base || full.startsWith(base + sep) ? full : null;
}
const known = (folder: unknown) => typeof folder === "string" && Project.folder(Project.preview(folder)) === folder;
// The text files the Inspector shows (Bend modules, shaders and their settings).
const TEXT = /\.(bend|glsl|hlsl|wgsl|shader|frag|vert|fs|vs|ps|json|txt|md)$/;

Bun.serve({
  port: SAVE_PORT,
  async fetch(req) {
    if (req.method === "OPTIONS") return new Response(null, { headers: cors });
    const route = new URL(req.url).pathname;
    if (req.method !== "POST" || !["/save", "/folder", "/read", "/create", "/check", "/write"].includes(route)) return new Response("not found", { status: 404, headers: cors });
    const body = await req.json();
    const { folder } = body;
    // Only a project PROJECT.bend knows by that folder: an unknown one opens the default project.
    if (!known(folder)) return new Response("unknown project", { status: 400, headers: cors });
    if (route === "/folder") {
      const full = inside(folder, body.path);
      if (!full) return new Response("outside the project", { status: 400, headers: cors });
      mkdirSync(full, { recursive: true });
      console.log(`made projects/${folder}/${body.path}/`);
      return new Response(listProject(folder).join("\n"), { headers: cors });
    }
    if (route === "/read") {
      const full = inside(folder, body.path);
      if (!full || !TEXT.test(full)) return new Response("not a text file of the project", { status: 400, headers: cors });
      return new Response(readFileSync(full, "utf8"), { headers: cors });
    }
    // Create: the files Bend wrote (editor/project/templates.bend), none of which may be there yet.
    // Writing them changes the project's code, so the engine restarts (its start() writes the
    // registry and the file list again) before the answer.
    if (route === "/create") {
      const files = Array.isArray(body.files) ? body.files : [];
      const fulls = files.map((f: any) => typeof f?.text === "string" ? inside(folder, f.path) : null);
      if (!files.length || fulls.some((f: string | null) => !f)) return new Response("outside the project", { status: 400, headers: cors });
      if (fulls.some((f: string) => existsSync(f))) return new Response("a file with that name is there already", { status: 409, headers: cors });
      files.forEach((f: any, i: number) => { mkdirSync(dirname(fulls[i]!), { recursive: true }); writeFileSync(fulls[i]!, f.text); console.log(`created projects/${folder}/${f.path}`); });
      await restartNow(`projects/${folder}/${files[0].path}`, files.map((f: any) => `${folder}/${f.path}`));
      return new Response("created", { headers: cors });
    }
    // A script (scripts/<Name>.bend) or a system (systems/<Name>.bend) of the project, and its text.
    const script = typeof body.path === "string" ? /^(scripts|systems)\/([A-Za-z][A-Za-z0-9_]*)\.bend$/.exec(body.path) : null;
    if (route === "/check" || route === "/write") {
      if (!script || typeof body.text !== "string") return new Response("not a script of the project", { status: 400, headers: cors });
      if (route === "/check") return Response.json(await checkScript(folder, script[2]!, body.text, script[1] as "scripts" | "systems"), { headers: cors });
      // Write: a script that is there already. The engine restarts before the answer, and its
      // registry checks the script again.
      const full = join(ROOT, "projects", folder, body.path);
      if (!existsSync(full)) return new Response("no such script", { status: 404, headers: cors });
      writeFileSync(full, body.text);
      console.log(`wrote projects/${folder}/${body.path}`);
      await restartNow(`projects/${folder}/${body.path}`, [`${folder}/${body.path}`]);
      return new Response(`projects/${folder}/${body.path}`, { headers: cors });
    }
    // Save: the scene's saved file, beside it (engine/scene/save.bend's file).
    const { scene, text } = body;
    if (typeof text !== "string" || typeof scene !== "string" || !/^[A-Za-z][A-Za-z0-9_]*$/.test(scene)
      || !existsSync(join(ROOT, "projects", folder, "scenes", `${scene}.bend`)))
      return new Response("no such scene", { status: 400, headers: cors });
    const path = Save.file(folder, scene);
    written.set(path.replace(/^projects\//, ""), Date.now());
    await Bun.write(join(ROOT, path), text);
    console.log(`saved ${path}`);
    // A scene saved for the first time has a saved file the registry must import now: the page's
    // code is compiled again (a restart; the page opens again, with nothing left to save).
    writeProjectFiles();
    if ((await writeRegistries()).changed) restart(`projects/${folder}/project_generated.bend`);
    return new Response(path, { headers: cors });
  },
});

process.on("SIGINT", () => { server?.kill(); process.exit(0); });
start();
