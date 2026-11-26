# Tests of a project's scripts in Play (engine/play/game.bend's tick_with, engine/play/play.bend's
# frame_with): start runs once, on the first tick, and update on every tick, after the rules. The
# script here is written as editor/project/templates.bend's script is, with a body: it raises a
# thing named "Box" by 1 m at start and by 1 m per second in update.
#
# Limits now:
# - Checked with one script; the registry's order of several is tools/project/registry.js's.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/core/transform.bend as Tr
import ../../engine/scene/scene.bend as S
import ../../engine/play/play.bend as Play
import ../../engine/play/tick.bend as Tick
import ../../engine/script/run.bend as Run

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.001)

def box() -> S.Scene:
  S.scene([S.thing("Box", Tr.identity(), S.Hidden{})])

def raise(+t: S.Thing, +by: F32) -> S.Thing:
  +p = S.place(t)
  S.with_place(t, Tr.with_position(p, V.add(Tr.position(p), V.V3{0.0, by, 0.0})))

# The script: start raises the Box by 1 m, update by 1 m per second.
def start(+s: S.Scene) -> S.Scene:
  S.put(s, 0, raise(S.at(s, 0), 1.0))

def update(+s: S.Scene, +dt: F32) -> S.Scene:
  S.put(s, 0, raise(S.at(s, 0), dt))

def frames(n: Nat, +x: Play.Session, +dt: F32) -> Play.Session:
  match n:
    case 0n:
      x
    case 1n+k:
      frames(k, Play.frame_with(~start, ~update, ~Run.none, x, dt, False{}), dt)

def height(+x: Play.Session) -> F32:
  V.y(Tr.position(S.place(S.at(Play.shown(x), 0))))

def playing() -> Play.Session:
  Play.start(Play.edit(box()))

def checks() -> List<&2, Check>:
  [Check{"before a tick, nothing ran", close(height(playing()), 0.0)},
   Check{"one tick: start once, then update for one tick", close(height(frames(1n, playing(), Tick.step())), (1.0 + Tick.step() : F32))},
   Check{"one second of ticks: start once, update sixty times", close(height(frames(60n, playing(), Tick.step())), 2.0)},
   Check{"while editing, scripts do not run", close(height(frames(10n, Play.edit(box()), Tick.step())), 0.0)},
   Check{"Stop gives back the scene as it was edited", close(height(Play.to_mode(frames(30n, playing(), Tick.step()), 0)), 0.0)},
   Check{"Step runs one tick with the scripts", close(height(Play.step_with(~start, ~update, ~Run.none, Play.to_mode(playing(), 2))), (1.0 + Tick.step() : F32))}]
