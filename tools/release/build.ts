// The hands of a release: git, bun, hashing, the archive. Every pin, name, rule and text is
// tools/release/RELEASE.bend's, loaded through ../bend's plugin as export/web.ts does.
//
// Limits now:
// - The Bend fork comes from the clone at ../bend (docs/not-in-bend.txt); it must hold the
//   pinned commit. Nothing is fetched for it.
// - `bun install` needs Bend-UI's tarball in Bun's cache or the network; it runs before any
//   check, outside any sandbox.
// - A build takes the time of a full `bun run check` (about a minute); the stage is left in
//   <out>/.stage when a build fails, for diagnosis.
// - verify rebuilds with this checkout's release tool and ../bend, from a clone of this
//   repository; it does not prove the tool itself is the one of the released commit.

import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync, chmodSync, mkdtempSync } from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";
import { gzip, tar, untar, type Entry } from "./tar";

const ROOT = resolve(import.meta.dir, "..", "..");
const BEND = resolve(ROOT, "..", "bend");

async function rules() {
  Bun.plugin((await import(join(BEND, "bend2", "main.ts"))).default);
  return (await import("./RELEASE.bend")).default;
}
type R = Awaited<ReturnType<typeof rules>>;

const list = (l: { $: string; head?: any; tail?: any }): any[] => {
  const out: any[] = [];
  for (let x = l; x.$ === "Con"; x = x.tail) out.push(x.head);
  return out;
};

const sha256 = (b: Uint8Array | string) => new Bun.CryptoHasher("sha256").update(b).digest("hex");

class Refused extends Error {}
const refuse = (why: string): never => { throw new Refused(why); };

async function run(cmd: string[], o: { cwd?: string; env?: Record<string, string | undefined>; stdin?: Uint8Array } = {}) {
  const p = Bun.spawn(cmd, { cwd: o.cwd ?? ROOT, env: o.env ?? process.env, stdin: o.stdin ?? "ignore", stdout: "pipe", stderr: "pipe" });
  const [out, err] = await Promise.all([new Response(p.stdout).arrayBuffer(), new Response(p.stderr).text()]);
  return { code: await p.exited, out: new Uint8Array(out), text: new TextDecoder().decode(out), err };
}

async function must(cmd: string[], o: Parameters<typeof run>[1] = {}) {
  const r = await run(cmd, o);
  if (r.code !== 0) refuse(`${cmd.join(" ")} failed (${r.code}):\n${(r.err || r.text).trim().split("\n").slice(-30).join("\n")}`);
  return r;
}

// The environment every step of a build runs in: no HLSL tool on PATH or in the environment,
// no telemetry, no hub.
function environment(F: R, extra: Record<string, string> = {}, first?: string) {
  const env: Record<string, string | undefined> = { ...process.env };
  for (const k of list(F.hidden_env())) delete env[k];
  delete env.BEND_LIB;
  const hidden: string[] = list(F.hidden_tools());
  const dirs = (env.PATH ?? "").split(":").filter((d) => d && !hidden.some((t) => existsSync(join(d, t))));
  env.PATH = [...(first ? [first] : []), ...dirs].join(":");
  env.BEND_NO_TELEMETRY = "1";
  env.BEND_HUB = F.no_hub();
  Object.assign(env, extra);
  for (const t of hidden) if (Bun.which(t, { PATH: env.PATH })) refuse(`${t} is still on PATH`);
  if (!Bun.which("bun", { PATH: env.PATH })) refuse("hiding the HLSL tools hid bun: put bun in a folder of its own on PATH");
  return env;
}

function walk(dir: string, base = dir): string[] {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    const s = lstatSync(p);
    if (s.isSymbolicLink()) refuse(`${relative(base, p)} is a symbolic link; a release holds files only`);
    return s.isDirectory() ? walk(p, base) : [relative(base, p)];
  }).sort();
}

function snapshot(dir: string): Map<string, string> {
  return new Map(walk(dir).map((p) => [p, sha256(readFileSync(join(dir, p)))]));
}

function changes(a: Map<string, string>, b: Map<string, string>): string[] {
  const out: string[] = [];
  for (const [p, h] of a) if (b.get(p) !== h) out.push(b.has(p) ? `changed ${p}` : `removed ${p}`);
  for (const p of b.keys()) if (!a.has(p)) out.push(`added ${p}`);
  return out;
}

function lines(F: R, dir: string, skip: Set<string> = new Set()): string {
  return walk(dir).filter((p) => !skip.has(p)).map((p) => F.manifest_line(sha256(readFileSync(join(dir, p))), p)).join("");
}

// Writes a tree from `git archive` and returns which paths git marks executable.
async function unpack(repo: string, commit: string, paths: string[], into: string): Promise<Set<string>> {
  const arch = await must(["git", "-C", repo, "-c", "core.autocrlf=false", "archive", "--format=tar", commit, ...paths]);
  const files = untar(arch.out);
  const tree = (await must(["git", "-C", repo, "ls-tree", "-r", "-z", commit, ...paths])).text.split("\0").filter(Boolean);
  const exec = new Set<string>();
  const want = new Set<string>();
  for (const l of tree) {
    const [meta, p] = l.split("\t");
    const mode = meta.split(" ")[0];
    if (mode === "120000" || mode === "160000") refuse(`${p} in ${commit} is a link or a submodule; a release holds files only`);
    if (mode === "100755") exec.add(p);
    want.add(p);
  }
  const got = new Set(files.map((f) => f.path));
  if (got.size !== want.size || [...want].some((p) => !got.has(p))) refuse(`git archive of ${commit} in ${repo} does not match its tree (export-ignore?)`);
  for (const f of files) {
    mkdirSync(dirname(join(into, f.path)), { recursive: true });
    writeFileSync(join(into, f.path), f.data);
  }
  return exec;
}

export type Build = { repo: string; commit: string; version: string; tag: string | null; out: string; say?: (s: string) => void };

export async function build(o: Build): Promise<{ folder: string; hash: string; sums: string; seconds: number }> {
  const t0 = performance.now();
  const say = o.say ?? console.log;
  const F = await rules();
  const env = environment(F);

  if (Bun.version !== F.bun_version()) refuse(F.bun_refused(Bun.version));
  const pathBun = (await must(["bun", "--version"], { env })).text.trim();
  if (pathBun !== F.bun_version()) refuse(F.bun_refused(pathBun));
  if (!F.version_ok(o.version)) refuse(F.version_refused(o.version));

  const commit = (await must(["git", "-C", o.repo, "rev-parse", "--verify", `${o.commit}^{commit}`])).text.trim();
  const epoch = Number((await must(["git", "-C", o.repo, "show", "-s", "--format=%ct", commit])).text.trim());

  if (o.tag !== null) {
    const v = F.tag_version(o.tag);
    if (v.$ !== "Some" || v.value !== o.version) refuse(F.tag_refused(o.tag));
    if ((await run(["git", "-C", o.repo, "cat-file", "-t", `refs/tags/${o.tag}`])).text.trim() !== "tag") refuse(`${o.tag} is not an annotated tag`);
    const at = (await must(["git", "-C", o.repo, "rev-parse", `${o.tag}^{commit}`])).text.trim();
    const head = (await must(["git", "-C", o.repo, "rev-parse", "HEAD"])).text.trim();
    if (at !== head || at !== commit) refuse(`HEAD is not at ${o.tag}`);
    if ((await must(["git", "-C", o.repo, "status", "--porcelain"])).text.trim() !== "") refuse("the working tree is not clean");
  }

  const bendCommit: string = F.bend_commit();
  if ((await run(["git", "-C", BEND, "cat-file", "-t", `${bendCommit}^{commit}`])).text.trim() !== "commit") refuse(`${BEND} has no commit ${bendCommit} (docs/not-in-bend.txt)`);
  const mainTs = (await must(["git", "-C", BEND, "show", `${bendCommit}:bend2/main.ts`])).text;
  if (!mainTs.split("\n").includes(F.bend_version_line())) refuse(`bend2/main.ts at ${bendCommit} is not Bend ${F.bend_version()}`);
  const compTs = (await must(["git", "-C", BEND, "show", `${bendCommit}:bend2/comp.ts`])).text;
  if (!compTs.includes(F.treeshake_line())) refuse(`bend2/comp.ts at ${bendCommit} lacks the tree-shake line (docs/not-in-bend.txt)`);

  const out = resolve(o.out);
  if (existsSync(out) && readdirSync(out).length) refuse(`${out} is not empty`);
  const name: string = F.folder(o.version);
  const stage = join(out, ".stage");
  const lib = join(stage, name);
  const src = join(lib, "src");
  mkdirSync(src, { recursive: true });

  say(`release ${o.version} of ${commit}${o.tag ? ` (${o.tag})` : " (dry run)"}`);
  const engineExec = await unpack(o.repo, commit, [], src);
  const bendExec = await unpack(BEND, bendCommit, list(F.bend_paths()), join(lib, "bend"));
  const tracked = snapshot(src);
  mkdirSync(join(lib, dirname(F.shim_path())), { recursive: true });
  writeFileSync(join(lib, F.shim_path()), F.shim_text());
  chmodSync(join(lib, F.shim_path()), 0o755);

  say("bun install --frozen-lockfile --ignore-scripts");
  await must(["bun", "install", "--frozen-lockfile", "--ignore-scripts"], { cwd: src, env });

  const gens: string[] = list(F.generators());
  let before = snapshot(src);
  let passes = 0;
  for (;;) {
    if (passes === F.max_passes()) refuse(`the generated files still change after ${passes} passes`);
    passes++;
    for (const g of gens) await must(["bun", g], { cwd: src, env });
    const after = snapshot(src);
    const moved = changes(before, after);
    before = after;
    if (!moved.length) break;
  }
  say(`generated files: pass ${passes} changed nothing`);
  const touched = changes(tracked, new Map([...before].filter(([p]) => tracked.has(p))));
  if (touched.length) refuse(`generation changed tracked files:\n${touched.join("\n")}`);
  const generated = [...before.keys()].filter((p) => !tracked.has(p) && !p.startsWith("node_modules/"));

  const hash: string = F.package_hash(sha256(lines(F, src)));
  const pkgDir = join(lib, hash);
  renameSync(src, pkgDir);
  mkdirSync(join(lib, "names"), { recursive: true });
  writeFileSync(join(lib, F.name_path(o.version)), F.name_text(hash));
  if (o.tag === null) writeFileSync(join(lib, F.dry_run_file()), F.dry_run_text(commit));

  say(`bun run check, inside ${hash}/`);
  const quiet = snapshot(lib);
  const checkEnv = environment(F, { BEND_LIB: lib }, join(lib, dirname(F.shim_path())));
  const check = await run(["bun", "run", "check"], { cwd: pkgDir, env: checkEnv });
  if (check.code !== 0) refuse(`bun run check failed inside the release:\n${(check.text + check.err).trim().split("\n").slice(-40).join("\n")}`);
  const moved = changes(quiet, snapshot(lib));
  if (moved.length) refuse(`bun run check changed the release:\n${moved.join("\n")}`);

  const skip = new Set<string>([F.release_file(), F.manifest_file()]);
  const manifest = lines(F, lib, skip);
  writeFileSync(join(lib, F.manifest_file()), manifest);
  let gl = F.paths_none();
  for (const p of [...generated].reverse()) gl = F.path(p, gl);
  const json: string = F.release_json(o.version, o.tag ?? "", commit, epoch, hash, sha256(manifest), gl);
  writeFileSync(join(lib, F.release_file()), json);

  const execOf = (p: string): boolean => p === F.shim_path()
    || (p.startsWith(`${hash}/`) && engineExec.has(p.slice(hash.length + 1)))
    || (p.startsWith("bend/") && bendExec.has(p.slice(5)));
  const files = walk(lib);
  const dirs = new Set<string>([""]);
  for (const f of files) for (let d = dirname(f); d !== "."; d = dirname(d)) dirs.add(d);
  const entries: Entry[] = [
    ...[...dirs].map((d) => ({ path: `${name}/${d ? `${d}/` : ""}`, data: new Uint8Array(), mode: F.mode(true) })),
    ...files.map((f) => ({ path: `${name}/${f}`, data: new Uint8Array(readFileSync(join(lib, f))), mode: F.mode(execOf(f)) })),
  ].sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
  const gz = gzip(tar(entries, epoch));
  writeFileSync(join(out, F.archive(o.version)), gz);
  writeFileSync(join(out, F.release_file()), json);
  const sums: string = F.sums(sha256(json), sha256(gz), o.version);
  writeFileSync(join(out, F.sums_file()), sums);

  renameSync(lib, join(out, name));
  rmSync(stage, { recursive: true, force: true });
  const seconds = (performance.now() - t0) / 1000;
  say(`${F.archive(o.version)}: ${gz.length} bytes, package ${F.package(o.version)} = ${hash}, ${seconds.toFixed(1)} s`);
  return { folder: join(out, name), hash, sums, seconds };
}

// Builds the release of `tag` from this repository, which must be clean and at that tag.
export async function buildTag(tag: string, out: string, say?: (s: string) => void) {
  const F = await rules();
  const v = F.tag_version(tag);
  if (v.$ !== "Some") refuse(F.tag_refused(tag));
  return build({ repo: ROOT, commit: "HEAD", version: v.value, tag, out, say });
}

// A dry run: any commit of this repository, a version, no tag.
export async function buildCommit(commit: string, version: string, out: string, say?: (s: string) => void) {
  return build({ repo: ROOT, commit, version, tag: null, out, say });
}

// Rebuilds a release from a fresh clone of this repository at the release's commit, and
// compares the two SHA256SUMS byte for byte.
export async function verify(dir: string, say = console.log): Promise<boolean> {
  const F = await rules();
  const at = resolve(dir);
  const meta = JSON.parse(readFileSync(join(at, F.release_file()), "utf8"));
  const theirs = readFileSync(join(at, F.sums_file()), "utf8");
  const work = mkdtempSync(join(dirname(at), `${basename(at)}.verify-`));
  const repo = join(work, "repo");
  await must(["git", "clone", "--quiet", "--no-local", ROOT, repo]);
  await must(["git", "-C", repo, "checkout", "--quiet", "--detach", meta.tag ?? meta.commit]);
  const ours = (await build({ repo, commit: meta.commit, version: meta.version, tag: meta.tag, out: join(work, "out"), say })).sums;
  const same = ours === theirs;
  say(`theirs:\n${theirs}ours:\n${ours}${same ? "SHA256SUMS match" : "SHA256SUMS DIFFER"}`);
  if (same) rmSync(work, { recursive: true, force: true });
  else say(`the rebuild is kept in ${work}`);
  return same;
}

export { Refused };
