# Numerical tests of engine/anim/locomotion.bend on the Character project's arm.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/core/transform.bend as Tr
import ../../engine/scene/scene.bend as S
import ../../engine/anim/figure.bend as Fig
import ../../engine/anim/locomotion.bend as Loco
import ../../projects/character/scenes/Character.bend as Ch

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.001)

def close3(+a: V.V3, +b: V.V3) -> Bool:
  (close(V.x(a), V.x(b)) && close(V.y(a), V.y(b)) && close(V.z(a), V.z(b)))

def place(+s: S.Scene) -> Tr.Transform:
  S.place(S.at(s, 0))

def speed(+s: S.Scene) -> F32:
  Fig.param(S.figure(S.look(S.at(s, 0))), "speed")

# n frames of 0.1 s each, with the same walk and turn held (-1 to 1).
def run(fuel: Nat, +s: S.Scene, +w: F32, +t: F32) -> S.Scene:
  match fuel:
    case 0n:
      s
    case 1n+k:
      run(k, Loco.drive(s, Loco.Input{w, t}, 0.1), w, t)

def start() -> S.Scene:
  Ch.start()

def neg(+x: F32) -> F32: (0.0 - x : F32)

def checks() -> List<&2, Check>:
  [Check{"holding Walk for a second reaches the walk's speed, 1.3 m/s",
     close(speed(run(10n, start(), 1.0, 0.0)), 1.3)},
   Check{"letting go for a second slows the character to a stop",
     close(speed(run(10n, run(10n, start(), 1.0, 0.0), 0.0, 0.0)), 0.0)},
   Check{"holding Walk moves the character forward, never sideways",
     close(V.x(Tr.position(place(run(10n, start(), 1.0, 0.0)))), 0.0)},
   Check{"holding Walk back moves it along its -Z",
     F32.is_lt(V.z(Tr.position(place(run(10n, start(), neg(1.0), 0.0)))), 0.0)},
   Check{"holding Turn left for 0.8 s turns the character 1.6 rad toward +X",
     close(Loco.heading(place(run(8n, start(), 0.0, 1.0))), 1.6)},
   Check{"with nothing held, nothing moves",
     close3(Tr.position(place(run(10n, start(), 0.0, 0.0))), V.V3{0.0, 0.0, 0.0})}]
