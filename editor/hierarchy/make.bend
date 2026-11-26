# Making and deleting things in the scene, from the Hierarchy (Unity's GameObject > Create Empty,
# 3D Object, and Delete; Godot's Add Node and Delete Node). What is made comes from
# projects/prefabs.bend; Save writes the things made and the things of the code deleted
# (engine/scene/save.bend), so the scene opens as it was left.
#
#   made(st, k)   a thing of kind k (Pre.kinds()'s place k) at the World's origin, with a name no
#                 other thing has ("Plane", then "Plane 2"), selected
#   deleted(st)   the thing selected, gone, with the rules that name it (its components)
#
# Neither works in Play: what changes in Play is the running copy, which Stop drops.
#
# Limits now:
# - A thing cannot be renamed, duplicated or put under another thing (no parent and child yet).
# - Deleting a thing of the code deletes every thing with its name: things are found by name.

import Base
import ../../engine/scene/scene.bend as S
import ../../engine/scene/save.bend as Save
import ../../engine/core/transform.bend as Tr
import ../../engine/script/rule.bend as R
import ../../engine/scene/reach.bend as Rc
import ../../projects/prefabs.bend as Pre
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P

def names_go(xs: List<&2, S.Thing>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      S.name(h) <> names_go(t)

def names(+s: S.Scene) -> List<&2, String>:
  names_go(S.things(s))

def has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (String.eq(h, x) || has(t, x))

# The first of base, base 2, base 3 ... that no thing has (at most 999 tries).
def free_go(fuel: Nat, +taken: List<&2, String>, +base: String, +n: U32) -> String:
  match fuel:
    case 0n:
      base ++ " " ++ U32.show(n)
    case 1n+p:
      P.pick_text(has(taken, base ++ " " ++ U32.show(n)), free_go(p, taken, base, (n + 1 : U32)), base ++ " " ++ U32.show(n))

def free(+taken: List<&2, String>, +base: String) -> String:
  P.pick_text(has(taken, base), free_go(999n, taken, base, 2), base)

def pick_kind(c: Bool, +a: Pre.Prefab, +b: Pre.Prefab) -> Pre.Prefab:
  match c:
    case True{}:
      a
    case False{}:
      b

def kind_at(ks: List<&2, Pre.Prefab>, +n: U32) -> Pre.Prefab:
  match ks:
    case Nil{}:
      Pre.Prefab.Empty{}
    case +h <> t:
      pick_kind(U32.is_eq(n, 0), h, kind_at(t, (n - 1 : U32)))

def is_editing(+st: W.St) -> Bool:
  U32.is_eq(W.play_mode(st), 0)

def make_one(+st: W.St, +m: Pre.Made) -> W.St:
  +c = W.cut(st)
  +s = Pre.add(W.scene(st), [m])
  W.with_dirty(W.with_cut(W.chosen(W.with_scene(st, s), (U32.from_nat(S.count(s)) - 1 : U32)), W.rebuilt(c, List.append(&2, Pre.Made, W.made(c), [m]), W.removed(c))), True{})

def made(+st: W.St, +n: U32) -> W.St:
  +k = kind_at(Pre.kinds(), n)
  P.pick_st(is_editing(st), make_one(st, Pre.Made{free(names(W.scene(st)), Pre.kind_name(k)), k, Tr.identity()}), st)

# ---------- Deleting ----------

def keep_made(gone: Bool, +h: Pre.Made, rest: List<&2, Pre.Made>) -> List<&2, Pre.Made>:
  match gone:
    case True{}:
      rest
    case False{}:
      h <> rest

def without_made(ms: List<&2, Pre.Made>, +name: String) -> List<&2, Pre.Made>:
  match ms:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep_made(String.eq(Pre.name_of(h), name), h, without_made(t, name))

def made_has(ms: List<&2, Pre.Made>, +name: String) -> Bool:
  match ms:
    case Nil{}:
      False{}
    case +h <> t:
      (String.eq(Pre.name_of(h), name) || made_has(t, name))

def keep_rule(gone: Bool, +h: R.Rule, rest: List<&2, R.Rule>) -> List<&2, R.Rule>:
  match gone:
    case True{}:
      rest
    case False{}:
      h <> rest

def rules_without(rs: List<&2, R.Rule>, +name: String) -> List<&2, R.Rule>:
  match rs:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep_rule(String.eq(R.thing(h), name), h, rules_without(t, name))

def names_rule(rs: List<&2, R.Rule>, +name: String) -> Bool:
  match rs:
    case Nil{}:
      False{}
    case +h <> t:
      (String.eq(R.thing(h), name) || names_rule(t, name))

# A thing made in the editor leaves the made list; a thing of the code is written as removed.
def cut_after(+c: W.Cut, +name: String) -> W.Cut:
  P.pick_cut(made_has(W.made(c), name), W.rebuilt(c, without_made(W.made(c), name), W.removed(c)), W.rebuilt(c, W.made(c), List.append(&2, String, W.removed(c), [name])))

# The rules that name a thing go with it (they are its components); the rest stay as they are.
def ruled_after(+st: W.St, +name: String) -> W.St:
  P.pick_st(names_rule(W.rules(st), name), W.with_rules(st, rules_without(W.rules(st), name)), st)

def delete_one(+st: W.St, +name: String) -> W.St:
  W.with_dirty(W.chosen(W.with_cut(ruled_after(W.with_scene(st, Save.without(W.scene(st), [name])), name), cut_after(W.cut(st), name)), 0), True{})

def deleted(+st: W.St) -> W.St:
  P.pick_st((is_editing(st) && W.in_scene(st)), delete_one(st, S.name(S.at(W.scene(st), W.selected(st)))), st)

# ---------- Saving ----------

def place_of(xs: List<&2, S.Thing>, +name: String, +now: Tr.Transform) -> Tr.Transform:
  match xs:
    case Nil{}:
      now
    case +h <> t:
      P.pick_place(String.eq(S.name(h), name), S.place(h), place_of(t, name, now))

# The things made, each at the place it has now in the scene.
def made_now(ms: List<&2, Pre.Made>, +s: S.Scene) -> List<&2, Pre.Made>:
  match ms:
    case Nil{}:
      Nil{}
    case +h <> t:
      Pre.Made{n, k, p} = h
      Pre.Made{n, k, place_of(S.things(s), n, p)} <> made_now(t, s)

# The text of the scene's saved file: the places that differ from the code (base), the things made,
# the things deleted, and the rules when they are the editor's own.
def save_text(+st: W.St, +base: S.Scene, +now: S.Scene) -> String:
  +c = W.cut(st)
  Save.text(Rc.sample(), W.project_folder(W.files(st)), W.scene_name(c), Save.changed(base, now), Pre.lines(made_now(W.made(c), now)), W.removed(c), W.own_rules(st), W.rules(st))

# Where the scene's saved file goes, inside the project's folder.
def save_path(+st: W.St) -> String:
  Save.file(W.scene_name(W.cut(st)))
