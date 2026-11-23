// The browser's frames: how long each one took, when the picture is drawn
// again, and the canvas keeping the size it is shown at. It decides nothing
// about time itself: the caller gets dt and says what moves.
//
// This is runtime code: a game without the editor runs on it too.
//
// Limits now:
// - dt is whatever the browser's frame took. In Play, Bend turns it into
//   fixed ticks (engine/play/tick.bend), at most 8 a frame; while editing,
//   the editor's clock still takes dt as it comes, so after a tab comes back
//   from the background the first dt is the whole time away
//   (engine/core/time.bend has a cap, max_step, nothing calls yet).

// `draw()` draws one picture; `tick(dt)` is called every frame with the
// seconds since the last one (0 on the first).
//
//   redraw()  asks for one picture at the next frame (many asks, one picture)
//   start()   starts calling tick
export function createLoop({ draw, tick }) {
  let queued = false;
  const frame = () => { queued = false; draw(); };
  const redraw = () => { if (!queued) { queued = true; requestAnimationFrame(frame); } };

  let last = 0;
  function step(now) {
    const dt = last ? (now - last) / 1000 : 0;
    last = now;
    tick(dt);
    requestAnimationFrame(step);
  }
  const start = () => requestAnimationFrame(step);

  return { redraw, start };
}

// The canvas's drawing size follows the size it is shown at, in device
// pixels; `redraw` is called after each change.
export function fitCanvas(canvas, redraw) {
  new ResizeObserver(() => {
    const dpr = devicePixelRatio || 1;
    canvas.width = Math.round(canvas.clientWidth * dpr);
    canvas.height = Math.round(canvas.clientHeight * dpr);
    redraw();
  }).observe(canvas);
}
