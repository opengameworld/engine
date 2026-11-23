# Numerical tests of engine/play/tick.bend and engine/play/play.bend: the clock's arithmetic is
# float math, which the law checker does not compute.
#
# Limits now:
# - Checked at a few frame lengths, not for every one.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/core/transform.bend as Tr
import ../../engine/scene/scene.bend as S
import ../../engine/play/tick.bend as Tick
import ../../engine/play/play.bend as Play
import ../../projects/character/scene.bend as Ch

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.0001)

def frames(n: Nat, +x: Play.Session, +dt: F32) -> Play.Session:
  match n:
    case 0n:
      x
    case 1n+k:
      frames(k, Play.frame(x, dt, False{}), dt)

# Playing the Character project with W held.
def walking() -> Play.Session:
  Play.key(Play.start(Play.edit(Ch.start())), "KeyW", True{})

def z(+x: Play.Session) -> F32:
  V.z(Tr.position(S.place(S.at(Play.shown(x), 0))))

def checks() -> List<&2, Check>:
  [Check{"a frame of 1/60 s holds one tick", U32.is_eq(Tick.steps(Tick.advance(Tick.zero(), 0.016666668)), 1)},
   Check{"a frame of 1/30 s holds two ticks", U32.is_eq(Tick.steps(Tick.advance(Tick.zero(), 0.033333335)), 2)},
   Check{"a frame of 10 s holds 8 ticks, never more", U32.is_eq(Tick.steps(Tick.advance(Tick.zero(), 10.0)), 8)},
   Check{"after a capped frame, at most one tick of time is left", F32.is_le(Tick.left(Tick.spent(Tick.advance(Tick.zero(), 10.0), 8)), Tick.step())},
   Check{"a frame of 1/120 s holds no tick yet, and the next one does", (U32.is_eq(Tick.steps(Tick.advance(Tick.zero(), 0.008333334)), 0) && U32.is_eq(Tick.steps(Tick.advance(Tick.advance(Tick.zero(), 0.008333334), 0.008333334)), 1))},
   Check{"W held for half a second: 30 frames of 1/60 s and 15 frames of 1/30 s reach the same place",
     close(z(frames(30n, walking(), 0.016666668)), z(frames(15n, walking(), 0.033333335)))},
   Check{"W held moves the character ahead in Play", F32.is_gt(z(frames(30n, walking(), 0.016666668)), 0.0)},
   Check{"Stop after walking gives back the character where it was edited", close(z(Play.stop(frames(30n, walking(), 0.016666668))), 0.0)}]
