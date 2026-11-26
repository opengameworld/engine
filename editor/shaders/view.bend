# Shaders: the material of the thing selected, as the Inspector's Material component (Unity's
# material inspector, with its Shader menu at the top), and a shader asset picked in the Project
# window.
#
# The shaders are the ones made for the project (projects/<name>/shaders/, read by
# tools/shaders/catalog.js into editor/shaders/catalog_generated.bend as values of
# engine/render/shader/asset.bend), each under the name its own settings give it, and "Original
# graph", the thing's own material. The Shader menu, or Apply on a shader picked in the Project
# window, gives one to the thing; the Material component shows one control per parameter (a
# number, a color, a toggle, a slider, a menu). Nothing is shown that the shaders' files do not
# say. What a parameter may be worth is engine/render/shader/asset.bend's rule. A shader file that
# could not be used is a line in the Console, and cannot be chosen.
#
# Limits now:
# - The shaders are a project's: a project without a shaders folder has none.
# - Shaders have no picture.
# - A color is three number fields (R, G, B): Bend-UI has no color input.
# - A parameter's slider is the browser's own range input: Bend-UI has no slider.
# - After a shader is picked in a menu, the focus does not go back to the menu's button.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene/scene.bend as S
import ../../engine/render/material.bend as Mat
import ../../engine/render/shader/asset.bend as A
import ../scene/panels.bend as O
import ../defaults/defaults.bend as D
import ../workspace/number.bend as Num
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P

# ---------- The Shaders screen ----------
# The same places as the Animation screen, for the material of the thing
# selected: on the left the Shader Library (this project's shader files,
# and the thing's own graph), a click applies one; on the right the
# shader's facts, its parameters as controls, and what is wrong with the
# files that could not be used.

def shade_catalog(h: W.Shade) -> A.Catalog:
  W.Shade{c, _} = h
  c

def shade_graphs(h: W.Shade) -> S.Scene:
  W.Shade{_, g} = h
  g

def catalog(+st: W.St) -> A.Catalog:
  shade_catalog(W.shade(st))

def graphs(+st: W.St) -> S.Scene:
  shade_graphs(W.shade(st))

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
def has_material(+st: W.St) -> Bool:
  (W.in_scene(st) && S.is_shown(S.at(W.scene(st), W.selected(st))))

def material(+st: W.St) -> Mat.Material:
  S.material(S.look(S.at(W.scene(st), W.selected(st))))

# The thing as it was when its material was last a graph.
def original(+st: W.St) -> S.Thing:
  S.at(graphs(st), W.selected(st))

def has_original(+st: W.St) -> Bool:
  (U32.is_lt(W.selected(st), U32.from_nat(S.count(graphs(st)))) && thing_graph(original(st)))

# The shader of the selected thing's material: an asset's id, or "" for a
# graph or for no material at all. (editor/app.js asks, to know when the
# drawing code must take another shader.)
def shader_of(+st: W.St) -> String:
  P.pick_text(has_material(st), Mat.shader_id(material(st)), "")

def params(+st: W.St) -> List<&2, A.Param>:
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
def remembered(+st: W.St) -> W.St:
  W.with_shade(st, W.Shade{catalog(st), S.with_things(W.scene(st), keep_go(S.things(W.scene(st)), S.things(graphs(st))))})

def any_shown(xs: List<&2, S.Thing>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (S.is_shown(h) || any_shown(t))

# Does the project have presets to list?
def has_presets(+st: W.St) -> Bool:
  Bool.not((List.is_empty(&2, A.Asset, A.assets(catalog(st))) && List.is_empty(&2, A.Problem, A.problems(catalog(st)))))

# What the library says when it has nothing to offer: only what is true of
# this scene and this project.
def nothing_to_do(+st: W.St) -> String:
  P.pick_text(Bool.not(any_shown(S.things(W.scene(st)))), "Nothing in this scene has a material.",
  P.pick_text(Bool.not(has_presets(st)), "This project has no shader presets.",
  "Select a thing with a material in the scene's list."))

# ----- The Material component

# A color's channel goes from 0 to 1, in hundredths; any other number is free.
def unit_range(rgb: Bool) -> List<&2, Web.Attr<W.Ev>>:
  match rgb:
    case True{}:
      [Web.attr{"step", "0.01"}, Web.attr{"min", "0"}, Web.attr{"max", "1"}]
    case False{}:
      [Web.attr{"step", "any"}]

def number_field(+label: String, +id: String, +value: F32, +name: String, +k: U32, rgb: Bool) -> Web.HTML<W.Ev>:
  Ui.field_with(W.Ev, "editor-panels__field", [Web.attr{"for", id}], [
    Ui.field_label(W.Ev, label),
    Ui.input_with(W.Ev, [Ui.input_sm{}], "", List.append(&2, Web.Attr<W.Ev>, [
      Web.attr{"id", id}, Web.attr{"type", "number"}, Web.attr{"value", F32.show(value)}, Web.attr{"aria-label", label},
      Web.on{Web.input{W.s_number{name, k, ""}}}, Web.on{Web.change{W.a_left{}}}], unit_range(rgb)))])

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

def choice_items(cs: List<&2, A.Choice>, +name: String, +now: F32) -> List<&2, Web.HTML<W.Ev>>:
  match cs:
    case Nil{}:
      Nil{}
    case h <> t:
      A.Choice{+l, +v} = h
      Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"type", "button"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", Ui.bool_text(F32.is_eq(v, now))}, Web.on{Web.click{W.s_set{name, v}}}], [
        Web.node{"span", [], [Web.text{l}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "menu__check", [], "check")]} <> choice_items(t, name, now)

# The control of one parameter, by its kind.
def control_field(c: A.Control, +name: String, +label: String, +v: List<&2, F32>, +id: String) -> Web.HTML<W.Ev>:
  match c:
    case A.AsNumber{}:
      number_field(label, id, nth(v, 0), name, 0, False{})
    case A.AsColor{}:
      Ui.box(W.Ev, "fieldset", "form__section editor-material__group", [], [
        Ui.says(W.Ev, "legend", "field__label", label),
        Ui.box(W.Ev, "div", "editor-panels__fields", [], [
          number_field("R", id ++ "-r", nth(v, 0), name, 0, True{}),
          number_field("G", id ++ "-g", nth(v, 1), name, 1, True{}),
          number_field("B", id ++ "-b", nth(v, 2), name, 2, True{})])])
    case A.AsToggle{}:
      Ui.box(W.Ev, "div", "field editor-material__field", [], [
        Ui.says(W.Ev, "span", "field__label", label),
        Ui.button_with(W.Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}, Ui.btn_toggle{}, Ui.btn_sm{}], "editor-material__toggle", [Web.attr{"type", "button"}, Web.attr{"aria-label", label}, Web.attr{"aria-pressed", Ui.bool_text(F32.is_eq(nth(v, 0), 1.0))}, Web.on{Web.click{W.s_set{name, other(F32.is_eq(nth(v, 0), 1.0))}}}], [Web.text{on_text(F32.is_eq(nth(v, 0), 1.0))}])])
    case A.AsSlider{lo, hi, step}:
      Ui.box(W.Ev, "label", "field editor-material__field", [], [
        Ui.says(W.Ev, "span", "field__label", label),
        Ui.box(W.Ev, "span", "editor-material__slider", [], [
          Web.node{"input", [Web.attr{"class", "editor-material__range"}, Web.attr{"id", id}, Web.attr{"type", "range"}, Web.attr{"aria-label", label}, Web.attr{"min", F32.show(lo)}, Web.attr{"max", F32.show(hi)}, Web.attr{"step", F32.show(step)}, Web.prop{"value", F32.show(nth(v, 0))}, Web.on{Web.input{W.s_number{name, 0, ""}}}], []},
          Ui.says(W.Ev, "output", "meta mono", F32.show(nth(v, 0)))])])
    case A.AsDropdown{+cs}:
      Ui.box(W.Ev, "div", "field editor-material__field", [], [
        Ui.says(W.Ev, "span", "field__label", label),
        Ui.box(W.Ev, "div", "editor-material__dropdown", [], [
          Ui.dropdown(W.Ev,
            Ui.trigger_with(W.Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}, Ui.btn_sm{}], "", [Web.attr{"type", "button"}, Web.attr{"aria-label", label ++ ": " ++ A.choice_label(cs, nth(v, 0))}], [
              Web.node{"span", [], [Web.text{A.choice_label(cs, nth(v, 0))}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "chevron-down")]),
            Ui.menu_with(W.Ev, [Ui.menu_end{}], "", [Web.attr{"role", "menu"}, Web.attr{"aria-label", label}], choice_items(cs, name, nth(v, 0))))])])

def param_fields(ps: List<&2, A.Param>, +vs: List<&2, Mat.Value>) -> List<&2, Web.HTML<W.Ev>>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> t:
      control_field(A.control(h), A.param_name(h), A.param_label(h), A.value(h, vs), "editor-shaders-" ++ A.param_name(h)) <> param_fields(t, vs)

# A graph's values: a number, or R G B for three.
def graph_value_fields(xs: List<&2, F32>, +name: String, +k: U32, +three: Bool) -> List<&2, Web.HTML<W.Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      Ui.field_with(W.Ev, "editor-panels__field", [], [
        Ui.field_label(W.Ev, O.label_for(three, name, k)),
        Ui.input_with(W.Ev, [Ui.input_sm{}], "", [Web.attr{"type", "number"}, Web.attr{"step", "0.01"}, Web.attr{"value", Num.fixed(h, 2)}, Web.attr{"aria-label", O.label_for(three, name, k)}, Web.on{Web.input{W.s_graph{name, k, ""}}}, Web.on{Web.change{W.a_left{}}}])]) <> graph_value_fields(t, name, (k + 1 : U32), three)

def graph_values(vs: List<&2, Mat.Value>) -> List<&2, Web.HTML<W.Ev>>:
  match vs:
    case Nil{}:
      Nil{}
    case h <> t:
      Mat.Value{+name, +xs} = h
      Ui.box(W.Ev, "fieldset", "form__section editor-material__group", [], [
        Ui.says(W.Ev, "legend", "field__label", name),
        Ui.box(W.Ev, "div", "editor-panels__fields", [], graph_value_fields(xs, name, 0, Nat.is_eq(List.length(&2, F32, xs), 3n)))]) <> graph_values(t)

# The preset applied, as its own settings describe it. The original graph
# has no settings to show.
def shader_facts(graph: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match graph:
    case True{}:
      Nil{}
    case False{}:
      +a = A.asset_of(A.assets(catalog(st)), shader_of(st))
      [P.section("Shader", W.still(st), [P.fact("Name", A.label(a)), P.fact("File", A.id(a)), P.fact("Language", A.language(a))])]

def menu_item(+id: String, +label: String, +on: Bool, +broken: Bool) -> Web.HTML<W.Ev>:
  Web.node{"button", List.append(&2, Web.Attr<W.Ev>, [Web.attr{"class", "menu__item"}, Web.attr{"type", "button"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", Ui.bool_text(on)}, Web.on{Web.click{W.s_apply{id}}}], P.disabled(broken)), [
    Web.node{"span", [], [Web.text{label}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "menu__check", [], "check")]}

def asset_items(xs: List<&2, A.Asset>, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      menu_item(A.id(h), A.label(h), String.eq(A.id(h), shader_of(st)), A.has_problem(A.problems(catalog(st)), A.id(h))) <> asset_items(t, st)

def graph_item(has: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match has:
    case True{}:
      [menu_item("", "Original graph", String.eq(shader_of(st), ""), False{})]
    case False{}:
      Nil{}

def shader_name(+st: W.St) -> String:
  P.pick_text(String.eq(shader_of(st), ""), "Original graph", A.label(A.asset_of(A.assets(catalog(st)), shader_of(st))))


# The Shader menu: the thing's original graph and the project's shaders; one that could not be
# used cannot be chosen.
def shader_menu(+st: W.St) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "field editor-material__field", [], [
    Ui.says(W.Ev, "span", "field__label", "Shader"),
    Ui.box(W.Ev, "div", "editor-material__dropdown", [], [
      Ui.dropdown(W.Ev,
        Ui.trigger_with(W.Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}, Ui.btn_sm{}], "", [Web.attr{"type", "button"}, Web.attr{"aria-label", "Shader: " ++ shader_name(st)}], [
          Web.node{"span", [], [Web.text{shader_name(st)}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "chevron-down")]),
        Ui.menu_with(W.Ev, [Ui.menu_end{}], "", [Web.attr{"role", "menu"}, Web.attr{"aria-label", "Shader"}], List.append(&2, Web.HTML<W.Ev>, graph_item(has_original(st), st), asset_items(A.assets(catalog(st)), st))))])])

def material_controls(graph: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match graph:
    case True{}:
      graph_values(Mat.values(material(st)))
    case False{}:
      param_fields(params(st), Mat.values(material(st)))

# The Material component of the thing selected: the Shader menu, then its parameters.
def material_section(+st: W.St) -> Web.HTML<W.Ev>:
  P.section("Material", W.still(st), shader_menu(st) <> material_controls(String.eq(shader_of(st), ""), st))

# ----- What the clicks mean

def pick_material(c: Bool, a: Mat.Material, b: Mat.Material) -> Mat.Material:
  match c:
    case True{}:
      a
    case False{}:
      b

def rematerial(go: Bool, +st: W.St, m: Mat.Material) -> W.St:
  match go:
    case True{}:
      W.with_scene(st, S.with_material(W.scene(st), W.selected(st), m))
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
def may_apply(+st: W.St, +id: String) -> Bool:
  (has_material(st) && Bool.not(String.eq(shader_of(st), id)) && pick_bool(String.eq(id, ""), has_original(st), Bool.not(A.has_problem(A.problems(catalog(st)), id))))

# A shader applied to the selected thing: its material becomes that asset
# with its defaults, or the graph it had.
def applied(+st: W.St, +id: String) -> W.St:
  rematerial(may_apply(st, id), st, pick_material(String.eq(id, ""), S.material(S.look(original(st))), Mat.imported(id)))

def numbered(+st: W.St, +name: String, +k: U32, got: Maybe<&2, F32>) -> W.St:
  match got:
    case Some{x}:
      rematerial(has_material(st), st, A.edit(material(st), params(st), name, A.set_at(A.value_named(params(st), Mat.values(material(st)), name), k, x)))
    case None{}:
      st

def graphed(+st: W.St, +name: String, +k: U32, got: Maybe<&2, F32>) -> W.St:
  match got:
    case Some{x}:
      W.with_scene(st, O.apply(W.scene(st), W.selected(st), O.Val{name, k}, x))
    case None{}:
      st

# The drawing code could not use a shader (it did not link): the state as
# it was before, with the problem written down, so the shader cannot be
# chosen again. (editor/app.js calls this with the state before the click.)
def failed(+before: W.St, +id: String, +message: String) -> W.St:
  W.with_shade(before, W.Shade{A.with_problem(catalog(before), id, message), graphs(before)})
