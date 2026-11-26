# Saved by the editor for the scene "Animation" of the project "animation"
# (engine/scene/save.bend). Do not edit by hand: Save in the editor writes it again. places()
# are the places that differ from Animation.bend's, made() the things made in the editor,
# removed() the things of the code deleted, and, when has_rules() is True, rules() are the
# scene's rules in place of the code's.

import Base
import ../../../../engine/core/vec.bend as V
import ../../../../engine/core/quat.bend as Q
import ../../../../engine/core/transform.bend as Tr
import ../../../../engine/scene/save.bend as Save
import ../../../../engine/script/rule.bend as R
import ../../../prefabs.bend as Pre

def places() -> List<&2, Save.Placed>:
  []

def made() -> List<&2, Pre.Made>:
  []

def removed() -> List<&2, String>:
  []

def has_rules() -> Bool: False{}

def rules() -> List<&2, R.Rule>:
  [R.Rule{"Mannequin", R.Trigger.Clicked{}, R.Response.Turn{1.5707964}}]
