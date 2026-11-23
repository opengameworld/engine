# The Water project's scene: the water plane, written by hand.
#
# This is content. The types (Scene, Thing, Look) are engine code, in
# engine/scene/scene.bend. A scene is a Bend value, so a scene is a .bend file like this one, and
# the laws check it like any other code. What the editor saves for it (places, things made or
# deleted, rules) is saved/Water.bend, beside it (engine/scene/save.bend).
#
# Limits now:
# - The editor shows things in this order; there is no other id.

import Base
import ../../../engine/script/rule.bend as R
import ../../../engine/scene/scene.bend as S
import ../../../engine/core/transform.bend as Tr
import ../water.bend as Water

def start() -> S.Scene:
  S.Scene{[
    S.Thing{"Water", Tr.identity(), S.Shown{Water.shape(), Water.material()}}]}

# What the scene's things do in Play (engine/script/rule.bend).
def rules() -> List<&2, R.Rule>:
  []
