# The script teste: what the project's scenes do in Play, as two pure functions from a
# scene to the next one (a system, in Bevy's word). The engine runs every script of the project,
# in the order of their file names, after the rules (engine/play/game.bend).
#
# A thing is found by its name: S.things(s) lists them, S.at(s, i) and S.put(s, i, t) read and
# write the one at place i (engine/scene/scene.bend).

import Base
import ../../../engine/scene/scene.bend as S

# Once, on the first tick of Play (Unity's Start, Godot's _ready).
def start(+s: S.Scene) -> S.Scene:
  s

# Every tick, dt seconds long (1/60 s) (Unity's Update, Godot's _process).
def update(+s: S.Scene, +dt: F32) -> S.Scene:
  s
