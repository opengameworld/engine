# The script Target: counts the Hits its thing receives, and adds up their power.

import Base
import ../../../engine/script/me.bend as Me
import ../messages.bend as Msg
import ../messages_generated.bend as Mail

type State is Data:
  State{hits: U32, power: F32}

def initial() -> State:
  State{0, 0.0}

def runs() -> Me.Runs:
  Me.server()

def start(+me: Me.Me, +s: State) -> Me.Me & State:
  (me, s)

def Target.hit(+s: State, +p: F32) -> State:
  State{hits, power} = s
  State{(hits + 1 : U32), (power + p : F32)}

def Target.add(+m: Msg.Message, +s: State) -> State:
  match m:
    case Msg.Hit{p}:
      Target.hit(s, p)
    case _:
      s

def Target.all(gs: List<&2, Mail.Got>, +s: State) -> State:
  match gs:
    case Nil{}:
      s
    case Con{+h, t}:
      Target.all(t, Target.add(Mail.message(h), s))

def update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State:
  (me, Target.all(Mail.received(me), s))
