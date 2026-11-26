# Tests of the editor's workspace as a page (editor/workspace/view.bend): how a number is shown,
# what a typed number does to the scene, and what the Hierarchy, the Inspector's rules, the
# Project window, the Console and Save do to the state.
#
# Limits now:
# - A test is checked at a few chosen values, not for every value as a law
#   is. It catches mistakes; it does not prove there are none.
# - What is drawn is not checked here: the editor is looked at in the browser.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../engine/core/vec.bend as V
import ../../engine/core/transform.bend as Tr
import ../../engine/scene/scene.bend as S
import ../../engine/script/rule.bend as R
import ../../engine/render/shader/asset.bend as A
import ../../editor/scene/panels.bend as O
import ../../editor/workspace/number.bend as Num
import ../../editor/workspace/state.bend as W
import ../../editor/workspace/view.bend as Work
import ../../editor/inspector/rules.bend as Ru
import ../../projects/prefabs.bend as Pre

type Check is Data:
  Check{name: String, ok: Bool}

def two() -> S.Scene:
  S.Scene{[S.Thing{"Box", Tr.identity(), S.Hidden{}}, S.Thing{"Lamp", Tr.identity(), S.Hidden{}}]}

def state_of(u: Web.Update<W.St, W.Ev>) -> W.St:
  match u:
    case Web.update{next, _}:
      next

def opened() -> W.St:
  state_of(Work.start(two(), False{}, A.none(), ["scenes/Test.bend", "shaders/"], [], False{}, "Test", "test", "Test", [], []))

# The state after an event.
def after(+ev: W.Ev, +st: W.St) -> W.St:
  state_of(Work.on_event(ev, st))

# A keystroke as the driver sends it: the field's message, filled with the text.
def typed(+text: String) -> W.Ev:
  Work.on_input(W.d_typed{O.Pos{0}, ""}, Web.typed{text})

# Position X of the scene's first thing.
def x_of(+st: W.St) -> F32:
  V.x(Tr.position(S.place(S.at(W.scene(st), 0))))

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.0001)

def count(+st: W.St) -> U32:
  U32.from_nat(List.length(&2, R.Rule, W.rules(st)))

def first_does(rs: List<&2, R.Rule>) -> R.Response:
  match rs:
    case Nil{}:
      R.Response.Play{7}
    case h <> _:
      R.does(h)

def first_thing(rs: List<&2, R.Rule>) -> String:
  match rs:
    case Nil{}:
      ""
    case h <> _:
      R.thing(h)

def turn_of(+d: R.Response) -> F32:
  match d:
    case R.Response.Turn{a}:
      a
    case _:
      0.0

def lines(+st: W.St) -> U32:
  U32.from_nat(List.length(&2, W.Line, W.log(st)))

def with_rule() -> W.St:
  after(W.r_add{}, opened())

def key(+name: String) -> W.Ev:
  Work.on_input(W.h_key{""}, Web.key{name, 0, 0})

def checks() -> List<&2, Check>:
  [Check{"2.5 with two decimals is 2.50", String.eq(Num.fixed(2.5, 2), "2.50")},
   Check{"0 with two decimals is 0.00", String.eq(Num.fixed(0.0, 2), "0.00")},
   Check{"1 with one decimal is 1.0", String.eq(Num.fixed(1.0, 1), "1.0")},
   Check{"-0.75 with two decimals is -0.75", String.eq(Num.fixed((0.0 - 0.75 : F32), 2), "-0.75")},
   Check{"12.345 with one decimal is 12.3", String.eq(Num.fixed(12.345, 1), "12.3")},
   Check{"3 with no decimals is 3", String.eq(Num.fixed(3.0, 0), "3")},
   Check{"0.05 with two decimals keeps its zero: 0.05", String.eq(Num.fixed(0.05, 2), "0.05")},
   Check{"the workspace opens with nothing to save", Bool.not(W.dirty(opened()))},
   Check{"typing 2.5 in Position X puts the thing at x = 2.5", close(x_of(after(typed("2.5"), opened())), 2.5)},
   Check{"typing a place marks the scene as not saved", W.dirty(after(typed("2.5"), opened()))},
   Check{"a text that is not a number changes nothing", close(x_of(after(typed("abc"), opened())), 0.0)},
   Check{"an empty field changes nothing", close(x_of(after(typed(""), opened())), 0.0)},
   Check{"leaving a field changes nothing", close(x_of(after(W.a_left{}, after(typed("4"), opened()))), 4.0)},
   Check{"Save leaves nothing to save", Bool.not(W.dirty(after(W.p_save{}, after(typed("2.5"), opened()))))},
   Check{"picking a thing in the Hierarchy selects it", U32.is_eq(W.selected(after(W.a_thing{1}, opened())), 1)},
   Check{"Down on the Hierarchy selects the next thing", U32.is_eq(W.selected(after(key("arrowdown"), opened())), 1)},
   Check{"Down on the last thing stays on it", U32.is_eq(W.selected(after(key("arrowdown"), after(W.a_thing{1}, opened()))), 1)},
   Check{"Up on the first thing stays on it", U32.is_eq(W.selected(after(key("arrowup"), opened())), 0)},
   Check{"End selects the last thing", U32.is_eq(W.selected(after(key("end"), opened())), 1)},
   Check{"Add Component > Rule adds a rule", U32.is_eq(count(with_rule()), 1)},
   Check{"a new rule names the thing selected", String.eq(first_thing(W.rules(with_rule())), "Box")},
   Check{"a rule added makes the rules the editor's own", W.own_rules(with_rule())},
   Check{"a rule added marks the scene as not saved", W.dirty(with_rule())},
   Check{"typing 90 in Turn turns a quarter turn", close(turn_of(first_does(W.rules(after(Work.on_input(W.r_num{0, 0, ""}, Web.typed{"90"}), with_rule())))), 1.5707964)},
   Check{"Do > Move makes the rule a move by nothing", U32.is_eq(Ru.response_n(first_does(W.rules(after(W.r_does{0, 0}, with_rule())))), 0)},
   Check{"Remove rule takes it off", U32.is_eq(count(after(W.r_drop{0}, with_rule())), 0)},
   Check{"a thing selected again shows in the Inspector", Bool.not(W.shows_asset(after(W.a_thing{0}, after(W.f_pick{"Assets/scenes/Test.bend"}, opened()))))},
   Check{"a project file picked shows in the Inspector", W.shows_asset(after(W.f_pick{"Assets/scenes/Test.bend"}, opened()))},
   Check{"a project file picked is asked of the dev server", String.eq(W.ask_what(W.ask(after(W.f_pick{"Assets/scenes/Test.bend"}, opened()))), "read")},
   Check{"a clip picked is the library's clip picked", W.picked(W.lib(after(W.f_pick{"Library/Animations/Universal Animation Library/Jog"}, opened())))},
   Check{"a folder opened is the folder shown", String.eq(W.at(W.files(after(W.f_go{"Assets/shaders"}, opened()))), "Assets/shaders")},
   Check{"Create asks for the folder named", String.eq(W.ask_path(W.ask(after(W.f_make{}, after(Work.on_input(W.f_name{""}, Web.typed{"Water"}), after(W.f_new{"folder"}, opened()))))), "Water")},
   Check{"Create with a taken name asks nothing", U32.is_eq(W.ask_n(W.ask(after(W.f_make{}, after(Work.on_input(W.f_name{""}, Web.typed{"shaders"}), after(W.f_new{"folder"}, opened()))))), 0)},
   Check{"a line for the Console is kept", U32.is_eq(lines(after(Work.log_event("info", "Saved."), opened())), 1)},
   Check{"Clear empties the Console", U32.is_eq(lines(after(W.c_clear{}, after(Work.log_event("info", "Saved."), opened()))), 0)},
   Check{"the dock's tab is the one chosen", U32.is_eq(W.dock(after(W.a_tab{1}, opened())), 1)},
   Check{"Create > Plane adds a thing", Nat.is_eq(S.count(W.scene(after(W.h_make{1}, opened()))), 3n)},
   Check{"a thing made is selected", U32.is_eq(W.selected(after(W.h_make{1}, opened())), 2)},
   Check{"a thing made takes a free name", String.eq(S.name(S.at(W.scene(after(W.h_make{0}, after(W.h_make{0}, opened()))), 3)), "Empty 2")},
   Check{"a thing made is saved as made", String.contains(Work.save_text(after(W.h_make{1}, opened()), two(), W.scene(after(W.h_make{1}, opened()))), "Pre.Made{\"Plane\", Pre.Prefab.Plane{}")},
   Check{"making a thing marks the scene as not saved", W.dirty(after(W.h_make{0}, opened()))},
   Check{"the list of things changed once per thing made", U32.is_eq(Work.built(after(W.h_make{0}, opened())), 1)},
   Check{"nothing is made in Play", Nat.is_eq(S.count(W.scene(after(W.h_make{1}, after(W.p_play{}, opened())))), 2n)},
   Check{"Delete removes the thing selected", Nat.is_eq(S.count(W.scene(after(W.h_delete{}, opened()))), 1n)},
   Check{"a thing of the code deleted is saved as removed", String.contains(Work.save_text(after(W.h_delete{}, opened()), two(), W.scene(after(W.h_delete{}, opened()))), "[\"Box\"]")},
   Check{"deleting a thing made forgets it", Bool.not(String.contains(Work.save_text(after(W.h_delete{}, after(W.h_make{1}, opened())), two(), W.scene(after(W.h_delete{}, after(W.h_make{1}, opened())))), "Pre.Made{"))},
   Check{"deleting a thing deletes its rules", U32.is_eq(count(after(W.h_delete{}, with_rule())), 0)},
   Check{"Delete on the Hierarchy deletes", Nat.is_eq(S.count(W.scene(after(key("delete"), opened()))), 1n)},
   Check{"the scene saves beside itself", String.eq(Work.save_path(opened()), "scenes/saved/Test.bend")},
   Check{"Create > Script asks for the script's files", String.eq(W.ask_what(W.ask(after(W.f_make{}, after(Work.on_input(W.f_name{""}, Web.typed{"Spin"}), after(W.f_new{"script"}, opened()))))), "create")},
   Check{"a new script is a file in scripts/", String.eq(Work.created_file(after(W.f_make{}, after(Work.on_input(W.f_name{""}, Web.typed{"Spin"}), after(W.f_new{"script"}, opened())))), "Assets/scripts/Spin.bend")},
   Check{"a script waits for Save while something is not saved", U32.is_eq(W.ask_n(W.ask(after(W.f_make{}, after(Work.on_input(W.f_name{""}, Web.typed{"Spin"}), after(W.f_new{"script"}, after(W.h_make{0}, opened())))))), 0)},
   Check{"a folder does not wait for Save", U32.is_eq(W.ask_n(W.ask(after(W.f_make{}, after(Work.on_input(W.f_name{""}, Web.typed{"Art"}), after(W.f_new{"folder"}, after(W.h_make{0}, opened())))))), 1)},
   Check{"a scene opens when nothing waits for Save", String.eq(W.ask_what(W.ask(after(W.f_open{"Beach", False{}}, opened()))), "open")},
   Check{"a scene does not open over what is not saved", U32.is_eq(W.ask_n(W.ask(after(W.f_open{"Beach", False{}}, after(W.h_make{0}, opened())))), 0)},
   Check{"Discard and open opens anyway", String.eq(W.ask_path(W.ask(after(W.f_open{"Beach", True{}}, after(W.h_make{0}, opened())))), "Beach")},
   Check{"a right click opens the menu", W.menu_open(W.cut(after(Work.menu_event(10.0, 20.0, 800.0), opened())))},
   Check{"choosing in the menu closes it", Bool.not(W.menu_open(W.cut(after(W.f_new{"scene"}, after(Work.menu_event(10.0, 20.0, 800.0), opened())))))}]
