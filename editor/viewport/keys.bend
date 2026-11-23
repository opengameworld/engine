# The editor's shortcuts: every key the editor takes lives here, in one list. Bend-UI's
# createKeys hears them (editor/app.js), and editor/viewport/LAWS.bend checks them together with
# Bend-UI's keys, so no two ever overlap.
#
# Views: 1 goes back to the start view; 2, 3 and 4 look along Y, X and Z (from the + side, like
# clicking that handle of the gizmo).
#
# A game's keys are not here: they are actions (engine/input/), heard only in Play. The laws
# check that no editor key is one the character walks with (engine/anim/locomotion.bend's
# context), so pressing a view key in Play never also walks.
#
# Limits now:
# - The view keys work in Play too (as Unity's Scene view keeps its shortcuts while playing).

import Base
import ../../node_modules/bend-ui/SPEC.bend as Spec
import ../../engine/input/actions.bend as Act

def keymap() -> List<&2, Spec.Shortcut>:
  [Spec.Shortcut{0, 0, "1", "view.home"},
   Spec.Shortcut{0, 0, "2", "view.y"},
   Spec.Shortcut{0, 0, "3", "view.x"},
   Spec.Shortcut{0, 0, "4", "view.z"}]

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# Does this action go back to the start view?
def is_home(+action: String) -> Bool:
  String.eq(action, "view.home")

# The gizmo handle each view looks from (editor/viewport/gizmo.bend: 0 +X, 1 +Y,
# 2 +Z), or 6 for an action that is not one.
def view_handle(+action: String) -> U32:
  pick(String.eq(action, "view.y"), 1,
  pick(String.eq(action, "view.x"), 0,
  pick(String.eq(action, "view.z"), 2, 6)))

# Bend's code for a shortcut's key (engine/input/keys.bend): its first character.
def Keys.code_of(m: Maybe<&2, Char>) -> U32:
  match m:
    case Some{c}:
      match c:
        case Chr{k}:
          k
    case None{}:
      0

def Keys.first(+key: String) -> U32:
  Keys.code_of(String.get(key, 0n))

def Keys.code(+s: Spec.Shortcut) -> U32:
  Spec.Shortcut{_, _, key, _} = s
  Keys.first(key)

# How many of these shortcuts take a key some context binds.
def taken_by(xs: List<&2, Spec.Shortcut>, +cs: List<&2, Act.Context>) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{+h, t}:
      (Spec.as_count(Act.binds_any(cs, Keys.code(h))) + taken_by(t, cs) : U32)
