# The thing's own components in the Inspector: its Transform (position, rotation in degrees,
# scale) and, for a character, its Animation values. panels.bend says what they hold (the
# sections, rows and fields) and what typing does; this file says what is drawn for them, in the
# workspace's page (editor/inspector/ puts them in the Inspector), and what a typed number does.
#
# A row of one number is one line, the name and its field ("Time  0.00"); a row of three is its
# name over X Y Z, as Unity's Inspector lays them out. A value's name is shown with a capital
# first letter, as Unity shows a field's name.
#
# Typing a place (Transform) or tags while editing marks the scene as changed: Save writes both.
#
# Limits now:
# - The field being typed in keeps its text while you type; Bend's own reading of the value shows
#   when you leave the field.
# - A number is shown with editor/workspace/number.bend's fixed (see its limits).

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene/scene.bend as S
import ../../engine/anim/figure.bend as Fig
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P
import ../workspace/number.bend as Num
import ./panels.bend as O

# A name as the Inspector shows it: "speed" is "Speed".
def nice(+name: String) -> String:
  String.to_upper(String.take(name, 1n)) ++ String.drop(name, 1n)

# A field's id: its section, row and place, so a label finds its field.
def field_id(+s: String, +r: U32, +k: U32) -> String:
  "inspector-" ++ s ++ "-" ++ U32.show(r) ++ "-" ++ U32.show(k)

def input(+f: O.Field, +id: String, +name: String) -> Web.HTML<W.Ev>:
  O.Field{edit, _, value, step, decimals} = f
  Ui.input_with(W.Ev, [Ui.input_sm{}], "", [
    Web.attr{"id", id}, Web.attr{"type", "number"}, Web.attr{"step", F32.show(step)},
    Web.attr{"value", Num.fixed(value, decimals)}, Web.attr{"aria-label", name},
    Web.on{Web.input{W.d_typed{edit, ""}}}, Web.on{Web.change{W.a_left{}}}])

def field_label(+f: O.Field) -> String:
  O.Field{_, label, _, _, _} = f
  label

def field(+f: O.Field, +id: String, +row: String) -> Web.HTML<W.Ev>:
  Ui.field_with(W.Ev, "editor-panels__field", [Web.attr{"for", id}], [
    Ui.field_label(W.Ev, field_label(f)),
    input(f, id, row ++ " " ++ field_label(f))])

def fields(+fs: List<&2, O.Field>, +s: String, +r: U32, +k: U32, +row: String) -> List<&2, Web.HTML<W.Ev>>:
  match fs:
    case Nil{}:
      Nil{}
    case +h <> t:
      field(h, field_id(s, r, k), row) <> fields(t, s, r, (k + 1 : U32), row)

# One number: its name and its field on one line.
def line(+f: O.Field, +id: String, +label: String) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "editor-inspector__line", [], [
    Web.node{"label", [Web.attr{"class", "field__label"}, Web.attr{"for", id}], [Web.text{nice(label)}]},
    input(f, id, nice(label))])

def row_of(+fs: List<&2, O.Field>, +label: String, +s: String, +r: U32) -> Web.HTML<W.Ev>:
  match fs:
    case Con{+one, Nil{}}:
      line(one, field_id(s, r, 0), label)
    case _:
      Ui.box(W.Ev, "fieldset", "form__section editor-panels__row", [], [
        Ui.says(W.Ev, "legend", "field__label", nice(label)),
        Ui.box(W.Ev, "div", "editor-panels__fields", [], fields(fs, s, r, 0, nice(label)))])

def row(+x: O.Row, +s: String, +r: U32) -> Web.HTML<W.Ev>:
  O.Row{label, fs} = x
  row_of(fs, label, s, r)

def rows(+xs: List<&2, O.Row>, +s: String, +r: U32) -> List<&2, Web.HTML<W.Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      row(h, s, r) <> rows(t, s, (r + 1 : U32))

def section_rows(+x: O.Section) -> List<&2, O.Row>:
  O.Section{_, rs} = x
  rs

# ---------- The components ----------

def thing(+st: W.St) -> S.Thing:
  S.at(W.scene(st), W.selected(st))

def transform(+st: W.St) -> Web.HTML<W.Ev>:
  P.section("Transform", W.still(st), rows(section_rows(O.transform_section(S.place(thing(st)))), "transform", 0))

def clip_toggles(+names: List<&2, String>, +n: U32, +shown: U32) -> List<&2, Web.HTML<W.Ev>>:
  match names:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Ui.toggle(W.Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "editor-panels__item", h, U32.is_eq(n, shown), W.a_show{n}) <> clip_toggles(t, (n + 1 : U32), shown)

# A character's Animation: the clips it has (a click shows one) and its animation values.
def animation(+st: W.St) -> Web.HTML<W.Ev>:
  +f = W.figure(st)
  P.section("Animation", W.still(st), List.append(&2, Web.HTML<W.Ev>, [
    Ui.says(W.Ev, "span", "field__label", "Clips"),
    Ui.box(W.Ev, "div", "editor-anim__list", [], clip_toggles("Locomotion" <> Fig.clip_names(f), 0, Fig.shown(f))),
    P.help("Locomotion is the idle and the walk, mixed by speed. A clip shows alone, over the whole body.")],
    rows(O.value_rows(Fig.params(f)), "animation", 0)))

# ---------- What typing does ----------

# Is this edit one Save writes (a place)?
def is_place(+e: O.Edit) -> Bool:
  match e:
    case O.Val{_, _}:
      False{}
    case _:
      True{}

def write(+st: W.St, got: Maybe<&2, F32>, +e: O.Edit) -> W.St:
  match got:
    case Some{x}:
      +now = W.with_scene(st, O.apply(W.scene(st), W.selected(st), e, x))
      P.pick_st((is_place(e) && U32.is_eq(W.play_mode(st), 0)), W.with_dirty(now, True{}), now)
    case None{}:
      st

# A number typed in the Inspector: the scene with that one value changed; a text that is not a
# number changes nothing.
def typed(+st: W.St, +e: O.Edit, +text: String) -> W.St:
  write(st, F32.read(text), e)

# ---------- Tags ----------

# A thing's tags as one line of text, and back: words between commas, trimmed, none empty.
def Tg.joined(gs: List<&2, String>) -> String:
  match gs:
    case Nil{}:
      ""
    case Con{+h, Nil{}}:
      h
    case Con{+h, t}:
      h ++ ", " ++ Tg.joined(t)

def Tg.cons_unless(empty: Bool, +w: String, rest: List<&2, String>) -> List<&2, String>:
  match empty:
    case True{}:
      rest
    case False{}:
      w <> rest

def Tg.words(ws: List<&2, String>) -> List<&2, String>:
  match ws:
    case Nil{}:
      []
    case Con{+h, t}:
      Tg.cons_unless(String.is_empty(String.trim(h)), String.trim(h), Tg.words(t))

def tags_of(+text: String) -> List<&2, String>:
  Tg.words(String.split(text, ','))

# The Tags of the thing selected: the words scripts find it by (engine/script/world.bend's tagged,
# as Unity's tags and Godot's groups).
def tags(+st: W.St) -> Web.HTML<W.Ev>:
  P.section("Tags", W.still(st), [
    Ui.box(W.Ev, "div", "editor-inspector__line", [], [
      Web.node{"label", [Web.attr{"class", "field__label"}, Web.attr{"for", "inspector-tags"}], [Web.text{"Tags"}]},
      Ui.input_with(W.Ev, [Ui.input_sm{}], "", [Web.attr{"id", "inspector-tags"}, Web.attr{"value", Tg.joined(S.tags(thing(st)))},
        Web.attr{"placeholder", "enemy, boss"}, Web.attr{"aria-describedby", "inspector-tags-help"},
        Web.on{Web.input{W.d_tags{""}}}, Web.on{Web.change{W.a_left{}}}])]),
    Web.node{"p", [Web.attr{"class", "editor-anim__help"}, Web.attr{"id", "inspector-tags-help"}], [Web.text{"Words scripts find this thing by. Separate them with commas."}]}])

# Tags typed: the thing selected has them; while editing, Save has something to write.
def tagged(+st: W.St, +text: String) -> W.St:
  +now = W.with_scene(st, S.put(W.scene(st), W.selected(st), S.with_tags(thing(st), tags_of(text))))
  P.pick_st(U32.is_eq(W.play_mode(st), 0), W.with_dirty(now, True{}), now)
