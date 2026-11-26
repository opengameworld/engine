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
import ../../engine/scene/reach.bend as Rc
import ../../editor/project/templates.bend as Tp

type Check is Data:
  Check{name: String, ok: Bool}

def moved() -> S.Scene:
  S.put(Anim.start(), 0, S.Thing{"Mannequin", Tr.at(V.V3{1.5, 0.0, 0.0}), S.look(S.at(Anim.start(), 0))})

def count(xs: List<&2, Save.Placed>) -> U32:
  U32.from_nat(List.length(&2, Save.Placed, xs))

def first(fs: List<&2, Tp.Written>) -> Tp.Written:
  match fs:
    case Nil{}:
      Tp.Written{"", ""}
    case f <> t:
      f

def checks() -> List<&2, Check>:
  [Check{"a whole number is written with a point: 1.0", String.eq(Save.number(1.0), "1.0")},
   Check{"a negative number is written as Bend reads it: (0.0 - 2.5 : F32)", String.eq(Save.number((0.0 - 2.5 : F32)), "(0.0 - 2.5 : F32)")},
   Check{"a scene as its code makes it has nothing to save", U32.is_eq(count(Save.changed(Anim.start(), Anim.start())), 0)},
   Check{"a moved thing is one place to save", U32.is_eq(count(Save.changed(Anim.start(), moved())), 1)},
   Check{"what was saved, put back, is the moved scene", Save.same_place(S.place(S.at(Save.apply(Anim.start(), Save.changed(Anim.start(), moved())), 0)), S.place(S.at(moved(), 0)))},
   Check{"the text names the thing and its place", String.contains(Save.text(Rc.sample(), "animation", "Animation", Save.changed(Anim.start(), moved()), "", [], False{}, []), "Save.Placed{\"Mannequin\", Tr.Transform{V.V3{1.5, 0.0, 0.0}")},
   Check{"a rule is written as Bend reads it", String.eq(Save.rule(R.Rule{"Box", R.Trigger.Clicked{}, R.Response.Turn{(0.0 - 0.5 : F32)}}), "R.Rule{\"Box\", R.Trigger.Clicked{}, R.Response.Turn{(0.0 - 0.5 : F32)}}")},
   Check{"a move is written with its vector", String.eq(Save.rule(R.Rule{"Box", R.Trigger.Started{}, R.Response.Move{V.V3{0.0, 1.0, 0.0}}}), "R.Rule{\"Box\", R.Trigger.Started{}, R.Response.Move{V.V3{0.0, 1.0, 0.0}}}")},
   Check{"the editor's own rules are saved with has_rules True", String.contains(Save.text(Rc.sample(), "animation", "Animation", [], "", [], True{}, Anim.rules()), "def has_rules() -> Bool: True{}")},
   Check{"the saved rules are the file's rules", String.contains(Save.text(Rc.sample(), "animation", "Animation", [], "", [], True{}, Anim.rules()), "  [R.Rule{\"Mannequin\", R.Trigger.Clicked{}, R.Response.Turn{1.5707964}}]")},
   Check{"the things of the code deleted are written by name", String.contains(Save.text(Rc.sample(), "animation", "Animation", [], "", ["Box", "Lamp"], False{}, []), "def removed() -> List<&2, String>:\n  [\"Box\", \"Lamp\"]")},
   Check{"a deleted thing is gone when the scene opens", Nat.is_eq(S.count(Save.without(Anim.start(), ["Mannequin"])), 0n)},
   Check{"rules the editor did not save are the code's", Nat.is_eq(List.length(&2, R.Rule, Save.rules(False{}, [], Anim.rules())), 1n)},
   Check{"a sample's saved file climbs four folders to the engine", String.contains(Save.text(Rc.sample(), "animation", "Animation", [], "", [], False{}, []), "import ../../../../engine/core/vec.bend as V\nimport ../../../../engine/core/quat.bend as Q\n")},
   Check{"a saved file outside the engine imports the engine's package", String.contains(Save.text(Rc.Reach.Package{"opengame-engine@0.4.0.0"}, "lake", "Shore", [], "", [], False{}, []), "import opengame-engine@0.4.0.0/engine/scene/save.bend as Save\n")},
   Check{"a sample's new scene climbs three folders to the engine", String.contains(Tp.text(first(Tp.files(Rc.sample(), "scene", "Shore"))), "import ../../../engine/scene/scene.bend as S\nimport ../../../engine/script/rule.bend as R\n")},
   Check{"a new script outside the engine imports the engine's package", String.contains(Tp.text(first(Tp.files(Rc.Reach.Package{"opengame-engine@0.4.0.0"}, "script", "Tide"))), "import opengame-engine@0.4.0.0/engine/scene/scene.bend as S\n")}]
