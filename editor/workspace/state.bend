# The workspace's state: what every window of the editor shares (the scene, the thing selected,
# the system asking for less motion) and what each window remembers (the desk: the dock's tab,
# the Project window's files, the Console's lines, the scene's rules, whether there is something
# to save, what the Inspector shows; the clip picked; the shader catalog; Play), and the one kind
# of event every window sends. Each window (editor/hierarchy/, editor/inspector/, editor/project/,
# editor/console/, editor/animation/, editor/shaders/) reads and changes it;
# editor/workspace/view.bend puts the windows in their places and says what an event does.
#
# Limits now:
# - The windows share one kind of event (Ev): a new window adds its events here.
# - Some shared classes are still named editor-anim__*, from when Animation was the only screen.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../engine/scene/scene.bend as S
import ../../engine/anim/figure.bend as Fig
import ../../engine/render/shader/asset.bend as A
import ../../engine/script/rule.bend as R
import ../scene/panels.bend as O
import ../../projects/prefabs.bend as Pre

# The animation library's clip picked in the Project window (its collection and place in it,
# when `picked`), and Mirror.
type Lib is Data:
  Lib{folder: U32, k: U32, picked: Bool, mirror: Bool}

# What the Shaders screen remembers: the project's catalog of shaders (with
# the problems found so far), and every thing as it was when its material
# was last a graph (so "Original graph" can bring it back).
type Shade is Data:
  Shade{catalog: A.Catalog, graphs: S.Scene}

# Play, as the toolbar shows it: the mode (0 editing, 1 playing, 2 paused), how many times Step
# was pressed, and how many times Save was. engine/play/play.bend's session follows it (editor/app.js hands the mode
# over with to_mode, and runs one tick for each new Step).
type Run is Data:
  Run{mode: U32, steps: U32, saves: U32}

# A line of the Console: its tone ("error", "warning" or "info") and its text.
type Line is Data:
  Line{tone: String, text: String}

# The Project window: the project's folder on disk, its files (inside that folder, as
# tools/project/files.js lists them), the folders open in the tree, the folder shown, the asset
# picked ("" for none), the search, the New folder field (open, and its text), and the text of
# the file picked (as the dev server read it).
type Files is Data:
  Files{folder: String, paths: List<&2, String>, open: List<&2, String>, at: String, picked: String, query: String, naming: Bool, name: String, text: String}

# What the page asks editor/app.js to do (the dev server does it): the n-th ask, what ("folder"
# makes a folder, "read" reads a file) and the path in the project's folder.
type Ask is Data:
  Ask{n: U32, what: String, path: String}

# The scene being edited: its name, the things made in the editor (projects/prefabs.bend) and the
# things of its code deleted (both saved, engine/scene/save.bend), how many times its list of
# things changed (editor/app.js uploads them again: platform/web/draw.js's rebuild), the Project
# window's Create menu opened by a right click (and where), and what New is making ("folder",
# "scene", "script" or "shader").
type Cut is Data:
  Cut{scene: String, made: List<&2, Pre.Made>, removed: List<&2, String>, built: U32, menu: Bool, mx: F32, my: F32, what: String, mh: F32}

# The desk: the dock's tab (0 Project, 1 Console, 2 Animation), the Project window, the Console's
# lines, the scene's rules (engine/script/rule.bend), whether they are the editor's own (saved in
# place of the code's), whether something Save writes was changed since the last Save, whether the
# Inspector shows the asset picked (or the thing selected), what is asked of the page, and the
# project's name.
type Desk is Data:
  Desk{dock: U32, files: Files, log: List<&2, Line>, rules: List<&2, R.Rule>, own: Bool, dirty: Bool, asset: Bool, ask: Ask, name: String, cut: Cut}

# The workspace: the scene, the thing selected, the system asking for less motion, the desk, the
# animation library's clip picked, the shader catalog and Play.
type St is Data:
  Screen{scene: S.Scene, selected: U32, still: Bool, desk: Desk, lib: Lib, shade: Shade, run: Run}

type Ev is Data:
  a_tab{n: U32}                      # the dock's tab: Project (0), Console (1) or Animation (2)
  a_left{}                           # a field was left (changes nothing)
  a_keep{}                           # Add to the character
  a_drop{}                           # Remove from the character
  a_show{n: U32}                     # a clip of the character was clicked (0: locomotion)
  a_play{on: Bool}                   # Play, or Stop
  a_step{ahead: Bool}                # one frame ahead, or back
  a_scrub{text: String}              # the time bar moved
  a_mirror{on: Bool}
  a_thing{i: U32}                    # a thing was clicked in the scene's list
  a_motion{still: Bool}              # the system's reduced motion changed
  s_apply{id: String}                # a shader was clicked ("": the original graph)
  s_number{name: String, k: U32, text: String}   # a number typed, or a slider moved, in a parameter
  s_set{name: String, value: F32}    # a toggle pressed, or a choice picked
  s_graph{name: String, k: U32, text: String}    # a number typed in a value of the original graph
  p_play{}                           # Play, or Stop
  p_pause{}                          # Pause, or go on
  p_step{}                           # one tick, while paused
  p_save{}                           # write the edited scene's places and rules to the project
  d_typed{edit: O.Edit, text: String}   # a number typed in the Inspector (Transform, Animation)
  h_key{name: String}                # a key on the Hierarchy
  r_add{}                            # Add Component: a Rule
  r_drop{k: U32}                     # rule k removed
  r_when{k: U32, n: U32}             # rule k's trigger: Clicked (0) or Started (1)
  r_does{k: U32, n: U32}             # rule k's response: Move (0), Turn (1) or Play (2)
  r_num{k: U32, axis: U32, text: String}   # a number of rule k: Move's X Y Z, or Turn's degrees
  r_clip{k: U32, n: U32}             # the clip rule k plays
  f_tree{path: String}               # a folder of the Project's tree clicked
  f_go{path: String}                 # a folder opened: a breadcrumb, or a double click
  f_pick{path: String}               # an asset clicked
  f_query{text: String}              # a keystroke in the Project's search
  f_naming{on: Bool}                 # New folder pressed, or the field closed
  f_name{text: String}               # a keystroke in the New folder field
  f_make{}                           # Create pressed
  f_listed{text: String}             # the project's files again, one per line (editor/app.js)
  f_text{path: String, text: String} # a file's text, as the dev server read it (editor/app.js)
  c_log{tone: String, text: String}  # a line for the Console (editor/app.js)
  c_clear{}                          # Clear pressed
  h_make{n: U32}                     # the Hierarchy's Create: Empty (0), Plane (1), Character (2)
  h_delete{}                         # the thing selected deleted
  f_new{what: String}                # Create: "folder", "scene", "script" or "shader"
  f_menu{x: F32, y: F32, h: F32}     # a right click in the Project window, and the page's height
  f_menu_close{}                     # the right click's menu closed
  f_open{name: String, force: Bool}  # open a scene; force: drop what is not saved

def no_ask() -> Ask:
  Ask{0, "", ""}

# The shader files that could not be used, as the Console's first lines.
def problem_lines(ps: List<&2, A.Problem>) -> List<&2, Line>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> t:
      Line{"warning", A.problem_label(h) ++ " (" ++ A.path(h) ++ "): " ++ A.message(h)} <> problem_lines(t)

# The workspace on a project: the scene as it opens, the system's reduced motion, the project's
# shader catalog and files, the scene's rules and whether they are the editor's own, the project's
# name and folder, the scene's name, and what the editor made and deleted in it.
def start(+scene: S.Scene, +still: Bool, +catalog: A.Catalog, +paths: List<&2, String>, +rules: List<&2, R.Rule>, +own: Bool, +name: String, +folder: String, +sc: String, +made: List<&2, Pre.Made>, +removed: List<&2, String>) -> Web.Update<St, Ev>:
  Web.update{Screen{scene, 0, still, Desk{0, Files{folder, paths, ["Assets"], "Assets", "", "", False{}, "", ""}, problem_lines(A.problems(catalog)), rules, own, False{}, False{}, no_ask(), name, Cut{sc, made, removed, 0, False{}, 0.0, 0.0, "", 0.0}}, Lib{0, 0, False{}, False{}}, Shade{catalog, scene}, Run{0, 0, 0}}, Web.none{}}

# ---------- The state's parts ----------

def scene(+st: St) -> S.Scene:
  match st:
    case Screen{s, _, _, _, _, _, _}:
      s

def selected(+st: St) -> U32:
  match st:
    case Screen{_, i, _, _, _, _, _}:
      i

def still(+st: St) -> Bool:
  match st:
    case Screen{_, _, b, _, _, _, _}:
      b

def desk(+st: St) -> Desk:
  match st:
    case Screen{_, _, _, d, _, _, _}:
      d

def with_desk(+st: St, +d: Desk) -> St:
  match st:
    case Screen{s, i, b, _, l, h, r}:
      Screen{s, i, b, d, l, h, r}

# ----- The desk's parts

def dock.of(+d: Desk) -> U32:
  Desk{n, _, _, _, _, _, _, _, _, _} = d
  n

def dock(+st: St) -> U32:
  dock.of(desk(st))

def files.of(+d: Desk) -> Files:
  Desk{_, f, _, _, _, _, _, _, _, _} = d
  f

def files(+st: St) -> Files:
  files.of(desk(st))

def log.of(+d: Desk) -> List<&2, Line>:
  Desk{_, _, g, _, _, _, _, _, _, _} = d
  g

def log(+st: St) -> List<&2, Line>:
  log.of(desk(st))

def rules.of(+d: Desk) -> List<&2, R.Rule>:
  Desk{_, _, _, rs, _, _, _, _, _, _} = d
  rs

def rules(+st: St) -> List<&2, R.Rule>:
  rules.of(desk(st))

def own_rules.of(+d: Desk) -> Bool:
  Desk{_, _, _, _, o, _, _, _, _, _} = d
  o

def own_rules(+st: St) -> Bool:
  own_rules.of(desk(st))

def dirty.of(+d: Desk) -> Bool:
  Desk{_, _, _, _, _, y, _, _, _, _} = d
  y

def dirty(+st: St) -> Bool:
  dirty.of(desk(st))

# Does the Inspector show the asset picked in the Project window (or the thing selected)?
def shows_asset.of(+d: Desk) -> Bool:
  Desk{_, _, _, _, _, _, a, _, _, _} = d
  a

def shows_asset(+st: St) -> Bool:
  shows_asset.of(desk(st))

def ask.of(+d: Desk) -> Ask:
  Desk{_, _, _, _, _, _, _, k, _, _} = d
  k

def ask(+st: St) -> Ask:
  ask.of(desk(st))

def project_name.of(+d: Desk) -> String:
  Desk{_, _, _, _, _, _, _, _, n, _} = d
  n

def project_name(+st: St) -> String:
  project_name.of(desk(st))

def cut.of(+d: Desk) -> Cut:
  Desk{_, _, _, _, _, _, _, _, _, c} = d
  c

def cut(+st: St) -> Cut:
  cut.of(desk(st))

def with_cut.of(+d: Desk, +c: Cut) -> Desk:
  Desk{n, f, g, rs, o, y, a, k, nm, _} = d
  Desk{n, f, g, rs, o, y, a, k, nm, c}

def with_cut(+st: St, +c: Cut) -> St:
  with_desk(st, with_cut.of(desk(st), c))

# ----- The scene being edited (Cut)

def scene_name(+c: Cut) -> String:
  Cut{n, _, _, _, _, _, _, _, _} = c
  n

def made(+c: Cut) -> List<&2, Pre.Made>:
  Cut{_, m, _, _, _, _, _, _, _} = c
  m

def removed(+c: Cut) -> List<&2, String>:
  Cut{_, _, r, _, _, _, _, _, _} = c
  r

def built(+c: Cut) -> U32:
  Cut{_, _, _, b, _, _, _, _, _} = c
  b

def menu_open(+c: Cut) -> Bool:
  Cut{_, _, _, _, o, _, _, _, _} = c
  o

def menu_x(+c: Cut) -> F32:
  Cut{_, _, _, _, _, x, _, _, _} = c
  x

def menu_y(+c: Cut) -> F32:
  Cut{_, _, _, _, _, _, y, _, _} = c
  y

def making(+c: Cut) -> String:
  Cut{_, _, _, _, _, _, _, w, _} = c
  w

# The list of things changed: what was made and deleted now, and one more change to upload.
def rebuilt(+c: Cut, +m: List<&2, Pre.Made>, +r: List<&2, String>) -> Cut:
  Cut{n, _, _, b, o, x, y, w, h} = c
  Cut{n, m, r, (b + 1 : U32), o, x, y, w, h}

# The right click's menu: open or closed, where it was asked (x, y) and how tall the page is (h).
def with_menu(+c: Cut, +o: Bool, +x: F32, +y: F32, +h: F32) -> Cut:
  Cut{n, m, r, b, _, _, _, w, _} = c
  Cut{n, m, r, b, o, x, y, w, h}

def menu_h(+c: Cut) -> F32:
  Cut{_, _, _, _, _, _, _, _, h} = c
  h

def with_making(+c: Cut, +w: String) -> Cut:
  Cut{n, m, r, b, _, x, y, _, h} = c
  Cut{n, m, r, b, False{}, x, y, w, h}

def with_dock.of(+d: Desk, +n: U32) -> Desk:
  Desk{_, f, g, rs, o, y, a, k, nm, c} = d
  Desk{n, f, g, rs, o, y, a, k, nm, c}

def with_dock(+st: St, +n: U32) -> St:
  with_desk(st, with_dock.of(desk(st), n))

def with_files.of(+d: Desk, +f: Files) -> Desk:
  Desk{n, _, g, rs, o, y, a, k, nm, c} = d
  Desk{n, f, g, rs, o, y, a, k, nm, c}

def with_files(+st: St, +f: Files) -> St:
  with_desk(st, with_files.of(desk(st), f))

def with_log.of(+d: Desk, +g: List<&2, Line>) -> Desk:
  Desk{n, f, _, rs, o, y, a, k, nm, c} = d
  Desk{n, f, g, rs, o, y, a, k, nm, c}

def with_log(+st: St, +g: List<&2, Line>) -> St:
  with_desk(st, with_log.of(desk(st), g))

# The scene's rules changed by the editor: they are its own now, and there is something to save.
def with_rules.of(+d: Desk, +rs: List<&2, R.Rule>) -> Desk:
  Desk{n, f, g, _, _, _, a, k, nm, c} = d
  Desk{n, f, g, rs, True{}, True{}, a, k, nm, c}

def with_rules(+st: St, +rs: List<&2, R.Rule>) -> St:
  with_desk(st, with_rules.of(desk(st), rs))

def with_dirty.of(+d: Desk, +y: Bool) -> Desk:
  Desk{n, f, g, rs, o, _, a, k, nm, c} = d
  Desk{n, f, g, rs, o, y, a, k, nm, c}

def with_dirty(+st: St, +y: Bool) -> St:
  with_desk(st, with_dirty.of(desk(st), y))

def with_asset.of(+d: Desk, +a: Bool) -> Desk:
  Desk{n, f, g, rs, o, y, _, k, nm, c} = d
  Desk{n, f, g, rs, o, y, a, k, nm, c}

def with_asset(+st: St, +a: Bool) -> St:
  with_desk(st, with_asset.of(desk(st), a))

def with_ask.of(+d: Desk, +k: Ask) -> Desk:
  Desk{n, f, g, rs, o, y, a, _, nm, c} = d
  Desk{n, f, g, rs, o, y, a, k, nm, c}

def with_ask(+st: St, +k: Ask) -> St:
  with_desk(st, with_ask.of(desk(st), k))

def ask_n(+k: Ask) -> U32:
  Ask{n, _, _} = k
  n

# One more ask of the page: `what` for `path`.
def asked(+st: St, +what: String, +path: String) -> St:
  with_ask(st, Ask{(ask_n(ask(st)) + 1 : U32), what, path})

def ask_what(+k: Ask) -> String:
  Ask{_, w, _} = k
  w

def ask_path(+k: Ask) -> String:
  Ask{_, _, p} = k
  p

# A line at the end of the Console.
def logged(+st: St, +tone: String, +text: String) -> St:
  with_log(st, List.append(&2, Line, log(st), [Line{tone, text}]))

def line_tone(+l: Line) -> String:
  Line{t, _} = l
  t

def line_text(+l: Line) -> String:
  Line{_, x} = l
  x

# Is the Animation tab of the dock open?
def is_open(+st: St) -> Bool:
  U32.is_eq(dock(st), 2)

# ----- The Project window's parts

def project_folder(+f: Files) -> String:
  Files{d, _, _, _, _, _, _, _, _} = f
  d

def paths(+f: Files) -> List<&2, String>:
  Files{_, ps, _, _, _, _, _, _, _} = f
  ps

def open_folders(+f: Files) -> List<&2, String>:
  Files{_, _, o, _, _, _, _, _, _} = f
  o

def at(+f: Files) -> String:
  Files{_, _, _, a, _, _, _, _, _} = f
  a

def picked_path(+f: Files) -> String:
  Files{_, _, _, _, p, _, _, _, _} = f
  p

def files_query(+f: Files) -> String:
  Files{_, _, _, _, _, q, _, _, _} = f
  q

def naming(+f: Files) -> Bool:
  Files{_, _, _, _, _, _, n, _, _} = f
  n

def new_name(+f: Files) -> String:
  Files{_, _, _, _, _, _, _, n, _} = f
  n

def file_text(+f: Files) -> String:
  Files{_, _, _, _, _, _, _, _, x} = f
  x

def with_paths(+f: Files, +ps: List<&2, String>) -> Files:
  Files{d, _, o, a, p, q, n, nm, x} = f
  Files{d, ps, o, a, p, q, n, nm, x}

def with_open(+f: Files, +o: List<&2, String>) -> Files:
  Files{d, ps, _, a, p, q, n, nm, x} = f
  Files{d, ps, o, a, p, q, n, nm, x}

def with_at(+f: Files, +a: String) -> Files:
  Files{d, ps, o, _, p, q, n, nm, x} = f
  Files{d, ps, o, a, p, q, n, nm, x}

def with_picked(+f: Files, +p: String) -> Files:
  Files{d, ps, o, a, _, q, n, nm, _} = f
  Files{d, ps, o, a, p, q, n, nm, ""}

def with_files_query(+f: Files, +q: String) -> Files:
  Files{d, ps, o, a, p, _, n, nm, x} = f
  Files{d, ps, o, a, p, q, n, nm, x}

def with_naming(+f: Files, +n: Bool) -> Files:
  Files{d, ps, o, a, p, q, _, _, x} = f
  Files{d, ps, o, a, p, q, n, "", x}

def with_new_name(+f: Files, +nm: String) -> Files:
  Files{d, ps, o, a, p, q, n, _, x} = f
  Files{d, ps, o, a, p, q, n, nm, x}

def with_text(+f: Files, +x: String) -> Files:
  Files{d, ps, o, a, p, q, n, nm, _} = f
  Files{d, ps, o, a, p, q, n, nm, x}

def shade(+st: St) -> Shade:
  match st:
    case Screen{_, _, _, _, _, h, _}:
      h

def with_shade(+st: St, +h: Shade) -> St:
  match st:
    case Screen{s, i, b, n, l, _, r}:
      Screen{s, i, b, n, l, h, r}

def lib(+st: St) -> Lib:
  match st:
    case Screen{_, _, _, _, l, _, _}:
      l

def with_scene(+st: St, +s: S.Scene) -> St:
  match st:
    case Screen{_, i, b, o, l, h, r}:
      Screen{s, i, b, o, l, h, r}

def with_lib(+st: St, +l: Lib) -> St:
  match st:
    case Screen{s, i, b, o, _, h, r}:
      Screen{s, i, b, o, l, h, r}

def folder(+l: Lib) -> U32:
  match l:
    case Lib{f, _, _, _}:
      f

def place(+l: Lib) -> U32:
  match l:
    case Lib{_, k, _, _}:
      k

def picked(+l: Lib) -> Bool:
  match l:
    case Lib{_, _, p, _}:
      p

def mirror(+l: Lib) -> Bool:
  match l:
    case Lib{_, _, _, m}:
      m

def follow_to(+st: St, +s: S.Scene, +i: U32) -> St:
  match st:
    case Screen{_, _, b, o, l, h, r}:
      Screen{s, i, b, o, l, h, r}

def motion_event(+still: Bool) -> Ev:
  a_motion{still}

# ---------- The character ----------

def in_scene(+st: St) -> Bool:
  U32.is_lt(selected(st), U32.from_nat(S.count(scene(st))))

# Is a character selected? The screen works on it.
def has_character(+st: St) -> Bool:
  (in_scene(st) && S.is_rigged(S.at(scene(st), selected(st))))

def figure(+st: St) -> Fig.Figure:
  S.figure(S.look(S.at(scene(st), selected(st))))

def character_name(+st: St) -> String:
  S.name(S.at(scene(st), selected(st)))

def refigure(+st: St, f: Fig.Figure) -> St:
  with_scene(st, S.put(scene(st), selected(st), S.with_figure(S.at(scene(st), selected(st)), f)))

# The state after `f` is done to the character; nothing, with no character.
def on_character(has: Bool, +st: St, f: Fig.Figure) -> St:
  match has:
    case True{}:
      refigure(st, f)
    case False{}:
      st


def with_pick(+l: Lib, +f: U32, +k: U32) -> Lib:
  match l:
    case Lib{_, _, _, m}:
      Lib{f, k, True{}, m}

def unpicked(+l: Lib) -> Lib:
  match l:
    case Lib{f, k, _, m}:
      Lib{f, k, False{}, m}

def with_mirror(+l: Lib, +m: Bool) -> Lib:
  match l:
    case Lib{f, k, p, _}:
      Lib{f, k, p, m}

def opened(+st: St, +n: U32) -> St:
  with_dock(st, n)

def stilled(+st: St, +b: Bool) -> St:
  match st:
    case Screen{s, i, _, o, l, h, r}:
      Screen{s, i, b, o, l, h, r}

# A thing selected (in the Hierarchy or the viewport): the Inspector shows it again.
def chosen(+st: St, +i: U32) -> St:
  match st:
    case Screen{s, _, b, o, l, h, r}:
      with_asset(Screen{s, i, b, o, unpicked(l), h, r}, False{})

# ---------- Play ----------

def run(+st: St) -> Run:
  match st:
    case Screen{_, _, _, _, _, _, r}:
      r

def W.mode_of(+r: Run) -> U32:
  Run{m, _, _} = r
  m

def W.steps_of(+r: Run) -> U32:
  Run{_, n, _} = r
  n

def W.saves_of(+r: Run) -> U32:
  Run{_, _, n} = r
  n

def saves(+st: St) -> U32:
  W.saves_of(run(st))

def play_mode(+st: St) -> U32:
  W.mode_of(run(st))

def steps(+st: St) -> U32:
  W.steps_of(run(st))

def with_run(+st: St, +r: Run) -> St:
  match st:
    case Screen{s, i, b, o, l, h, _}:
      Screen{s, i, b, o, l, h, r}

def W.pick(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# Play pressed: Play while editing, Stop while playing or paused.
def played(+st: St) -> St:
  with_run(st, Run{W.pick(U32.is_eq(play_mode(st), 0), 1, 0), steps(st), saves(st)})

# Pause pressed: pause while playing, go on while paused, nothing while editing.
def paused(+st: St) -> St:
  with_run(st, Run{W.pick(U32.is_eq(play_mode(st), 1), 2, W.pick(U32.is_eq(play_mode(st), 2), 1, 0)), steps(st), saves(st)})

# Step pressed: one tick, only while paused.
def stepped(+st: St) -> St:
  with_run(st, Run{play_mode(st), W.pick(U32.is_eq(play_mode(st), 2), (steps(st) + 1 : U32), steps(st)), saves(st)})

# Save pressed: the edited scene's places and its rules are written (editor/app.js asks
# engine/scene/save.bend for the text). Nothing is left to save.
def saved(+st: St) -> St:
  with_dirty(with_run(st, Run{play_mode(st), steps(st), (saves(st) + 1 : U32)}), False{})
