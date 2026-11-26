# The workspace: the editor's windows, each in its place, as Unity's default layout has them.
#
#   top       the toolbar: the project's name (and "Not saved" when Save has something to write),
#             Play, Pause and Next tick in the middle, Save on the right
#   left      the Hierarchy: the scene's things (editor/hierarchy/)
#   middle    the viewport: the editor's window, already on the page (editor/index.html); it shows
#             what the Animation tab plays over it (tags)
#   right     the Inspector: the thing or the asset selected last (editor/inspector/)
#   bottom    the dock, with three tabs: Project (the project's files and the library,
#             editor/project/), Console (editor/console/) and Animation (the transport,
#             editor/animation/)
#
# Every window stays where it is: choosing a dock tab changes the dock only. What the windows
# share is editor/workspace/state.bend: the state and the one kind of event. This file puts the
# windows in their places, holds the page's styles, and says what each event does (step). It is
# one page written in Bend (Bend-UI's Web.bend and UI.bend), drawn on the page's body, around the
# editor's window that is already there; nothing of it is in index.html, in editor.css or in
# JavaScript. editor/app.js only mounts it, hands the scene back and forth, does what the page
# asks (a folder made, a file read, the scene saved) and tells it how that went.
#
# The sizes are Bend-UI's: the Hierarchy and the Inspector are as wide as Bend-UI's side bar
# (TOKENS.bend's side_width), and the dock is as tall as they are wide.
#
# Accessibility (ACCESSIBILITY.bend): nothing here moves by itself (see each window). The body says
# data-motion="reduce" while reduce motion is on, so nothing moves under the pointer either
# (editor/icons/view.bend): only colors change.
#
# Limits now:
# - The windows cannot be resized, moved, closed or docked elsewhere (Unity's are): Bend-UI's
#   panes take their size from panes.js, which draws outside this page (a request for Bend-UI).
# - No layout for a narrow screen: the editor is laid out for a desktop.
# - The styles are one text in a <style> node, so a wrong token name in them is not caught by
#   Bend-UI's laws.
# - No Move, Rotate and Scale tools in the toolbar: the viewport has no handles to drag yet
#   (editor/viewport/gizmo.bend is the axis gizmo only), so a place is typed in the Inspector.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene/scene.bend as S
import ../../engine/anim/figure.bend as Fig
import ../../engine/script/rule.bend as R
import ../../engine/render/shader/asset.bend as A
import ./state.bend as W
import ./pieces.bend as P
import ../scene/view.bend as Sc
import ../hierarchy/view.bend as H
import ../inspector/view.bend as I
import ../inspector/rules.bend as Ru
import ../project/view.bend as Pj
import ../console/view.bend as C
import ../animation/view.bend as An
import ../shaders/view.bend as Sh
import ../icons/view.bend as Ic
import ../defaults/defaults.bend as D
import ../hierarchy/make.bend as Mk
import ../project/templates.bend as Tp
import ../../projects/prefabs.bend as Pre
import ../../engine/script/problem.bend as Pb
import ../code/view.bend as Ce
import ../code/code.bend as Cd
import ../../engine/script/attach.bend as At
import ../../engine/script/value.bend as Val
import ../inspector/scripts.bend as Xs

# ---------- What editor/app.js asks ----------
# A Bend module gives only its own defs, so what app.js asks of the state is named again here.

def start(+scene: S.Scene, +still: Bool, +catalog: A.Catalog, +paths: List<&2, String>, +rules: List<&2, R.Rule>, +own: Bool, +name: String, +folder: String, +sc: String, +made: List<&2, Pre.Made>, +removed: List<&2, String>, +broken: List<&2, Pb.Problem>, +offers: List<&2, At.Offer>) -> Web.Update<W.St, W.Ev>:
  W.start(scene, still, catalog, paths, rules, own, name, folder, sc, made, removed, broken, offers)

# The scene being edited, and how many times its list of things changed (editor/app.js uploads
# them again: platform/web/draw.js's rebuild).
def scene_name(+st: W.St) -> String:
  W.scene_name(W.cut(st))

def built(+st: W.St) -> U32:
  W.built(W.cut(st))

# Save: the text of the scene's saved file (base: the scene as its code makes it; now: as edited),
# and where it goes.
def save_text(+st: W.St, +base: S.Scene, +now: S.Scene) -> String:
  Mk.save_text(st, base, now)

def save_path(+st: W.St) -> String:
  Mk.save_path(st)

# Create: the files a scene, a script or a shader is made of, each a path inside the project's
# folder and its text; and where the Project window shows the new file when the page opens again.
def create_files(+st: W.St) -> List<&2, Tp.Written>:
  Pj.create_files(st)

def file_path(+f: Tp.Written) -> String:
  Tp.path(f)

def file_text(+f: Tp.Written) -> String:
  Tp.text(f)

def created_at(+st: W.St) -> String:
  Pj.created_at(st)

def created_file(+st: W.St) -> String:
  Pj.created_file(st)

# What editor/app.js hands over: a right click in the Project window, and the folder and the asset
# to show when the page opens on a file just made.
def menu_event(+x: F32, +y: F32, +h: F32) -> W.Ev:
  W.f_menu{x, y, h}

def go_event(+path: String) -> W.Ev:
  W.f_go{path}

def pick_event(+path: String) -> W.Ev:
  W.f_pick{path}

def scene(+st: W.St) -> S.Scene:
  W.scene(st)

def selected(+st: W.St) -> U32:
  W.selected(st)

def motion_event(+still: Bool) -> W.Ev:
  W.motion_event(still)

# Play, as the toolbar shows it (engine/play/play.bend's to_mode takes it), and how many times
# Step and Save were pressed.
def play_mode(+st: W.St) -> U32:
  W.play_mode(st)

def steps(+st: W.St) -> U32:
  W.steps(st)

def saves(+st: W.St) -> U32:
  W.saves(st)

# The scene's rules, and whether they are the editor's own (engine/scene/save.bend saves them).
def rules(+st: W.St) -> List<&2, R.Rule>:
  W.rules(st)

def own_rules(+st: W.St) -> Bool:
  W.own_rules(st)

# What the page asks of editor/app.js: a new ask has a new number.
def ask_n(+st: W.St) -> U32:
  W.ask_n(W.ask(st))

def ask_what(+st: W.St) -> String:
  W.ask_what(W.ask(st))

def ask_path(+st: W.St) -> String:
  W.ask_path(W.ask(st))

# What editor/app.js tells the page.
def listed_event(+text: String) -> W.Ev:
  W.f_listed{text}

def text_event(+path: String, +text: String) -> W.Ev:
  W.f_text{path, text}

def log_event(+tone: String, +text: String) -> W.Ev:
  W.c_log{tone, text}

def shader_of(+st: W.St) -> String:
  Sh.shader_of(st)

def failed(+before: W.St, +id: String, +message: String) -> W.St:
  W.logged(Sh.failed(before, id, message), "error", "The shader " ++ id ++ " could not be used: " ++ message)

# The scene and the selection as the viewport left them (editor/app.js).
def follow(+st: W.St, +s: S.Scene, +i: U32) -> W.St:
  Sh.remembered(W.follow_to(st, s, i))

# The script editor (editor/code/): whether a script is open, which one, and its text (editor/app.js
# sends the text to be checked or written, and keeps the script in the page's address).
def code_open(+st: W.St) -> Bool:
  Cd.is_open(W.code(st))

def code_path(+st: W.St) -> String:
  Cd.path(W.code(st))

def code_text(+st: W.St) -> String:
  Cd.text(W.code(st))

# What editor/app.js tells the script editor: open a script; the checker's answer for text (found:
# a problem of this kind (tools/script/check.ts names it), at line and col, len characters, in the
# module `inside` or "" for the script itself).
def code_event(+path: String) -> W.Ev:
  W.k_open{path}

def checked_event(+text: String, +found: Bool, +kind: String, +line: U32, +col: U32, +len: U32, +said: String, +inside: String, +st: W.St) -> W.Ev:
  W.k_checked{text, found, Pb.Problem{Cd.name(W.code(st)), Pb.kind_of(kind), line, col, len, said, inside}}


# ---------- The toolbar ----------

# Play, Pause and Step, as Unity's toolbar has them. Bend-UI has no stop or pause icon: while
# playing, the Play button is tinted and its name is Stop, and Pause is a toggle with its name
# written.
def play_button(editing: Bool) -> Web.HTML<W.Ev>:
  match editing:
    case True{}:
      Ui.icon_button(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Play", "play", W.p_play{})
    case False{}:
      Ui.icon_button(W.Ev, [Ui.btn_tinted{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Stop", "play", W.p_play{})

def mode_tag(+m: U32) -> List<&2, Web.HTML<W.Ev>>:
  P.pick_html(U32.is_eq(m, 0), Nil{}, [Ui.says(W.Ev, "span", "tag tag--accent", P.pick_text(U32.is_eq(m, 1), "Playing", "Paused"))])

# While a script does not compile, the toolbar says so beside Play (pressing Play says why).
def broken_tag(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  P.pick_html(W.scripts_compile(st), Nil{}, [Ui.says(W.Ev, "span", "tag tag--danger", "Script errors")])

def play_controls(+st: W.St) -> Web.HTML<W.Ev>:
  Web.node{"div", [Web.attr{"class", "editor-play"}, Web.attr{"role", "group"}, Web.attr{"aria-label", "Play"}], List.append(&2, Web.HTML<W.Ev>, [
    play_button(U32.is_eq(W.play_mode(st), 0)),
    Ui.toggle(W.Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}, Ui.btn_sm{}], "", "Pause", U32.is_eq(W.play_mode(st), 2), W.p_pause{}),
    Ui.icon_button(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Next tick", "chevron-right", W.p_step{})],
    List.append(&2, Web.HTML<W.Ev>, mode_tag(W.play_mode(st)), broken_tag(st)))}

def save_button(dirty: Bool) -> Web.HTML<W.Ev>:
  match dirty:
    case True{}:
      Ui.button(W.Ev, [Ui.btn_filled{}, Ui.btn_sm{}], "Save", W.p_save{})
    case False{}:
      Ui.button(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}], "Save", W.p_save{})

def toolbar(+st: W.St) -> Web.HTML<W.Ev>:
  Web.node{"header", [Web.attr{"class", "toolbar editor-toolbar"}], [
    Ui.box(W.Ev, "div", "editor-toolbar__start", [], List.append(&2, Web.HTML<W.Ev>, [Ui.says(W.Ev, "span", "item-title", W.project_name(st)), Ui.says(W.Ev, "span", "meta", "/"), Ui.says(W.Ev, "span", "item-title", W.scene_name(W.cut(st)))],
      P.pick_html(W.dirty(st), [Ui.says(W.Ev, "span", "meta", "Not saved")], Nil{}))),
    play_controls(st),
    Ui.box(W.Ev, "div", "editor-toolbar__end", [], [save_button(W.dirty(st))])]}

# ---------- The dock ----------

def dock_view(+n: U32, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match n:
    case 1:
      C.view(st)
    case 2:
      An.view(st)
    case _:
      Pj.view(st)

def dock(+st: W.St) -> Web.HTML<W.Ev>:
  Ui.panel_as(W.Ev, "section", "editor-window editor-dock", [Web.attr{"aria-label", "Project, Console and Animation"}],
    Ui.panel_header(W.Ev, [
      Ui.segmented(W.Ev, [], "Dock", [
        Ui.choice(W.Ev, "Project", U32.is_eq(W.dock(st), 0), W.a_tab{0}),
        Ui.choice(W.Ev, C.tab_name(st), U32.is_eq(W.dock(st), 1), W.a_tab{1}),
        Ui.choice(W.Ev, "Animation", U32.is_eq(W.dock(st), 2), W.a_tab{2})])]) <> dock_view(W.dock(st), st))

# ---------- Over the viewport ----------

# What the Animation tab plays, over the viewport: the character, its clip, in place.
def showing(+st: W.St) -> Web.HTML<W.Ev>:
  Web.node{"div", [Web.attr{"class", "editor-showing"}], P.pick_html((W.is_open(st) && Bool.not(Cd.is_open(W.code(st)))), An.showing_kids(W.has_character(st), st), Nil{})}

# ---------- The page ----------

# The screen's styles, with Bend-UI's tokens. The body becomes a grid of three columns
# (Hierarchy, viewport, Inspector) and three rows (toolbar, viewport, dock); the editor's window,
# which is already on the page, takes the middle.
def styles() -> String:
  "body[data-editor] { display: grid; grid-template-columns: var(--side-width) minmax(0, 1fr) var(--side-width); grid-template-rows: auto minmax(0, 1fr) var(--side-width); height: 100dvh; overflow: hidden; gap: 0; }" ++
  "body[data-editor] > .window { grid-column: 2; grid-row: 2; min-width: 0; min-height: 0; border-radius: 0; }" ++
  ".editor-toolbar { grid-column: 1 / 4; grid-row: 1; display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; gap: var(--space-2); padding: var(--space-1) var(--space-3); border-bottom: var(--border-width) solid var(--border); background: var(--bg); }" ++
  ".editor-toolbar__start { display: flex; align-items: center; gap: var(--space-2); min-width: 0; }" ++
  ".editor-toolbar__end { display: flex; justify-content: flex-end; gap: var(--space-2); }" ++
  ".editor-play { display: flex; align-items: center; gap: var(--space-1); }" ++
  ".editor-window { display: flex; flex-direction: column; min-height: 0; min-width: 0; border-radius: 0; border: 0; background: var(--bg); }" ++
  ".editor-window__body { flex: 1; overflow: auto; min-height: 0; }" ++
  ".editor-hierarchy { grid-column: 1; grid-row: 2; border-right: var(--border-width) solid var(--border); }" ++
  ".editor-hierarchy__tree:focus-visible { outline: var(--focus-width) solid var(--accent); outline-offset: var(--focus-offset); border-radius: var(--radius-sm); }" ++
  ".editor-inspector { grid-column: 3; grid-row: 2 / 4; border-left: var(--border-width) solid var(--border); }" ++
  ".editor-inspector__head { display: flex; align-items: center; justify-content: space-between; gap: var(--space-2); padding: var(--space-1) var(--space-2); }" ++
  ".editor-inspector__line { display: grid; grid-template-columns: minmax(0, 2fr) minmax(0, 3fr); align-items: center; gap: var(--space-2); padding: var(--space-1) var(--space-2); }" ++
  ".editor-inspector__line .input { width: 100%; min-width: 0; }" ++
  ".editor-inspector__add { display: flex; justify-content: center; padding: var(--space-3) var(--space-2); }" ++
  ".editor-inspector__remove { align-self: flex-start; }" ++
  ".editor-inspector__text { margin: 0 var(--space-2); padding: var(--space-2); max-height: calc(var(--side-width) * 2); overflow: auto; font-family: var(--font-mono); font-size: var(--text-xs); line-height: var(--leading-body); white-space: pre; background: var(--surface-2); border: var(--border-width) solid var(--border); border-radius: var(--radius-md); }" ++
  ".editor-dock { grid-column: 1 / 3; grid-row: 3; border-top: var(--border-width) solid var(--border); }" ++
  ".editor-dock__bar { display: flex; align-items: center; gap: var(--space-2); padding: var(--space-1) var(--space-2); border-bottom: var(--border-width) solid var(--border); min-width: 0; }" ++
  ".editor-dock__scroll { flex: 1; overflow: auto; min-height: 0; padding: var(--space-2); }" ++
  ".editor-project { flex: 1; display: grid; grid-template-columns: var(--side-width) minmax(0, 1fr); min-height: 0; }" ++
  ".editor-project__folders { border-right: var(--border-width) solid var(--border); }" ++
  ".editor-project__crumbs { flex: 1; }" ++
  ".editor-project__search { width: calc(var(--side-width) * 3 / 4); }" ++
  ".editor-project__naming .input { width: var(--side-width); }" ++
  ".editor-project__tiles { display: grid; grid-template-columns: repeat(auto-fill, minmax(calc(var(--space-8) + var(--space-5)), 1fr)); gap: var(--space-1); align-content: start; }" ++
  ".editor-project__tile { height: auto; flex-direction: column; align-items: center; gap: var(--space-1); padding: var(--space-2) var(--space-1); border-radius: var(--radius-md); position: relative; min-width: 0; }" ++
  ".editor-project__name { font-size: var(--text-xs); max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }" ++
  ".editor-project__warning { position: absolute; top: var(--space-1); right: var(--space-1); color: var(--warning-text); }" ++
  ".editor-console__lines { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--space-hairline); font-size: var(--text-sm); }" ++
  ".editor-console__line { display: flex; align-items: baseline; gap: var(--space-2); padding: var(--space-1) var(--space-2); border-radius: var(--radius-sm); }" ++
  ".editor-console__line:nth-child(odd) { background: var(--surface-2); }" ++
  ".editor-console__line[data-tone='error'] .editor-console__icon, .editor-console__line[data-tone='error'] .editor-console__tone { color: var(--danger-text); }" ++
  ".editor-console__line[data-tone='warning'] .editor-console__icon, .editor-console__line[data-tone='warning'] .editor-console__tone { color: var(--warning-text); }" ++
  ".editor-console__icon { flex: none; align-self: center; }" ++
  ".editor-console__tone { flex: none; font-weight: var(--weight-medium); }" ++
  ".editor-console__text { min-width: 0; overflow-wrap: anywhere; white-space: pre-wrap; }" ++
  ".editor-showing { grid-column: 2; grid-row: 2; align-self: start; justify-self: start; margin: var(--space-4); z-index: var(--layer-foot); pointer-events: none; display: flex; flex-wrap: wrap; gap: var(--space-1); }" ++
  ".editor-transport { gap: var(--space-2); flex-wrap: wrap; }" ++
  ".editor-transport__time { flex: 1; min-width: var(--space-8); accent-color: var(--accent); }" ++
  ".editor-transport__read { font-family: var(--font-mono); font-size: var(--text-sm); color: var(--text-2); font-variant-numeric: tabular-nums; }" ++
  ".editor-transport__motion { display: flex; align-items: center; gap: var(--space-2); font-size: var(--text-sm); color: var(--text-2); }" ++
  ".editor-material__field, .editor-material__group { padding: var(--space-1) var(--space-2); min-width: 0; }" ++
  ".editor-material__group { border: 0; margin: 0; }" ++
  ".editor-material__group .input { padding: 0 var(--space-1); }" ++
  ".editor-material__dropdown, .editor-material__dropdown > .dropdown, .editor-material__dropdown > .dropdown > .btn { width: 100%; }" ++
  ".editor-material__dropdown > .dropdown > .btn { justify-content: space-between; }" ++
  ".editor-material__toggle { align-self: flex-start; }" ++
  ".editor-material__slider { display: flex; align-items: center; gap: var(--space-2); min-height: var(--control-sm); }" ++
  ".editor-material__range { flex: 1; min-width: 0; margin: 0; accent-color: var(--accent); }" ++
  ".editor-anim__list { display: flex; flex-direction: column; gap: var(--space-1); }" ++
  ".editor-anim__picture { width: var(--control-lg); height: var(--control-lg); flex: none; border-radius: var(--radius-md); background: var(--bg); border: var(--border-width) solid var(--border); stroke: var(--text-2); stroke-width: var(--space-hairline); stroke-linecap: round; fill: none; }" ++
  ".editor-anim__picture circle { fill: var(--text-2); stroke: none; }" ++
  ".editor-anim__fact { display: flex; align-items: baseline; justify-content: space-between; gap: var(--space-4); }" ++
  ".editor-anim__fact > .detail { text-align: right; min-width: 0; overflow-wrap: anywhere; }" ++
  ".editor-anim__stack { display: flex; flex-direction: column; gap: var(--space-2); padding: var(--space-1) var(--space-2); }" ++
  ".editor-anim__help { margin: 0; font-size: var(--text-sm); line-height: var(--leading-ui); color: var(--text-detail); }" ++
  ".editor-anim__foot { display: flex; flex-direction: column; padding: var(--space-2); }" ++
  ".editor-anim__wide { display: flex; }" ++
  ".editor-anim__wide > button { flex: 1; padding: 0 var(--space-2); }" ++
  ".editor-anim__wide > button:disabled { opacity: var(--disabled-opacity); cursor: default; }" ++
  ".editor-menu-layer { position: fixed; inset: 0; z-index: var(--layer-menu); }" ++
  ".editor-context-menu { position: fixed; top: auto; z-index: var(--layer-menu); }" ++
  ".editor-inspector__choices { display: flex; flex-wrap: wrap; gap: var(--space-2); padding: var(--space-1) var(--space-2); }" ++
  Ic.styles() ++ Ce.styles()

# The windows, as children of the page's body, around the editor's window.
def render(+st: W.St) -> Web.HTML<W.Ev>:
  Web.node{"body", [Web.attr{"data-editor", ""}, Web.attr{"data-motion", P.pick_text(D.reduce_motion(W.still(st)), "reduce", "")}], List.append(&2, Web.HTML<W.Ev>, [
    Web.node{"style", [], [Web.text{styles()}]},
    toolbar(st), H.panel(st), showing(st), I.panel(st), dock(st)], List.append(&2, Web.HTML<W.Ev>, Ce.panel(st), Pj.context_menu(W.menu_open(W.cut(st)), st)))}

# Is the page showing a time that moves by itself now? Then it is drawn every frame (editor/app.js
# asks before drawing it again): the Animation tab's time bar, while a character is selected.
def draws_frames(+st: W.St) -> Bool:
  (W.is_open(st) && W.has_character(st))

# ---------- What clicks and keystrokes mean ----------

# A keystroke, a key or a move of a bar carries what it has: the message comes back holding it.
def on_input(+msg: W.Ev, +got: Web.Input) -> W.Ev:
  match msg got:
    case W.a_scrub{_} Web.typed{v}:
      W.a_scrub{v}
    case W.s_number{n, k, _} Web.typed{v}:
      W.s_number{n, k, v}
    case W.s_graph{n, k, _} Web.typed{v}:
      W.s_graph{n, k, v}
    case W.d_tags{_} Web.typed{v}:
      W.d_tags{v}
    case W.d_typed{e, _} Web.typed{v}:
      W.d_typed{e, v}
    case W.r_num{k, a, _} Web.typed{v}:
      W.r_num{k, a, v}
    case W.f_query{_} Web.typed{v}:
      W.f_query{v}
    case W.x_num{k, f, _} Web.typed{v}:
      W.x_num{k, f, v}
    case W.x_int{k, f, _} Web.typed{v}:
      W.x_int{k, f, v}
    case W.x_text{k, f, _} Web.typed{v}:
      W.x_text{k, f, v}
    case W.x_vec{k, f, a, _} Web.typed{v}:
      W.x_vec{k, f, a, v}
    case W.k_typed{_} Web.typed{v}:
      W.k_typed{v}
    case W.f_name{_} Web.typed{v}:
      W.f_name{v}
    case W.h_key{_} Web.key{name, _, _}:
      W.h_key{name}
    case _ _:
      msg

# A thing's place typed in Play changes the running copy only; Stop forgets it (engine/play/).
# A rule's change is the editor's: it is kept, and Save writes it.
#
# a_left is the last case on purpose, and must stay last: Bend-UI's driver hands this page the
# events of any page mounted inside it (Editor Defaults, in the editor's window;
# docs/bend-ui-requests.txt), and Bend's JS takes a constructor it does not know as the last case
# of a match. a_left changes nothing, so a foreign event changes nothing.
def step(+ev: W.Ev, +st: W.St) -> W.St:
  match ev:
    case W.a_tab{n}:
      W.opened(st, n)
    case W.a_mirror{m}:
      An.tried((W.has_character(st) && W.picked(W.lib(st))), W.with_lib(st, W.with_mirror(W.lib(st), m)))
    case W.a_keep{}:
      W.on_character((W.has_character(st) && Fig.shows_trial(W.figure(st))), st, Fig.keep(W.figure(st)))
    case W.a_drop{}:
      W.with_lib(W.on_character((W.has_character(st) && Bool.not(Fig.shows_trial(W.figure(st)))), st, Fig.remove_shown(W.figure(st))), W.unpicked(W.lib(st)))
    case W.a_show{n}:
      W.with_lib(W.on_character(W.has_character(st), st, Fig.show(W.figure(st), n)), W.unpicked(W.lib(st)))
    case W.a_play{on}:
      W.on_character(W.has_character(st), st, Fig.set_on(W.figure(st), on))
    case W.a_step{ahead}:
      W.on_character(W.has_character(st), st, Fig.step_frame(Fig.set_on(W.figure(st), False{}), ahead))
    case W.a_scrub{text}:
      An.seeked(st, F32.read(text))
    case W.a_thing{i}:
      W.chosen(st, i)
    case W.a_motion{b}:
      W.stilled(st, b)
    case W.s_apply{id}:
      Sh.applied(st, id)
    case W.s_number{name, k, text}:
      Sh.numbered(st, name, k, F32.read(text))
    case W.s_set{name, value}:
      Sh.rematerial(Sh.has_material(st), st, A.edit(Sh.material(st), Sh.params(st), name, [value]))
    case W.s_graph{name, k, text}:
      Sh.graphed(st, name, k, F32.read(text))
    case W.p_play{}:
      W.played(st)
    case W.p_pause{}:
      W.paused(st)
    case W.p_step{}:
      W.stepped(st)
    case W.p_save{}:
      W.saved(st)
    case W.d_tags{text}:
      Sc.tagged(st, text)
    case W.d_typed{e, text}:
      Sc.typed(st, e, text)
    case W.h_key{name}:
      H.key(st, name)
    case W.r_add{}:
      I.rule_added(st)
    case W.r_drop{k}:
      I.ruled(st, Ru.dropped(W.rules(st), k))
    case W.r_when{k, n}:
      I.ruled(st, Ru.with_when(W.rules(st), k, n))
    case W.r_does{k, n}:
      I.ruled(st, Ru.with_does(W.rules(st), k, n))
    case W.r_num{k, a, text}:
      I.rule_number(st, k, a, F32.read(text))
    case W.r_clip{k, n}:
      I.ruled(st, Ru.with_clip(W.rules(st), k, n))
    case W.f_tree{path}:
      Pj.treed(st, path)
    case W.f_go{path}:
      Pj.went(st, path)
    case W.f_pick{path}:
      Pj.picked(st, path)
    case W.f_query{text}:
      W.with_files(st, W.with_files_query(W.files(st), text))
    case W.f_naming{on}:
      W.with_files(st, W.with_naming(W.files(st), on))
    case W.f_name{text}:
      W.with_files(st, W.with_new_name(W.files(st), text))
    case W.f_make{}:
      Pj.made(st)
    case W.f_listed{text}:
      Pj.listed(st, text)
    case W.f_text{path, text}:
      Ce.text_in(Pj.read(st, path, text), path, text)
    case W.c_log{tone, text}:
      W.logged(st, tone, text)
    case W.c_clear{}:
      W.with_log(st, Nil{})
    case W.h_make{n}:
      Mk.made(st, n)
    case W.h_delete{}:
      Mk.deleted(st)
    case W.f_new{what}:
      Pj.started(st, what)
    case W.f_menu{x, y, h}:
      W.with_cut(st, W.with_menu(W.cut(st), True{}, x, y, h))
    case W.f_menu_close{}:
      W.with_cut(st, W.with_menu(W.cut(st), False{}, 0.0, 0.0, 0.0))
    case W.f_open{name, force}:
      P.pick_st((force || Bool.not(W.dirty(st))), W.asked(st, "open", name), st)
    case W.k_open{path}:
      Ce.opened(st, path)
    case W.k_typed{text}:
      Ce.typed(st, text)
    case W.k_checked{text, found, p}:
      Ce.checked(st, text, found, p)
    case W.k_save{}:
      Ce.save(st)
    case W.k_close{force}:
      Ce.close(st, force)
    case W.x_add{name}:
      Xs.added(st, name)
    case W.x_drop{k}:
      Xs.dropped(st, k)
    case W.x_num{k, f, text}:
      Xs.numbered(st, k, f, text)
    case W.x_int{k, f, text}:
      Xs.counted(st, k, f, text)
    case W.x_flag{k, f, on}:
      Xs.set_field(st, k, f, Val.Value.Flag{on})
    case W.x_text{k, f, text}:
      Xs.set_field(st, k, f, Val.Value.Text{text})
    case W.x_vec{k, f, a, text}:
      Xs.axised(st, k, f, a, text)
    case W.x_ref{k, f, n}:
      Xs.referred(st, k, f, n)
    case W.a_left{}:
      st

# The state after an event, with every graph material remembered.
def on_event(+ev: W.Ev, +st: W.St) -> Web.Update<W.St, W.Ev>:
  Web.update{Sh.remembered(step(ev, st)), Web.none{}}
