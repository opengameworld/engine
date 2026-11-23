# The Mannequin project's scene: the standard character alone, at the World's origin, as
# mannequin/scene.bend makes it.

import Base
import ../../../engine/scene/scene.bend as S
import ../../../engine/script/rule.bend as R
import ../../../mannequin/scene.bend as Mannequin

def start() -> S.Scene:
  Mannequin.start()

# What the scene's things do in Play (engine/script/rule.bend).
def rules() -> List<&2, R.Rule>:
  []
