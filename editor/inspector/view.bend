# The Inspector: what was selected last, as Unity's Inspector shows it (Unreal: Details).
#
#   a thing (Hierarchy, viewport)   its components, one section each: Transform; Material for a
#                                   shown thing (editor/shaders/); Animation for a character
#                                   (editor/scene/); one Rule for each rule that names it
#                                   (engine/script/rule.bend, editor/inspector/rules.bend); then Add
#                                   Component
#   an asset (Project window)       what it is: a clip (where it comes from, how it plays, Root,
#                                   Mirror, and Add to the character); a shader (its file, and
#                                   Apply to the thing selected); a scene (Open, as a double click
#                                   opens one in Unity; with something not saved, Save first or
#                                   Discard, as Unity asks); a script (when it runs, and its text);
#                                   a folder; any other project file (its text)
#
# A rule is a script made in the editor: when the thing is clicked in Play, or when Play starts,
# it moves, turns, or plays a clip. Its trigger and its response are picked from menus, so a rule
# is always one the engine knows how to run.
#
# Limits now:
# - Add Component offers Rule only: a thing's look (shown, character, hidden) is set in the
#   project's code.
# - A component cannot be removed, except a Rule; Delete removes the whole thing
#   (editor/hierarchy/make.bend).
# - A file's text is shown as it is, without colors, and cannot be edited here.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene/scene.bend as S
import ../../engine/anim/figure.bend as Fig
import ../../engine/script/rule.bend as R
import ../../engine/core/vec.bend as V
import ../../engine/render/shader/asset.bend as A
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P
import ../workspace/number.bend as Num
import ../scene/view.bend as Sc
import ../animation/view.bend as An
import ../shaders/view.bend as Sh
import ../project/files.bend as F
import ./rules.bend as Ru
import ../hierarchy/make.bend as Mk

# ---------- A rule ----------

def menu_items(+names: List<&2, String>, +n: U32, +now: U32, +k: U32, +when: Bool) -> List<&2, Web.HTML<W.Ev>>:
  match names:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"type", "button"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", Ui.bool_text(U32.is_eq(n, now))},
        Web.on{Web.click{P.pick_ev(when, W.r_when{k, n}, W.r_does{k, n})}}], [
        Web.node{"span", [], [Web.text{h}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "menu__check", [], "check")]} <> menu_items(t, (n + 1 : U32), now, k, when)

def clip_items(+names: List<&2, String>, +n: U32, +now: U32, +k: U32) -> List<&2, Web.HTML<W.Ev>>:
  match names:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"type", "button"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", Ui.bool_text(U32.is_eq(n, now))},
        Web.on{Web.click{W.r_clip{k, n}}}], [
        Web.node{"span", [], [Web.text{h}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "menu__check", [], "check")]} <> clip_items(t, (n + 1 : U32), now, k)

def nth_name(names: List<&2, String>, +n: U32) -> String:
  match names:
    case Nil{}:
      ""
    case h <> t:
      P.pick_text(U32.is_eq(n, 0), h, nth_name(t, (n - 1 : U32)))

# A field with a menu: its label, the choice shown, and the menu's items.
def menu_field(+label: String, +now: String, +items: List<&2, Web.HTML<W.Ev>>) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "editor-inspector__line", [], [
    Ui.says(W.Ev, "span", "field__label", label),
    Ui.box(W.Ev, "div", "editor-material__dropdown", [], [
      Ui.dropdown(W.Ev,
        Ui.trigger_with(W.Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}, Ui.btn_sm{}], "", [Web.attr{"type", "button"}, Web.attr{"aria-label", label ++ ": " ++ now}], [
          Web.node{"span", [], [Web.text{now}]}, Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "chevron-down")]),
        Ui.menu_with(W.Ev, [Ui.menu_end{}], "", [Web.attr{"role", "menu"}, Web.attr{"aria-label", label}], items))])])

def number_input(+id: String, +label: String, +x: F32, +step: String, +msg: W.Ev) -> Web.HTML<W.Ev>:
  Ui.input_with(W.Ev, [Ui.input_sm{}], "", [Web.attr{"id", id}, Web.attr{"type", "number"}, Web.attr{"step", step}, Web.attr{"value", Num.fixed(x, 2)},
    Web.attr{"aria-label", label}, Web.on{Web.input{msg}}, Web.on{Web.change{W.a_left{}}}])

def axis_field(+k: U32, +a: U32, +name: String, +x: F32) -> Web.HTML<W.Ev>:
  Ui.field_with(W.Ev, "editor-panels__field", [Web.attr{"for", "rule-" ++ U32.show(k) ++ "-" ++ name}], [
    Ui.field_label(W.Ev, name),
    number_input("rule-" ++ U32.show(k) ++ "-" ++ name, "Move " ++ name ++ ", in meters", x, "0.1", W.r_num{k, a, ""})])

# What the response needs: Move's X Y Z, Turn's degrees, or the clip Play plays.
def response_fields(+d: R.Response, +k: U32, +st: W.St, +rigged: Bool) -> List<&2, Web.HTML<W.Ev>>:
  match d:
    case R.Response.Move{v}:
      [Ui.box(W.Ev, "fieldset", "form__section editor-panels__row", [], [
        Ui.says(W.Ev, "legend", "field__label", "By (m)"),
        Ui.box(W.Ev, "div", "editor-panels__fields", [], [
          axis_field(k, 0, "X", V.x(Ru.move_of(d))),
          axis_field(k, 1, "Y", V.y(Ru.move_of(d))),
          axis_field(k, 2, "Z", V.z(Ru.move_of(d)))])])]
    case R.Response.Turn{_}:
      [Ui.box(W.Ev, "div", "editor-inspector__line", [], [
        Web.node{"label", [Web.attr{"class", "field__label"}, Web.attr{"for", "rule-" ++ U32.show(k) ++ "-angle"}], [Web.text{"Angle (°)"}]},
        number_input("rule-" ++ U32.show(k) ++ "-angle", "Turn, in degrees", Ru.degrees_of(d), "1", W.r_num{k, 0, ""})]),
       P.help("Around the World's up. A positive angle turns +Z toward +X.")]
    case R.Response.Play{c}:
      P.pick_html(rigged,
        [menu_field("Clip", nth_name("Locomotion" <> Fig.clip_names(W.figure(st)), c), clip_items("Locomotion" <> Fig.clip_names(W.figure(st)), 0, c, k))],
        [P.help("Play needs a character: this thing has no clips.")])

def trigger_help(+w: R.Trigger) -> String:
  match w:
    case R.Trigger.Clicked{}:
      "In Play, when the thing is clicked."
    case R.Trigger.Started{}:
      "Once, when Play starts."

def rule_section(+r: R.Rule, +k: U32, +st: W.St, +rigged: Bool) -> Web.HTML<W.Ev>:
  R.Rule{_, +w, +d} = r
  P.section("Rule", W.still(st), List.append(&2, Web.HTML<W.Ev>, [
    menu_field("When", nth_name(Ru.trigger_names(), Ru.trigger_n(w)), menu_items(Ru.trigger_names(), 0, Ru.trigger_n(w), k, True{})),
    P.help(trigger_help(w)),
    menu_field("Do", nth_name(Ru.response_names(), Ru.response_n(d)), menu_items(Ru.response_names(), 0, Ru.response_n(d), k, False{}))],
    List.append(&2, Web.HTML<W.Ev>, response_fields(d, k, st, rigged), [
      Ui.button_with(W.Ev, [Ui.btn_plain{}, Ui.btn_danger{}, Ui.btn_sm{}], "editor-inspector__remove", [Web.on{Web.click{W.r_drop{k}}}], [
        Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "trash-2"), Web.text{"Remove rule"}])])))

# Every rule that names this thing, with its place in the scene's list.
def rule_sections(rs: List<&2, R.Rule>, +k: U32, +name: String, +st: W.St, +rigged: Bool) -> List<&2, Web.HTML<W.Ev>>:
  match rs:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.append(&2, Web.HTML<W.Ev>, P.pick_html(String.eq(R.thing(h), name), [rule_section(h, k, st, rigged)], Nil{}), rule_sections(t, (k + 1 : U32), name, st, rigged))

def add_component() -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "editor-inspector__add", [], [
    Ui.dropdown(W.Ev,
      Ui.trigger_with(W.Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_wide{}], "", [Web.attr{"type", "button"}], [
        Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "plus"), Web.node{"span", [], [Web.text{"Add Component"}]}]),
      Ui.menu_with(W.Ev, [], "", [Web.attr{"role", "menu"}, Web.attr{"aria-label", "Add Component"}], [
        Ui.menu_item(W.Ev, "mouse-pointer-click", "Rule", W.r_add{})]))])

# ---------- A thing ----------

# Delete: the thing and its rules (editor/hierarchy/make.bend). Off in Play.
def delete_button(+st: W.St) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "editor-inspector__add", [], [
    Ui.button_with(W.Ev, [Ui.btn_plain{}, Ui.btn_danger{}, Ui.btn_sm{}], "", Web.on{Web.click{W.h_delete{}}} <> P.disabled(Bool.not(Mk.is_editing(st))), [
      Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "trash-2"), Web.text{"Delete thing"}])])

def look_name(+t: S.Thing) -> String:
  P.pick_text(S.is_rigged(t), "Character", P.pick_text(S.is_shown(t), "Shown", "Hidden"))

def look_sections(+st: W.St, +t: S.Thing) -> List<&2, Web.HTML<W.Ev>>:
  P.pick_html(S.is_rigged(t), [Sc.animation(st)], P.pick_html(S.is_shown(t), [Sh.material_section(st)], Nil{}))

def thing_body(has: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match has:
    case False{}:
      [P.help("Select a thing in the Hierarchy or the viewport, or an asset in the Project window.")]
    case True{}:
      +t = Sc.thing(st)
      List.append(&2, Web.HTML<W.Ev>, [
        Ui.box(W.Ev, "div", "editor-inspector__head", [], [
          Ui.says(W.Ev, "span", "item-title", S.name(t)), Ui.says(W.Ev, "span", "tag", look_name(t))]),
        Sc.transform(st)],
      List.append(&2, Web.HTML<W.Ev>, look_sections(st, t),
      List.append(&2, Web.HTML<W.Ev>, rule_sections(W.rules(st), 0, S.name(t), st, S.is_rigged(t)), [add_component(), delete_button(st)])))

# ---------- An asset ----------

def clip_body(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  List.append(&2, Web.HTML<W.Ev>, [P.section("Clip", W.still(st), An.clip_facts(W.picked(W.lib(st)), W.lib(st)))],
    P.pick_html(W.has_character(st), An.keep_button(W.figure(st), W.character_name(st)), [P.help("Select a character in the Hierarchy, then pick the clip again to try it on the character.")]))

def shader_body(+st: W.St, +path: String) -> List<&2, Web.HTML<W.Ev>>:
  +id = F.shader_id(path)
  +broken = A.has_problem(A.problems(Sh.catalog(st)), id)
  +a = A.asset_of(A.assets(Sh.catalog(st)), id)
  List.append(&2, Web.HTML<W.Ev>, [P.section("Shader", W.still(st), [
      P.fact("Name", P.pick_text(broken, F.name(path), A.label(a))), P.fact("File", id), P.fact("Language", P.pick_text(broken, "", A.language(a)))])],
    P.pick_html(broken, [P.help("This shader could not be used: the Console says why.")],
      P.pick_html(Sh.has_material(st), [
        Ui.button_with(W.Ev, [Ui.btn_filled{}, Ui.btn_sm{}], "", Web.on{Web.click{W.s_apply{id}}} <> P.disabled(String.eq(Sh.shader_of(st), id)), [
          Web.text{P.pick_text(String.eq(Sh.shader_of(st), id), "Applied to " ++ S.name(Sc.thing(st)), "Apply to " ++ S.name(Sc.thing(st)))}])],
        [P.help("Select a thing with a material in the Hierarchy to apply this shader to it.")])))

def folder_body(+st: W.St, +path: String) -> List<&2, Web.HTML<W.Ev>>:
  [P.section("Folder", W.still(st), [P.fact("Name", F.name(path)), P.fact("Path", path),
    P.fact("Holds", Nat.show(List.length(&2, String, F.paths_of(F.kids(F.all(W.paths(W.files(st))), path)))))])]

def file_body(+st: W.St, +path: String) -> List<&2, Web.HTML<W.Ev>>:
  +x = W.file_text(W.files(st))
  [P.section(F.kind_name(F.kind(F.all(W.paths(W.files(st))), path)), W.still(st), [P.fact("Name", F.name(path)), P.fact("Path", "projects/" ++ W.project_folder(W.files(st)) ++ "/" ++ F.on_disk(path))]),
   P.pick_one(String.is_empty(x), P.help("The file's text shows under `bun run dev`."), Web.node{"pre", [Web.attr{"class", "editor-inspector__text"}, Web.attr{"tabindex", "0"}, Web.attr{"aria-label", "The file's text"}], [Web.text{x}]})]

# A scene's name: its file's, without .bend.
def scene_of(+path: String) -> String:
  String.reverse(String.drop(String.reverse(F.name(path)), 5n))

def open_buttons(dirty: Bool, +name: String) -> List<&2, Web.HTML<W.Ev>>:
  match dirty:
    case False{}:
      [Ui.button_with(W.Ev, [Ui.btn_filled{}, Ui.btn_sm{}], "", [Web.on{Web.click{W.f_open{name, False{}}}}], [Web.text{"Open scene"}])]
    case True{}:
      [P.help("This scene has changes that are not saved. Save them, or discard them and open " ++ name ++ "."),
       Ui.box(W.Ev, "div", "editor-inspector__choices", [], [
         Ui.button(W.Ev, [Ui.btn_filled{}, Ui.btn_sm{}], "Save", W.p_save{}),
         Ui.button(W.Ev, [Ui.btn_bordered{}, Ui.btn_danger{}, Ui.btn_sm{}], "Discard and open", W.f_open{name, True{}})])]

def scene_body(+st: W.St, +path: String) -> List<&2, Web.HTML<W.Ev>>:
  +name = scene_of(path)
  List.append(&2, Web.HTML<W.Ev>, [P.section("Scene", W.still(st), [P.fact("Name", name), P.fact("Path", "projects/" ++ W.project_folder(W.files(st)) ++ "/" ++ F.on_disk(path))])],
    P.pick_html(String.eq(name, W.scene_name(W.cut(st))), [P.help("This scene is open.")], open_buttons(W.dirty(st), name)))

def script_body(+st: W.St, +path: String) -> List<&2, Web.HTML<W.Ev>>:
  List.append(&2, Web.HTML<W.Ev>, [P.help("Runs in Play: start once, on the first tick; update every tick, after the rules. Every script of the project runs, in the order of the file names.")], file_body(st, path))

def asset_by(+k: F.Sort, +st: W.St, +path: String) -> List<&2, Web.HTML<W.Ev>>:
  match k:
    case F.Sort.Scene{}:
      scene_body(st, path)
    case F.Sort.Script{}:
      script_body(st, path)
    case F.Sort.Clip{}:
      clip_body(st)
    case F.Sort.Shader{}:
      shader_body(st, path)
    case F.Sort.Folder{}:
      folder_body(st, path)
    case _:
      file_body(st, path)

def asset_body(+st: W.St, +path: String) -> List<&2, Web.HTML<W.Ev>>:
  asset_by(F.kind(F.all(W.paths(W.files(st))), path), st, path)

def body(asset: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match asset:
    case True{}:
      asset_body(st, W.picked_path(W.files(st)))
    case False{}:
      thing_body(W.in_scene(st), st)

def title(asset: Bool, +st: W.St) -> String:
  match asset:
    case True{}:
      F.name(W.picked_path(W.files(st)))
    case False{}:
      P.pick_text(W.in_scene(st), S.name(Sc.thing(st)), "")

def panel(+st: W.St) -> Web.HTML<W.Ev>:
  Ui.panel_as(W.Ev, "section", "editor-window editor-inspector", [Web.attr{"aria-labelledby", "editor-inspector-title"}], [
    Ui.panel_header(W.Ev, [
      Web.node{"span", [Web.attr{"id", "editor-inspector-title"}], [Web.text{"Inspector"}]},
      Ui.says(W.Ev, "span", "meta", title(W.shows_asset(st), st))]),
    Ui.panel_body_with(W.Ev, "editor-window__body editor-panels__body", [], body(W.shows_asset(st), st))])

# ---------- What its clicks mean ----------

def ruled(+st: W.St, +rs: List<&2, R.Rule>) -> W.St:
  W.with_rules(st, rs)

def rule_number(+st: W.St, +k: U32, +a: U32, got: Maybe<&2, F32>) -> W.St:
  match got:
    case Some{x}:
      ruled(st, Ru.with_number(W.rules(st), k, a, x))
    case None{}:
      st

def rule_added(+st: W.St) -> W.St:
  P.pick_st(W.in_scene(st), ruled(st, Ru.added(W.rules(st), S.name(Sc.thing(st)))), st)
