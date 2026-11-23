// Reading the keyboard and the pointer in the browser. It hands over what the person did and
// decides nothing: which key is which, what a key does and how a drag moves the camera are
// Bend's (engine/input/, engine/play/play.bend, engine/scene/camera.bend).
//
// This is runtime code: a game without the editor reads input with it too.
//
//   key(code, down)    a key went down or up; `code` is the browser's KeyboardEvent.code, the
//                      key's place on the keyboard, not the letter it types (MDN). Bend turns it
//                      into its own code (engine/input/keys.bend's from_web).
//   focus(on)          the page lost (false) or got back (true) the focus: the window was left,
//                      or the tab was hidden. Bend lets go of every key (engine/input/keyboard.bend).
//   drag(dx, dy, pan)  the pointer moved while down; pan is right-drag or Shift-drag
//   wheel(dy)          the wheel turned
//   release(x0, y0, x, y)  the main button was let go at (x, y), pressed at (x0, y0), in the
//                      canvas's pixels from its top left; Bend says whether it was a click
//                      (engine/input/pointer.bend) and what was under it (engine/scene/pick.bend)
//
// Limits now:
// - A key typed into a field (a number in the Details, the library's search) is not handed over:
//   it is the field's. A key pressed with ⌘, Ctrl or Alt is not handed over either: those are
//   shortcuts, the browser's or Bend-UI's (editor/viewport/keys.bend's laws keep them apart).
// - An auto-repeated key down is handed over too; Bend counts only the first.
// - No touch gestures, no gamepad, no pointer lock.

export function createInput(canvas, { key, focus, drag, wheel, release = () => {} }) {
  const typing = (e) => /^(INPUT|TEXTAREA|SELECT)$/.test(e.target?.tagName ?? "");
  addEventListener("keydown", (e) => {
    if (typing(e) || e.metaKey || e.ctrlKey || e.altKey) return;
    key(e.code, true);
  });
  addEventListener("keyup", (e) => key(e.code, false));
  addEventListener("blur", () => focus(false));
  addEventListener("focus", () => focus(true));
  document.addEventListener("visibilitychange", () => focus(document.visibilityState === "visible"));

  let held = null;
  canvas.addEventListener("contextmenu", (e) => e.preventDefault());
  const local = (e) => { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  canvas.addEventListener("pointerdown", (e) => {
    const [x0, y0] = local(e);
    held = { x: e.clientX, y: e.clientY, x0, y0, main: e.button === 0, pan: e.button !== 0 || e.shiftKey };
    canvas.setPointerCapture(e.pointerId);
  });
  canvas.addEventListener("pointermove", (e) => {
    if (!held) return;
    const dx = e.clientX - held.x, dy = e.clientY - held.y;
    held.x = e.clientX; held.y = e.clientY;
    drag(dx, dy, held.pan);
  });
  canvas.addEventListener("pointerup", (e) => {
    if (held?.main) { const [x, y] = local(e); release(held.x0, held.y0, x, y); }
    held = null;
  });
  canvas.addEventListener("pointercancel", () => { held = null; });
  canvas.addEventListener("wheel", (e) => {
    e.preventDefault();
    wheel(e.deltaY);
  }, { passive: false });
}
