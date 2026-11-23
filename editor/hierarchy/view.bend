# The Hierarchy: every thing of the scene, under the scene's name, as Unity's Hierarchy window
# lists a scene's GameObjects under the scene (Unreal: the Outliner). A click selects a thing; the
# arrow keys, Home and End move the selection when the list has the focus (WAI-ARIA's tree, with
# the selection on aria-activedescendant, so the focus stays on the list).
#
# The scene's row ends with "*" when something Save writes changed since the last Save, as
# Unity's scene row does.
#
# Each row has its thing's icon (editor/icons/): the scene a cube, a character a person, a shown
# thing the sphere its material is drawn on, a hidden thing an eye struck through.
#
# The rows are Bend-UI's tree rows (panes.css: .tree, .tree__row, .tree__kids); the selected row
# is aria-selected and drawn as the tree's current row.
#
# Create, in its header, makes a thing (editor/hierarchy/make.bend: Empty, Plane, Character); Delete
# or Backspace on the list deletes the thing selected. Neither works in Play.
#
# Limits now:
# - The scene has no parent and child (engine/scene/scene.bend): every thing is one level under
#   the scene, so nothing folds.
# - No renaming or reordering things from here.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene/scene.bend as S
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P
import ../project/files.bend as F
import ../icons/icons.bend as I
import ../icons/view.bend as Ic
import ../../projects/prefabs.bend as Pre
import ./make.bend as Mk

def row_id(+i: U32) -> String:
  "editor-hierarchy-" ++ U32.show(i)

def row(+t: S.Thing, +i: U32, +n: U32, +sel: U32) -> Web.HTML<W.Ev>:
  Web.node{"div", [Web.attr{"class", "tree__row"}, Web.attr{"role", "treeitem"}, Web.attr{"id", row_id(i)},
    Web.attr{"aria-level", "2"}, Web.attr{"aria-posinset", U32.show((i + 1 : U32))}, Web.attr{"aria-setsize", U32.show(n)},
    Web.attr{"aria-selected", Ui.bool_text(U32.is_eq(i, sel))}, Web.attr{"aria-current", Ui.bool_text(U32.is_eq(i, sel))},
    Web.on{Web.click{W.a_thing{i}}}], [
    Ic.glyph(I.thing_glyph(t), I.thing_color(t)),
    Ui.says(W.Ev, "span", "tree__name", S.name(t))]}

def rows(xs: List<&2, S.Thing>, +i: U32, +n: U32, +sel: U32) -> List<&2, Web.HTML<W.Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      row(h, i, n, sel) <> rows(t, (i + 1 : U32), n, sel)

def star(dirty: Bool) -> String:
  P.pick_text(dirty, "*", "")

# The scene's row and its things' rows. The list holds the focus; the selected row is its active one.
def tree(+st: W.St) -> Web.HTML<W.Ev>:
  +n = U32.from_nat(S.count(W.scene(st)))
  Web.node{"div", [Web.attr{"class", "tree editor-hierarchy__tree"}, Web.attr{"role", "tree"}, Web.attr{"aria-label", "Hierarchy"},
    Web.attr{"tabindex", "0"}, Web.attr{"aria-activedescendant", P.pick_text(W.in_scene(st), row_id(W.selected(st)), "")},
    Web.on{Web.key_down{W.h_key{""}}}], [
    Web.node{"div", [Web.attr{"class", "tree__row editor-hierarchy__scene"}, Web.attr{"role", "treeitem"}, Web.attr{"aria-level", "1"}, Web.attr{"aria-expanded", "true"}], [
      Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "chevron-down"),
      Ic.glyph(I.scene_glyph(), I.color(F.Sort.Scene{})),
      Ui.says(W.Ev, "span", "tree__name", W.scene_name(W.cut(st)) ++ star(W.dirty(st)))]},
    Web.node{"div", [Web.attr{"class", "tree__kids"}, Web.attr{"role", "group"}], rows(S.things(W.scene(st)), 0, n, W.selected(st))}]}

def body(empty: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match empty:
    case True{}:
      [P.help("The scene is empty.")]
    case False{}:
      [tree(st)]

def make_items(ks: List<&2, Pre.Prefab>, +n: U32) -> List<&2, Web.HTML<W.Ev>>:
  match ks:
    case Nil{}:
      Nil{}
    case +h <> t:
      Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"type", "button"}, Web.attr{"role", "menuitem"}, Web.on{Web.click{W.h_make{n}}}], [
        Web.node{"span", [], [Web.text{Pre.kind_name(h)}]}]} <> make_items(t, (n + 1 : U32))

# Create: the kinds projects/prefabs.bend has. Off in Play.
def create(+st: W.St) -> Web.HTML<W.Ev>:
  Ui.dropdown(W.Ev,
    Ui.trigger_with(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}], "", Web.attr{"type", "button"} <> Web.attr{"aria-label", "Create a thing"} <> P.disabled(Bool.not(Mk.is_editing(st))), [
      Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "plus"), Web.node{"span", [], [Web.text{"Create"}]}]),
    Ui.menu_with(W.Ev, [Ui.menu_end{}], "", [Web.attr{"role", "menu"}, Web.attr{"aria-label", "Create a thing"}], make_items(Pre.kinds(), 0)))

def panel(+st: W.St) -> Web.HTML<W.Ev>:
  Ui.panel_as(W.Ev, "section", "editor-window editor-hierarchy", [Web.attr{"aria-labelledby", "editor-hierarchy-title"}], [
    Ui.panel_header(W.Ev, [
      Web.node{"span", [Web.attr{"id", "editor-hierarchy-title"}], [Web.text{"Hierarchy"}]},
      create(st)]),
    Ui.panel_body_with(W.Ev, "editor-window__body", [], body(Nat.is_eq(S.count(W.scene(st)), 0n), st))])

# ---------- Keys ----------

def last_of(+n: U32) -> U32:
  P.pick_u(U32.is_eq(n, 0), 0, (n - 1 : U32))

# The thing a key selects: Down the next, Up the one before, Home the first, End the last; any
# other key leaves the selection.
def keyed(+name: String, +sel: U32, +n: U32) -> U32:
  P.pick_u(String.eq(name, "arrowdown"), P.pick_u(U32.is_lt((sel + 1 : U32), n), (sel + 1 : U32), sel),
  P.pick_u(String.eq(name, "arrowup"), P.pick_u(U32.is_eq(sel, 0), 0, (sel - 1 : U32)),
  P.pick_u(String.eq(name, "home"), 0,
  P.pick_u(String.eq(name, "end"), last_of(n), sel))))

def moved(+st: W.St, +name: String) -> W.St:
  +n = U32.from_nat(S.count(W.scene(st)))
  +i = keyed(name, W.selected(st), n)
  P.pick_st(U32.is_eq(i, W.selected(st)), st, W.chosen(st, i))

# Delete or Backspace deletes the thing selected; the other keys move the selection.
def key(+st: W.St, +name: String) -> W.St:
  P.pick_st((String.eq(name, "delete") || String.eq(name, "backspace")), Mk.deleted(st), moved(st, name))
