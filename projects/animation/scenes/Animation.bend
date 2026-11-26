# The Animation project: the place to try the animation library on the
# mannequin.
#
# The scene is the mannequin (mannequin/scene.bend), standing at the
# World's origin. Pick a clip in the Project window (Library/Animations): it is tried on the
# mannequin, Add keeps it, and the dock's Animation tab plays it.
#
# It also holds the engine's first rule (engine/script/rule.bend): in Play, a click on the
# mannequin turns it a quarter turn, so a click doing something is plain to see.
#
# Limits now:
# - A clip added to the mannequin lives while the page is open: Save does not write clips yet,
#   and a reload starts from the mannequin with no clips.
# - One character. The library works on any character that keeps the rig
#   standard, and the mannequin is the only one there is.

import Base
import ../../../engine/scene/scene.bend as S
import ../../../engine/core/transform.bend as Tr
import ../../../mannequin/scene.bend as Mannequin
import ../../../engine/script/rule.bend as R

def start() -> S.Scene:
  S.scene([
    S.thing("Mannequin", Tr.identity(), S.Rigged{Mannequin.figure()})])

# What the scene's things do in Play.
def rules() -> List<&2, R.Rule>:
  [R.Rule{"Mannequin", R.Trigger.Clicked{}, R.Response.Turn{1.5707964}}]
