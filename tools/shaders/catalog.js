import { mkdirSync, readdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { compileHlsl } from "./hlsl.js";

const stages = {
  frag: "fragment", fs: "fragment", ps: "fragment", fragment: "fragment", pixel: "fragment",
  vert: "vertex", vs: "vertex", vertex: "vertex",
  geom: "geometry", gs: "geometry", geometry: "geometry",
  comp: "compute", cs: "compute", compute: "compute",
  tesc: "tessellation control", hs: "tessellation control", hull: "tessellation control",
  tese: "tessellation evaluation", ds: "tessellation evaluation", domain: "tessellation evaluation",
  mesh: "mesh", task: "task", rgen: "ray generation", rchit: "ray hit", rmiss: "ray miss",
};
const languages = new Set(["glsl", "hlsl", "wgsl", "shader"]);
const controls = new Set(["number", "slider", "dropdown", "toggle", "color"]);
const reserved = new Set(["u_vp", "u_model", "u_time"]);

function classify(file) {
  const parts = file.toLowerCase().split("/").at(-1).split(".");
  if (parts.length < 2) return null;
  const extension = parts.pop();
  if (Object.hasOwn(stages, extension)) return { language: "glsl", stage: stages[extension] };
  if (!languages.has(extension)) return null;
  const qualifier = parts.length > 1 ? parts.at(-1) : "";
  const stage = Object.hasOwn(stages, qualifier) ? stages[qualifier] : undefined;
  return { language: extension, stage };
}

const finite = (x) => typeof x === "number" && Number.isFinite(Math.fround(x));
const exactInteger = (x) => finite(x) && Number.isInteger(x) && Math.fround(x) === x;
const text = (x) => typeof x === "string" && x.trim().length > 0;
const record = (x) => x && typeof x === "object" && !Array.isArray(x);

function parameter(p, names) {
  if (!record(p) || typeof p.name !== "string" || !/^[a-zA-Z_]\w*$/.test(p.name)
    || reserved.has(p.name) || names.has(p.name)) {
    throw new Error("Parameter names must be unique, non-reserved shader identifiers.");
  }
  names.add(p.name);
  if (!text(p.label) || !controls.has(p.control)) {
    throw new Error(`Parameter "${p.name}" needs a label and a supported control.`);
  }
  const fail = () => { throw new Error(`Invalid settings for parameter "${p.name}" (${p.control}).`); };
  const common = { name: p.name, label: p.label, control: p.control };
  switch (p.control) {
    case "number":
      if (!finite(p.default)) fail();
      return { ...common, default: [p.default] };
    case "slider":
      if (![p.min, p.max, p.step, p.default].every(finite) || p.min >= p.max
        || p.step <= 0 || p.default < p.min || p.default > p.max) fail();
      return { ...common, default: [p.default], min: p.min, max: p.max, step: p.step };
    case "toggle":
      if (typeof p.default !== "boolean") fail();
      return { ...common, default: [Number(p.default)] };
    case "color":
      if (!Array.isArray(p.default) || p.default.length !== 3
        || !p.default.every((x) => finite(x) && x >= 0 && x <= 1)) fail();
      return { ...common, default: p.default };
    case "dropdown": {
      if (!Array.isArray(p.options) || !p.options.length) fail();
      const values = new Set();
      const options = p.options.map((option) => {
        if (!record(option) || !text(option.label) || !exactInteger(option.value)
          || option.value < -2147483648 || option.value > 2147483647 || values.has(option.value)) fail();
        values.add(option.value);
        return { label: option.label, value: option.value };
      });
      if (!values.has(p.default)) fail();
      return { ...common, default: [p.default], options };
    }
  }
}

function loadAsset(directory, path, kind, available, compile) {
  if (kind.stage && kind.stage !== "fragment") {
    throw new Error(`Unsupported shader stage "${kind.stage}". Only fragment shaders are supported.`);
  }
  if (kind.language !== "glsl" && kind.language !== "hlsl") {
    throw new Error(`Unsupported shader language "${kind.language}". Use GLSL or HLSL.`);
  }
  const descriptor = `${path}.json`;
  if (!available.has(descriptor)) throw new Error(`Missing descriptor "${descriptor}".`);
  let data;
  try {
    data = JSON.parse(readFileSync(resolve(directory, descriptor), "utf8").replace(/^\uFEFF/, ""));
  } catch (error) {
    throw new Error(`Cannot read descriptor "${descriptor}": ${error.message}`);
  }
  if (!record(data)) throw new Error("The shader descriptor must be a JSON object.");
  if (typeof data.stage !== "string" || data.stage.toLowerCase() !== "fragment") {
    throw new Error(`Unsupported shader stage "${data.stage ?? "unspecified"}". Only fragment shaders are supported.`);
  }
  if (typeof data.lighting !== "string" || data.lighting.toLowerCase() !== "unlit") {
    throw new Error(`Unsupported lighting model "${data.lighting ?? "unspecified"}". Only UNLIT shaders are supported.`);
  }
  if (!text(data.label) || !Array.isArray(data.parameters)) {
    throw new Error("The descriptor needs a label and a parameters array.");
  }
  const names = new Set();
  const parameters = data.parameters.map((p) => parameter(p, names));
  const source = readFileSync(resolve(directory, path), "utf8").replace(/^\uFEFF/, "");
  const code = source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\r\n]*/g, " ");
  if (kind.language === "glsl" && !/^\s*#\s*version\s+300\s+es(?:\s|$)/.test(code)) {
    throw new Error("GLSL shaders must start with #version 300 es.");
  }
  return { label: data.label, language: kind.language, parameters,
    source: kind.language === "glsl" ? source : compile(source, path) };
}

function shaderFiles(directory, prefix = "") {
  const paths = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = `${prefix}${entry.name}`;
    if (entry.isDirectory()) paths.push(...shaderFiles(resolve(directory, entry.name), `${path}/`));
    if (entry.isFile()) paths.push(path);
  }
  return paths;
}

// One project's shaders, from any project folder: the assets in its shaders/ folder, and what is wrong with the files that could not be used.
export function scanProject(dir, compile = compileHlsl) {
  const directory = resolve(dir, "shaders");
  const assets = [], diagnostics = [];
  let files;
  try {
    files = shaderFiles(directory).sort();
  } catch (error) {
    if (error.code !== "ENOENT") diagnostics.push({ path: "shaders", message: error.message });
    files = [];
  }
  const available = new Set(files);
  for (const path of files) {
    const kind = classify(path);
    if (!kind) {
      const shader = path.slice(0, -5);
      if (path.endsWith(".json") && classify(shader) && !available.has(shader)) {
        diagnostics.push({ path, message: `Shader source "${shader}" is missing.` });
      }
      continue;
    }
    try {
      assets.push({ id: path, ...loadAsset(directory, path, kind, available, compile) });
    } catch (error) {
      diagnostics.push({ path, message: error.message });
    }
  }
  return { assets, diagnostics };
}

export function scanShaders(projects, compile = compileHlsl) {
  const catalog = Object.create(null);
  for (const project of readdirSync(projects, { withFileTypes: true })) {
    if (!project.isDirectory()) continue;
    catalog[project.name] = scanProject(resolve(projects, project.name), compile);
  }
  return catalog;
}

// The catalog again, as Bend values (engine/render/shader/asset.bend): each project's assets with their
// parameters, and what is wrong with the files that could not be used. The editor's Shaders screen
// (editor/workspace/view.bend) reads these; the shader sources stay in the JSON, for the GPU.
const bendText = (s) => JSON.stringify(String(s));
const bendNumber = (x) => {
  const s = Number.isInteger(x) ? Math.abs(x).toFixed(1) : String(Math.abs(x));
  return x < 0 ? `neg(${s})` : s;
};
const bendList = (items) => `[${items.join(", ")}]`;
function bendControl(p) {
  switch (p.control) {
    case "slider": return `A.AsSlider{${bendNumber(p.min)}, ${bendNumber(p.max)}, ${bendNumber(p.step)}}`;
    case "dropdown": return `A.AsDropdown{${bendList(p.options.map((o) => `A.Choice{${bendText(o.label)}, ${bendNumber(o.value)}}`))}}`;
    case "toggle": return "A.AsToggle{}";
    case "color": return "A.AsColor{}";
    default: return "A.AsNumber{}";
  }
}
// engine: the import prefix from the generated file's folder to the engine's root.
export function bendCatalog(catalog, engine = "../../") {
  const projects = Object.keys(catalog).sort();
  const name = (project) => `project_${project.replace(/[^a-zA-Z0-9]/g, "_")}`;
  const defs = projects.map((project) => {
    const { assets, diagnostics } = catalog[project];
    const assetLines = assets.map((a) => `    A.Asset{${bendText(a.id)}, ${bendText(a.label)}, ${bendText(a.language)}, ${bendList(a.parameters.map((p) =>
      `\n      A.Param{${bendText(p.name)}, ${bendText(p.label)}, ${bendControl(p)}, ${bendList(p.default.map(bendNumber))}}`))}}`);
    const problemLines = diagnostics.map((d) => `    A.Problem{${bendText(d.path)}, ${bendText(d.label ?? d.path)}, ${bendText(d.message)}}`);
    return `def ${name(project)}() -> A.Catalog:\n  A.Catalog{[\n${assetLines.join(",\n")}], [\n${problemLines.join(",\n")}]}\n`;
  });
  const picks = projects.reduceRight((rest, project) => `pick(String.eq(folder, ${bendText(project)}), ${name(project)}(), ${rest})`, "A.none()");
  return `# GENERATED by tools/shaders/catalog.js from projects/*/shaders. Do not edit:
# change the shader files or their .json settings; bun run dev, build and
# check write this file again.

import Base
import ${engine}engine/render/shader/asset.bend as A

def neg(+x: F32) -> F32: (0.0 - x : F32)

def pick(c: Bool, a: A.Catalog, b: A.Catalog) -> A.Catalog:
  match c:
    case True{}:
      a
    case False{}:
      b

${defs.join("\n")}
# The catalog of a project's folder; an empty one for a project without shaders.
def of(+folder: String) -> A.Catalog:
  ${picks}
`;
}

// Writes the samples' catalog (every folder under projects) into directory, as JSON and as Bend.
export function writeShaderCatalog(projects = resolve("projects"), directory = resolve("editor/shaders"), engine = "../../") {
  const output = resolve(directory, "catalog.generated.json");
  const catalog = scanShaders(projects);
  mkdirSync(directory, { recursive: true });
  const temporary = `${output}.${process.pid}.tmp`;
  writeFileSync(temporary, `${JSON.stringify(catalog, null, 2)}\n`);
  renameSync(temporary, output);
  // A file that could not be used still has the name its settings give it: the editor lists it by that name.
  for (const [project, { diagnostics }] of Object.entries(catalog)) {
    for (const d of diagnostics) {
      try { d.label = JSON.parse(readFileSync(resolve(projects, project, "shaders", `${d.path}.json`), "utf8")).label; } catch {}
      if (typeof d.label !== "string" || !d.label.trim()) delete d.label;
    }
  }
  const bend = resolve(directory, "catalog_generated.bend");
  writeFileSync(`${bend}.${process.pid}.tmp`, bendCatalog(catalog, engine));
  renameSync(`${bend}.${process.pid}.tmp`, bend);
  for (const [project, { diagnostics }] of Object.entries(catalog)) {
    for (const { path, message } of diagnostics) console.warn(`[${project}/shaders/${path}] ${message}`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  writeShaderCatalog();
}
