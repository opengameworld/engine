# One tick of a game: what the World does in 1/60 s (engine/play/tick.bend's step).
#
# The order is fixed, as Unreal's tick groups and Bevy's schedules fix theirs: first the input
# moves the characters (engine/anim/locomotion.bend), then the rules answer what happened
# (engine/script/respond.bend: a click, Play starting), then every figure's clock moves on, so
# the pose drawn is the one for where the character stands now.
#
# Pressing Play is motion asked for, as pressing Play on a clip is (engine/anim/figure.bend's
# play): a tick moves the figures with reduce motion on too. What reduce motion changes in Play
# is the camera's (engine/scene/camera.bend's follow).
#
# A project's scripts run after the rules (engine/script/, projects/<name>/scripts/): their start
# once, on the tick that answers Play starting (Unity's Start, Godot's _ready, Bevy's Startup),
# and their update on every tick (Unity's Update, Godot's _process, Bevy's Update), with the
# tick's length. They are passed in as templates (~start, ~update): a compiled function, chosen
# when the project is built, as Bevy's systems are added to its App before it runs. tick() is a
# tick with no scripts.
#
# Limits now:
# - Every character reads the same input.
# - A script sees the whole scene; it finds its things by name (no query by component yet).

import Base
import ../scene/scene.bend as S
import ../anim/locomotion.bend as Loco
import ./tick.bend as Tick
import ../script/rule.bend as R
import ../script/respond.bend as Resp

def Game.is_start(+h: R.Happening) -> Bool:
  match h:
    case R.Happening.Started{}:
      True{}
    case R.Happening.Clicked{_}:
      False{}

# Did Play start in this tick?
def Game.starts(hs: List<&2, R.Happening>) -> Bool:
  match hs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (Game.is_start(h) || Game.starts(t))

def Game.started(~start: @+s: S.Scene -> S.Scene, go: Bool, s: S.Scene) -> S.Scene:
  match go:
    case True{}:
      start(s)
    case False{}:
      s

def tick_with(~start: @+s: S.Scene -> S.Scene, ~update: @+s: S.Scene -> @+dt: F32 -> S.Scene, s: S.Scene, +i: Loco.Input, +rs: List<&2, R.Rule>, +hs: List<&2, R.Happening>) -> S.Scene:
  S.advance(update(Game.started(~start, Game.starts(hs), Resp.respond(Loco.drive(s, i, Tick.step()), rs, hs)), Tick.step()), Tick.step(), False{})

def Game.no_start(+s: S.Scene) -> S.Scene:
  s

def Game.no_update(+s: S.Scene, +dt: F32) -> S.Scene:
  s

def tick(s: S.Scene, +i: Loco.Input, +rs: List<&2, R.Rule>, +hs: List<&2, R.Happening>) -> S.Scene:
  tick_with(~Game.no_start, ~Game.no_update, s, i, rs, hs)
