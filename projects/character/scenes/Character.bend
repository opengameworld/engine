# The Character project: a clean place to build and test the engine's
# animation system, one step at a time.
#
# This is content. It uses only the engine's own test character, a short
# arm written by hand (arm.bend). The standard character is the Mannequin
# project (mannequin/).
#
# Limits now:
# - The arm has no skin: it is drawn as lines, one per bone, colored by
#   role (engine/anim/pose.bend).

import Base
import ../../../engine/script/rule.bend as R
import ../../../engine/scene/scene.bend as S
import ../../../engine/core/transform.bend as Tr
import ../../../engine/anim/figure.bend as Fig
import ../arm.bend as Arm

def start() -> S.Scene:
  S.scene([
    S.thing("Arm", Tr.identity(), S.Rigged{Fig.make(Arm.skeleton(), "", Arm.rules())})])

# What the scene's things do in Play (engine/script/rule.bend).
def rules() -> List<&2, R.Rule>:
  []
