// export's hands for the web: it measures, generates, bundles, hashes and writes. Every decision
// (what a game takes, the text of each generated file, what each built file is, whether the
// build ships, the manifest, the serve headers) is export/files.bend's, through the Bend loader
// of ../bend (the engine's Bend, see not-in-bend.txt).
//
// Limits now:
// - Bundling is `bend <page> -o <dir>` from ../bend: Bun's HTML bundle, hashed names flat in the
//   folder (no _/ or a/ subfolders yet).
// - `bun run check` runs in full before every build (about 40 s): nothing ships unchecked.
// - The build writes into a stage folder and renames it into place; a crash leaves the stage
//   behind (.export/web/<game>.stage-*), never a half-written game.

import { existsSync, mkdirSync, readdirSync, renameSync, rmSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { closure, imports } from "../tools/layers";

export const ROOT = join(import.meta.dir, "..");
const BEND = join(ROOT, "..", "bend");

// Bend modules load through ../bend's plugin, as tools/test.ts does.
async function files() {
  const plugin = (await import(join(BEND, "bend2", "main.ts"))).default;
  Bun.plugin(plugin);
  return (await import("./files.bend")).default;
}

type Bend = Awaited<ReturnType<typeof files>>;

const list = (l: { $: string; head?: any; tail?: any }) => {
  const out: any[] = [];
  for (let x = l; x.$ === "Con"; x = x.tail) out.push(x.head);
  return out;
};

const sha256 = (b: Uint8Array | string) => new Bun.CryptoHasher("sha256").update(b).digest("hex");

async function sh(cmd: string[], cwd = ROOT) {
  const p = Bun.spawn(cmd, { cwd, stdout: "pipe", stderr: "pipe" });
  const [out, err] = await Promise.all([new Response(p.stdout).text(), new Response(p.stderr).text()]);
  return { code: await p.exited, out, err };
}

// What the build machine has: the Bend version ../bend is at, whether its loader has the module
// tree shaking, and the shader tools.
async function toolchain(F: Bend) {
  const tag = (await sh(["git", "-C", BEND, "describe", "--tags", "--abbrev=0"])).out.trim().replace(/^v/, "");
  const comp = existsSync(join(BEND, "bend2", "comp.ts")) ? await Bun.file(join(BEND, "bend2", "comp.ts")).text() : "";
  const treeshake = comp.includes('&& !k.includes(":");');
  return F.tools(tag || "unknown", treeshake, Bun.which("dxc") !== null, Bun.which("spirv-cross") !== null);
}

function walk(dir: string, base = dir): string[] {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    return statSync(p).isDirectory() ? walk(p, base) : [relative(base, p)];
  }).sort();
}

export async function exportWeb(slug: string, say = console.log): Promise<{ ok: boolean; folder?: string; build?: string }> {
  const F = await files();
  if (!F.known(slug)) {
    say(`no game named "${slug}": the games are PROJECT.bend's projects (water, character, mannequin, animation)`);
    return { ok: false };
  }

  say("checking (bun run check)...");
  const checks = (await sh(["bun", "run", "check"])).code === 0;
  const tools = await toolchain(F);

  // Generated sources, all text from Bend.
  const gen = join(ROOT, F.gen_dir(slug));
  rmSync(gen, { recursive: true, force: true });
  mkdirSync(gen, { recursive: true });
  await Bun.write(join(gen, "game.bend"), F.game_module(slug));
  await Bun.write(join(gen, "entry.js"), F.entry_js(slug));
  await Bun.write(join(gen, "index.html"), F.index_html(slug));
  await sh(["bun", "tools/shaders/catalog.js"]);
  const catalog = await Bun.file(join(ROOT, "editor", "shaders", "catalog.generated.json")).json().catch(() => ({}));
  const wanted = new Set(list(F.shader_ids(slug)));
  const mine = catalog[F.shader_folder(slug)] ?? { assets: [], diagnostics: [] };
  await Bun.write(join(gen, "shaders.json"), JSON.stringify({
    assets: (mine.assets ?? []).filter((a: any) => wanted.has(a.id)),
    diagnostics: (mine.diagnostics ?? []).filter((d: any) => wanted.has(d.id)),
  }, null, 2));

  // Bundle into a stage folder with ../bend's own CLI (its loader, its Bun.build).
  const folder = join(ROOT, F.folder(slug));
  const stage = `${folder}.stage-${process.pid}`;
  const site = join(stage, "site");
  rmSync(stage, { recursive: true, force: true });
  say("bundling...");
  const b = await sh(["bun", join(BEND, "bend2", "main.ts"), join(gen, "index.html"), "-o", site]);
  if (b.code !== 0) {
    rmSync(stage, { recursive: true, force: true });
    say(`bundling failed:\n${b.err || b.out}`);
    return { ok: false };
  }
  await Bun.write(join(site, "credits.html"), F.credits_html(slug));

  // Measure every file, then let Bend decide.
  let entries = F.entries_none();
  for (const path of walk(site).reverse()) {
    const bytes = new Uint8Array(await Bun.file(join(site, path)).arrayBuffer());
    entries = F.entry(path, bytes.length, Bun.gzipSync(bytes, { level: 9 }).length, sha256(bytes), entries);
  }
  // What the build reaches from its page, and the generated game's own imports: LAYERS.bend,
  // through files.bend, refuses a file that may not ship or an import a game may not make.
  const genRel = F.gen_dir(slug);
  const reached = closure([`${genRel}/index.html`]);
  let reachedList = F.paths_none(), froms = F.paths_none(), tos = F.paths_none();
  for (const p of [...reached].reverse()) reachedList = F.path(p, reachedList);
  for (const f of reached.filter((p) => p.startsWith(`${genRel}/`) && /\.(bend|js|html)$/.test(p)))
    for (const t of imports(f)) { froms = F.path(f, froms); tos = F.path(t, tos); }
  const outcome = F.release(checks, slug, entries, existsSync(join(site, "credits.html")), tools, reachedList, froms, tos);
  if (!F.shipped(outcome)) {
    rmSync(stage, { recursive: true, force: true });
    say(F.reasons_text(outcome).trimEnd());
    return { ok: false };
  }

  const build = sha256(F.id_text(outcome)).slice(0, 12);
  await Bun.write(join(stage, "game.json"), F.json(outcome, build));
  rmSync(folder, { recursive: true, force: true });
  renameSync(stage, folder);
  const m = await Bun.file(join(folder, "game.json")).json();
  say(`${relative(ROOT, folder)}  build ${build}`);
  say(`  code ${m.load.code} bytes, assets ${m.load.assets} bytes on the wire; ${m.entries.length} files`);
  say(`  credits: ${m.credits.map((c: any) => c.title).join(", ") || "none"}`);
  return { ok: true, folder, build };
}

// The built folder on localhost, with the headers Bend gives each file. Files Bend says travel
// gzipped are sent gzipped to a browser that accepts it.
export async function serve(slug: string, port = 3200, say = console.log) {
  const F = await files();
  const site = join(ROOT, F.site_dir(slug));
  if (!existsSync(join(site, "index.html"))) {
    say(`no build of "${slug}" yet: run bun run export web ${slug}`);
    return null;
  }
  const server = Bun.serve({
    port,
    async fetch(req) {
      const url = new URL(req.url);
      const path = url.pathname === "/" ? "index.html" : decodeURIComponent(url.pathname.slice(1));
      const file = Bun.file(join(site, path));
      if (path.includes("..") || !(await file.exists())) return new Response("not found", { status: 404 });
      const headers: Record<string, string> = { "Content-Type": F.content_type(path), "Cache-Control": F.cache_control(path) };
      const body = new Uint8Array(await file.arrayBuffer());
      if (F.compresses(path) && (req.headers.get("accept-encoding") ?? "").includes("gzip")) {
        headers["Content-Encoding"] = "gzip";
        return new Response(Bun.gzipSync(body), { headers });
      }
      return new Response(body, { headers });
    },
  });
  say(`serving ${relative(ROOT, site)} at http://localhost:${server.port}/`);
  return server;
}
