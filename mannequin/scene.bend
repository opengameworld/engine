# The Mannequin project: the engine's standard character, standing at the
# World's origin.
#
# The mannequin is what Unreal's Manny and Quinn are to Unreal: the
# character the engine opens with, the one its clips are made on and shown
# on, and the rig every other character is checked against and retargeted
# to. It is content, not engine code: a game may use it or bring its own
# character, as long as that character keeps the rig standard
# (engine/anim/skeleton.bend).
#
# What is here:
# - rig.json        how the source file is read into the standard
# - gen/            what tools/gltf.ts wrote: skeleton, helper rules,
#                   weights (as Bend, for the laws) and the skin
# - LAWS.bend       the laws the mannequin keeps
# - source/, gltf/  the files it was made from
# - CREDITS.md      whose work it is; the credit goes wherever it goes
#
# Limits now:
# - One mesh and one outfit. The 64 Chain bones (hair, sleeves, hem, hood)
#   belong to this outfit, not to the standard's core; they stay at rest
#   until spring chains exist.
# - No clips of its own: it plays the code-made idle and walk
#   (engine/anim/gait.bend).
# - No levels of detail: always all 171 bones.

import Base
import ../engine/scene/scene.bend as S
import ../engine/core/transform.bend as Tr
import ../engine/anim/figure.bend as Fig
import ./gen/skeleton.bend as Man
import ./gen/rules.bend as Rules

# The name of the mannequin's skin: the page that draws it gives the files
# under this name (editor/main.js).
def skin() -> String: "mannequin"

def figure() -> Fig.Figure:
  Fig.make(Man.skeleton(), skin(), Rules.rules())

def start() -> S.Scene:
  S.scene([
    S.thing("Mannequin", Tr.identity(), S.Rigged{figure()})])
