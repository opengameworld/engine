# Saved by the editor for the project "mannequin" (engine/scene/save.bend). Do not edit by
# hand: Save in the editor writes it again. Each line of places() is a thing of
# projects/mannequin/scene.bend, by name, and the place it was saved at; when has_rules() is
# True, rules() are the scene's rules in place of the code's. PROJECT.bend puts them back.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/core/quat.bend as Q
import ../../engine/core/transform.bend as Tr
import ../../engine/scene/save.bend as Save
import ../../engine/script/rule.bend as R

def places() -> List<&2, Save.Placed>:
  []

def has_rules() -> Bool: False{}

def rules() -> List<&2, R.Rule>:
  []
