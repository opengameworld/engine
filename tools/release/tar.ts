// A deterministic tar writer, and a reader for what `git archive` writes. The release decides
// names, modes and the time (tools/release/RELEASE.bend); this file only lays out bytes.
//
// Limits now:
// - Writes regular files and directories only: no links, devices or sparse files.
// - Long or non-ASCII paths get a pax `path` record; sizes stay under the ustar limit (8 GiB).
// - The reader takes regular files, directories and pax headers (git archive's set); anything
//   else is refused.

export type Entry = { path: string; data: Uint8Array; mode: number };

const enc = new TextEncoder();
const dec = new TextDecoder();
const BLOCK = 512;

function octal(n: number, width: number): string {
  return n.toString(8).padStart(width - 1, "0") + "\0";
}

function header(name: Uint8Array, mode: number, size: number, mtime: number, type: string): Uint8Array {
  const h = new Uint8Array(BLOCK);
  const put = (at: number, s: string | Uint8Array) => h.set(typeof s === "string" ? enc.encode(s) : s, at);
  put(0, name.subarray(0, 100));
  put(100, octal(mode, 8));
  put(108, octal(0, 8));
  put(116, octal(0, 8));
  put(124, octal(size, 12));
  put(136, octal(mtime, 12));
  put(148, "        ");
  put(156, type);
  put(257, "ustar\0");
  put(263, "00");
  put(329, octal(0, 8));
  put(337, octal(0, 8));
  let sum = 0;
  for (const b of h) sum += b;
  put(148, sum.toString(8).padStart(6, "0") + "\0 ");
  return h;
}

// A pax record's length counts its own digits.
function paxRecord(key: string, value: string): Uint8Array {
  const body = ` ${key}=${value}\n`;
  const n = enc.encode(body).length;
  let len = n + String(n).length;
  if (String(len).length !== String(n).length) len = n + String(len).length;
  return enc.encode(`${len}${body}`);
}

function pad(n: number): Uint8Array {
  return new Uint8Array((BLOCK - (n % BLOCK)) % BLOCK);
}

// Entries must be sorted by the caller; directories end with "/".
export function tar(entries: Entry[], mtime: number): Uint8Array {
  const parts: Uint8Array[] = [];
  for (const e of entries) {
    const name = enc.encode(e.path);
    const dir = e.path.endsWith("/");
    if (name.length > 100 || /[^\x20-\x7e]/.test(e.path)) {
      const rec = paxRecord("path", e.path);
      parts.push(header(enc.encode("././@PaxHeader"), 0o644, rec.length, mtime, "x"), rec, pad(rec.length));
    }
    const size = dir ? 0 : e.data.length;
    parts.push(header(name, e.mode, size, mtime, dir ? "5" : "0"));
    if (!dir) parts.push(e.data, pad(size));
  }
  parts.push(new Uint8Array(BLOCK * 2));
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) { out.set(p, at); at += p.length; }
  return out;
}

// gzip with no name and a zero time; the OS byte is fixed to Unix (3) so a build on another
// system writes the same bytes.
export function gzip(data: Uint8Array): Uint8Array {
  const gz = Bun.gzipSync(data, { level: 9 });
  if (gz[3] !== 0 || gz[4] | gz[5] | gz[6] | gz[7]) throw new Error("gzip header carries a name or a time");
  gz[9] = 3;
  return gz;
}

export type Read = { path: string; data: Uint8Array; mode: number };

function field(h: Uint8Array, at: number, len: number): string {
  const s = h.subarray(at, at + len);
  const end = s.indexOf(0);
  return dec.decode(end < 0 ? s : s.subarray(0, end));
}

function paxPath(data: Uint8Array): string | undefined {
  for (let i = 0; i < data.length;) {
    const sp = data.indexOf(0x20, i);
    const len = Number(dec.decode(data.subarray(i, sp)));
    if (sp < 0 || !(len > 0)) throw new Error("malformed pax header");
    const kv = dec.decode(data.subarray(sp + 1, i + len - 1));
    if (kv.startsWith("path=")) return kv.slice(5);
    i += len;
  }
  return undefined;
}

// The regular files of a tar (directories are implied by their paths).
export function untar(buf: Uint8Array): Read[] {
  const out: Read[] = [];
  let at = 0;
  let next: string | undefined;
  while (at + BLOCK <= buf.length) {
    const h = buf.subarray(at, at + BLOCK);
    if (h.every((b) => b === 0)) break;
    const size = parseInt(field(h, 124, 12).trim() || "0", 8);
    const type = String.fromCharCode(h[156] || 48);
    const data = buf.subarray(at + BLOCK, at + BLOCK + size);
    at += BLOCK + size + ((BLOCK - (size % BLOCK)) % BLOCK);
    if (type === "g") continue;
    if (type === "x") { next = paxPath(data); continue; }
    const prefix = field(h, 345, 155);
    const name = next ?? (prefix ? `${prefix}/${field(h, 0, 100)}` : field(h, 0, 100));
    next = undefined;
    if (type === "5") continue;
    if (type !== "0") throw new Error(`tar entry ${name}: type ${type} is not a regular file`);
    out.push({ path: name, data: data.slice(), mode: parseInt(field(h, 100, 8).trim(), 8) });
  }
  return out;
}
