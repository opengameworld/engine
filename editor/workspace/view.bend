# The workspace: the editor's tabs and the screens behind them.
#
#   Scene      the scene's list and the Details of the thing selected
#              (editor/panels/): the page as it always was
#   Animation  the animation library, on the character selected
#   Shaders    the shader library, on the material of the thing selected
#
# Animation and Shaders are screens of their own, as Unreal's Animation
# Editor and Material Editor are, and Unity's Animation window. Every
# screen has the same places, so a new one is a new tab and its parts:
# - left, a library: a search and folders, one per source, with the name
#   and the credit on the folder. A click on a row uses it on the thing
#   selected.
# - over the viewport, what is showing (tags).
# - right, the scene's list and the Details of what was picked.
# - under the viewport, a transport, for a screen that has time
#   (Animation).
#
# The Animation screen follows Mixamo's flow: a click on a clip tries it on
# the character (engine/figure.bend's trial), Add keeps it, Remove takes it
# off; the transport steps frames, plays and seeks; the Details show where
# the clip comes from, how it plays, Root and Mirror, and the character's
# clips.
#
# The Shaders screen lists the project's shader presets: the shaders made
# for it (projects/<name>/shaders/, read by tools/shaders/catalog.js into
# editor/shaders/catalog_generated.bend as values of
# engine/shader/asset.bend), each under the name its own settings give it,
# and "Original graph", the thing's own material. A click applies a
# preset; the Details show its name, file and language, one control per
# parameter (a number, a color, a toggle, a slider, a menu), and the
# shader warnings. Nothing is shown that the presets' files do not say. What a
# parameter may be worth is engine/shader/asset.bend's rule.
#
# The whole workspace is this file: one page written in Bend (Bend-UI's
# Web.bend and UI.bend), drawn on the page's body, around the editor's
# window that is already there. Its nodes, its layout and its styles
# (styles(), written with Bend-UI's tokens) all come from here; nothing of
# it is in index.html, in editor.css or in JavaScript. editor/app.js only
# mounts it, hands the scene back and forth, and tells it when the drawing
# code could not use a shader.
#
#   start(scene, still, catalog)  the workspace, on the Scene tab
#   render(state)                 the tabs, and the open screen's parts
#   draws_frames(state)           is it showing a time that moves every frame?
#   shader_of(state)              the selected thing's shader ("" for a graph)
#   failed(before, id, message)   a shader could not be used
#   on_input(msg, got)            a keystroke, a move of a bar
#   on_event(event, state)        everything a click means
#
# Accessibility (ACCESSIBILITY.bend): nothing here moves by itself. A clip
# plays only after Play is pressed, in place, and the transport shows
# Reduce motion's state.
#
# Limits now:
# - One file for the tabs and both screens (about a thousand lines): the
#   screens share one state and one kind of event, and a Bend module cannot
#   import the page it is part of. Splitting it needs the state in a
#   module of its own.
# - The classes of the shared places are still named editor-anim__*, from
#   when Animation was the only screen.
# - Root shows In place only: the library's clips have no root track, and
#   reading root motion is not built (engine/motion.bend).
# - A row of a library and a clip on the character are pressed toggle
#   buttons: Bend-UI has no selectable list yet (a request for Bend-UI).
# - The time bar and a parameter's slider are the browser's own range
#   input: Bend-UI has no slider (a request for Bend-UI).
# - There is no pause icon in Bend-UI's set: while a clip plays, the Play
#   button is tinted and its name is Stop.
# - The presets' folder is named, and credited to their author, in this
#   file (presets_name, presets_credit): the shader files carry no author.
# - The presets are a project's: a project without a shaders folder has
#   none, and the Shaders screen says so.
# - A clip's picture is the source rig's stick figure, not the selected
#   character in that pose; code-made clips have none. Shaders have no
#   picture.
# - A color is three number fields (R, G, B): Bend-UI has no color input.
# - After a shader is picked in a menu, the focus does not go back to the
#   menu's button.
# - The categories take two lines when they do not fit in one.
# - The screens use the project's scene and its camera, not a preview scene
#   of their own.
# - While a clip plays with the Animation screen open, the whole page is
#   drawn again every frame, to move the time bar: Web.bend draws a page
#   whole.
# - The page is mounted on the body, not on the editor's window: Bend-UI's
#   driver takes another page's root inside its own as one of its nodes
#   (a request for Bend-UI). So the tabs run over the whole width.
# - The styles are one text in a <style> node, so a wrong token name in
#   them is not caught by Bend-UI's laws.
# - What is added or changed lives while the page is open; nothing is
#   written to the project's files.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene.bend as S
import ../../engine/figure.bend as Fig
import ../../engine/library.bend as L
import ../../library/catalog.bend as Cat
import ../../engine/material.bend as Mat
import ../../engine/shader/asset.bend as A
import ../panels/panels.bend as O
import ../defaults/defaults.bend as D
import ../panels/view.bend as Num

# What the library panel remembers: the search, the category, the clip
# picked (folder and place in it, when `picked`), and Mirror.
type Lib is Data:
  Lib{query: String, category: String, folder: U32, k: U32, picked: Bool, mirror: Bool}

# What the Shaders screen remembers: the project's catalog of shaders (with
# the problems found so far), and every thing as it was when its material
# was last a graph (so "Original graph" can bring it back).
type Shade is Data:
  Shade{catalog: A.Catalog, graphs: S.Scene}

# The workspace: the scene, the thing selected, the system asking for less
# motion, the tab that is open (0 Scene, 1 Animation, 2 Shaders), the
# animation library's panel and the Shaders screen.
type St is Data:
  Screen{scene: S.Scene, selected: U32, still: Bool, tab: U32, lib: Lib, shade: Shade}

type Ev is Data:
  a_tab{n: U32}                      # Scene (0), Animation (1) or Shaders (2)
  a_typed{text: String}              # a keystroke in the search
  a_left{}                           # the search was left
  a_category{name: String}
  a_pick{folder: U32, k: U32}        # a clip of the library was clicked
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

def all() -> String: "All"

def start(+scene: S.Scene, +still: Bool, catalog: A.Catalog) -> Web.Update<St, Ev>:
  Web.update{Screen{scene, 0, still, 0, Lib{"", all(), 0, 0, False{}, False{}}, Shade{catalog, scene}}, Web.none{}}

# ---------- The state's parts ----------

def scene(+st: St) -> S.Scene:
  match st:
    case Screen{s, _, _, _, _, _}:
      s

def selected(+st: St) -> U32:
  match st:
    case Screen{_, i, _, _, _, _}:
      i

def still(+st: St) -> Bool:
  match st:
    case Screen{_, _, b, _, _, _}:
      b

def tab(+st: St) -> U32:
  match st:
    case Screen{_, _, _, n, _, _}:
      n

# Is the Animation screen open?
def is_open(+st: St) -> Bool:
  U32.is_eq(tab(st), 1)

# Is the Shaders screen open?
def shows_shaders(+st: St) -> Bool:
  U32.is_eq(tab(st), 2)

def shade(+st: St) -> Shade:
  match st:
    case Screen{_, _, _, _, _, h}:
      h

def with_shade(+st: St, +h: Shade) -> St:
  match st:
    case Screen{s, i, b, n, l, _}:
      Screen{s, i, b, n, l, h}

def lib(+st: St) -> Lib:
  match st:
    case Screen{_, _, _, _, l, _}:
      l

def with_scene(+st: St, +s: S.Scene) -> St:
  match st:
    case Screen{_, i, b, o, l, h}:
      Screen{s, i, b, o, l, h}

def with_lib(+st: St, +l: Lib) -> St:
  match st:
    case Screen{s, i, b, o, _, h}:
      Screen{s, i, b, o, l, h}

def query(+l: Lib) -> String:
  match l:
    case Lib{q, _, _, _, _, _}:
      q

def category(+l: Lib) -> String:
  match l:
    case Lib{_, c, _, _, _, _}:
      c

def folder(+l: Lib) -> U32:
  match l:
    case Lib{_, _, f, _, _, _}:
      f

def place(+l: Lib) -> U32:
  match l:
    case Lib{_, _, _, k, _, _}:
      k

def picked(+l: Lib) -> Bool:
  match l:
    case Lib{_, _, _, _, p, _}:
      p

def mirror(+l: Lib) -> Bool:
  match l:
    case Lib{_, _, _, _, _, m}:
      m

def follow_to(+st: St, +s: S.Scene, +i: U32) -> St:
  match st:
    case Screen{_, _, b, o, l, h}:
      Screen{s, i, b, o, l, h}

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

# ---------- Small pieces ----------

def hidden(hide: Bool) -> List<&2, Web.Attr<Ev>>:
  match hide:
    case True{}:
      [Web.attr{"hidden", ""}]
    case False{}:
      Nil{}

def chevron(reduced: Bool) -> List<&2, Web.Attr<Ev>>:
  match reduced:
    case True{}:
      [Web.style{"transition", "none"}]
    case False{}:
      Nil{}

def pick_text(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_html(c: Bool, +a: List<&2, Web.HTML<Ev>>, +b: List<&2, Web.HTML<Ev>>) -> List<&2, Web.HTML<Ev>>:
  match c:
    case True{}:
      a
    case False{}:
      b

def seconds_text(+x: F32) -> String:
  Num.fixed(x, 1) ++ " s"

def plays_text(loop: Bool) -> String:
  match loop:
    case True{}:
      "loop"
    case False{}:
      "once"

# A row of the Details: a name and its value.
def fact(+k: String, +v: String) -> Web.HTML<Ev>:
  Ui.box(Ev, "div", "editor-anim__fact", [], [Ui.says(Ev, "span", "item-title", k), Ui.says(Ev, "span", "mono detail", v)])

def help(+text: String) -> Web.HTML<Ev>:
  Ui.says(Ev, "p", "editor-anim__help", text)

def section(+title: String, +still: Bool, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Ui.disclosure_with(Ev, "", [Web.attr{"open", ""}], chevron(D.reduce_motion(still)), [Ui.disclosure_title(Ev, title)], [Ui.box(Ev, "div", "editor-anim__stack", [], kids)])

# ---------- Tabs ----------

def tabs(+st: St) -> Web.HTML<Ev>:
  Web.node{"div", [Web.attr{"class", "toolbar editor-tabs"}], [
    Ui.segmented(Ev, [], "Workspace", [
      Ui.choice(Ev, "Scene", U32.is_eq(tab(st), 0), a_tab{0}),
      Ui.choice(Ev, "Animation", is_open(st), a_tab{1}),
      Ui.choice(Ev, "Shaders", shows_shaders(st), a_tab{2})])]}

# ---------- The library (left) ----------

# The clip's picture: a head and a line per bone (engine/library.bend).
def bones_go(+ns: List<&2, F32>) -> List<&2, Web.HTML<Ev>>:
  match ns:
    case Con{x1, Con{y1, Con{x2, Con{y2, rest}}}}:
      Web.node{"line", [Web.attr{"x1", Num.fixed(x1, 1)}, Web.attr{"y1", Num.fixed(y1, 1)}, Web.attr{"x2", Num.fixed(x2, 1)}, Web.attr{"y2", Num.fixed(y2, 1)}], []} <> bones_go(rest)
    case _:
      Nil{}

def picture_kids(+ns: List<&2, F32>) -> List<&2, Web.HTML<Ev>>:
  match ns:
    case Con{x, Con{y, Con{r, rest}}}:
      Web.node{"circle", [Web.attr{"cx", Num.fixed(x, 1)}, Web.attr{"cy", Num.fixed(y, 1)}, Web.attr{"r", Num.fixed(r, 1)}], []} <> bones_go(rest)
    case _:
      Nil{}

def picture(+ns: List<&2, F32>) -> Web.HTML<Ev>:
  Web.node{"svg", [Web.attr{"class", "editor-anim__picture"}, Web.attr{"viewBox", "0 0 40 40"}, Web.attr{"aria-hidden", "true"}], picture_kids(ns)}

def added_tag(added: Bool) -> List<&2, Web.HTML<Ev>>:
  match added:
    case True{}:
      [Ui.box(Ev, "span", "tag tag--accent", [], [Ui.icon_with(Ev, [Ui.icon_sm{}], "", [], "check"), Web.text{"added"}])]
    case False{}:
      Nil{}

# One clip of a folder: its picture, its name, its length and how it
# plays, and whether the character has it.
def entry(+e: L.Entry, +f: U32, +k: U32, +on: Bool, +added: Bool) -> Web.HTML<Ev>:
  Ui.button_with(Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "editor-anim__clip", [Web.attr{"type", "button"}, Web.attr{"aria-pressed", Ui.bool_text(on)}, Web.on{Web.click{a_pick{f, k}}}],
    picture(L.entry_thumb(e)) <> Ui.box(Ev, "span", "editor-anim__clip-text", [], [
      Ui.says(Ev, "span", "item-title", L.entry_name(e)),
      Ui.says(Ev, "span", "detail", seconds_text(L.entry_seconds(e)) ++ " · " ++ plays_text(L.entry_loops(e)))]) <> added_tag(added))

# Does the search and the category let this clip through?
def passes(+e: L.Entry, +l: Lib) -> Bool:
  ((String.eq(category(l), all()) || String.eq(category(l), L.entry_category(e))) && String.contains(String.to_lower(L.entry_name(e)), String.to_lower(String.trim(query(l)))))

def entry_if(show: Bool, +e: L.Entry, +f: U32, +k: U32, +l: Lib, +fig: Fig.Figure) -> List<&2, Web.HTML<Ev>>:
  match show:
    case True{}:
      [entry(e, f, k, (picked(l) && U32.is_eq(folder(l), f) && U32.is_eq(place(l), k)), Fig.has_clip(fig, L.entry_name(e)))]
    case False{}:
      Nil{}

def entries(+es: List<&2, L.Entry>, +f: U32, +k: U32, +l: Lib, +fig: Fig.Figure) -> List<&2, Web.HTML<Ev>>:
  match es:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      List.append(&2, Web.HTML<Ev>, entry_if(passes(h, l), h, f, k, l, fig), entries(t, f, (k + 1 : U32), l, fig))

def or_none(+rows: List<&2, Web.HTML<Ev>>) -> List<&2, Web.HTML<Ev>>:
  pick_html(List.is_empty(&2, Web.HTML<Ev>, rows), [help("Nothing in this folder matches.")], rows)

# A folder of the library: its name, who made it and the license, then its clips.
def folder_view(+c: L.Collection, +f: U32, +l: Lib, +fig: Fig.Figure, +still: Bool) -> Web.HTML<Ev>:
  Ui.disclosure_with(Ev, "editor-anim__folder", [Web.attr{"open", ""}], chevron(D.reduce_motion(still)), [
    Ui.icon(Ev, "folder"),
    Ui.box(Ev, "span", "editor-anim__folder-text", [], [
      Ui.says(Ev, "span", "item-title", L.name(c)),
      Ui.says(Ev, "span", "detail", L.byline(c))])],
    [Ui.box(Ev, "div", "editor-anim__list", [], or_none(entries(L.entries(c), f, 0, l, fig)))])

def folders(+cs: List<&2, L.Collection>, +f: U32, +l: Lib, +fig: Fig.Figure, +still: Bool) -> List<&2, Web.HTML<Ev>>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      folder_view(h, f, l, fig, still) <> folders(t, (f + 1 : U32), l, fig, still)

def category_choices(+names: List<&2, String>, +now: String) -> List<&2, Web.HTML<Ev>>:
  match names:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Ui.choice(Ev, h, String.eq(h, now), a_category{h}) <> category_choices(t, now)

def search(+l: Lib) -> Web.HTML<Ev>:
  Ui.box(Ev, "div", "input-icon", [], [
    Ui.icon(Ev, "search"),
    Ui.input_with(Ev, [], "", [Web.attr{"id", "editor-anim-search"}, Web.attr{"type", "search"}, Web.attr{"placeholder", "Search clips"}, Web.attr{"aria-label", "Search clips"}, Web.attr{"value", query(l)}, Web.on{Web.input{a_typed{""}}}, Web.on{Web.change{a_left{}}}])])

# Add keeps the clip being tried; Remove takes off the added clip that shows.
def keep_button(+fig: Fig.Figure, +name: String) -> List<&2, Web.HTML<Ev>>:
  pick_html(Fig.shows_trial(fig),
    [Ui.box(Ev, "div", "editor-anim__foot", [], [Ui.button_with(Ev, [Ui.btn_primary{}], "", [Web.on{Web.click{a_keep{}}}], [Ui.icon(Ev, "plus"), Web.text{"Add to " ++ name}])])],
    pick_html(Fig.shows_locomotion(fig), Nil{},
      [Ui.box(Ev, "div", "editor-anim__foot", [], [Ui.button_with(Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}], "", [Web.on{Web.click{a_drop{}}}], [Ui.icon(Ev, "x"), Web.text{"Remove from " ++ name}])])]))

def library_body(has: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match has:
    case False{}:
      [help("Select a character in the scene's list: the library tries its clips on it.")]
    case True{}:
      [search(lib(st)),
       Ui.box(Ev, "div", "editor-anim__categories", [], [Ui.segmented(Ev, [], "Category", category_choices(all() <> Cat.categories(), category(lib(st))))]),
       Ui.box(Ev, "div", "editor-anim__folders", [], folders(Cat.collections(), 0, lib(st), figure(st), still(st)))]

# Under the list, always in sight: Add, or Remove.
def library_foot(has: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match has:
    case False{}:
      Nil{}
    case True{}:
      keep_button(figure(st), character_name(st))

def animation_library(+st: St) -> Web.HTML<Ev>:
  Web.node{"div", [Web.attr{"class", "editor-anim__panel"}], [
    Ui.panel_as(Ev, "section", "editor-anim__panel", [Web.attr{"aria-labelledby", "editor-anim-title"}],
      Ui.panel_header(Ev, [Web.node{"span", [Web.attr{"id", "editor-anim-title"}], [Web.text{"Animation Library"}]}]) <>
      Ui.panel_body_with(Ev, "editor-anim__body", [], library_body(has_character(st), st)) <> library_foot(has_character(st), st))]}

# ---------- The transport (under the viewport) ----------

# A choice nobody can press: it shows the state.
def shown_choice(+label: String, on: Bool) -> Web.HTML<Ev>:
  Ui.choice_with(Ev, on, [Web.attr{"type", "button"}, Web.attr{"tabindex", "-1"}], [Web.text{label}])

# Play; while a clip plays the same button is tinted and stops it.
def play_button(on: Bool) -> Web.HTML<Ev>:
  match on:
    case True{}:
      Ui.icon_button(Ev, [Ui.btn_tinted{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Stop", "play", a_play{False{}})
    case False{}:
      Ui.icon_button(Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Play", "play", a_play{True{}})

def three(+n: U32) -> String:
  pick_text(U32.is_lt(n, 10), "00", pick_text(U32.is_lt(n, 100), "0", "")) ++ U32.show(n)

def transport_kids(has: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match has:
    case False{}:
      Nil{}
    case True{}:
      +f = figure(st)
      [Ui.icon_button(Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Previous frame", "chevron-left", a_step{False{}}),
       play_button(Fig.is_on(f)),
       Ui.icon_button(Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Next frame", "chevron-right", a_step{True{}}),
       Web.node{"input", [Web.attr{"class", "editor-transport__time"}, Web.attr{"id", "editor-transport-time"}, Web.attr{"type", "range"}, Web.attr{"min", "0"}, Web.attr{"max", Num.fixed(Fig.length(f), 4)}, Web.attr{"step", Num.fixed(Fig.frame(), 4)}, Web.prop{"value", Num.fixed(Fig.param(f, "time"), 4)}, Web.attr{"aria-label", "Time, in seconds"}, Web.on{Web.input{a_scrub{""}}}], []},
       Ui.says(Ev, "span", "editor-transport__read", Num.fixed(Fig.param(f, "time"), 2) ++ " s · f " ++ three(Fig.frame_now(f))),
       Ui.box(Ev, "span", "toolbar__sep", [], []),
       Ui.box(Ev, "span", "editor-transport__motion", [], [
         Web.node{"span", [Web.attr{"id", "editor-transport-motion"}], [Web.text{"Reduce motion"}]},
         Ui.segmented_with(Ev, [], "editor-defaults__readonly", [Web.attr{"role", "group"}, Web.attr{"aria-labelledby", "editor-transport-motion"}], [
           shown_choice("Off", Bool.not(D.reduce_motion(still(st)))),
           shown_choice("On", D.reduce_motion(still(st)))])])]

def transport(+st: St) -> Web.HTML<Ev>:
  Web.node{"div", Web.attr{"class", "toolbar editor-transport"} <> hidden(Bool.not((is_open(st) && has_character(st)))), transport_kids(has_character(st), st)}

# ---------- What shows (over the viewport) ----------

def showing_kids(has: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match has:
    case False{}:
      Nil{}
    case True{}:
      [Ui.says(Ev, "span", "tag", character_name(st)),
       Ui.says(Ev, "span", "tag tag--mono", Fig.shown_name(figure(st))),
       Ui.says(Ev, "span", "tag", "in place")]

# ---------- The details (right) ----------

def things(+names: List<&2, String>, +i: U32, +sel: U32) -> List<&2, Web.HTML<Ev>>:
  match names:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Ui.toggle(Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "editor-panels__item", h, U32.is_eq(i, sel), a_thing{i}) <> things(t, (i + 1 : U32), sel)

def thing_names(xs: List<&2, S.Thing>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      S.name(h) <> thing_names(t)

def scene_panel(+st: St) -> Web.HTML<Ev>:
  Ui.panel_as(Ev, "section", "editor-panels__scene", [Web.attr{"aria-labelledby", "editor-anim-scene"}], [
    Ui.panel_header(Ev, [
      Web.node{"span", [Web.attr{"id", "editor-anim-scene"}], [Web.text{"Scene"}]},
      Ui.says(Ev, "span", "meta", Nat.show(S.count(scene(st))))]),
    Ui.panel_body_with(Ev, "editor-panels__list", [], things(thing_names(S.things(scene(st))), 0, selected(st)))])

def entry_at(es: List<&2, L.Entry>, +k: U32) -> L.Entry:
  match es:
    case Nil{}:
      L.Entry{"", 0.0, "", True{}, Nil{}}
    case h <> t:
      match k:
        case 0:
          h
        case _:
          entry_at(t, (k - 1 : U32))

def collection_at(cs: List<&2, L.Collection>, +f: U32) -> L.Collection:
  match cs:
    case Nil{}:
      L.Collection{"", "", "", Nil{}}
    case h <> t:
      match f:
        case 0:
          h
        case _:
          collection_at(t, (f - 1 : U32))

def disabled(off: Bool) -> List<&2, Web.Attr<Ev>>:
  match off:
    case True{}:
      [Web.attr{"disabled", ""}]
    case False{}:
      Nil{}

def labeled(+label: String, +id: String, +control: Web.HTML<Ev>, +note: String) -> Web.HTML<Ev>:
  Ui.box(Ev, "div", "field", [], [Web.node{"span", [Web.attr{"class", "field__label"}, Web.attr{"id", id}], [Web.text{label}]}, control, help(note)])

# The clip picked in the library: where it comes from and how it plays.
def clip_facts(has: Bool, +l: Lib) -> List<&2, Web.HTML<Ev>>:
  match has:
    case False{}:
      [help("Pick a clip in the library to try it on the character.")]
    case True{}:
      +c = collection_at(Cat.collections(), folder(l))
      +e = entry_at(L.entries(c), place(l))
      [fact("Name", L.entry_name(e)),
       fact("Collection", L.name(c)),
       fact("Credit", L.byline(c)),
       fact("Category", L.entry_category(e)),
       fact("Length", seconds_text(L.entry_seconds(e))),
       fact("Plays", plays_text(L.entry_loops(e))),
       labeled("Root", "editor-anim-root",
         Ui.segmented_with(Ev, [], "editor-anim__wide", [Web.attr{"role", "group"}, Web.attr{"aria-labelledby", "editor-anim-root"}], [
           Ui.choice_with(Ev, True{}, [Web.attr{"type", "button"}], [Web.text{"In place"}]),
           Ui.choice_with(Ev, False{}, [Web.attr{"type", "button"}, Web.attr{"disabled", ""}], [Web.text{"Root motion"}])]),
         "The clip stays where it is: code moves the character (engine/locomotion.bend). This clip has no root track, and reading root motion is not built."),
       labeled("Mirror", "editor-anim-mirror",
         Ui.segmented_with(Ev, [], "editor-anim__wide", [Web.attr{"role", "group"}, Web.attr{"aria-labelledby", "editor-anim-mirror"}], [
           Ui.choice_with(Ev, Bool.not(mirror(l)), Web.on{Web.click{a_mirror{False{}}}} <> disabled(Bool.not(Cat.mirrors(folder(l)))), [Web.text{"Off"}]),
           Ui.choice_with(Ev, mirror(l), Web.on{Web.click{a_mirror{True{}}}} <> disabled(Bool.not(Cat.mirrors(folder(l)))), [Web.text{"On"}])]),
         pick_text(Cat.mirrors(folder(l)), "On: left and right trade places.", "A clip made by code cannot be mirrored."))]

def clip_toggles(+names: List<&2, String>, +n: U32, +shown: U32) -> List<&2, Web.HTML<Ev>>:
  match names:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Ui.toggle(Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "editor-panels__item", h, U32.is_eq(n, shown), a_show{n}) <> clip_toggles(t, (n + 1 : U32), shown)

def details_body(has: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match has:
    case False{}:
      [Ui.says(Ev, "p", "meta", "No character selected.")]
    case True{}:
      [section("Clip", still(st), clip_facts(picked(lib(st)), lib(st))),
       section("Animation", still(st), [
         Ui.says(Ev, "span", "field__label", "Clips"),
         Ui.box(Ev, "div", "editor-anim__list", [], clip_toggles("Locomotion" <> Fig.clip_names(figure(st)), 0, Fig.shown(figure(st)))),
         help("Locomotion is the idle and the walk, mixed by speed. A clip shows alone, over the whole body.")])]

def details_panel(+st: St) -> Web.HTML<Ev>:
  Ui.panel_as(Ev, "section", "editor-panels__details", [Web.attr{"aria-labelledby", "editor-anim-details"}], [
    Ui.panel_header(Ev, [
      Web.node{"span", [Web.attr{"id", "editor-anim-details"}], [Web.text{"Details"}]},
      Ui.says(Ev, "span", "meta", pick_text(has_character(st), Fig.shown_name(figure(st)), ""))]),
    Ui.panel_body_with(Ev, "editor-panels__body", [], details_body(has_character(st), st))])

# ---------- The Shaders screen ----------
# The same places as the Animation screen, for the material of the thing
# selected: on the left the Shader Library (this project's shader files,
# and the thing's own graph), a click applies one; on the right the
# shader's facts, its parameters as controls, and what is wrong with the
# files that could not be used.

def shade_catalog(h: Shade) -> A.Catalog:
  Shade{c, _} = h
  c

def shade_graphs(h: Shade) -> S.Scene:
  Shade{_, g} = h
  g

def catalog(+st: St) -> A.Catalog:
  shade_catalog(shade(st))

def graphs(+st: St) -> S.Scene:
  shade_graphs(shade(st))

def is_graph(m: Mat.Material) -> Bool:
  match m:
    case Mat.Material{_, _}:
      True{}
    case Mat.Imported{_, _}:
      False{}

# Is this a drawn thing whose material is a graph?
def thing_graph(+t: S.Thing) -> Bool:
  (S.is_shown(t) && is_graph(S.material(S.look(t))))

# Is a thing with a material selected? The screen works on it.
def has_material(+st: St) -> Bool:
  (in_scene(st) && S.is_shown(S.at(scene(st), selected(st))))

def material(+st: St) -> Mat.Material:
  S.material(S.look(S.at(scene(st), selected(st))))

# The thing as it was when its material was last a graph.
def original(+st: St) -> S.Thing:
  S.at(graphs(st), selected(st))

def has_original(+st: St) -> Bool:
  (U32.is_lt(selected(st), U32.from_nat(S.count(graphs(st)))) && thing_graph(original(st)))

# The shader of the selected thing's material: an asset's id, or "" for a
# graph or for no material at all. (editor/app.js asks, to know when the
# drawing code must take another shader.)
def shader_of(+st: St) -> String:
  pick_text(has_material(st), Mat.shader_id(material(st)), "")

def params(+st: St) -> List<&2, A.Param>:
  A.params_of(A.assets(catalog(st)), shader_of(st))

def pick_thing(c: Bool, a: S.Thing, b: S.Thing) -> S.Thing:
  match c:
    case True{}:
      a
    case False{}:
      b

# Each thing of `nows` when its material is a graph, the thing of `olds`
# in its place otherwise.
def keep_go(nows: List<&2, S.Thing>, olds: List<&2, S.Thing>) -> List<&2, S.Thing>:
  match nows:
    case Nil{}:
      Nil{}
    case +n <> nt:
      match olds:
        case Nil{}:
          n <> keep_go(nt, Nil{})
        case o <> ot:
          pick_thing(thing_graph(n), n, o) <> keep_go(nt, ot)

# The state with every graph material of the scene remembered.
def remembered(+st: St) -> St:
  with_shade(st, Shade{catalog(st), S.Scene{keep_go(S.things(scene(st)), S.things(graphs(st)))}})

# ----- The library (left)
# One folder: the shader presets of the project, the shaders its author
# made (projects/<name>/shaders/), each under the name its settings give
# it. "Original graph" is the thing's own material, when it had one.

def presets_name() -> String: "Shader Presets"
def presets_credit() -> String: "Pedro Vinicius"

def warning_tag(broken: Bool) -> List<&2, Web.HTML<Ev>>:
  match broken:
    case True{}:
      [Ui.box(Ev, "span", "tag tag--warning", [], [Ui.icon_with(Ev, [Ui.icon_sm{}], "", [], "triangle-alert"), Web.text{"warning"}])]
    case False{}:
      Nil{}

# One preset: its name and its file. The one applied is pressed; one with
# a warning cannot be chosen.
def shader_row(+id: String, +name: String, +note: String, +applied: Bool, +broken: Bool) -> Web.HTML<Ev>:
  Ui.button_with(Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "editor-anim__clip", Web.attr{"type", "button"} <> Web.attr{"aria-pressed", Ui.bool_text(applied)} <> Web.on{Web.click{s_apply{id}}} <> disabled(broken),
    Ui.box(Ev, "span", "editor-anim__clip-text", [], [
      Ui.says(Ev, "span", "item-title", name),
      Ui.says(Ev, "span", "detail", note)]) <> warning_tag(broken))

def asset_rows(xs: List<&2, A.Asset>, +st: St) -> List<&2, Web.HTML<Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      shader_row(A.id(h), A.label(h), A.id(h), String.eq(A.id(h), shader_of(st)), A.has_problem(A.problems(catalog(st)), A.id(h))) <> asset_rows(t, st)

def is_asset(xs: List<&2, A.Asset>, +want: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (String.eq(A.id(h), want) || is_asset(t, want))

# A preset whose file could not be used: listed by its name, not to be chosen.
def problem_row_if(show: Bool, +p: A.Problem) -> List<&2, Web.HTML<Ev>>:
  match show:
    case True{}:
      [shader_row(A.path(p), A.problem_label(p), A.path(p), False{}, True{})]
    case False{}:
      Nil{}

def problem_rows(ps: List<&2, A.Problem>, +st: St) -> List<&2, Web.HTML<Ev>>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.append(&2, Web.HTML<Ev>, problem_row_if(Bool.not(is_asset(A.assets(catalog(st)), A.path(h))), h), problem_rows(t, st))

def graph_rows(has: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match has:
    case True{}:
      [shader_row("", "Original graph", "", String.eq(shader_of(st), ""), False{})]
    case False{}:
      Nil{}

def preset_rows(+st: St) -> List<&2, Web.HTML<Ev>>:
  List.append(&2, Web.HTML<Ev>, graph_rows(has_original(st), st), List.append(&2, Web.HTML<Ev>, asset_rows(A.assets(catalog(st)), st), problem_rows(A.problems(catalog(st)), st)))

def presets_folder(+st: St) -> Web.HTML<Ev>:
  Ui.disclosure_with(Ev, "editor-anim__folder", [Web.attr{"open", ""}], chevron(D.reduce_motion(still(st))), [
    Ui.icon(Ev, "folder"),
    Ui.box(Ev, "span", "editor-anim__folder-text", [], [
      Ui.says(Ev, "span", "item-title", presets_name()),
      Ui.says(Ev, "span", "detail", presets_credit())])],
    [Ui.box(Ev, "div", "editor-anim__list", [], preset_rows(st))])

def any_shown(xs: List<&2, S.Thing>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (S.is_shown(h) || any_shown(t))

# Does the project have presets to list?
def has_presets(+st: St) -> Bool:
  Bool.not((List.is_empty(&2, A.Asset, A.assets(catalog(st))) && List.is_empty(&2, A.Problem, A.problems(catalog(st)))))

# What the library says when it has nothing to offer: only what is true of
# this scene and this project.
def nothing_to_do(+st: St) -> String:
  pick_text(Bool.not(any_shown(S.things(scene(st)))), "Nothing in this scene has a material.",
  pick_text(Bool.not(has_presets(st)), "This project has no shader presets.",
  "Select a thing with a material in the scene's list."))

def shader_library_body(ready: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match ready:
    case False{}:
      [help(nothing_to_do(st))]
    case True{}:
      [Ui.box(Ev, "div", "editor-anim__folders", [], [presets_folder(st)])]

def shader_library(+st: St) -> Web.HTML<Ev>:
  Ui.panel_as(Ev, "section", "editor-anim__panel", [Web.attr{"aria-labelledby", "editor-shaders-title"}], [
    Ui.panel_header(Ev, [Web.node{"span", [Web.attr{"id", "editor-shaders-title"}], [Web.text{"Shader Library"}]}]),
    Ui.panel_body_with(Ev, "editor-anim__body", [], shader_library_body((has_material(st) && has_presets(st)), st))])

# ----- The details (right)

# A color's channel goes from 0 to 1, in hundredths; any other number is free.
def unit_range(rgb: Bool) -> List<&2, Web.Attr<Ev>>:
  match rgb:
    case True{}:
      [Web.attr{"step", "0.01"}, Web.attr{"min", "0"}, Web.attr{"max", "1"}]
    case False{}:
      [Web.attr{"step", "any"}]

def number_field(+label: String, +id: String, +value: F32, +name: String, +k: U32, rgb: Bool) -> Web.HTML<Ev>:
  Ui.field_with(Ev, "editor-panels__field", [Web.attr{"for", id}], [
    Ui.field_label(Ev, label),
    Ui.input_with(Ev, [Ui.input_sm{}], "", List.append(&2, Web.Attr<Ev>, [
      Web.attr{"id", id}, Web.attr{"type", "number"}, Web.attr{"value", F32.show(value)}, Web.attr{"aria-label", label},
      Web.on{Web.input{s_number{name, k, ""}}}, Web.on{Web.change{a_left{}}}], unit_range(rgb)))])

def nth(xs: List<&2, F32>, +k: U32) -> F32:
  match xs:
    case Nil{}:
      0.0
    case h <> t:
      match k:
        case 0:
          h
        case _:
          nth(t, (k - 1 : U32))

def on_text(on: Bool) -> String:
  match on:
    case True{}:
      "On"
    case False{}:
      "Off"

def other(on: Bool) -> F32:
  match on:
    case True{}:
      0.0
    case False{}:
      1.0

def choice_items(cs: List<&2, A.Choice>, +name: String, +now: F32) -> List<&2, Web.HTML<Ev>>:
  match cs:
    case Nil{}:
      Nil{}
    case h <> t:
      A.Choice{+l, +v} = h
      Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"type", "button"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", Ui.bool_text(F32.is_eq(v, now))}, Web.on{Web.click{s_set{name, v}}}], [
        Web.node{"span", [], [Web.text{l}]}, Ui.icon_with(Ev, [Ui.icon_sm{}], "menu__check", [], "check")]} <> choice_items(t, name, now)

# The control of one parameter, by its kind.
def control_field(c: A.Control, +name: String, +label: String, +v: List<&2, F32>, +id: String) -> Web.HTML<Ev>:
  match c:
    case A.AsNumber{}:
      number_field(label, id, nth(v, 0), name, 0, False{})
    case A.AsColor{}:
      Ui.box(Ev, "fieldset", "form__section editor-material__group", [], [
        Ui.says(Ev, "legend", "field__label", label),
        Ui.box(Ev, "div", "editor-panels__fields", [], [
          number_field("R", id ++ "-r", nth(v, 0), name, 0, True{}),
          number_field("G", id ++ "-g", nth(v, 1), name, 1, True{}),
          number_field("B", id ++ "-b", nth(v, 2), name, 2, True{})])])
    case A.AsToggle{}:
      Ui.box(Ev, "div", "field editor-material__field", [], [
        Ui.says(Ev, "span", "field__label", label),
        Ui.button_with(Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}, Ui.btn_toggle{}, Ui.btn_sm{}], "editor-material__toggle", [Web.attr{"type", "button"}, Web.attr{"aria-label", label}, Web.attr{"aria-pressed", Ui.bool_text(F32.is_eq(nth(v, 0), 1.0))}, Web.on{Web.click{s_set{name, other(F32.is_eq(nth(v, 0), 1.0))}}}], [Web.text{on_text(F32.is_eq(nth(v, 0), 1.0))}])])
    case A.AsSlider{lo, hi, step}:
      Ui.box(Ev, "label", "field editor-material__field", [], [
        Ui.says(Ev, "span", "field__label", label),
        Ui.box(Ev, "span", "editor-material__slider", [], [
          Web.node{"input", [Web.attr{"class", "editor-material__range"}, Web.attr{"id", id}, Web.attr{"type", "range"}, Web.attr{"aria-label", label}, Web.attr{"min", F32.show(lo)}, Web.attr{"max", F32.show(hi)}, Web.attr{"step", F32.show(step)}, Web.prop{"value", F32.show(nth(v, 0))}, Web.on{Web.input{s_number{name, 0, ""}}}], []},
          Ui.says(Ev, "output", "meta mono", F32.show(nth(v, 0)))])])
    case A.AsDropdown{+cs}:
      Ui.box(Ev, "div", "field editor-material__field", [], [
        Ui.says(Ev, "span", "field__label", label),
        Ui.box(Ev, "div", "editor-material__dropdown", [], [
          Ui.dropdown(Ev,
            Ui.trigger_with(Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}, Ui.btn_sm{}], "", [Web.attr{"type", "button"}, Web.attr{"aria-label", label ++ ": " ++ A.choice_label(cs, nth(v, 0))}], [
              Web.node{"span", [], [Web.text{A.choice_label(cs, nth(v, 0))}]}, Ui.icon_with(Ev, [Ui.icon_sm{}], "", [], "chevron-down")]),
            Ui.menu_with(Ev, [Ui.menu_end{}], "", [Web.attr{"role", "menu"}, Web.attr{"aria-label", label}], choice_items(cs, name, nth(v, 0))))])])

def param_fields(ps: List<&2, A.Param>, +vs: List<&2, Mat.Value>) -> List<&2, Web.HTML<Ev>>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> t:
      control_field(A.control(h), A.param_name(h), A.param_label(h), A.value(h, vs), "editor-shaders-" ++ A.param_name(h)) <> param_fields(t, vs)

# A graph's values: a number, or R G B for three.
def graph_value_fields(xs: List<&2, F32>, +name: String, +k: U32, +three: Bool) -> List<&2, Web.HTML<Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      Ui.field_with(Ev, "editor-panels__field", [], [
        Ui.field_label(Ev, O.label_for(three, name, k)),
        Ui.input_with(Ev, [Ui.input_sm{}], "", [Web.attr{"type", "number"}, Web.attr{"step", "0.01"}, Web.attr{"value", Num.fixed(h, 2)}, Web.attr{"aria-label", O.label_for(three, name, k)}, Web.on{Web.input{s_graph{name, k, ""}}}, Web.on{Web.change{a_left{}}}])]) <> graph_value_fields(t, name, (k + 1 : U32), three)

def graph_values(vs: List<&2, Mat.Value>) -> List<&2, Web.HTML<Ev>>:
  match vs:
    case Nil{}:
      Nil{}
    case h <> t:
      Mat.Value{+name, +xs} = h
      Ui.box(Ev, "fieldset", "form__section editor-material__group", [], [
        Ui.says(Ev, "legend", "field__label", name),
        Ui.box(Ev, "div", "editor-panels__fields", [], graph_value_fields(xs, name, 0, Nat.is_eq(List.length(&2, F32, xs), 3n)))]) <> graph_values(t)

def problem_items(ps: List<&2, A.Problem>) -> List<&2, Web.HTML<Ev>>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> t:
      Web.node{"li", [], [Ui.says(Ev, "span", "field__label", A.problem_label(h)), Ui.says(Ev, "p", "meta", A.message(h))]} <> problem_items(t)

# What is wrong with the shader files, when something is.
def warnings(none: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match none:
    case True{}:
      Nil{}
    case False{}:
      [Ui.box(Ev, "div", "editor-material__warnings", [Web.attr{"role", "status"}], [
        section("Shader warnings (" ++ Nat.show(List.length(&2, A.Problem, A.problems(catalog(st)))) ++ ")", still(st), [
          Web.node{"ul", [Web.attr{"class", "editor-material__diagnostics"}], problem_items(A.problems(catalog(st)))}])])]

# The preset applied, as its own settings describe it. The original graph
# has no settings to show.
def shader_facts(graph: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match graph:
    case True{}:
      Nil{}
    case False{}:
      +a = A.asset_of(A.assets(catalog(st)), shader_of(st))
      [section("Shader", still(st), [fact("Name", A.label(a)), fact("File", A.id(a)), fact("Language", A.language(a))])]

def material_controls(graph: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match graph:
    case True{}:
      graph_values(Mat.values(material(st)))
    case False{}:
      param_fields(params(st), Mat.values(material(st)))

def shader_details_body(has: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match has:
    case False{}:
      List.append(&2, Web.HTML<Ev>, [Ui.says(Ev, "p", "meta", nothing_to_do(st))], warnings(List.is_empty(&2, A.Problem, A.problems(catalog(st))), st))
    case True{}:
      List.append(&2, Web.HTML<Ev>, shader_facts(String.eq(shader_of(st), ""), st), List.append(&2, Web.HTML<Ev>,
        [section("Material", still(st), material_controls(String.eq(shader_of(st), ""), st))],
        warnings(List.is_empty(&2, A.Problem, A.problems(catalog(st))), st)))

def shader_name(+st: St) -> String:
  pick_text(String.eq(shader_of(st), ""), "Original graph", A.label(A.asset_of(A.assets(catalog(st)), shader_of(st))))

def shader_details(+st: St) -> Web.HTML<Ev>:
  Ui.panel_as(Ev, "section", "editor-panels__details", [Web.attr{"aria-labelledby", "editor-shaders-details"}], [
    Ui.panel_header(Ev, [
      Web.node{"span", [Web.attr{"id", "editor-shaders-details"}], [Web.text{"Details"}]},
      Ui.says(Ev, "span", "meta", pick_text(has_material(st), shader_name(st), ""))]),
    Ui.panel_body_with(Ev, "editor-panels__body", [], shader_details_body(has_material(st), st))])

# ----- What the Shaders screen's clicks mean

def pick_material(c: Bool, a: Mat.Material, b: Mat.Material) -> Mat.Material:
  match c:
    case True{}:
      a
    case False{}:
      b

def rematerial(go: Bool, +st: St, m: Mat.Material) -> St:
  match go:
    case True{}:
      with_scene(st, S.with_material(scene(st), selected(st), m))
    case False{}:
      st

def pick_bool(c: Bool, a: Bool, b: Bool) -> Bool:
  match c:
    case True{}:
      a
    case False{}:
      b

# May this shader be applied now? Not the one already applied, not one
# with a problem; the original graph only when there is one to go back to.
def may_apply(+st: St, +id: String) -> Bool:
  (has_material(st) && Bool.not(String.eq(shader_of(st), id)) && pick_bool(String.eq(id, ""), has_original(st), Bool.not(A.has_problem(A.problems(catalog(st)), id))))

# A shader applied to the selected thing: its material becomes that asset
# with its defaults, or the graph it had.
def applied(+st: St, +id: String) -> St:
  rematerial(may_apply(st, id), st, pick_material(String.eq(id, ""), S.material(S.look(original(st))), Mat.imported(id)))

def numbered(+st: St, +name: String, +k: U32, got: Maybe<&2, F32>) -> St:
  match got:
    case Some{x}:
      rematerial(has_material(st), st, A.edit(material(st), params(st), name, A.set_at(A.value_named(params(st), Mat.values(material(st)), name), k, x)))
    case None{}:
      st

def graphed(+st: St, +name: String, +k: U32, got: Maybe<&2, F32>) -> St:
  match got:
    case Some{x}:
      with_scene(st, O.apply(scene(st), selected(st), O.Val{name, k}, x))
    case None{}:
      st

# The drawing code could not use a shader (it did not link): the state as
# it was before, with the problem written down, so the shader cannot be
# chosen again. (editor/app.js calls this with the state before the click.)
def failed(+before: St, +id: String, +message: String) -> St:
  with_shade(before, Shade{A.with_problem(catalog(before), id, message), graphs(before)})

# ---------- The screens in their places ----------

def shader_showing(has: Bool, +st: St) -> List<&2, Web.HTML<Ev>>:
  match has:
    case False{}:
      Nil{}
    case True{}:
      [Ui.says(Ev, "span", "tag", S.name(S.at(scene(st), selected(st)))), Ui.says(Ev, "span", "tag tag--mono", shader_name(st))]

def showing_of(+n: U32, +st: St) -> List<&2, Web.HTML<Ev>>:
  match n:
    case 1:
      showing_kids(has_character(st), st)
    case 2:
      shader_showing(has_material(st), st)
    case _:
      Nil{}

def showing(+st: St) -> Web.HTML<Ev>:
  Web.node{"div", Web.attr{"class", "editor-showing"} <> hidden(U32.is_eq(tab(st), 0)), showing_of(tab(st), st)}

# Each screen has the same places: a library on the left, what shows over
# the viewport, the scene's list and the Details on the right. A new
# screen is a new tab and its own library and details.
def library_of(+n: U32, +st: St) -> List<&2, Web.HTML<Ev>>:
  match n:
    case 1:
      [animation_library(st)]
    case 2:
      [shader_library(st)]
    case _:
      Nil{}

def library(+st: St) -> Web.HTML<Ev>:
  Web.node{"aside", Web.attr{"class", "editor-panels editor-library"} <> Web.attr{"aria-label", "Library"} <> hidden(U32.is_eq(tab(st), 0)), library_of(tab(st), st)}

def details_of(+n: U32, +st: St) -> List<&2, Web.HTML<Ev>>:
  match n:
    case 1:
      [scene_panel(st), details_panel(st)]
    case 2:
      [scene_panel(st), shader_details(st)]
    case _:
      Nil{}

def details(+st: St) -> Web.HTML<Ev>:
  Web.node{"aside", Web.attr{"class", "editor-panels editor-clip"} <> Web.attr{"aria-label", "Scene and Details"} <> hidden(U32.is_eq(tab(st), 0)), details_of(tab(st), st)}

# The scene and the selection as the Scene tab left them (editor/app.js).
def follow(+st: St, +s: S.Scene, +i: U32) -> St:
  remembered(follow_to(st, s, i))

# ---------- The page ----------

# The screen's styles, with Bend-UI's tokens. The body becomes a grid of
# three columns (library, window, details) and three rows (tabs, window,
# transport); the editor's window, which is already on the page, takes
# the middle, and its Scene and Details panels step aside while the
# Animation tab is open.
def styles() -> String:
  "body[data-screen] { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; grid-template-rows: auto minmax(0, 1fr) auto; }" ++
  "body[data-screen] > .window { grid-column: 2; grid-row: 2; min-width: 0; min-height: 0; }" ++
  "body[data-screen='animation'] #editor-panels, body[data-screen='shaders'] #editor-panels { display: none; }" ++
  ".editor-material__field, .editor-material__group { padding: var(--space-1) var(--space-2); min-width: 0; }" ++
  ".editor-material__group { border: 0; margin: 0; }" ++
  ".editor-material__group .input { padding: 0 var(--space-1); }" ++
  ".editor-material__dropdown, .editor-material__dropdown > .dropdown, .editor-material__dropdown > .dropdown > .btn { width: 100%; }" ++
  ".editor-material__dropdown > .dropdown > .btn { justify-content: space-between; }" ++
  ".editor-material__toggle { align-self: flex-start; }" ++
  ".editor-material__slider { display: flex; align-items: center; gap: var(--space-2); min-height: var(--control-sm); }" ++
  ".editor-material__range { flex: 1; min-width: 0; margin: 0; accent-color: var(--accent); }" ++
  ".editor-material__diagnostics { margin: 0; padding: var(--space-1) var(--space-2) var(--space-1) var(--space-5); overflow-wrap: anywhere; }" ++
  ".editor-material__diagnostics p { white-space: pre-wrap; margin: var(--space-1) 0 var(--space-2); }" ++
  ".editor-tabs { grid-column: 2; grid-row: 1; }" ++
  ".editor-library { grid-column: 1; grid-row: 1 / 4; border-left: 0; border-right: var(--border-width) solid var(--border); }" ++
  ".editor-clip { grid-column: 3; grid-row: 1 / 4; }" ++
  ".editor-showing { grid-column: 2; grid-row: 2; align-self: start; justify-self: start; margin: var(--space-4); z-index: var(--layer-foot); pointer-events: none; display: flex; flex-wrap: wrap; gap: var(--space-1); }" ++
  ".editor-transport { grid-column: 2; grid-row: 3; border-bottom: 0; border-top: var(--border-width) solid var(--border); gap: var(--space-2); padding: var(--space-2) var(--space-3); flex-wrap: wrap; }" ++
  ".editor-transport__time { flex: 1; min-width: var(--space-8); accent-color: var(--accent); }" ++
  ".editor-transport__read { font-family: var(--font-mono); font-size: var(--text-sm); color: var(--text-2); font-variant-numeric: tabular-nums; }" ++
  ".editor-transport__motion { display: flex; align-items: center; gap: var(--space-2); font-size: var(--text-sm); color: var(--text-2); }" ++
  ".editor-anim__panel { flex: 1; display: flex; flex-direction: column; min-height: 0; }" ++
  ".editor-anim__body { overflow: auto; min-height: 0; padding: var(--space-2); display: flex; flex-direction: column; gap: var(--space-2); }" ++
  ".editor-anim__categories > .segmented { display: flex; flex-wrap: wrap; border-radius: var(--radius-lg); }" ++
  ".editor-anim__categories > .segmented > button { flex: 1 0 auto; padding: 0 var(--space-2); }" ++
  ".editor-anim__foot { flex: none; display: flex; flex-direction: column; padding: var(--space-2); border-top: var(--border-width) solid var(--border); }" ++
  ".editor-anim__folders, .editor-anim__list { display: flex; flex-direction: column; gap: var(--space-1); }" ++
  ".editor-anim__folder > summary .icon:not(.disclosure__chevron) { flex: none; color: var(--text-2); }" ++
  ".editor-anim__folder-text { flex: 1; min-width: 0; display: flex; flex-direction: column; }" ++
  ".editor-anim__clip { height: auto; width: 100%; justify-content: flex-start; text-align: left; gap: var(--space-2); padding: var(--space-1) var(--space-2) var(--space-1) var(--space-1); border-radius: var(--radius-lg); }" ++
  ".editor-anim__clip-text { flex: 1; min-width: 0; display: flex; flex-direction: column; }" ++
  ".editor-anim__picture { width: var(--control-lg); height: var(--control-lg); flex: none; border-radius: var(--radius-md); background: var(--bg); border: var(--border-width) solid var(--border); stroke: var(--text-2); stroke-width: var(--space-hairline); stroke-linecap: round; fill: none; }" ++
  ".editor-anim__picture circle { fill: var(--text-2); stroke: none; }" ++
  ".editor-anim__fact { display: flex; align-items: baseline; justify-content: space-between; gap: var(--space-4); }" ++
  ".editor-anim__fact > .detail { text-align: right; min-width: 0; }" ++
  ".editor-anim__stack { display: flex; flex-direction: column; gap: var(--space-2); padding: var(--space-1) var(--space-2); }" ++
  ".editor-anim__help { margin: 0; font-size: var(--text-sm); line-height: var(--leading-ui); color: var(--text-detail); }" ++
  ".editor-anim__wide { display: flex; }" ++
  ".editor-anim__wide > button { flex: 1; padding: 0 var(--space-2); }" ++
  ".editor-anim__wide > button:disabled { opacity: var(--disabled-opacity); cursor: default; }"

def screen_name(+n: U32) -> String:
  match n:
    case 0:
      "scene"
    case 1:
      "animation"
    case _:
      "shaders"

# The screen, as children of the page's body, beside the editor's window.
def render(+st: St) -> Web.HTML<Ev>:
  Web.node{"body", [Web.attr{"data-screen", screen_name(tab(st))}], [
    Web.node{"style", [], [Web.text{styles()}]},
    tabs(st), library(st), showing(st), transport(st), details(st)]}

# Is the screen showing a time that moves by itself now? Then every frame
# is drawn (editor/app.js asks before drawing the screen again).
def draws_frames(+st: St) -> Bool:
  (is_open(st) && has_character(st))

# ---------- What clicks and keystrokes mean ----------

# A keystroke or a move of the bar carries its text: the message comes back holding it.
def on_input(+msg: Ev, +got: Web.Input) -> Ev:
  match msg got:
    case a_typed{_} Web.typed{v}:
      a_typed{v}
    case a_scrub{_} Web.typed{v}:
      a_scrub{v}
    case s_number{n, k, _} Web.typed{v}:
      s_number{n, k, v}
    case s_graph{n, k, _} Web.typed{v}:
      s_graph{n, k, v}
    case _ _:
      msg

def with_query(+l: Lib, +q: String) -> Lib:
  match l:
    case Lib{_, c, f, k, p, m}:
      Lib{q, c, f, k, p, m}

def with_category(+l: Lib, +c: String) -> Lib:
  match l:
    case Lib{q, _, f, k, p, m}:
      Lib{q, c, f, k, p, m}

def with_pick(+l: Lib, +f: U32, +k: U32) -> Lib:
  match l:
    case Lib{q, c, _, _, _, m}:
      Lib{q, c, f, k, True{}, m}

def unpicked(+l: Lib) -> Lib:
  match l:
    case Lib{q, c, f, k, _, m}:
      Lib{q, c, f, k, False{}, m}

def with_mirror(+l: Lib, +m: Bool) -> Lib:
  match l:
    case Lib{q, c, f, k, p, _}:
      Lib{q, c, f, k, p, m}

# The picked clip, made for the character and tried on it.
def tried(go: Bool, +st: St) -> St:
  match go:
    case True{}:
      +l = lib(st)
      +f = figure(st)
      refigure(st, Fig.try(f, Cat.clip(Fig.skeleton(f), folder(l), place(l), (mirror(l) && Cat.mirrors(folder(l))))))
    case False{}:
      st

def seeked(+st: St, got: Maybe<&2, F32>) -> St:
  match got:
    case Some{t}:
      on_character(has_character(st), st, Fig.seek(figure(st), t))
    case None{}:
      st

def opened(+st: St, +n: U32) -> St:
  match st:
    case Screen{s, i, b, _, l, h}:
      Screen{s, i, b, n, l, h}

def stilled(+st: St, +b: Bool) -> St:
  match st:
    case Screen{s, i, _, o, l, h}:
      Screen{s, i, b, o, l, h}

def chosen(+st: St, +i: U32) -> St:
  match st:
    case Screen{s, _, b, o, l, h}:
      Screen{s, i, b, o, unpicked(l), h}

def step(+ev: Ev, +st: St) -> St:
  match ev:
    case a_tab{n}:
      opened(st, n)
    case a_typed{text}:
      with_lib(st, with_query(lib(st), text))
    case a_left{}:
      st
    case a_category{name}:
      with_lib(st, with_category(lib(st), name))
    case a_pick{f, k}:
      tried(has_character(st), with_lib(st, with_pick(lib(st), f, k)))
    case a_mirror{m}:
      tried((has_character(st) && picked(lib(st))), with_lib(st, with_mirror(lib(st), m)))
    case a_keep{}:
      on_character((has_character(st) && Fig.shows_trial(figure(st))), st, Fig.keep(figure(st)))
    case a_drop{}:
      with_lib(on_character((has_character(st) && Bool.not(Fig.shows_trial(figure(st)))), st, Fig.remove_shown(figure(st))), unpicked(lib(st)))
    case a_show{n}:
      with_lib(on_character(has_character(st), st, Fig.show(figure(st), n)), unpicked(lib(st)))
    case a_play{on}:
      on_character(has_character(st), st, Fig.set_on(figure(st), on))
    case a_step{ahead}:
      on_character(has_character(st), st, Fig.step_frame(Fig.set_on(figure(st), False{}), ahead))
    case a_scrub{text}:
      seeked(st, F32.read(text))
    case a_thing{i}:
      chosen(st, i)
    case a_motion{b}:
      stilled(st, b)
    case s_apply{id}:
      applied(st, id)
    case s_number{name, k, text}:
      numbered(st, name, k, F32.read(text))
    case s_set{name, value}:
      rematerial(has_material(st), st, A.edit(material(st), params(st), name, [value]))
    case s_graph{name, k, text}:
      graphed(st, name, k, F32.read(text))

# The state after an event, with every graph material remembered.
def on_event(+ev: Ev, +st: St) -> Web.Update<St, Ev>:
  Web.update{remembered(step(ev, st)), Web.none{}}
