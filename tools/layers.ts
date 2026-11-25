// The hands of LAYERS.bend: finds the repository's code files and the imports in them, and the
// files a build reaches from its entry. It decides nothing: LAYERS.bend says what each file is
// and whether an import may be.
//
// Limits now:
// - Imports are read as text: `import ./x.bend` and an effect's `import "./x.js"` in .bend;
//   `import ... from "x"`, `export ... from "x"`, `import "x"` and `import("x")` in JS and TS;
//   `src=` and `href=` in HTML. A path computed at run time is not seen.
// - A bare specifier resolves to node_modules/<package>/<rest>; node and Bun built-ins ("node:fs",
//   "bun") are not files and are left out, and so is a path outside the repository (../bend).

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, normalize, relative } from "node:path";

export const ROOT = join(import.meta.dir, "..");
const SKIP = new Set([".git", "node_modules", "dist", ".export", "tothinkabout"]);
const CODE = /\.(bend|js|mjs|ts|html)$/;

// LAYERS.bend, loaded through ../bend's plugin (the engine's Bend, see docs/not-in-bend.txt).
export async function rules() {
  const plugin = (await import(join(ROOT, "..", "bend", "bend2", "main.ts"))).default;
  Bun.plugin(plugin);
  return (await import(join(ROOT, "LAYERS.bend"))).default;
}

export function codeFiles(dir = ROOT): string[] {
  return readdirSync(dir).sort().flatMap((n) => {
    if (SKIP.has(n) || n.startsWith(".checking")) return [];   // .checking-<pid>: the script checker's drafts
    const p = join(dir, n);
    return statSync(p).isDirectory() ? codeFiles(p) : CODE.test(n) ? [relative(ROOT, p)] : [];
  });
}

const BUILTIN = /^(node:|bun$|bun:)/;
const NODE = new Set(["fs", "path", "os", "url", "child_process", "zlib", "crypto", "util", "stream", "events", "worker_threads"]);

function resolve(from: string, spec: string): string | null {
  if (BUILTIN.test(spec) || NODE.has(spec) || /^[a-z]+:\/\//.test(spec) || spec.startsWith("/") || spec.startsWith("#")) return null;
  if (spec.startsWith(".")) {
    const p = normalize(join(dirname(from), spec.split(/[?#]/)[0]));
    return p.startsWith("..") ? null : p;   // outside the repository (../bend, the loader)
  }
  return `node_modules/${spec}${spec.includes("/") ? "" : "/"}`;
}

export function imports(file: string): string[] {
  const raw = readFileSync(join(ROOT, file), "utf8");
  // JS and TS comments are dropped first, so an example in a comment is not an import.
  const src = /\.(js|mjs|ts)$/.test(file) ? raw.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'`])\/\/.*$/gm, "$1") : raw;
  const specs: string[] = [];
  const add = (re: RegExp) => { for (const m of src.matchAll(re)) specs.push(m[1]); };
  if (file.endsWith(".bend")) {
    add(/^import\s+(\.{1,2}\/[^\s]+)/gm);
    add(/^\s+import\s+"([^"]+)"/gm);
  } else if (file.endsWith(".html")) {
    add(/\ssrc=["']([^"']+)["']/g);
    add(/<link\b[^>]*\shref=["']([^"']+)["']/g);
  } else {
    add(/(?:^|[\s;])(?:import|export)\s[^'"`;]*?\sfrom\s*["']([^"']+)["']/gm);
    add(/(?:^|[\s;])import\s*["']([^"']+)["']/gm);
    add(/import\(\s*["']([^"']+)["']\s*\)/g);
  }
  return [...new Set(specs.map((s) => resolve(file, s)).filter((x): x is string => x !== null))];
}

// Every file a build reaches from its entries, following the imports of each code file.
export function closure(entries: string[]): string[] {
  const seen = new Set<string>();
  const todo = [...entries];
  while (todo.length) {
    const f = todo.pop()!;
    if (seen.has(f)) continue;
    seen.add(f);
    if (CODE.test(f) && existsSync(join(ROOT, f)) && statSync(join(ROOT, f)).isFile()) todo.push(...imports(f));
  }
  return [...seen].sort();
}
