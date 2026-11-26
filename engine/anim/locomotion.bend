# Locomotion: the character walks through the World.
#
# Input moves the character's place (its thing's Transform), and the figure's speed follows, so
# the animator blends idle and walk by itself. Clips stay in place (they do not move the
# character); code moves it, as a pure step(state, input, dt) a server can run again to check a
# player (the study's decision: in-place clips, movement by code).
#
# The character reads two actions (engine/input/actions.bend), never keys: Walk, from -1 (back)
# to 1 (ahead), and Turn, from -1 (right) to 1 (left). While Walk is held the character speeds
# up to the walk's speed, turns at a steady rate, and slows down when let go. context() is the
# keys a character walks with unless a game says otherwise: W and S walk, A and D turn, as two
# axes (Unreal's Axis1D with Negate). The character faces its own +Z; turning left turns it
# toward its +X.
#
# It runs only in Play (engine/play/), one fixed tick at a time: pressing Play is motion asked
# for, as pressing Play on a clip is (engine/anim/figure.bend), so it runs with reduce motion on
# too. What reduce motion changes in Play is the camera's (engine/scene/camera.bend's follow).
#
# Limits now:
# - Flat ground: the character's height never changes.
# - Nothing blocks it: no collision.
# - Turning turns the whole body at once (no turn-in-place clip).
# - Every character in the scene reads the same actions: there is no "the player's character".

import Base
import ../core/vec.bend as V
import ../core/quat.bend as Q
import ../core/transform.bend as Tr
import ./figure.bend as Fig
import ./clip.bend as C
import ../scene/scene.bend as S
import ../input/keys.bend as Keys
import ../input/keyboard.bend as Kb
import ../input/actions.bend as Act

type Input is Data:
  Input{walk: F32, turn: F32}

def still() -> Input:
  Input{0.0, 0.0}

# The keys a character walks with unless a game says otherwise.
def context() -> Act.Context:
  Act.Context{"walk", [Act.Bind.Axis{"Walk", Keys.w(), Keys.s()}, Act.Bind.Axis{"Turn", Keys.a(), Keys.d()}]}

# What the actions say this tick.
def read(+b: Kb.Keyboard, +cs: List<&2, Act.Context>) -> Input:
  Input{Act.value(b, cs, "Walk"), Act.value(b, cs, "Turn")}

def accel() -> F32: 3.0             # m/s², speeding up and slowing down
def turn_rate() -> F32: 2.0         # rad/s while Turn is held

# The heading (radians around Y) of a place's rotation, and back.
def y_part(q: Q.Q) -> F32:
  Q.Q{_, y, _, _} = q
  y

def heading(+p: Tr.Transform) -> F32:
  +q = Tr.rotation(p)
  (2.0 * Q.atan2(y_part(q), Q.w_part(q)) : F32)

def facing(+h: F32) -> Q.Q:
  Q.axis_angle(V.V3{0.0, 1.0, 0.0}, h)

def ahead(+h: F32) -> V.V3:
  V.V3{F32.sin(h), 0.0, F32.cos(h)}

def toward(+v: F32, +target: F32, +by: F32) -> F32:
  F32.clamp(target, (v - by : F32), (v + by : F32))

# One tick of the actions.
def run(+t: S.Thing, i: Input, +dt: F32) -> S.Thing:
  Input{+w, +tn} = i
  +p = S.place(t)
  +fig = S.figure(S.look(t))
  +top = C.speed(Fig.walk(fig))
  +v = toward(Fig.param(fig, "speed"), (w * top : F32), (accel() * dt : F32))
  +h = (heading(p) + tn * turn_rate() * dt : F32)
  +pos = V.add(Tr.position(p), V.scale(ahead(h), (v * dt : F32)))
  S.with_look(S.with_place(t, Tr.with_rotation(Tr.with_position(p, pos), facing(h))), S.Rigged{Fig.set_param(fig, "speed", F32.abs(v))})

def Loco.when_rigged(rigged: Bool, +t: S.Thing, +i: Input, +dt: F32) -> S.Thing:
  match rigged:
    case True{}:
      run(t, i, dt)
    case False{}:
      t

# One thing, driven: a character walks, anything else stays as it is.
def drive_thing(+t: S.Thing, +i: Input, +dt: F32) -> S.Thing:
  Loco.when_rigged(S.is_rigged(t), t, i, dt)

def drive_go(xs: List<&2, S.Thing>, +i: Input, +dt: F32) -> List<&2, S.Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      drive_thing(h, i, dt) <> drive_go(t, i, dt)

# Every character in the scene, driven by the same input.
def drive(+s: S.Scene, +i: Input, +dt: F32) -> S.Scene:
  S.with_things(s, drive_go(S.things(s), i, dt))
