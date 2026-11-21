// The editor: shared by every page that opens a scene (index.html for the
// engine's projects, refs/*/index.html for reference characters). It puts
// the pieces together and decides nothing: Bend says what the panels show,
// what a key does and how the camera moves; platform/web/ draws the scene
// (draw.js), reads the keyboard and the pointer (input.js) and runs the
// frames (loop.js).
//
// Only what belongs to the editor lives here: the theme, Editor Defaults
// (gizmo and info), the Scene and Details panels, the shortcuts, and the
// editor's camera.
//
// Limits now:
// - There is no Play: the scene being edited is the one that moves. A
//   character's animation runs and W/A/S/D walk it while editing.

import { theme } from "bend-ui";
import { mount } from "bend-ui/web";
import { createKeys } from "bend-ui/keys";
import Keys from "../KEYS.bend";
import Scene from "../engine/scene.bend";
import Camera from "../engine/camera.bend";
import Material from "../engine/material.bend";
import { mountDefaults } from "./defaults/defaults.js";
import Panels from "./panels/view.bend";
import Defaults from "./defaults/defaults.bend";
import Loco from "../engine/locomotion.bend";
import { createRenderer } from "../platform/web/draw.js";
import { createInput } from "../platform/web/input.js";
import { createLoop, fitCanvas } from "../platform/web/loop.js";
import { materialInspector } from "./shaders/inspector.js";

// Opens the editor on a scene (a Bend value, engine/scene.bend).
//
// `camera` is where the editor's camera starts (engine/camera.bend; its
// start() when none). `skins` gives, for each figure's skin name, the files
// to draw it with (platform/web/draw.js says their shape).
export function startEditor(opening, { skins = {}, camera = null, shaders = {} } = {}) {
  theme({ mode: "dark", radius: "pill" });   // every button and segmented in the layout is a pill

  const canvas = document.getElementById("scene");
  let scene = opening;
  let cam = camera ?? Camera.start();

  // The system asking for reduced motion (ACCESSIBILITY.bend decides what it means, through Editor Defaults).
  const still = matchMedia("(prefers-reduced-motion: reduce)");

  // The clock: characters' animations move on by themselves only when
  // motion is not reduced (ACCESSIBILITY.bend, through Editor Defaults).
  // With reduce_motion on, a character moves only when its time is typed
  // in the Details panel.
  const loop = createLoop({
    draw: () => { renderer.draw(scene, cam); defaults.draw(); },
    tick: (dt) => {
      if (Scene.animated(scene) && !Defaults.reduce_motion(still.matches)) {
        moved(Scene.advance(Loco.drive(scene, held(), dt, false), dt, false));
        redraw();
      }
    },
  });
  const redraw = loop.redraw;

  const renderer = createRenderer(canvas, opening, { skins, redraw, shaders });

  const defaults = mountDefaults(document.getElementById("editor-defaults"), {
    getCam: () => cam,
    setCam: (c) => { cam = c; redraw(); },
    orbit: (c, dx, dy) => Camera.orbit(c, dx, dy),
  });

  // The Scene and Details panels (editor/panels/view.bend): the scene's things and the
  // selected one's components. Bend says what they show and what a click or a typed number
  // does; Bend-UI's driver draws it. When an edit made a new scene, it comes back here.
  const inspector = materialInspector({
    assets: renderer.shaderAssets,
    errors: renderer.shaderErrors,
    inspect: renderer.inspectMaterial,
    assign: (i, id) => {
      const current = Scene.material(Scene.look(Scene.at(scene, i)));
      if (Material.shader_id(current) === id) return;
      const material = id ? Material.imported(id) : renderer.inspectMaterial(i)?.original;
      if (!material || !renderer.bindMaterial(i, material)) return;
      scene = Scene.with_material(scene, i, material);
      panels.set(Panels.with_scene(panels.state, scene));
      redraw();
    },
    edit: (i, name, numbers) => {
      const object = renderer.inspectMaterial(i);
      if (!object?.shader.asset) return;
      const material = Scene.material(Scene.look(Scene.at(scene, i)));
      const updated = renderer.updateMaterial(material, object.values.fields, name, numbers);
      moved(Scene.with_material(scene, i, updated));
      renderer.edited(scene, i);
      redraw();
    },
  });
  inspector.render(0);
  const panels = mount(document.getElementById("editor-panels"), {
    init: () => Panels.start(scene, still.matches),
    render: Panels.render, on_event: Panels.on_event, on_input: Panels.on_input,
  }, {
    adopt: true,
    patched: inspector.attach,
    changed: (st, before) => {
      const selected = Panels.selected(st);
      if (selected !== Panels.selected(before)) inspector.render(selected);
      const next = Panels.scene(st);
      if (next === scene) return;   // a thing was picked: the scene is the same
      scene = next;
      renderer.edited(scene, selected);
      redraw();
    },
  });
  still.addEventListener("change", () => panels.dispatch(Panels.motion_event(still.matches)));
  // The scene moved on outside the panels (a walk, the clock): they get it, and draw it at their
  // next event, as before (the Details fields are not drawn again every frame).
  const moved = (next) => { scene = next; panels.set(Panels.with_scene(panels.state, scene), { render: false }); };

  // Shortcuts: the keymap and what each view looks from are KEYS.bend.
  {
    const handlers = {};
    for (let l = Keys.keymap(); l.$ === "Con"; l = l.tail) {
      const action = l.head.action;
      handlers[action] = Keys.is_walk(action) ? () => {}
        : Keys.is_home(action) ? () => defaults.home() : () => defaults.look(Keys.view_handle(action));
    }
    createKeys(Keys.keymap(), handlers);
  }

  loop.start();

  // Walking (engine/locomotion.bend, keys in KEYS.bend). With motion
  // allowed, held keys drive the character every frame (the clock above).
  // With reduce_motion on, each press is one step: a key held down does not
  // repeat.
  const walkKeys = new Map();
  for (let l = Keys.keymap(); l.$ === "Con"; l = l.tail) {
    if (Keys.is_walk(l.head.action)) walkKeys.set(l.head.key, l.head.action);
  }
  // Drag orbits, right-drag or Shift-drag pans, the wheel zooms.
  const input = createInput(canvas, {
    wants: (key) => walkKeys.has(key),
    stepping: () => Defaults.reduce_motion(still.matches),
    press: (key) => {
      const a = walkKeys.get(key);
      moved(Loco.drive(scene, Loco.input(Keys.walk_forward(a), Keys.walk_turn(a)), 0, true));
      redraw();
    },
    drag: (dx, dy, pan) => {
      cam = pan ? Camera.pan(cam, dx, dy, canvas.clientHeight) : Camera.orbit(cam, dx, dy);
      redraw();
    },
    wheel: (dy) => { cam = Camera.zoom(cam, dy); redraw(); },
  });
  function held() {
    const acts = [...input.down].map((k) => walkKeys.get(k));
    const code = (fwd) => acts.reduce((c, a) => { const x = fwd ? Keys.walk_forward(a) : Keys.walk_turn(a); return x === 0 ? c : c === 0 ? x : -1; }, 0);
    const f = code(true), t = code(false);
    return Loco.input(f < 0 ? 0 : f, t < 0 ? 0 : t);   // opposite keys cancel
  }

  fitCanvas(canvas, redraw);
}
