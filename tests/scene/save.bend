# Numerical tests of engine/scene/save.bend: comparing places and writing numbers are float
# math, which the law checker does not compute.
#
# Limits now:
# - The written text is checked as text here; that Bend reads it back is checked by hand (a
#   saved file compiles and opens at the saved place) and by `bun run check` on every saved file.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/core/transform.bend as Tr
import ../../engine/scene/scene.bend as S
import ../../engine/scene/save.bend as Save
import ../../projects/animation/scenes/Animation.bend as Anim
import ../../engine/script/rule.bend as R
import ../../engine/script/attach.bend as At
import ../../engine/script/value.bend as Val
import ../../projects/arena/project_generated.bend as Arena

type Check is Data:
  Check{name: String, ok: Bool}

def moved() -> S.Scene:
  S.put(Anim.start(), 0, S.thing("Mannequin", Tr.at(V.V3{1.5, 0.0, 0.0}), S.look(S.at(Anim.start(), 0))))

def count(xs: List<&2, Save.Placed>) -> U32:
  U32.from_nat(List.length(&2, Save.Placed, xs))

def checks() -> List<&2, Check>:
  [Check{"a whole number is written with a point: 1.0", String.eq(Save.number(1.0), "1.0")},
   Check{"a negative number is written as Bend reads it: (0.0 - 2.5 : F32)", String.eq(Save.number((0.0 - 2.5 : F32)), "(0.0 - 2.5 : F32)")},
   Check{"a scene as its code makes it has nothing to save", U32.is_eq(count(Save.changed(Anim.start(), Anim.start())), 0)},
   Check{"a moved thing is one place to save", U32.is_eq(count(Save.changed(Anim.start(), moved())), 1)},
   Check{"what was saved, put back, is the moved scene", Save.same_place(S.place(S.at(Save.apply(Anim.start(), Save.changed(Anim.start(), moved())), 0)), S.place(S.at(moved(), 0)))},
   Check{"the text names the thing and its place", String.contains(Save.text("animation", "Animation", Save.changed(Anim.start(), moved()), "", [], False{}, [], [], []), "Save.Placed{\"Mannequin\", Tr.Transform{V.V3{1.5, 0.0, 0.0}")},
   Check{"a rule is written as Bend reads it", String.eq(Save.rule(R.Rule{"Box", R.Trigger.Clicked{}, R.Response.Turn{(0.0 - 0.5 : F32)}}), "R.Rule{\"Box\", R.Trigger.Clicked{}, R.Response.Turn{(0.0 - 0.5 : F32)}}")},
   Check{"a move is written with its vector", String.eq(Save.rule(R.Rule{"Box", R.Trigger.Started{}, R.Response.Move{V.V3{0.0, 1.0, 0.0}}}), "R.Rule{\"Box\", R.Trigger.Started{}, R.Response.Move{V.V3{0.0, 1.0, 0.0}}}")},
   Check{"the editor's own rules are saved with has_rules True", String.contains(Save.text("animation", "Animation", [], "", [], True{}, Anim.rules(), [], []), "def has_rules() -> Bool: True{}")},
   Check{"the saved rules are the file's rules", String.contains(Save.text("animation", "Animation", [], "", [], True{}, Anim.rules(), [], []), "  [R.Rule{\"Mannequin\", R.Trigger.Clicked{}, R.Response.Turn{1.5707964}}]")},
   Check{"the things of the code deleted are written by name", String.contains(Save.text("animation", "Animation", [], "", ["Box", "Lamp"], False{}, [], [], []), "def removed() -> List<&2, String>:\n  [\"Box\", \"Lamp\"]")},
   Check{"a deleted thing is gone when the scene opens", Nat.is_eq(S.count(Save.without(Anim.start(), ["Mannequin"])), 0n)},
   Check{"rules the editor did not save are the code's", Nat.is_eq(List.length(&2, R.Rule, Save.rules(False{}, [], Anim.rules())), 1n)},
   Check{"tags that differ from the code are saved by name", String.contains(Save.text("animation", "Animation", [], "", [], False{}, [], Save.tags_changed(Anim.start(), S.put(Anim.start(), 0, S.with_tags(S.at(Anim.start(), 0), ["hero"]))), []), "Save.Tagged{\"Mannequin\", [\"hero\"]}")},
   Check{"saved tags are put back when the scene opens", S.has_tag(S.at(Save.tag(Anim.start(), [Save.Tagged{"Mannequin", ["hero"]}]), 0), "hero")},
   Check{"an attached script is saved with its thing, its script and its fields", String.contains(Save.text("arena", "Arena", [], "", [], False{}, [], [], Save.attachments(Arena.opened("Arena"))), "Save.Attachment{\"Walker B\", \"Walker\", Val.Value.Rec{[\"speed\", \"pings\"], [Val.Value.Num{2.0}, Val.Value.Int{0}]}}")},
   Check{"a reference is saved as the name of its thing", String.contains(Save.text("arena", "Arena", [], "", [], False{}, [], [], Save.attachments(Arena.opened("Arena"))), "Val.Value.Named{\"Target\"}")},
   Check{"saved attachments replace the code's when the editor saved its own", Nat.is_eq(List.length(&2, At.Attached, S.scripts(S.at(Save.attach(Arena.code("Arena"), True{}, []), 1))), 0n)}]
