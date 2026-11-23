# Editing the scene's rules (engine/script/rule.bend) from the Inspector: a rule is a component of
# the thing it names, as a UnityEvent entry is a row of its component, with its trigger and its
# response picked from menus and its numbers typed.
#
# A rule is found by its place in the scene's list of rules (k), so two rules of one thing stay
# apart.
#
#   added(rs, thing)          a new rule for the thing: when it is clicked, turn 0° (it does
#                             nothing until a number is typed)
#   dropped(rs, k)            rule k removed
#   with_when(rs, k, n)       rule k's trigger: Clicked (0) or Started (1)
#   with_does(rs, k, n)       rule k's response: Move (0), Turn (1) or Play (2), with its numbers at 0
#   with_number(rs, k, a, x)  Move's axis a (meters), or Turn's angle (x in degrees)
#   with_clip(rs, k, c)       the clip Play plays (0 is locomotion)
#
# Limits now:
# - A rule names its thing by name (engine/script/rule.bend): renaming a thing leaves its rules
#   behind.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/core/quat.bend as Q
import ../../engine/script/rule.bend as R

def added(+rs: List<&2, R.Rule>, +thing: String) -> List<&2, R.Rule>:
  List.append(&2, R.Rule, rs, [R.Rule{thing, R.Trigger.Clicked{}, R.Response.Turn{0.0}}])

def pick_rule(c: Bool, +a: R.Rule, +b: R.Rule) -> R.Rule:
  match c:
    case True{}:
      a
    case False{}:
      b

def drop_if(c: Bool, +h: R.Rule, rest: List<&2, R.Rule>) -> List<&2, R.Rule>:
  match c:
    case True{}:
      rest
    case False{}:
      h <> rest

def dropped(rs: List<&2, R.Rule>, +k: U32) -> List<&2, R.Rule>:
  match rs:
    case Nil{}:
      Nil{}
    case +h <> t:
      drop_if(U32.is_eq(k, 0), h, dropped(t, (k - 1 : U32)))

# ---------- Trigger and response ----------

def trigger_of(+n: U32) -> R.Trigger:
  match n:
    case 1:
      R.Trigger.Started{}
    case _:
      R.Trigger.Clicked{}

def trigger_n(+w: R.Trigger) -> U32:
  match w:
    case R.Trigger.Clicked{}:
      0
    case R.Trigger.Started{}:
      1

def response_of(+n: U32) -> R.Response:
  match n:
    case 0:
      R.Response.Move{V.V3{0.0, 0.0, 0.0}}
    case 2:
      R.Response.Play{0}
    case _:
      R.Response.Turn{0.0}

def response_n(+d: R.Response) -> U32:
  match d:
    case R.Response.Move{_}:
      0
    case R.Response.Turn{_}:
      1
    case R.Response.Play{_}:
      2

def trigger_names() -> List<&2, String>:
  ["Clicked", "Started"]

def response_names() -> List<&2, String>:
  ["Move", "Turn", "Play"]

# ---------- One rule changed ----------

def set_axis(+v: V.V3, +a: U32, +x: F32) -> V.V3:
  V.V3{+vx, +vy, +vz} = v
  match a:
    case 0:
      V.V3{x, vy, vz}
    case 1:
      V.V3{vx, x, vz}
    case _:
      V.V3{vx, vy, x}

def numbered(+d: R.Response, +a: U32, +x: F32) -> R.Response:
  match d:
    case R.Response.Move{v}:
      R.Response.Move{set_axis(v, a, x)}
    case R.Response.Turn{_}:
      R.Response.Turn{Q.to_radians(x)}
    case R.Response.Play{c}:
      R.Response.Play{c}

def clipped(+d: R.Response, +c: U32) -> R.Response:
  match d:
    case R.Response.Play{_}:
      R.Response.Play{c}
    case R.Response.Move{v}:
      R.Response.Move{v}
    case R.Response.Turn{a}:
      R.Response.Turn{a}

# What a change does to one rule: 0 its trigger, 1 its response, 2 a number, 3 its clip.
type Change is Data:
  Change.When{n: U32}
  Change.Does{n: U32}
  Change.Number{axis: U32, x: F32}
  Change.Clip{c: U32}

def pick_does(c: Bool, +a: R.Response, +b: R.Response) -> R.Response:
  match c:
    case True{}:
      a
    case False{}:
      b

def changed(+r: R.Rule, +ch: Change) -> R.Rule:
  R.Rule{+n, +w, +d} = r
  match ch:
    case Change.When{t}:
      R.Rule{n, trigger_of(t), d}
    case Change.Does{t}:
      R.Rule{n, w, pick_does(U32.is_eq(t, response_n(d)), d, response_of(t))}
    case Change.Number{a, x}:
      R.Rule{n, w, numbered(d, a, x)}
    case Change.Clip{c}:
      R.Rule{n, w, clipped(d, c)}

# Rule k with a change; every other rule as it is.
def change(rs: List<&2, R.Rule>, +k: U32, +ch: Change) -> List<&2, R.Rule>:
  match rs:
    case Nil{}:
      Nil{}
    case +h <> t:
      pick_rule(U32.is_eq(k, 0), changed(h, ch), h) <> change(t, (k - 1 : U32), ch)

def with_when(+rs: List<&2, R.Rule>, +k: U32, +n: U32) -> List<&2, R.Rule>:
  change(rs, k, Change.When{n})

def with_does(+rs: List<&2, R.Rule>, +k: U32, +n: U32) -> List<&2, R.Rule>:
  change(rs, k, Change.Does{n})

def with_number(+rs: List<&2, R.Rule>, +k: U32, +a: U32, +x: F32) -> List<&2, R.Rule>:
  change(rs, k, Change.Number{a, x})

def with_clip(+rs: List<&2, R.Rule>, +k: U32, +c: U32) -> List<&2, R.Rule>:
  change(rs, k, Change.Clip{c})

# ---------- Reading a rule ----------

# Move's vector (zero for another response).
def move_of(+d: R.Response) -> V.V3:
  match d:
    case R.Response.Move{v}:
      v
    case _:
      V.V3{0.0, 0.0, 0.0}

# Turn's angle in degrees (zero for another response).
def degrees_of(+d: R.Response) -> F32:
  match d:
    case R.Response.Turn{a}:
      Q.to_deg(a)
    case _:
      0.0

def clip_of(+d: R.Response) -> U32:
  match d:
    case R.Response.Play{c}:
      c
    case _:
      0
