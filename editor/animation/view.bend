# The Animation window: the clip picked in the Project window, tried on the character selected,
# and the transport that plays it, in the dock (as Unity's Animation window sits under the Scene
# view).
#
# It follows Mixamo's flow: picking a clip in the Project window's Library/Animations tries it on
# the character (engine/anim/figure.bend's trial); the Inspector shows where it comes from, how it
# plays, Root and Mirror, and Add keeps it or Remove takes it off; the transport steps frames, plays
# and seeks. The character's own clips are its Animation component in the Inspector.
#
# Accessibility (ACCESSIBILITY.bend): nothing here moves by itself. A clip plays only after Play
# is pressed, in place, and the transport shows Reduce motion's state.
#
# Limits now:
# - Root shows In place only: the library's clips have no root track, and reading root motion is
#   not built (engine/anim/motion.bend).
# - A clip on the character is a pressed toggle button: Bend-UI has no selectable list yet (a
#   request for Bend-UI).
# - The time bar is the browser's own range input: Bend-UI has no slider (a request for Bend-UI).
# - There is no pause icon in Bend-UI's set: while a clip plays, the Play button is tinted and
#   its name is Stop.
# - A clip's picture is the source rig's stick figure, not the selected character in that pose;
#   code-made clips have none.
# - The library's categories are not a filter any more: the Project window's search finds a clip
#   by its name.
# - While a clip plays with the Animation tab open, the whole page is drawn again every frame, to
#   move the time bar: Web.bend draws a page whole.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene/scene.bend as S
import ../../engine/anim/figure.bend as Fig
import ../../engine/anim/library.bend as L
import ../../library/catalog.bend as Cat
import ../defaults/defaults.bend as D
import ../workspace/number.bend as Num
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P

# ---------- The library (left) ----------

# The clip's picture: a head and a line per bone (engine/anim/library.bend).
def bones_go(+ns: List<&2, F32>) -> List<&2, Web.HTML<W.Ev>>:
  match ns:
    case Con{x1, Con{y1, Con{x2, Con{y2, rest}}}}:
      Web.node{"line", [Web.attr{"x1", Num.fixed(x1, 1)}, Web.attr{"y1", Num.fixed(y1, 1)}, Web.attr{"x2", Num.fixed(x2, 1)}, Web.attr{"y2", Num.fixed(y2, 1)}], []} <> bones_go(rest)
    case _:
      Nil{}

def picture_kids(+ns: List<&2, F32>) -> List<&2, Web.HTML<W.Ev>>:
  match ns:
    case Con{x, Con{y, Con{r, rest}}}:
      Web.node{"circle", [Web.attr{"cx", Num.fixed(x, 1)}, Web.attr{"cy", Num.fixed(y, 1)}, Web.attr{"r", Num.fixed(r, 1)}], []} <> bones_go(rest)
    case _:
      Nil{}

def picture(+ns: List<&2, F32>) -> Web.HTML<W.Ev>:
  Web.node{"svg", [Web.attr{"class", "editor-anim__picture"}, Web.attr{"viewBox", "0 0 40 40"}, Web.attr{"aria-hidden", "true"}], picture_kids(ns)}

# Add keeps the clip being tried; Remove takes off the added clip that shows.
def keep_button(+fig: Fig.Figure, +name: String) -> List<&2, Web.HTML<W.Ev>>:
  P.pick_html(Fig.shows_trial(fig),
    [Ui.box(W.Ev, "div", "editor-anim__foot", [], [Ui.button_with(W.Ev, [Ui.btn_primary{}], "", [Web.on{Web.click{W.a_keep{}}}], [Ui.icon(W.Ev, "plus"), Web.text{"Add to " ++ name}])])],
    P.pick_html(Fig.shows_locomotion(fig), Nil{},
      [Ui.box(W.Ev, "div", "editor-anim__foot", [], [Ui.button_with(W.Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}], "", [Web.on{Web.click{W.a_drop{}}}], [Ui.icon(W.Ev, "x"), Web.text{"Remove from " ++ name}])])]))

# ---------- The transport (under the viewport) ----------

# A choice nobody can press: it shows the state.
def shown_choice(+label: String, on: Bool) -> Web.HTML<W.Ev>:
  Ui.choice_with(W.Ev, on, [Web.attr{"type", "button"}, Web.attr{"tabindex", "-1"}], [Web.text{label}])

# Play; while a clip plays the same button is tinted and stops it.
def play_button(on: Bool) -> Web.HTML<W.Ev>:
  match on:
    case True{}:
      Ui.icon_button(W.Ev, [Ui.btn_tinted{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Stop", "play", W.a_play{False{}})
    case False{}:
      Ui.icon_button(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Play", "play", W.a_play{True{}})

def three(+n: U32) -> String:
  P.pick_text(U32.is_lt(n, 10), "00", P.pick_text(U32.is_lt(n, 100), "0", "")) ++ U32.show(n)

def transport_kids(has: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match has:
    case False{}:
      Nil{}
    case True{}:
      +f = W.figure(st)
      [Ui.icon_button(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Previous frame", "chevron-left", W.a_step{False{}}),
       play_button(Fig.is_on(f)),
       Ui.icon_button(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Next frame", "chevron-right", W.a_step{True{}}),
       Web.node{"input", [Web.attr{"class", "editor-transport__time"}, Web.attr{"id", "editor-transport-time"}, Web.attr{"type", "range"}, Web.attr{"min", "0"}, Web.attr{"max", Num.fixed(Fig.length(f), 4)}, Web.attr{"step", Num.fixed(Fig.frame(), 4)}, Web.prop{"value", Num.fixed(Fig.param(f, "time"), 4)}, Web.attr{"aria-label", "Time, in seconds"}, Web.on{Web.input{W.a_scrub{""}}}], []},
       Ui.says(W.Ev, "span", "editor-transport__read", Num.fixed(Fig.param(f, "time"), 2) ++ " s · f " ++ three(Fig.frame_now(f))),
       Ui.box(W.Ev, "span", "toolbar__sep", [], []),
       Ui.box(W.Ev, "span", "editor-transport__motion", [], [
         Web.node{"span", [Web.attr{"id", "editor-transport-motion"}], [Web.text{"Reduce motion"}]},
         Ui.segmented_with(W.Ev, [], "editor-defaults__readonly", [Web.attr{"role", "group"}, Web.attr{"aria-labelledby", "editor-transport-motion"}], [
           shown_choice("Off", Bool.not(D.reduce_motion(W.still(st)))),
           shown_choice("On", D.reduce_motion(W.still(st)))])])]

def transport_or_help(has: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match has:
    case True{}:
      [Web.node{"div", [Web.attr{"class", "editor-dock__bar editor-transport"}], transport_kids(True{}, st)},
       Ui.box(W.Ev, "div", "editor-dock__scroll", [], [P.help(P.pick_text(Fig.shows_locomotion(W.figure(st)), "Pick a clip in the Project window (Library/Animations) to try it on " ++ W.character_name(st) ++ ".", "Showing " ++ Fig.shown_name(W.figure(st)) ++ " on " ++ W.character_name(st) ++ ". Add or Remove it in the Inspector."))])]
    case False{}:
      [Ui.box(W.Ev, "div", "editor-dock__scroll", [], [P.help("Select a character in the Hierarchy: its clips play here.")])]

# The dock's Animation tab.
def view(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  transport_or_help(W.has_character(st), st)

# ---------- What shows (over the viewport) ----------

def showing_kids(has: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match has:
    case False{}:
      Nil{}
    case True{}:
      [Ui.says(W.Ev, "span", "tag", W.character_name(st)),
       Ui.says(W.Ev, "span", "tag tag--mono", Fig.shown_name(W.figure(st))),
       Ui.says(W.Ev, "span", "tag", "in place")]

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

# The clip picked in the library: where it comes from and how it plays.
def clip_facts(has: Bool, +l: W.Lib) -> List<&2, Web.HTML<W.Ev>>:
  match has:
    case False{}:
      [P.help("Pick a clip in the library to try it on the character.")]
    case True{}:
      +c = collection_at(Cat.collections(), W.folder(l))
      +e = entry_at(L.entries(c), W.place(l))
      [P.fact("Name", L.entry_name(e)),
       P.fact("Collection", L.name(c)),
       P.fact("Credit", L.byline(c)),
       P.fact("Category", L.entry_category(e)),
       P.fact("Length", P.seconds_text(L.entry_seconds(e))),
       P.fact("Plays", P.plays_text(L.entry_loops(e))),
       P.labeled("Root", "editor-anim-root",
         Ui.segmented_with(W.Ev, [], "editor-anim__wide", [Web.attr{"role", "group"}, Web.attr{"aria-labelledby", "editor-anim-root"}], [
           Ui.choice_with(W.Ev, True{}, [Web.attr{"type", "button"}], [Web.text{"In place"}]),
           Ui.choice_with(W.Ev, False{}, [Web.attr{"type", "button"}, Web.attr{"disabled", ""}], [Web.text{"Root motion"}])]),
         "The clip stays where it is: code moves the character (engine/anim/locomotion.bend). This clip has no root track, and reading root motion is not built."),
       P.labeled("Mirror", "editor-anim-mirror",
         Ui.segmented_with(W.Ev, [], "editor-anim__wide", [Web.attr{"role", "group"}, Web.attr{"aria-labelledby", "editor-anim-mirror"}], [
           Ui.choice_with(W.Ev, Bool.not(W.mirror(l)), Web.on{Web.click{W.a_mirror{False{}}}} <> P.disabled(Bool.not(Cat.mirrors(W.folder(l)))), [Web.text{"Off"}]),
           Ui.choice_with(W.Ev, W.mirror(l), Web.on{Web.click{W.a_mirror{True{}}}} <> P.disabled(Bool.not(Cat.mirrors(W.folder(l)))), [Web.text{"On"}])]),
         P.pick_text(Cat.mirrors(W.folder(l)), "On: left and right trade places.", "A clip made by code cannot be mirrored."))]

def clip_toggles(+names: List<&2, String>, +n: U32, +shown: U32) -> List<&2, Web.HTML<W.Ev>>:
  match names:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Ui.toggle(W.Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "editor-panels__item", h, U32.is_eq(n, shown), W.a_show{n}) <> clip_toggles(t, (n + 1 : U32), shown)

# The picked clip, made for the character and tried on it.
def tried(go: Bool, +st: W.St) -> W.St:
  match go:
    case True{}:
      +l = W.lib(st)
      +f = W.figure(st)
      W.refigure(st, Fig.try(f, Cat.clip(Fig.skeleton(f), W.folder(l), W.place(l), (W.mirror(l) && Cat.mirrors(W.folder(l))))))
    case False{}:
      st

def seeked(+st: W.St, got: Maybe<&2, F32>) -> W.St:
  match got:
    case Some{t}:
      W.on_character(W.has_character(st), st, Fig.seek(W.figure(st), t))
    case None{}:
      st
