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
# Limits now:
# - Every character reads the same input.
# - A project cannot add its own step after the rules yet.

import Base
import ../scene/scene.bend as S
import ../anim/locomotion.bend as Loco
import ./tick.bend as Tick
import ../script/rule.bend as R
import ../script/respond.bend as Resp

def tick(s: S.Scene, +i: Loco.Input, +rs: List<&2, R.Rule>, +hs: List<&2, R.Happening>) -> S.Scene:
  S.advance(Resp.respond(Loco.drive(s, i, Tick.step()), rs, hs), Tick.step(), False{})
