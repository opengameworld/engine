# The script Follower: its thing walks to its target (a direct reference, set in the Inspector or
# by name in the scene's code) at its speed, and sends the target a Hit each second it is there.
# A target that is gone (or no target) leaves the thing where it is.

import Base
import ../../../engine/script/me.bend as Me
import ../../../engine/script/world.bend as World
import ../../../engine/scene/id.bend as Id
import ../../../engine/core/vec.bend as V
import ../messages.bend as Msg
import ../messages_generated.bend as Mail

type State is Data:
  State{target: Id.Id, speed: F32, wait: F32}

def initial() -> State:
  State{Me.nobody(), 1.5, 0.0}

def runs() -> Me.Runs:
  Me.both()

def start(+me: Me.Me, +s: State) -> Me.Me & State:
  (me, s)

# How much of the way to go in this tick: all of it when it is shorter than a step.
def Follower.part(+far: F32, +step: F32) -> F32:
  F32.min(1.0, (step / F32.max(far, step) : F32))

def Follower.hit(due: Bool, +me: Me.Me, +target: Id.Id, +speed: F32, +wait: F32) -> Me.Me & State:
  match due:
    case True{}:
      (Mail.send(me, target, Msg.Hit{speed}), State{target, speed, 1.0})
    case False{}:
      (me, State{target, speed, wait})

def Follower.there(near: Bool, +me: Me.Me, +target: Id.Id, +speed: F32, +wait: F32, +dt: F32) -> Me.Me & State:
  match near:
    case True{}:
      Follower.hit(F32.is_le(wait, 0.0), me, target, speed, (wait - dt : F32))
    case False{}:
      (me, State{target, speed, wait})

def update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State:
  State{target, speed, wait} = s
  +here = Me.position(me)
  +to = World.position_of(Me.world(me), target, here)
  +far = V.dist(here, to)
  +moved = Me.moved(me, V.scale(V.sub(to, here), Follower.part(far, (speed * dt : F32))))
  Follower.there((World.exists(Me.world(me), target) && F32.is_le(far, (speed * dt : F32))), moved, target, speed, wait, dt)
