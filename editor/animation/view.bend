# The Animation screen: the editor's own place for the animation library,
# as Unreal's Animation Editor and Unity's Animation window are places of
# their own. It is a tab beside Scene; the viewport is the same one.
#
# The screen follows Mixamo's flow, on the character selected in the scene:
# - left, the Animation Library: search, categories, and the library's
#   folders (library/catalog.bend), one per source, with the name and the
#   credit on the folder. A click on a clip tries it on the character
#   (engine/figure.bend's trial), as Mixamo previews a clip on yours.
#   Add keeps it on the character; Remove takes it off.
# - under the viewport, the transport: a frame back, Play, a frame ahead,
#   the time bar, the time and the frame, and Reduce motion's state.
# - over the viewport, what is showing: the character, the clip, in place.
# - right, the scene's things and the Details of the clip picked (where it
#   comes from, how long, loop or once, Root, Mirror) and of the
#   character's animation (its clips: click one to show it).
#
# The whole screen is this file: one page written in Bend (Bend-UI's
# Web.bend and UI.bend), drawn on the page's body, around the editor's
# window that is already there. Its nodes, its layout and its styles (styles(),
# written with Bend-UI's tokens) all come from here; nothing of it is in
# index.html, in editor.css or in JavaScript. editor/app.js only mounts it
# and hands the scene back and forth, as it does for the Scene and Details
# panels.
#
#   start(scene, still)      the screen, closed, on a scene
#   render(state)            the tabs, and when open the library, the
#                            transport, what shows and the details
#   draws_frames(state)      is it showing a time that moves every frame?
#   on_input(msg, got)       a keystroke in the search, a move of the time bar
#   on_event(event, state)   everything a click means
#
# Accessibility (ACCESSIBILITY.bend): nothing here moves by itself. A clip
# plays only after Play is pressed, in place, and the transport shows
# Reduce motion's state. The time bar and the frame buttons move time by
# hand.
#
# Limits now:
# - Root shows In place only: the library's clips have no root track, and
#   reading root motion is not built (engine/motion.bend).
# - The clip in a folder and the clip on the character are shown as pressed
#   toggle buttons: Bend-UI has no selectable list yet (a request for
#   Bend-UI).
# - The categories take two lines when they do not fit in one: a segmented
#   is one line, and the panel is as wide as the Scene and Details panels.
# - The time bar is the browser's own range input: Bend-UI has no slider
#   (a request for Bend-UI).
# - There is no pause icon in Bend-UI's set: while a clip plays, the Play
#   button is tinted and its name is Stop.
# - A clip's picture is the source rig's stick figure, not the selected
#   character in that pose; code-made clips have none.
# - The preview uses the project's scene and its camera, not a scene of
#   its own.
# - While a clip plays with the screen open, the whole screen is drawn
#   again every frame, to move the time bar: Web.bend draws a page whole.
# - The page is mounted on the body, not on the editor's window: Bend-UI's
#   driver takes another page's root inside its own as one of its nodes,
#   and the Scene and Details panels are such a root (a request for
#   Bend-UI). So the tabs run over the whole width, panels included.
# - The styles are one text in a <style> node, so a wrong token name in
#   them is not caught by Bend-UI's laws.
# - What is added lives while the page is open; nothing is written to the
#   project's files.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene.bend as S
import ../../engine/figure.bend as Fig
import ../../engine/library.bend as L
import ../../library/catalog.bend as Cat
import ../defaults/defaults.bend as D
import ../panels/view.bend as Num

# What the library panel remembers: the search, the category, the clip
# picked (folder and place in it, when `picked`), and Mirror.
type Lib is Data:
  Lib{query: String, category: String, folder: U32, k: U32, picked: Bool, mirror: Bool}

# The screen: the scene, the thing selected, the system asking for less
# motion, whether the Animation tab is open, and the library panel.
type St is Data:
  Screen{scene: S.Scene, selected: U32, still: Bool, open: Bool, lib: Lib}

type Ev is Data:
  a_tab{open: Bool}                  # Scene or Animation
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

def all() -> String: "All"

def start(+scene: S.Scene, +still: Bool) -> Web.Update<St, Ev>:
  Web.update{Screen{scene, 0, still, False{}, Lib{"", all(), 0, 0, False{}, False{}}}, Web.none{}}

# ---------- The state's parts ----------

def scene(+st: St) -> S.Scene:
  match st:
    case Screen{s, _, _, _, _}:
      s

def selected(+st: St) -> U32:
  match st:
    case Screen{_, i, _, _, _}:
      i

def still(+st: St) -> Bool:
  match st:
    case Screen{_, _, b, _, _}:
      b

def is_open(+st: St) -> Bool:
  match st:
    case Screen{_, _, _, o, _}:
      o

def lib(+st: St) -> Lib:
  match st:
    case Screen{_, _, _, _, l}:
      l

def with_scene(+st: St, +s: S.Scene) -> St:
  match st:
    case Screen{_, i, b, o, l}:
      Screen{s, i, b, o, l}

def with_lib(+st: St, +l: Lib) -> St:
  match st:
    case Screen{s, i, b, o, _}:
      Screen{s, i, b, o, l}

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

# The scene and the selection as the Scene tab left them (editor/app.js).
def follow(+st: St, +s: S.Scene, +i: U32) -> St:
  match st:
    case Screen{_, _, b, o, l}:
      Screen{s, i, b, o, l}

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
      Ui.choice(Ev, "Scene", Bool.not(is_open(st)), a_tab{False{}}),
      Ui.choice(Ev, "Animation", is_open(st), a_tab{True{}})])]}

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

def library(+st: St) -> Web.HTML<Ev>:
  Web.node{"aside", Web.attr{"class", "editor-panels editor-library"} <> Web.attr{"aria-label", "Animation Library"} <> hidden(Bool.not(is_open(st))), [
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

def showing(+st: St) -> Web.HTML<Ev>:
  Web.node{"div", Web.attr{"class", "editor-showing"} <> hidden(Bool.not(is_open(st))), showing_kids(has_character(st), st)}

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

def details(+st: St) -> Web.HTML<Ev>:
  Web.node{"aside", Web.attr{"class", "editor-panels editor-clip"} <> Web.attr{"aria-label", "Scene and the clip's Details"} <> hidden(Bool.not(is_open(st))), [scene_panel(st), details_panel(st)]}

# ---------- The page ----------

# The screen's styles, with Bend-UI's tokens. The body becomes a grid of
# three columns (library, window, details) and three rows (tabs, window,
# transport); the editor's window, which is already on the page, takes
# the middle, and its Scene and Details panels step aside while the
# Animation tab is open.
def styles() -> String:
  "body[data-screen] { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; grid-template-rows: auto minmax(0, 1fr) auto; }" ++
  "body[data-screen] > .window { grid-column: 2; grid-row: 2; min-width: 0; min-height: 0; }" ++
  "body[data-screen='animation'] #editor-panels { display: none; }" ++
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

def screen_name(open: Bool) -> String:
  match open:
    case True{}:
      "animation"
    case False{}:
      "scene"

# The screen, as children of the page's body, beside the editor's window.
def render(+st: St) -> Web.HTML<Ev>:
  Web.node{"body", [Web.attr{"data-screen", screen_name(is_open(st))}], [
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

def opened(+st: St, +o: Bool) -> St:
  match st:
    case Screen{s, i, b, _, l}:
      Screen{s, i, b, o, l}

def stilled(+st: St, +b: Bool) -> St:
  match st:
    case Screen{s, i, _, o, l}:
      Screen{s, i, b, o, l}

def chosen(+st: St, +i: U32) -> St:
  match st:
    case Screen{s, _, b, o, l}:
      Screen{s, i, b, o, unpicked(l)}

def on_event(+ev: Ev, +st: St) -> Web.Update<St, Ev>:
  match ev:
    case a_tab{o}:
      Web.update{opened(st, o), Web.none{}}
    case a_typed{text}:
      Web.update{with_lib(st, with_query(lib(st), text)), Web.none{}}
    case a_left{}:
      Web.update{st, Web.none{}}
    case a_category{name}:
      Web.update{with_lib(st, with_category(lib(st), name)), Web.none{}}
    case a_pick{f, k}:
      Web.update{tried(has_character(st), with_lib(st, with_pick(lib(st), f, k))), Web.none{}}
    case a_mirror{m}:
      Web.update{tried((has_character(st) && picked(lib(st))), with_lib(st, with_mirror(lib(st), m))), Web.none{}}
    case a_keep{}:
      Web.update{on_character((has_character(st) && Fig.shows_trial(figure(st))), st, Fig.keep(figure(st))), Web.none{}}
    case a_drop{}:
      Web.update{with_lib(on_character((has_character(st) && Bool.not(Fig.shows_trial(figure(st)))), st, Fig.remove_shown(figure(st))), unpicked(lib(st))), Web.none{}}
    case a_show{n}:
      Web.update{with_lib(on_character(has_character(st), st, Fig.show(figure(st), n)), unpicked(lib(st))), Web.none{}}
    case a_play{on}:
      Web.update{on_character(has_character(st), st, Fig.set_on(figure(st), on)), Web.none{}}
    case a_step{ahead}:
      Web.update{on_character(has_character(st), st, Fig.step_frame(Fig.set_on(figure(st), False{}), ahead)), Web.none{}}
    case a_scrub{text}:
      Web.update{seeked(st, F32.read(text)), Web.none{}}
    case a_thing{i}:
      Web.update{chosen(st, i), Web.none{}}
    case a_motion{b}:
      Web.update{stilled(st, b), Web.none{}}
