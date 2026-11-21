// Reading the keyboard and the pointer in the browser. It reports what the
// person did and decides nothing: which keys matter, what a key does and
// how a drag moves the camera are the caller's (and, through it, Bend's).
//
// This is runtime code: a game without the editor reads input with it too.
//
// Limits now:
// - It reports through callbacks. It should hand Bend a list of the
//   language's own Event values per tick (engine/input/, not written yet).
// - Keys are matched by the letter typed (event.key), not by the key's
//   place on the keyboard (event.code): W/A/S/D fall apart on AZERTY.
// - A key pressed and released between two frames is lost while keys are
//   held (not stepping): only what is down when the frame runs counts.
// - No touch gestures, no gamepad, no pointer lock.

// Starts listening. `canvas` takes the drags and the wheel; keys are heard
// on the whole window.
//
//   wants(key)        is this key (lowercase) one the caller uses?
//   stepping()        true: each press is one step and a held key does not
//                     repeat (reduce motion); false: keys are held
//   press(key)        one press, while stepping
//   drag(dx, dy, pan) the pointer moved while down; pan is right-drag or Shift-drag
//   wheel(dy)         the wheel turned
//
// Gives back `down`, the set of wanted keys held right now.
export function createInput(canvas, { wants, stepping, press, drag, wheel }) {
  const down = new Set();
  const typing = (e) => /^(INPUT|TEXTAREA|SELECT)$/.test(e.target?.tagName ?? "");
  addEventListener("keydown", (e) => {
    const key = e.key.toLowerCase();
    if (!wants(key) || typing(e) || e.metaKey || e.ctrlKey || e.altKey) return;
    if (stepping()) {
      if (e.repeat) return;
      press(key);
    } else down.add(key);
  });
  addEventListener("keyup", (e) => down.delete(e.key.toLowerCase()));
  addEventListener("blur", () => down.clear());

  let held = null;
  canvas.addEventListener("contextmenu", (e) => e.preventDefault());
  canvas.addEventListener("pointerdown", (e) => {
    held = { x: e.clientX, y: e.clientY, pan: e.button !== 0 || e.shiftKey };
    canvas.setPointerCapture(e.pointerId);
  });
  canvas.addEventListener("pointermove", (e) => {
    if (!held) return;
    const dx = e.clientX - held.x, dy = e.clientY - held.y;
    held.x = e.clientX; held.y = e.clientY;
    drag(dx, dy, held.pan);
  });
  const release = () => { held = null; };
  canvas.addEventListener("pointerup", release);
  canvas.addEventListener("pointercancel", release);
  canvas.addEventListener("wheel", (e) => {
    e.preventDefault();
    wheel(e.deltaY);
  }, { passive: false });

  return { down };
}
