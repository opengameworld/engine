// Drawing a scene in the browser, with WebGL2. It draws what Bend returns
// and decides nothing: the World (engine/world.bend) and the camera
// (engine/camera.bend) give every number, the scene (engine/scene.bend) says
// what is in the World, engine/shader/glsl.bend writes the shaders and
// engine/material.bend gives the values of their parameters.
//
// This is runtime code: a game without the editor draws with it too. It
// knows nothing of the editor (panels, gizmo, shortcuts).
//
// Limits now:
// - Material things are drawn without the depth test, in the scene's order:
//   the water lies on y = 0 with the grid, so two surfaces on one plane
//   would fight. What is drawn last shows on top.
// - A shown thing is uploaded once, from the opening scene; a thing added
//   later is not seen (an edit of place or values is: edited()).
// - Bone lines and skinning matrices are copied from Bend lists every frame
//   (gpu.js's flat), one number at a time.
// - The order of drawing is written here, in JS. It should come from Bend.

import World from "../../engine/world.bend";
import Scene from "../../engine/scene.bend";
import Camera from "../../engine/camera.bend";
import Glsl from "../../engine/shader/glsl.bend";
import Material from "../../engine/material.bend";
import Transform from "../../engine/transform.bend";
import Figure from "../../engine/figure.bend";
import { flat, program as link } from "./gpu.js";

// A renderer for `canvas`, ready for the things of `opening`.
//
// `skins` gives, for each figure's skin name, the files to draw it with:
//   { [name]: { info: <skin.json>, bin: <url of skin.bin>, textures: [url per part] } }
// written by tools/gltf.ts. A figure whose skin has no entry is drawn as bones.
// `redraw` is called when something arrives late (a skin's files) and the
// picture must be drawn again.
export function createRenderer(canvas, opening, { skins = {}, redraw = () => {} } = {}) {
  const gl = canvas.getContext("webgl2", { antialias: true });
  const program = (vert, frag) => link(gl, vert, frag);

  const prog = program(Glsl.line_vert(), Glsl.line_frag());

  const u = {
    vp: gl.getUniformLocation(prog, "u_vp"),
    eye: gl.getUniformLocation(prog, "u_eye"),
    fade: gl.getUniformLocation(prog, "u_fade"),
  };

  // The ground: built once by world.bend, 6 floats per vertex (x y z r g b).
  const lines = new Float32Array(flat(World.lines()));
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, lines, gl.STATIC_DRAW);
  const pos = gl.getAttribLocation(prog, "a_pos");
  const col = gl.getAttribLocation(prog, "a_col");
  gl.enableVertexAttribArray(pos);
  gl.vertexAttribPointer(pos, 3, gl.FLOAT, false, 24, 0);
  gl.enableVertexAttribArray(col);
  gl.vertexAttribPointer(col, 3, gl.FLOAT, false, 24, 12);

  // A material's values go to their uniforms; material.bend names each one.
  // Setting a value never compiles anything.
  function setValues(p, values) {
    for (let l = values; l.$ === "Con"; l = l.tail) {
      const loc = gl.getUniformLocation(p, Material.uniform(l.head));
      const xs = flat(Material.numbers(l.head));
      if (xs.length === 1) gl.uniform1f(loc, xs[0]);
      else if (xs.length === 3) gl.uniform3fv(loc, xs);
    }
  }

  // Every thing that is shown gets, once, its shader (from its material),
  // its mesh on the GPU (3 floats per vertex, 3 indices per triangle) and
  // its model matrix (from its place).
  function upload(thing) {
    const look = Scene.look(thing);
    const material = Scene.material(look);
    const shape = Scene.shape(look);
    const p = program(Glsl.mesh_vert(), Material.frag(material));
    gl.useProgram(p);
    setValues(p, Material.values(material));
    const idx = new Uint32Array(flat(shape.indices));
    const vao = gl.createVertexArray();
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(flat(shape.vertices)), gl.STATIC_DRAW);
    const at = gl.getAttribLocation(p, "a_pos");
    gl.enableVertexAttribArray(at);
    gl.vertexAttribPointer(at, 3, gl.FLOAT, false, 12, 0);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, idx, gl.STATIC_DRAW);
    return {
      prog: p, vao, count: idx.length,
      vp: gl.getUniformLocation(p, "u_vp"),
      model: gl.getUniformLocation(p, "u_model"),
      matrix: flat(Transform.flat(Scene.place(thing))),
    };
  }

  // Each shown thing, by its place in the scene's list.
  const shown = new Map();
  flat(Scene.things(opening)).forEach((t, i) => { if (Scene.is_shown(t)) shown.set(i, upload(t)); });

  // After thing i of `scene` got a new place or new values: the GPU gets its
  // new matrix and values. The graph never changes, so no shader is compiled.
  function edited(scene, i) {
    const g = shown.get(i);
    if (!g) return;
    const thing = Scene.at(scene, i);
    g.matrix = flat(Transform.flat(Scene.place(thing)));
    gl.useProgram(g.prog);
    setValues(g.prog, Material.values(Scene.material(Scene.look(thing))));
  }

  // Characters (things with a figure): their bones as lines, in the same
  // format as the grid, asked from Bend again every frame because a pose
  // changes over time.
  const boneVao = gl.createVertexArray();
  const boneBuf = gl.createBuffer();
  gl.bindVertexArray(boneVao);
  gl.bindBuffer(gl.ARRAY_BUFFER, boneBuf);
  gl.enableVertexAttribArray(pos);
  gl.vertexAttribPointer(pos, 3, gl.FLOAT, false, 24, 0);
  gl.enableVertexAttribArray(col);
  gl.vertexAttribPointer(col, 3, gl.FLOAT, false, 24, 12);

  function boneLines(scene) {
    const out = [];
    for (const t of flat(Scene.things(scene))) {
      if (!Scene.is_rigged(t)) continue;
      const fig = Scene.figure(Scene.look(t));
      if (Figure.shows_bones(fig)) out.push(...flat(Figure.lines(fig, Scene.place(t))));
    }
    return new Float32Array(out);
  }

  // Skinned characters
  // ==================
  // The mesh (positions, normals, UVs, 4 joints and 4 weights per vertex)
  // goes to the GPU once; every frame Bend gives the skinning matrices
  // (Figure.palette), which go into a float texture the vertex shader reads.
  const skinProg = program(Glsl.skinned_vert(), Glsl.skinned_frag());
  const su = {
    vp: gl.getUniformLocation(skinProg, "u_vp"),
    bones: gl.getUniformLocation(skinProg, "u_bones"),
    tex: gl.getUniformLocation(skinProg, "u_tex"),
    textured: gl.getUniformLocation(skinProg, "u_textured"),
    tint: gl.getUniformLocation(skinProg, "u_tint"),
    sun: gl.getUniformLocation(skinProg, "u_sun"),
    eyeDir: gl.getUniformLocation(skinProg, "u_eye_dir"),
  };
  const loaded = new Map();   // skin name → GPU objects, once its files arrive

  function image(url) {
    return new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => ok(null); i.src = url; });
  }

  async function loadSkin(name) {
    const entry = skins[name];
    if (!entry || loaded.has(name)) return;
    loaded.set(name, null);
    const info = entry.info;
    const bytes = await (await fetch(entry.bin)).arrayBuffer();
    const vao = gl.createVertexArray();
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Uint8Array(bytes, 0, info.indexOffset), gl.STATIC_DRAW);
    const L = info.layout, S = info.stride;
    const at = (n) => gl.getAttribLocation(skinProg, n);
    gl.enableVertexAttribArray(at("a_pos")); gl.vertexAttribPointer(at("a_pos"), 3, gl.FLOAT, false, S, L.position);
    gl.enableVertexAttribArray(at("a_normal")); gl.vertexAttribPointer(at("a_normal"), 3, gl.FLOAT, false, S, L.normal);
    gl.enableVertexAttribArray(at("a_uv")); gl.vertexAttribPointer(at("a_uv"), 2, gl.FLOAT, false, S, L.uv);
    gl.enableVertexAttribArray(at("a_joints")); gl.vertexAttribIPointer(at("a_joints"), 4, gl.UNSIGNED_SHORT, S, L.joints);
    gl.enableVertexAttribArray(at("a_weights")); gl.vertexAttribPointer(at("a_weights"), 4, gl.UNSIGNED_SHORT, true, S, L.weights);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint32Array(bytes, info.indexOffset, info.indices), gl.STATIC_DRAW);
    const boneTex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, boneTex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, 4, info.bones, 0, gl.RGBA, gl.FLOAT, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    const textures = await Promise.all(info.parts.map(async (_, k) => {
      const img = entry.textures?.[k] ? await image(entry.textures[k]) : null;
      if (!img) return null;
      const t = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, t);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
      gl.generateMipmap(gl.TEXTURE_2D);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
      return t;
    }));
    loaded.set(name, { vao, boneTex, textures, info });
    redraw();
  }

  function drawSkins(scene, frame) {
    for (const t of flat(Scene.things(scene))) {
      if (!Scene.is_rigged(t)) continue;
      const fig = Scene.figure(Scene.look(t));
      const g = loaded.get(Figure.skin(fig));
      if (!g) continue;
      const palette = new Float32Array(flat(Figure.palette(fig, Scene.place(t))));
      gl.useProgram(skinProg);
      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(gl.TEXTURE_2D, g.boneTex);
      gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, 4, g.info.bones, gl.RGBA, gl.FLOAT, palette);
      gl.uniform1i(su.bones, 1);
      gl.uniformMatrix4fv(su.vp, false, frame.slice(0, 16));
      gl.uniform3fv(su.sun, flat(Glsl.sun()));
      gl.uniform3fv(su.eyeDir, frame.slice(16, 19).map((x) => -x));
      gl.uniform3fv(su.tint, [0.8, 0.78, 0.74]);
      gl.bindVertexArray(g.vao);
      g.info.parts.forEach((part, k) => {
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, g.textures[k]);
        gl.uniform1i(su.tex, 0);
        gl.uniform1f(su.textured, g.textures[k] ? 1 : 0);
        gl.drawElements(gl.TRIANGLES, part.count, gl.UNSIGNED_INT, part.first * 4);
      });
    }
  }

  for (const t of flat(Scene.things(opening))) {
    if (Scene.is_rigged(t)) loadSkin(Figure.skin(Scene.figure(Scene.look(t))));
  }

  const [skyR, skyG, skyB] = flat(World.sky());

  // One picture of `scene`, seen from `cam`.
  function draw(scene, cam) {
    const w = canvas.width, h = canvas.height;
    const frame = flat(Camera.frame(cam, w / Math.max(h, 1)));
    gl.viewport(0, 0, w, h);
    gl.clearColor(skyR, skyG, skyB, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    // Characters first, with the depth test. Then the scene's material
    // things, in order, without it: the water lies on y = 0 with the grid,
    // so drawing order decides who shows. Then the grid, tested against the
    // characters only.
    gl.enable(gl.DEPTH_TEST);
    drawSkins(scene, frame);
    gl.disable(gl.DEPTH_TEST);
    for (const t of shown.values()) {
      gl.useProgram(t.prog);
      gl.uniformMatrix4fv(t.vp, false, frame.slice(0, 16));
      gl.uniformMatrix4fv(t.model, false, t.matrix);
      gl.bindVertexArray(t.vao);
      gl.drawElements(gl.TRIANGLES, t.count, gl.UNSIGNED_INT, 0);
    }
    // The grid is tested against the characters' depth, so it hides behind
    // them, but writes none of its own.
    gl.enable(gl.DEPTH_TEST);
    gl.depthMask(false);
    gl.useProgram(prog);
    gl.uniformMatrix4fv(u.vp, false, frame.slice(0, 16));
    gl.uniform3fv(u.eye, frame.slice(16, 19));
    gl.uniform2fv(u.fade, flat(World.fade(cam)));
    gl.bindVertexArray(vao);
    gl.drawArrays(gl.LINES, 0, lines.length / 6);
    gl.depthMask(true);
    gl.disable(gl.DEPTH_TEST);
    // Bones last, over everything, so they show through a skin (x-ray).
    const bones = boneLines(scene);
    if (bones.length) {
      gl.bindVertexArray(boneVao);
      gl.bindBuffer(gl.ARRAY_BUFFER, boneBuf);
      gl.bufferData(gl.ARRAY_BUFFER, bones, gl.DYNAMIC_DRAW);
      gl.drawArrays(gl.LINES, 0, bones.length / 6);
    }
  }

  return { draw, edited };
}
