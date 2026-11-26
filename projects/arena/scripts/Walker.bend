# The script Walker: its thing walks along X at its speed, and counts the Pings it receives.
# The same script on two things walks each at its own speed (each has its own State).

import Base
import ../../../engine/script/me.bend as Me
import ../../../engine/core/vec.bend as V
import ../messages.bend as Msg
import ../messages_generated.bend as Mail

# This script's fields: each thing it is on has its own.
type State is Data:
  State{speed: F32, pings: U32}

def initial() -> State:
  State{1.0, 0}

def runs() -> Me.Runs:
  Me.both()

def start(+me: Me.Me, +s: State) -> Me.Me & State:
  (me, s)

def Walker.is_ping(+m: Msg.Message) -> U32:
  match m:
    case Msg.Ping{}:
      1
    case _:
      0

def Walker.pings(gs: List<&2, Mail.Got>) -> U32:
  match gs:
    case Nil{}:
      0
    case Con{+h, t}:
      (Walker.is_ping(Mail.message(h)) + Walker.pings(t) : U32)

def update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State:
  State{speed, pings} = s
  (Me.moved(me, V.V3{(speed * dt : F32), 0.0, 0.0}), State{speed, (pings + Walker.pings(Mail.received(me)) : U32)})
