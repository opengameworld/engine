// The game without the editor: draws its scene and runs it, the player's counterpart of
// startEditor (editor/app.js). This is runtime code: it ships in every published game.
//
// `game` is the Bend module export writes for one game (.export/gen/<game>/game.bend): its
// opening scene and camera, the frame rule (engine/locomotion.bend's runs and frame), the walking
// keys (KEYS.bend) and reduce motion (ACCESSIBILITY.bend plus the system's setting). Nothing is
// decided here.
//
// Limits now:
// - The minimal version, to be replaced when engine/input/, tick.bend and play.bend exist: the
//   frame rule and the key handling are the editor's, copied (the same variable dt, the same
//   keys held or stepped).
// - Which held keys make which walk (opposite keys cancel) is worked out here in JS, as in the
//   editor; it belongs in Bend with engine/input/.
// - No camera control: the camera stays where the game's opening camera puts it.

import { createRenderer } from "./draw.js";
import { createInput } from "./input.js";
import { createLoop, fitCanvas } from "./loop.js";

export function runGame(canvas, game, { skins = {}, shaders = {} } = {}) {
  let scene = game.start();
  const cam = game.camera();
  const still = matchMedia("(prefers-reduced-motion: reduce)");

  const loop = createLoop({
    draw: () => renderer.draw(scene, cam),
    tick: (dt) => {
      const reduce = game.reduce_motion(still.matches);
      if (game.runs(scene, reduce)) {
        scene = game.frame(scene, held(), dt, reduce);
        loop.redraw();
      }
    },
  });
  const renderer = createRenderer(canvas, scene, { skins, redraw: loop.redraw, shaders });

  const walkKeys = new Map();
  for (let l = game.keymap(); l.$ === "Con"; l = l.tail) {
    if (game.is_walk(l.head.action)) walkKeys.set(l.head.key, l.head.action);
  }
  const input = createInput(canvas, {
    wants: (key) => walkKeys.has(key),
    stepping: () => game.reduce_motion(still.matches),
    press: (key) => {
      const a = walkKeys.get(key);
      scene = game.drive(scene, game.input(game.walk_forward(a), game.walk_turn(a)), 0, true);
      loop.redraw();
    },
    drag: () => {},
    wheel: () => {},
  });
  function held() {
    const acts = [...input.down].map((k) => walkKeys.get(k));
    const code = (fwd) => acts.reduce((c, a) => { const x = fwd ? game.walk_forward(a) : game.walk_turn(a); return x === 0 ? c : c === 0 ? x : -1; }, 0);
    const f = code(true), t = code(false);
    return game.input(f < 0 ? 0 : f, t < 0 ? 0 : t);
  }

  fitCanvas(canvas, loop.redraw);
  loop.start();
}
