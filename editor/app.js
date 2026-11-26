// The editor: shared by every page that opens a scene (editor/index.html for the
// engine's projects, refs/*/index.html for study-only characters). It puts
// the pieces together and decides nothing: Bend says what the panels show,
// what a key does and how the camera moves; platform/web/ draws the scene
// (draw.js), reads the keyboard and the pointer (input.js) and runs the
// frames (loop.js).
//
// Only what belongs to the editor lives here: the theme, Editor Defaults
// (gizmo and info), the workspace (the toolbar, Hierarchy, Inspector and the dock with Project,
// Console and Animation: editor/workspace/), the shortcuts, and the editor's camera.
//
// Play (engine/play/play.bend) is a session this file holds: the scene being edited, and while
// playing, the copy that runs. What is drawn is the session's shown(); the toolbar's Play, Pause
// and Step (editor/workspace/) change its mode; keys reach it only in Play.
//
// The workspace asks for what a page cannot do by itself, and this file does it with the dev
// server (tools/dev.ts): Save writes the scene's places and rules, a script is checked as it is typed
// and written when saved (editor/code/), a new folder is made in the
// project, a project file is read for the Inspector. How it went is a line in the Console.
//
// Limits now:
// - The Inspector shows the running copy while playing: an edit there changes the copy, and Stop
//   forgets it (as Unity does). A rule's change is kept.

import { theme } from "bend-ui";
import { mount } from "bend-ui/web";
import { createKeys } from "bend-ui/keys";
import Keys from "./viewport/keys.bend";
import Scene from "../engine/scene/scene.bend";
import Camera from "../engine/scene/camera.bend";
import { mountDefaults } from "./defaults/defaults.js";
import "bend-ui/panes";   // Bend-UI's tree rows (panes.css), drawn by the workspace's Hierarchy and Project
import Work from "./workspace/view.bend";
import Files from "./project/files_generated.bend";
import Catalog from "./shaders/catalog_generated.bend";
import Defaults from "./defaults/defaults.bend";
import Play from "../engine/play/play.bend";
import Project from "../PROJECT.bend";
import Select from "./viewport/select.bend";
import Save from "../engine/scene/save.bend";
import { flat } from "../platform/web/gpu.js";
import { createRenderer } from "../platform/web/draw.js";
import { createInput } from "../platform/web/input.js";
import { createLoop, fitCanvas } from "../platform/web/loop.js";

// Opens the editor on a scene (a Bend value, engine/scene/scene.bend).
//
// `camera` is where the editor's camera starts (engine/scene/camera.bend; its
// start() when none). `skins` gives, for each figure's skin name, the files
// to draw it with (platform/web/draw.js says their shape).
export function startEditor(opening, { skins = {}, camera = null, shaders = {}, folder = "", name = "", rules = [], ownRules = false, base = opening,
  project = null, scene: sceneName = "", made = { $: "Nil" }, removed = { $: "Nil" }, at = "", pick = "", problems = { $: "Nil" }, code = "", offers = { $: "Nil" } } = {}) {
  theme({ mode: "dark", radius: "pill" });   // every button and segmented in the layout is a pill

  const canvas = document.getElementById("scene");
  let session = Play.with_rules(Play.edit(opening), rules);
  let scene = opening;
  let cam = camera ?? Camera.start();
  // The camera drawn: the person's while editing; in Play it follows the character (Bend's rule).
  const view = () => Play.camera(session, cam);

  // The system asking for reduced motion (ACCESSIBILITY.bend decides what it means, through Editor Defaults).
  const still = matchMedia("(prefers-reduced-motion: reduce)");

  // The frames: Bend says whether a frame changes what is drawn (runs) and what the session
  // becomes (frame): the editor's clock while editing, fixed ticks while playing.
  const loop = createLoop({
    draw: () => { renderer.draw(scene, view()); defaults.draw(); },
    tick: (dt) => {
      const reduce = Defaults.reduce_motion(still.matches);
      if (Play.runs(session, reduce)) {
        // The project's scripts run in Play's ticks (PROJECT.bend's frame); a page with no project
        // (refs/) plays with none.
        session = project ? Project.frame(project, session, dt, reduce) : Play.frame(session, dt, reduce);
        moved(Play.shown(session));
        redraw();
      }
    },
  });
  const redraw = loop.redraw;

  const renderer = createRenderer(canvas, opening, { skins, redraw, shaders });
  // Every shown thing gets its place and values again (after Play starts or stops).
  const redrawAll = () => flat(Scene.things(scene)).forEach((_, i) => renderer.edited(scene, i));

  const defaults = mountDefaults(document.getElementById("editor-defaults"), {
    getCam: () => view(),
    setCam: (c) => { cam = c; redraw(); },
    orbit: (c, dx, dy) => Camera.orbit(c, dx, dy),
  });

  // The workspace (editor/workspace/view.bend): the toolbar, the Hierarchy, the Inspector and the
  // dock. It is one page written in Bend, drawn on the body around the editor's window; Bend says
  // everything it shows and does. Here it is only mounted, and the scene goes back and forth.
  // When Bend gave the selected thing another shader, the drawing code takes it; if it cannot
  // (the shader does not link), Bend is told, and gives back the state before the click with the
  // problem written down. When the toolbar's mode changed, the session goes to it; each new Step
  // is one tick. When the rules changed, Play gets them.
  const SERVER = "http://localhost:3101";
  const post = (route, body) => fetch(SERVER + route, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ folder, ...body }) })
    .then(async (r) => { const text = await r.text(); if (!r.ok) throw new Error(text); return text; });
  const say = (tone, text) => work.dispatch(Work.log_event(tone, text));
  const offline = (what) => (e) => say("error", `${what} needs \`bun run dev\` (${e.message}).`);

  const work = mount(document.body, {
    init: () => Work.start(scene, still.matches, Catalog.of(folder), Files.of(folder), rules, ownRules, name, folder, sceneName, made, removed, problems, offers),
    render: Work.render, on_event: Work.on_event, on_input: Work.on_input,
  }, {
    adopt: true,
    changed: (st, before) => {
      // Save: Bend writes the scene's saved file (editor/hierarchy/make.bend's save_text); the dev
      // server writes it where Bend says (tools/dev.ts).
      if (Work.saves(st) !== Work.saves(before)) {
        const text = Work.save_text(st, base, Play.edited(session));
        post("/save", { scene: sceneName, text }).then((path) => say("info", `Saved ${path}.`), offline("Saving"));
        return;
      }
      // What the page asked: a folder made, a file read, a scene, script or shader created, a
      // scene opened.
      if (Work.ask_n(st) !== Work.ask_n(before)) {
        const what = Work.ask_what(st), path = Work.ask_path(st);
        if (what === "folder") post("/folder", { path }).then((list) => { work.dispatch(Work.listed_event(list)); say("info", `Made the folder ${path}.`); }, offline("Making a folder"));
        if (what === "read") post("/read", { path }).then((text) => work.dispatch(Work.text_event(path, text)), () => {});
        if (what === "create") create(st);
        if (what === "open") location.assign(link({ scene: path }));
        if (what === "check") check(path, Work.code_text(st));
        if (what === "write") write(path, Work.code_text(st));
      }
      // The script open stays in the page's address, so a reload (after Save) opens it again.
      if (Work.code_open(st) !== Work.code_open(before) || Work.code_path(st) !== Work.code_path(before))
        history.replaceState(null, "", link({ code: Work.code_open(st) ? Work.code_path(st) : "" }));
      if (Work.rules(st) !== Work.rules(before)) session = Play.with_rules(session, Work.rules(st));
      if (Work.play_mode(st) !== Work.play_mode(before) || Work.steps(st) !== Work.steps(before)) {
        // A project whose script does not compile stays in Edit (PROJECT.bend's to_mode).
        session = project ? Project.to_mode(project, session, Work.play_mode(st)) : Play.to_mode(session, Work.play_mode(st));
        if (Work.steps(st) !== Work.steps(before)) session = project ? Project.step(project, session) : Play.step(session);
        moved(Play.shown(session));
        redrawAll();
        redraw();
        return;
      }
      const next = Work.scene(st), i = Work.selected(st);
      // A thing made or deleted: the scene's list changed, and every thing is uploaded again.
      if (Work.built(st) !== Work.built(before)) {
        session = Play.with_scene(session, next);
        scene = next;
        renderer.rebuild(scene);
        redraw();
        return;
      }
      if (next !== scene && Work.shader_of(st) !== Work.shader_of(before) && i === Work.selected(before)
        && !renderer.bindMaterial(i, Scene.material(Scene.look(Scene.at(next, i))))) {
        const id = Work.shader_of(st);
        work.set(Work.failed(before, id, renderer.shaderErrors.get(id || "Original graph") ?? ""));
        return;
      }
      if (next === scene) return;
      session = Play.with_scene(session, next);
      scene = next;
      renderer.edited(scene, i);
      redraw();
    },
  });

  // This page's address with some of its parameters changed (an empty value drops one).
  function link(change) {
    const params = new URLSearchParams(location.search);
    for (const [k, v] of Object.entries(change)) v ? params.set(k, v) : params.delete(k);
    return `${location.pathname}?${params}`;
  }

  // Create: the files Bend wrote go to the dev server, which writes them and restarts the engine to
  // compile them; the page opens again on the new file, in its folder.
  function create(st) {
    const files = [];
    for (let l = Work.create_files(st); l.$ === "Con"; l = l.tail) files.push({ path: Work.file_path(l.head), text: Work.file_text(l.head) });
    const shown = link({ at: Work.created_at(st), pick: Work.created_file(st) });
    post("/create", { files }).then(async () => {
      say("info", `Created ${Work.created_file(st)}. The engine restarts to compile it.`);
      history.replaceState(null, "", shown);
      // The dev server restarts: the page opens again once it answers.
      for (let tries = 0; tries < 40; tries++) {
        await new Promise((ok) => setTimeout(ok, 500));
        if (await fetch(shown, { method: "HEAD" }).then((r) => r.ok, () => false)) { location.replace(shown); return; }
      }
    }, offline("Creating"));
  }

  // The script editor (editor/code/): the text goes to Bend's checker (the dev server's /check,
  // tools/script/check.ts), and its answer back to Bend, with the text it was for. Without the
  // dev server, the answer says so.
  function check(path, text) {
    const answer = (p) => work.dispatch(Work.checked_event(text, !!p, p?.kind ?? "type", p?.line ?? 0, p?.col ?? 0, p?.len ?? 0, p?.text ?? "", p?.where ?? "", work.state));
    post("/check", { path, text }).then((t) => answer(JSON.parse(t)), (e) => answer({ text: `Checking needs \`bun run dev\` (${e.message}).` }));
  }

  // Save: the dev server writes the script; the engine restarts to compile it (its registry checks
  // it again), and the page opens again on it, as after a Create.
  function write(path, text) {
    post("/write", { path, text }).then(async () => {
      say("info", `Saved ${path}. The engine restarts to compile it.`);
      const shown = link({ code: path });
      for (let tries = 0; tries < 40; tries++) {
        await new Promise((ok) => setTimeout(ok, 500));
        if (await fetch(shown, { method: "HEAD" }).then((r) => r.ok, () => false)) { location.replace(shown); return; }
      }
    }, offline("Saving the script"));
  }

  // A right click in the Project window opens Create there (Web.bend has no context-menu event
  // yet: docs/bend-ui-requests.txt). Bend says what the menu holds.
  document.addEventListener("contextmenu", (e) => {
    if (!e.target.closest?.(".editor-project")) return;
    e.preventDefault();
    work.dispatch(Work.menu_event(e.clientX, e.clientY, innerHeight));
  });

  // The page opened on a file just made: the Project window shows its folder, and it.
  if (at) work.dispatch(Work.go_event(at));
  if (pick) work.dispatch(Work.pick_event(pick));
  // The page opened on a script (?code=, after its Save or a reload): the script editor opens it.
  if (code) work.dispatch(Work.code_event(code));

  // The scene or the selection changed outside the page: it gets them, and is drawn again when
  // asked (`draw`), or when Bend says it shows a time that moves every frame.
  function follow(next, selected, draw) {
    const st = Work.follow(work.state, next, selected);
    work.set(st, { render: draw || Work.draws_frames(st) });
  }
  still.addEventListener("change", () => work.dispatch(Work.motion_event(still.matches)));
  // The scene moved on outside the page (a tick, the clock, Play or Stop): it gets it, and draws
  // it at its next event (the Inspector's fields are not drawn again every frame).
  const moved = (next) => {
    scene = next;
    follow(scene, Work.selected(work.state), false);
  };

  // Shortcuts: the editor's keymap and what each view looks from are editor/viewport/keys.bend.
  {
    const handlers = {};
    for (let l = Keys.keymap(); l.$ === "Con"; l = l.tail) {
      const action = l.head.action;
      handlers[action] = Keys.is_home(action) ? () => defaults.home() : () => defaults.look(Keys.view_handle(action));
    }
    createKeys(Keys.keymap(), handlers);
  }

  loop.start();

  // Keys go to the session (heard only in Play); drag orbits, right-drag or Shift-drag pans, the
  // wheel zooms.
  createInput(canvas, {
    key: (code, down) => { session = Play.key(session, code, down); },
    focus: (on) => { session = Play.focus(session, on); },
    drag: (dx, dy, pan) => {
      cam = Camera.drag(cam, dx, dy, pan, canvas.clientHeight);
      redraw();
    },
    wheel: (dy) => { cam = Camera.zoom(cam, dy); redraw(); },
    // A click: while editing it selects the thing under it (editor/viewport/select.bend); while
    // playing it is the scene's to answer (engine/play/play.bend's click, the rules).
    release: (x0, y0, x, y) => {
      const w = canvas.clientWidth, h = canvas.clientHeight;
      if (!Play.is_editing(session)) { session = Play.click(session, view(), x0, y0, x, y, w, h); return; }
      const now = Work.selected(work.state);
      const i = Select.picked(scene, view(), x0, y0, x, y, w, h, now);
      if (i === now) return;
      follow(scene, i, true);
    },
  });

  fitCanvas(canvas, redraw);
}
