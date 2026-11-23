# Answering rules: one pure step from a scene and what happened in a tick to the next scene.
#
#   respond(scene, rules, happenings)
#
# For each thing that happened, in order, every rule whose trigger it is does its response, in
# the order the rules are written: the result is the same on every machine (Unity warns that
# the order of the same event across objects is not reliable; here it is). A response never
# makes something else happen in the same tick: what it causes is seen by the next tick (Bevy's
# observers and Godot's signals run at once and can cascade; these do not). It runs in Play
# only, inside engine/play/game.bend's tick, after the input moved the characters.
# References: docs/references/scripting-and-events.md.
#
# Limits now:
# - A rule finds its thing by name: two things with one name both answer.
# - Turn turns around the World's up only.

import Base
import ../core/vec.bend as V
import ../core/quat.bend as Q
import ../core/transform.bend as Tr
import ../anim/figure.bend as Fig
import ../scene/scene.bend as S
import ./rule.bend as R

# A response, done to a thing.
def Resp.look_play(l: S.Look, +clip: U32) -> S.Look:
  match l:
    case S.Rigged{f}:
      S.Rigged{Fig.set_on(Fig.show(f, clip), True{})}
    case S.Shown{sh, m}:
      S.Shown{sh, m}
    case S.Hidden{}:
      S.Hidden{}

def apply(+d: R.Response, t: S.Thing) -> S.Thing:
  match d:
    case R.Response.Move{by}:
      S.Thing{n, +p, l} = t
      S.Thing{n, Tr.with_position(p, V.add(Tr.position(p), by)), l}
    case R.Response.Turn{a}:
      S.Thing{n, +p, l} = t
      S.Thing{n, Tr.with_rotation(p, Q.mul(Q.axis_angle(V.V3{0.0, 1.0, 0.0}, a), Tr.rotation(p))), l}
    case R.Response.Play{c}:
      S.Thing{n, p, l} = t
      S.Thing{n, p, Resp.look_play(l, c)}

def Resp.if_named(hit: Bool, +d: R.Response, t: S.Thing) -> S.Thing:
  match hit:
    case True{}:
      apply(d, t)
    case False{}:
      t

# Every thing with the rule's name does its response.
def Resp.on_named(xs: List<&2, S.Thing>, +name: String, +d: R.Response) -> List<&2, S.Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Resp.if_named(String.eq(S.name(h), name), d, h) <> Resp.on_named(t, name, d)

def Resp.do(+s: S.Scene, +r: R.Rule) -> S.Scene:
  S.Scene{xs} = s
  S.Scene{Resp.on_named(xs, R.thing(r), R.does(r))}

def Resp.clicked(+h: R.Happening, +name: String, +s: S.Scene) -> Bool:
  match h:
    case R.Happening.Clicked{i}:
      (U32.is_lt(i, U32.from_nat(S.count(s))) && String.eq(S.name(S.at(s, i)), name))
    case R.Happening.Started{}:
      False{}

def Resp.started(+h: R.Happening) -> Bool:
  match h:
    case R.Happening.Started{}:
      True{}
    case R.Happening.Clicked{_}:
      False{}

# Does this rule answer this happening, in this scene?
def Resp.answers_when(w: R.Trigger, +r: R.Rule, +h: R.Happening, +s: S.Scene) -> Bool:
  match w:
    case R.Trigger.Clicked{}:
      Resp.clicked(h, R.thing(r), s)
    case R.Trigger.Started{}:
      Resp.started(h)

def Resp.answers(+r: R.Rule, +h: R.Happening, +s: S.Scene) -> Bool:
  Resp.answers_when(R.when(r), r, h, s)

def Resp.maybe(hit: Bool, +s: S.Scene, +r: R.Rule) -> S.Scene:
  match hit:
    case True{}:
      Resp.do(s, r)
    case False{}:
      s

# One happening, answered by every rule in order.
def Resp.rules(rs: List<&2, R.Rule>, +h: R.Happening, +s: S.Scene) -> S.Scene:
  match rs:
    case Nil{}:
      s
    case Con{+r, t}:
      Resp.rules(t, h, Resp.maybe(Resp.answers(r, h, s), s, r))

def Resp.all(hs: List<&2, R.Happening>, +rs: List<&2, R.Rule>, +s: S.Scene) -> S.Scene:
  match hs:
    case Nil{}:
      s
    case Con{+h, t}:
      Resp.all(t, rs, Resp.rules(rs, h, s))

def respond(+s: S.Scene, +rs: List<&2, R.Rule>, +hs: List<&2, R.Happening>) -> S.Scene:
  Resp.all(hs, rs, s)
