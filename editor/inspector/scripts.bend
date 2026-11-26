# The scripts attached to the thing selected, in the Inspector (engine/script/attach.bend), as
# Unity's Inspector shows a MonoBehaviour: one section for each, titled with the script's name,
# with where it runs, its fields, and Remove. Add Component > Script lists the project's scripts
# (its registry's, PROJECT.bend's offers); a new attachment gets the script's initial() fields.
#
# A field is drawn by its kind (engine/script/value.bend): a number (F32 or U32), a switch (Bool),
# a text (String), three numbers (a V3), or a menu of the scene's things (a reference, Id.Id), as
# Unity's object field takes a scene object. A field's name is shown with a capital first letter.
#
# Every change marks the scene as not saved: Save writes the attachments with the scene
# (engine/scene/save.bend's attached). In Play, nothing here changes: the running copy is the
# scripts' own.
#
# Limits now:
# - A script's fields are edited here, not its code (the script editor, editor/code/, edits that).
# - Attachments cannot be reordered; a thing's scripts run in the order they were added.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/core/vec.bend as V
import ../../engine/scene/scene.bend as S
import ../../engine/scene/id.bend as Id
import ../../engine/script/attach.bend as At
import ../../engine/script/value.bend as Val
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P
import ../workspace/number.bend as Num
import ../code/code.bend as Cd

def Xs.nice(+name: String) -> String:
  String.to_upper(String.take(name, 1n)) ++ String.drop(name, 1n)

def Xs.id(+k: U32, +field: String) -> String:
  "script-" ++ U32.show(k) ++ "-" ++ field

# ---------- One field ----------

def Xs.number(+k: U32, +field: String, +text: String, +step: String, +msg: W.Ev) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "editor-inspector__line", [], [
    Web.node{"label", [Web.attr{"class", "field__label"}, Web.attr{"for", Xs.id(k, field)}], [Web.text{Xs.nice(field)}]},
    Ui.input_with(W.Ev, [Ui.input_sm{}], "", [Web.attr{"id", Xs.id(k, field)}, Web.attr{"type", "number"}, Web.attr{"step", step},
      Web.attr{"value", text}, Web.on{Web.input{msg}}, Web.on{Web.change{W.a_left{}}}])])

def Xs.text(+k: U32, +field: String, +text: String) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "editor-inspector__line", [], [
    Web.node{"label", [Web.attr{"class", "field__label"}, Web.attr{"for", Xs.id(k, field)}], [Web.text{Xs.nice(field)}]},
    Ui.input_with(W.Ev, [Ui.input_sm{}], "", [Web.attr{"id", Xs.id(k, field)}, Web.attr{"value", text},
      Web.on{Web.input{W.x_text{k, field, ""}}}, Web.on{Web.change{W.a_left{}}}])])

def Xs.flag(+k: U32, +field: String, +on: Bool) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "editor-inspector__line", [], [
    Ui.says(W.Ev, "span", "field__label", Xs.nice(field)),
    Ui.toggle(W.Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}, Ui.btn_sm{}], "", P.pick_text(on, "On", "Off"), on, W.x_flag{k, field, Bool.not(on)})])

def Xs.axis(+k: U32, +field: String, +a: U32, +name: String, +x: F32) -> Web.HTML<W.Ev>:
  Ui.field_with(W.Ev, "editor-panels__field", [Web.attr{"for", Xs.id(k, field) ++ "-" ++ name}], [
    Ui.field_label(W.Ev, name),
    Ui.input_with(W.Ev, [Ui.input_sm{}], "", [Web.attr{"id", Xs.id(k, field) ++ "-" ++ name}, Web.attr{"type", "number"}, Web.attr{"step", "0.1"},
      Web.attr{"value", Num.fixed(x, 2)}, Web.attr{"aria-label", Xs.nice(field) ++ " " ++ name},
      Web.on{Web.input{W.x_vec{k, field, a, ""}}}, Web.on{Web.change{W.a_left{}}}])])

def Xs.vec(+k: U32, +field: String, +v: V.V3) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "fieldset", "form__section editor-panels__row", [], [
    Ui.says(W.Ev, "legend", "field__label", Xs.nice(field)),
    Ui.box(W.Ev, "div", "editor-panels__fields", [], [
      Xs.axis(k, field, 0, "X", V.x(v)), Xs.axis(k, field, 1, "Y", V.y(v)), Xs.axis(k, field, 2, "Z", V.z(v))])])

def Xs.thing_items(xs: List<&2, S.Thing>, +k: U32, +field: String, +n: U32, +now: Id.Id) -> List<&2, Web.HTML<W.Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"type", "button"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", Ui.bool_text(Id.same(S.id(h), now))},
        Web.on{Web.click{W.x_ref{k, field, n}}}], [
        Web.node{"span", [], [Web.text{S.name(h)}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "menu__check", [], "check")]} <> Xs.thing_items(t, k, field, (n + 1 : U32), now)

def Xs.name_in(m: Maybe<&2, S.Thing>) -> String:
  match m:
    case Some{t}:
      S.name(t)
    case None{}:
      "None"

# A reference: a menu of the scene's things, and None.
def Xs.ref(+st: W.St, +k: U32, +field: String, +now: Id.Id) -> Web.HTML<W.Ev>:
  +label = Xs.nice(field)
  +shown = Xs.name_in(S.find(W.scene(st), now))
  Ui.box(W.Ev, "div", "editor-inspector__line", [], [
    Ui.says(W.Ev, "span", "field__label", label),
    Ui.box(W.Ev, "div", "editor-material__dropdown", [], [
      Ui.dropdown(W.Ev,
        Ui.trigger_with(W.Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}, Ui.btn_sm{}], "", [Web.attr{"type", "button"}, Web.attr{"aria-label", label ++ ": " ++ shown}], [
          Web.node{"span", [], [Web.text{shown}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "chevron-down")]),
        Ui.menu_with(W.Ev, [Ui.menu_end{}], "", [Web.attr{"role", "menu"}, Web.attr{"aria-label", label}],
          Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"type", "button"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", Ui.bool_text(Id.is_none(now))},
            Web.on{Web.click{W.x_ref{k, field, U32.from_nat(S.count(W.scene(st)))}}}], [Web.node{"span", [], [Web.text{"None"}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "menu__check", [], "check")]} <>
          Xs.thing_items(S.things(W.scene(st)), k, field, 0, now)))])])

def Xs.field(+st: W.St, +k: U32, +field: String, +v: Val.Value) -> Web.HTML<W.Ev>:
  match v:
    case Val.Value.Num{n}:
      Xs.number(k, field, Num.fixed(n, 2), "0.1", W.x_num{k, field, ""})
    case Val.Value.Int{n}:
      Xs.number(k, field, U32.show(n), "1", W.x_int{k, field, ""})
    case Val.Value.Flag{b}:
      Xs.flag(k, field, b)
    case Val.Value.Text{t}:
      Xs.text(k, field, t)
    case Val.Value.Vec{x}:
      Xs.vec(k, field, x)
    case Val.Value.Ref{i}:
      Xs.ref(st, k, field, i)
    case _:
      P.help(Xs.nice(field))

def Xs.fields(+st: W.St, +k: U32, ns: List<&2, String>, vs: List<&2, Val.Value>) -> List<&2, Web.HTML<W.Ev>>:
  match ns vs:
    case Con{+n, nt} Con{+v, vt}:
      Xs.field(st, k, n, v) <> Xs.fields(st, k, nt, vt)
    case _ _:
      Nil{}

# ---------- One script ----------

def Xs.section(+st: W.St, +k: U32, +a: At.Attached) -> Web.HTML<W.Ev>:
  +f = At.fields(a)
  P.section(At.script(a), W.still(st), List.append(&2, Web.HTML<W.Ev>, [
    P.fact("Runs on", At.kind_runs(At.kind_of(Cd.offers(W.code(st)), At.script(a))))],
    List.append(&2, Web.HTML<W.Ev>, P.pick_html(List.is_empty(&2, String, Val.names(f)), [P.help("This script has no fields.")], Xs.fields(st, k, Val.names(f), Val.values(f))), [
      Ui.button_with(W.Ev, [Ui.btn_plain{}, Ui.btn_danger{}, Ui.btn_sm{}], "editor-inspector__remove", Web.on{Web.click{W.x_drop{k}}} <> P.disabled(U32.is_ne(W.play_mode(st), 0)), [
        Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "trash-2"), Web.text{"Remove script"}])])))

def Xs.sections_go(+st: W.St, as: List<&2, At.Attached>, +k: U32) -> List<&2, Web.HTML<W.Ev>>:
  match as:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Xs.section(st, k, h) <> Xs.sections_go(st, t, (k + 1 : U32))

def thing_of(+st: W.St) -> S.Thing:
  S.at(W.scene(st), W.selected(st))

# A section for every script attached to the thing selected.
def sections(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  Xs.sections_go(st, S.scripts(thing_of(st)), 0)

def Xs.offer_items(os: List<&2, At.Offer>) -> List<&2, Web.HTML<W.Ev>>:
  match os:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Ui.menu_item(W.Ev, "code", At.kind_name(h), W.x_add{At.kind_name(h)}) <> Xs.offer_items(t)

# Add Component's script items: one for each script of the project.
def menu_items(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  Xs.offer_items(Cd.offers(W.code(st)))

# ---------- What its events do ----------

def Xs.is_editing(+st: W.St) -> Bool:
  U32.is_eq(W.play_mode(st), 0)

# The thing selected with these attachments: the scene changed, and something to save.
def Xs.with_attached(+st: W.St, +as: List<&2, At.Attached>) -> W.St:
  P.pick_st(Xs.is_editing(st), W.with_dirty(W.with_scene(st, S.put(W.scene(st), W.selected(st), S.with_scripts(thing_of(st), as))), True{}), st)

# A script attached to the thing selected, with its initial() fields.
def added(+st: W.St, +name: String) -> W.St:
  P.pick_st(W.in_scene(st), Xs.with_attached(st, List.append(&2, At.Attached, S.scripts(thing_of(st)), [At.Attached{name, At.kind_defaults(At.kind_of(Cd.offers(W.code(st)), name))}])), st)

# Attachment k removed.
def dropped(+st: W.St, +k: U32) -> W.St:
  Xs.with_attached(st, At.drop(S.scripts(thing_of(st)), k))

# Attachment k with field `field` set to x.
def set_field(+st: W.St, +k: U32, +field: String, +x: Val.Value) -> W.St:
  +a = At.nth(S.scripts(thing_of(st)), k)
  Xs.with_attached(st, At.put(S.scripts(thing_of(st)), k, At.with_fields(a, Val.with_field(At.fields(a), field, x))))

def Xs.set_num(+st: W.St, +k: U32, +field: String, got: Maybe<&2, F32>) -> W.St:
  match got:
    case Some{x}:
      set_field(st, k, field, Val.Value.Num{x})
    case None{}:
      st

def Xs.set_int(+st: W.St, +k: U32, +field: String, got: Maybe<&2, U32>) -> W.St:
  match got:
    case Some{x}:
      set_field(st, k, field, Val.Value.Int{x})
    case None{}:
      st

def numbered(+st: W.St, +k: U32, +field: String, +text: String) -> W.St:
  Xs.set_num(st, k, field, F32.read(text))

def counted(+st: W.St, +k: U32, +field: String, +text: String) -> W.St:
  Xs.set_int(st, k, field, U32.read(text))

def Xs.with_axis(+v: V.V3, +a: U32, +x: F32) -> V.V3:
  V.V3{P.pick_f(U32.is_eq(a, 0), x, V.x(v)), P.pick_f(U32.is_eq(a, 1), x, V.y(v)), P.pick_f(U32.is_eq(a, 2), x, V.z(v))}

def Xs.set_axis(+st: W.St, +k: U32, +field: String, +a: U32, got: Maybe<&2, F32>) -> W.St:
  match got:
    case Some{x}:
      set_field(st, k, field, Val.Value.Vec{Xs.with_axis(Val.vec(Val.at(At.fields(At.nth(S.scripts(thing_of(st)), k)), field)), a, x)})
    case None{}:
      st

def axised(+st: W.St, +k: U32, +field: String, +a: U32, +text: String) -> W.St:
  Xs.set_axis(st, k, field, a, F32.read(text))

def Xs.pick_id(c: Bool, +a: Id.Id, +b: Id.Id) -> Id.Id:
  match c:
    case True{}:
      a
    case False{}:
      b

# A reference set to the scene's thing n (none, when n is past the last).
def referred(+st: W.St, +k: U32, +field: String, +n: U32) -> W.St:
  set_field(st, k, field, Val.Value.Ref{Xs.pick_id(U32.is_lt(n, U32.from_nat(S.count(W.scene(st)))), S.id(S.at(W.scene(st), n)), Id.none())})
