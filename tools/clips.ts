// The clip importer: reads the animations of .glb files and writes them as
// motions (engine/anim/motion.bend), the form that plays on any character that
// keeps the rig standard.
//
//   bun tools/clips.ts <clips.json> <out dir>
//
// It writes <out dir>/motions.bend: the collection's name, credit and
// license, how many motions there are, each one's name and length, and
// motion(i), the motion itself.
//
// clips.json says how to read the files (see library/quaternius/clips.json):
// - pose   the clip that holds the rig in the T-pose (or "" for the file's
//          rest pose)
// - head   how far the head's top is over the head bone's start, as a part
//          of that height (for the pictures)
// - slots  the engine's slot of each bone
// - files  each file, and the clips to take from it: its name in the file,
//          the name it gets, and whether it loops
//
// What it does, for each clip:
// - samples every slot 30 times a second (glTF's LINEAR and STEP samplers);
// - for each key, finds how far the bone has turned from the T-pose, in
//   the character's own space: turn = now × inverse(T-pose). That is the
//   same turn on any rig that rests in the T-pose;
// - writes the hips' place as a distance from where they rest, in leg
//   lengths (the hip joint's height over the floor);
// - keeps one key for a slot that never turns, and every other key of a
//   clip whose motion is the same without the ones between;
// - draws the clip's picture for the library: the source rig as a stick
//   figure, at a moment two fifths into the clip, as numbers (thumb).
//
// It refuses a clip whose category clips.json does not list, a file whose
// T-pose is not one (arms not level, not facing
// +Z), a slot it cannot find, and a bone that is scaled.
//
// Limits now:
// - CUBICSPLINE samplers are not read.
// - Position is read only for the hips. Scale tracks are ignored after
//   checking that the T-pose has none.
// - The side is told by the letter "*" stands for: l and r.
// - The pictures leave the fingers out.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join, relative } from "node:path";

const [cfgPath, outDir] = process.argv.slice(2);
if (!cfgPath || !outDir) { console.error("usage: bun tools/clips.ts <clips.json> <out dir>"); process.exit(1); }
const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));
const ENGINE = relative(outDir, "engine").split("\\").join("/");
const FPS = 30;       // keys a second
const CHUNK = 32;     // keys in one def: a longer list is too much for Bend's checker in one piece

type Q = number[]; type V = number[];
const qmul = (a: Q, b: Q): Q => [a[3]*b[0]+a[0]*b[3]+a[1]*b[2]-a[2]*b[1], a[3]*b[1]-a[0]*b[2]+a[1]*b[3]+a[2]*b[0], a[3]*b[2]+a[0]*b[1]-a[1]*b[0]+a[2]*b[3], a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]];
const qconj = (q: Q): Q => [-q[0], -q[1], -q[2], q[3]];
const qnorm = (q: Q): Q => { const l = Math.hypot(...q) || 1; return q.map((x) => x / l); };
const qdot = (a: Q, b: Q) => a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3];
const qrot = (q: Q, v: V): V => { const u = q.slice(0, 3), w = q[3];
  const c1 = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]];
  const c2 = [u[1]*c1[2]-u[2]*c1[1], u[2]*c1[0]-u[0]*c1[2], u[0]*c1[1]-u[1]*c1[0]];
  return v.map((_, i) => v[i] + 2 * (w * c1[i] + c2[i])); };
const nlerp = (a: Q, b: Q, t: number): Q => { const s = qdot(a, b) < 0 ? -1 : 1; return qnorm(a.map((x, i) => x + (s * b[i] - x) * t)); };
const lerp = (a: V, b: V, t: number): V => a.map((x, i) => x + (b[i] - x) * t);

function open(path: string) {
  const b = readFileSync(path);
  if (b.readUInt32LE(0) !== 0x46546c67) throw new Error(`${path} is not a .glb`);
  const jl = b.readUInt32LE(12), j = JSON.parse(b.subarray(20, 20 + jl).toString()), bin = b.subarray(20 + jl + 8);
  const acc = (i: number): number[][] => {
    const a = j.accessors[i], v = j.bufferViews[a.bufferView];
    if (a.componentType !== 5126) throw new Error(`${path}: an animation accessor is not float`);
    const n = ({ SCALAR: 1, VEC3: 3, VEC4: 4 } as any)[a.type], off = (v.byteOffset || 0) + (a.byteOffset || 0), stride = v.byteStride || n * 4;
    return Array.from({ length: a.count }, (_, k) => Array.from({ length: n }, (_, c) => bin.readFloatLE(off + stride * k + c * 4)));
  };
  const parent = new Map<number, number>();
  j.nodes.forEach((n: any, i: number) => (n.children || []).forEach((c: number) => parent.set(c, i)));
  const byName = new Map<string, number>(j.nodes.map((n: any, i: number) => [n.name, i]));
  // An animation, ready to sample: per node, its translation, rotation and scale keys.
  function reader(name: string) {
    const a = name === "" ? { channels: [], samplers: [] } : (j.animations || []).find((x: any) => x.name === name);
    if (!a) throw new Error(`${path} has no animation "${name}"`);
    const ch = new Map<string, { ts: number[]; vs: number[][]; step: boolean }>();
    let end = 0;
    for (const c of a.channels) {
      const s = a.samplers[c.sampler];
      if (s.interpolation === "CUBICSPLINE") throw new Error(`${path} "${name}": CUBICSPLINE keys are not read`);
      const ts = acc(s.input).map((x) => x[0]);
      end = Math.max(end, ts[ts.length - 1]);
      ch.set(c.target.node + ":" + c.target.path, { ts, vs: acc(s.output), step: s.interpolation === "STEP" });
    }
    const at = (node: number, path: string, t: number, rest: number[]): number[] => {
      const c = ch.get(node + ":" + path); if (!c) return rest;
      if (t <= c.ts[0]) return c.vs[0];
      const last = c.ts.length - 1; if (t >= c.ts[last]) return c.vs[last];
      let k = 0; while (c.ts[k + 1] <= t) k++;
      if (c.step) return c.vs[k];
      const u = (t - c.ts[k]) / (c.ts[k + 1] - c.ts[k]);
      return path === "rotation" ? nlerp(c.vs[k], c.vs[k + 1], u) : lerp(c.vs[k], c.vs[k + 1], u);
    };
    // Every node's place in the character's space at time t.
    const world = (t: number) => {
      const done = new Map<number, { r: Q; t: V; s: V }>();
      const get = (i: number): { r: Q; t: V; s: V } => {
        if (done.has(i)) return done.get(i)!;
        const n = j.nodes[i];
        const lt = at(i, "translation", t, n.translation || [0, 0, 0]), lr = qnorm(at(i, "rotation", t, n.rotation || [0, 0, 0, 1])), ls = at(i, "scale", t, n.scale || [1, 1, 1]);
        const p = parent.has(i) ? get(parent.get(i)!) : { r: [0, 0, 0, 1], t: [0, 0, 0], s: [1, 1, 1] };
        const w = { r: qnorm(qmul(p.r, lr)), t: qrot(p.r, lt.map((x, k) => x * p.s[k])).map((x, k) => x + p.t[k]), s: ls.map((x, k) => x * p.s[k]) };
        done.set(i, w); return w;
      };
      return get;
    };
    return { end, world };
  }
  return { byName, parent, reader };
}

// The bones to read: file name → slot, with "*" opened to both sides.
const slotOf: [string, string][] = [];
for (const [bone, slot] of Object.entries(cfg.slots as Record<string, string>)) {
  if (bone.includes("*")) { slotOf.push([bone.replace("*", "l"), slot + ".L"], [bone.replace("*", "r"), slot + ".R"]); }
  else slotOf.push([bone, slot]);
}

// Four decimals: a turn is right to about a hundredth of a degree, a place to a tenth of a millimeter of leg.
const num = (x: number) => { const s = Math.abs(x).toFixed(4); return x < 0 && Number(s) !== 0 ? `neg(${s})` : s; };
const ident = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "_");
const defs: string[] = [];
const motions: { name: string; seconds: number; fn: string; category: string; loop: boolean; thumb: string }[] = [];
const base = dirname(cfgPath);

// A list too long for one def, as several defs joined.
function list(fn: string, type: string, items: string[]): string {
  const parts: string[] = [];
  for (let i = 0; i < items.length; i += CHUNK) {
    const name = `${fn}_${i / CHUNK}`;
    defs.push(`def ${name}() -> List<&2, ${type}>:\n  [${items.slice(i, i + CHUNK).join(", ")}]\n`);
    parts.push(`${name}()`);
  }
  return parts.reduce((a, b) => `List.append(&2, ${type}, ${a}, ${b})`);
}

for (const f of cfg.files) {
  const glb = open(join(base, f.file));
  const node = (bone: string) => { const i = glb.byName.get(bone); if (i === undefined) throw new Error(`${f.file} has no bone "${bone}"`); return i; };
  // The T-pose: every turn is measured from it.
  const tpose = glb.reader(cfg.pose || "").world(0);
  for (const [bone] of slotOf) if (tpose(node(bone)).s.some((x) => Math.abs(x - 1) > 0.001)) throw new Error(`${f.file}: "${bone}" is scaled in the T-pose`);
  const find = (slot: string) => { const e = slotOf.find(([, s]) => s === slot); if (!e) throw new Error(`clips.json maps no bone to "${slot}"`); return node(e[0]); };
  const sh = tpose(find("upper_arm.L")).t, hd = tpose(find("hand.L")).t, an = tpose(find("foot.L")).t, toe = tpose(find("toes.L")).t;
  if (!(hd[0] > sh[0] && Math.abs(hd[1] - sh[1]) < 0.01 && Math.abs(hd[2] - sh[2]) < 0.01)) throw new Error(`${f.file}: the left arm is not level along +X in the pose "${cfg.pose}"`);
  if (!(toe[2] > an[2])) throw new Error(`${f.file}: the character does not face +Z`);
  const hips0 = tpose(find("hips")).t, leg = tpose(find("upper_leg.L")).t[1];
  if (!(leg > 0)) throw new Error(`${f.file}: the hip joint is not above the floor`);

  // The stick figure's bones: each read bone to the nearest read bone above it.
  const parentOf = (i: number): number | undefined => { for (let x = glb.parent.get(i); x !== undefined; x = glb.parent.get(x)) if (slotOf.some(([b]) => node(b) === x)) return x; return undefined; };
  const top = tpose(find("head")).t[1] * (1 + cfg.head);   // the head's top (clips.json's head)
  const finger = (slot: string) => /^(thumb|index|middle|ring|little)_/.test(slot);   // too small for the picture
  const BOX = 40, PAD = 4, unit = (BOX - 2 * PAD) / top;
  const dot = (p: V) => [BOX / 2 + (p[0] * 0.5 + p[2] * 0.85) * unit, BOX - PAD - p[1] * unit];

  for (const c of f.clips) {
    if (!(cfg.categories as string[]).includes(c.category)) throw new Error(`"${c.name}": clips.json lists no category "${c.category}"`);
    const r = glb.reader(c.from), n = Math.max(1, Math.round(r.end * FPS)) + 1, fn = `m${motions.length}`;
    const turns = new Map<string, Q[]>(slotOf.map(([, s]) => [s, []]));
    const hips: V[] = [];
    for (let k = 0; k < n; k++) {
      const w = r.world(Math.min(k / FPS, r.end));
      for (const [bone, slot] of slotOf) {
        const i = node(bone), list = turns.get(slot)!;
        let d = qnorm(qmul(w(i).r, qconj(tpose(i).r)));
        const before = list.length ? list[list.length - 1] : [0, 0, 0, 1];
        if (qdot(d, before) < 0) d = d.map((x) => -x);   // the same turn, on the side of the key before
        list.push(d);
      }
      hips.push(w(find("hips")).t.map((x, a) => (x - hips0[a]) / leg));
    }
    // Half the keys, when the keys left say the same motion: every key taken out is within half a
    // degree (and half a hundredth of a leg, for the hips) of the middle of its two neighbours.
    const half = n % 2 === 1 && n > 2
      && [...turns.values()].every((qs) => qs.every((q, k) => k % 2 === 0 || Math.abs(qdot(q, nlerp(qs[k - 1], qs[k + 1], 0.5))) > 0.99999))
      && hips.every((v, k) => k % 2 === 0 || v.every((x, a) => Math.abs(x - (hips[k - 1][a] + hips[k + 1][a]) / 2) < 0.005));
    const kept = <T>(xs: T[]) => (half ? xs.filter((_, k) => k % 2 === 0) : xs);
    const tracks: string[] = [];
    slotOf.forEach(([, slot], ti) => {
      const qs = turns.get(slot)!;
      const still = qs.every((q) => Math.abs(qdot(q, qs[0])) > 0.99999);   // never more than half a degree from its first key
      const items = (still ? [qs[0]] : kept(qs)).map((q) => `q(${q.map(num).join(", ")})`);
      tracks.push(`M.Track{"${slot}", ${list(`${fn}_t${ti}`, "Q.Q", items)}}`);
    });
    const hipItems = kept(hips).map((v) => `v(${v.map(num).join(", ")})`);
    defs.push(`# "${c.from}" of ${f.file.split("/").pop()}: ${n} keys.\ndef ${fn}() -> M.Motion:\n  M.Motion{"${c.name}", ${num((n - 1) / FPS)}, ${num((half ? 2 : 1) / FPS)}, ${c.loop ? "True" : "False"}{}, ${list(`${fn}_hips`, "V.V3", hipItems)}, [\n    ${tracks.join(",\n    ")}]}\n`);
    // The picture: head (x, y, radius), then one line per bone (x1, y1, x2, y2), in a 40 × 40 box.
    const w = r.world(r.end * 0.4), hw = w(find("head")), up = qrot(hw.r, qrot(qconj(tpose(find("head")).r), [0, 1, 0]));
    const headR = (top - tpose(find("head")).t[1]) / 2;
    const pic: number[] = [...dot(hw.t.map((x, a) => x + up[a] * headR)), headR * unit];
    for (const [bone, slot] of slotOf) { if (finger(slot)) continue; const i = node(bone), p = parentOf(i); if (p !== undefined) pic.push(...dot(w(p).t), ...dot(w(i).t)); }
    motions.push({ name: c.name, seconds: (n - 1) / FPS, fn, category: c.category, loop: !!c.loop, thumb: pic.map((x) => x.toFixed(1)).join(", ") });
    console.log(`${c.name.padEnd(10)} ${String(half ? (n + 1) / 2 : n).padStart(3)} keys  ${((n - 1) / FPS).toFixed(2)} s  from ${c.from}`);
  }
}

const cases = (f: (m: typeof motions[0]) => string, other: string) =>
  motions.map((m, i) => `    case ${i}:\n      ${f(m)}`).join("\n") + `\n    case _:\n      ${other}`;
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, "motions.bend"), `# GENERATED by tools/clips.ts from ${cfgPath.split("/").pop()}. Do not edit:
# change clips.json and run the importer again.
#
# ${cfg.name}, by ${cfg.credit} (${cfg.license}).

import Base
import ${ENGINE}/core/vec.bend as V
import ${ENGINE}/core/quat.bend as Q
import ${ENGINE}/anim/motion.bend as M

def neg(+x: F32) -> F32: (0.0 - x : F32)

def q(+x: F32, +y: F32, +z: F32, +w: F32) -> Q.Q:
  Q.Q{x, y, z, w}

def v(+x: F32, +y: F32, +z: F32) -> V.V3:
  V.V3{x, y, z}

${defs.join("\n")}
# The collection these motions come from, for the library's folder.
def collection() -> String: ${JSON.stringify(cfg.name)}
def credit() -> String: ${JSON.stringify(cfg.credit)}
def license() -> String: ${JSON.stringify(cfg.license)}

def categories() -> List<&2, String>:
  [${(cfg.categories as string[]).map((x) => JSON.stringify(x)).join(", ")}]

def count() -> U32: ${motions.length}

def name(+i: U32) -> String:
  match i:
${cases((m) => `"${m.name}"`, `""`)}

def seconds(+i: U32) -> F32:
  match i:
${cases((m) => num(m.seconds), "0.0")}

def category(+i: U32) -> String:
  match i:
${cases((m) => `"${m.category}"`, `""`)}

def loops(+i: U32) -> Bool:
  match i:
${cases((m) => (m.loop ? "True{}" : "False{}"), "False{}")}

# The clip's picture: the head (x, y, radius), then a line per bone
# (x1, y1, x2, y2), in a box of 40 by 40.
def thumb(+i: U32) -> List<&2, F32>:
  match i:
${cases((m) => `[${m.thumb}]`, "Nil{}")}

# Motion i. Only the one asked for is built.
def motion(+i: U32) -> M.Motion:
  match i:
${cases((m) => `${m.fn}()`, `M.Motion{"", 0.0, 0.0, False{}, Nil{}, Nil{}}`)}
`);
console.log(`${motions.length} motions → ${join(outDir, "motions.bend")}`);
