# The Animation project: the place to try the animation library on the
# mannequin.
#
# The scene is the mannequin (mannequin/scene.bend), standing at the
# World's origin. Open the Animation tab (editor/animation/view.bend): a
# click on a clip of the library tries it on the mannequin, Add keeps it,
# and the transport under the viewport plays it.
#
# Limits now:
# - What is added lives while the page is open: nothing writes it back to
#   this file, and a reload starts from the mannequin with no clips.
# - One character. The library works on any character that keeps the rig
#   standard, and the mannequin is the only one there is.

import Base
import ../../engine/scene.bend as S
import ../../engine/transform.bend as Tr
import ../../mannequin/scene.bend as Mannequin

def start() -> S.Scene:
  S.Scene{[
    S.Thing{"Mannequin", Tr.identity(), S.Rigged{Mannequin.figure()}}]}
