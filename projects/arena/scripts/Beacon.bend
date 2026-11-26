# The script Beacon: every `every` seconds it sends a Ping to every thing tagged "crowd".

import Base
import ../../../engine/script/me.bend as Me
import ../messages.bend as Msg
import ../messages_generated.bend as Mail

type State is Data:
  State{every: F32, left: F32}

def initial() -> State:
  State{1.0, 1.0}

def runs() -> Me.Runs:
  Me.server()

def start(+me: Me.Me, +s: State) -> Me.Me & State:
  (me, s)

def Beacon.tick(due: Bool, +me: Me.Me, +every: F32, +left: F32) -> Me.Me & State:
  match due:
    case True{}:
      (Mail.broadcast(me, "crowd", Msg.Ping{}), State{every, every})
    case False{}:
      (me, State{every, left})

def update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State:
  State{every, left} = s
  +now = (left - dt : F32)
  Beacon.tick(F32.is_le(now, 0.0), me, every, now)
