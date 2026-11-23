// The game without the editor: draws its scene and runs it, the player's counterpart of
// startEditor (editor/app.js). This is runtime code: it ships in every published game.
//
// `game` is the Bend module export writes for one game (.export/gen/<game>/game.bend): a Play
// session already playing its opening scene (engine/play/play.bend), its camera, and reduce
// motion (ACCESSIBILITY.bend plus the system's setting). Keys go to the session; every frame the
// session moves on by fixed ticks and says what to draw and where the camera looks. Nothing is
// decided here.
//
// Limits now:
// - The camera follows the first character (engine/scene/camera.bend's follow); the person can
//   orbit it with a drag and zoom with the wheel.

import { createRenderer } from "./draw.js";
import { createInput } from "./input.js";
import { createLoop, fitCanvas } from "./loop.js";

export function runGame(canvas, game, { skins = {}, shaders = {} } = {}) {
  let session = game.start();
  let cam = game.camera();
  const still = matchMedia("(prefers-reduced-motion: reduce)");

  const loop = createLoop({
    draw: () => renderer.draw(game.shown(session), game.view(session, cam)),
    tick: (dt) => {
      const reduce = game.reduce_motion(still.matches);
      if (game.runs(session, reduce)) {
        session = game.frame(session, dt, reduce);
        loop.redraw();
      }
    },
  });
  const renderer = createRenderer(canvas, game.shown(session), { skins, redraw: loop.redraw, shaders });

  createInput(canvas, {
    key: (code, down) => { session = game.key(session, code, down); },
    focus: (on) => { session = game.focus(session, on); },
    drag: (dx, dy, pan) => { cam = game.orbit(cam, dx, dy, pan, canvas.clientHeight); loop.redraw(); },
    wheel: (dy) => { cam = game.zoom(cam, dy); loop.redraw(); },
    release: (x0, y0, x, y) => { session = game.click(session, game.view(session, cam), x0, y0, x, y, canvas.clientWidth, canvas.clientHeight); },
  });

  fitCanvas(canvas, loop.redraw);
  loop.start();
}
