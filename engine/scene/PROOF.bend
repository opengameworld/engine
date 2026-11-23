# The proofs of engine/scene/LAWS.bend.

import Base
import ./LAWS.bend as Laws
import ./scene.bend as S
import ./save.bend as Save


def Laws.scene_materials_are_complete():
  {==}

def Laws.hidden_thing_is_complete():
  {==}

def Laws.origin_is_the_center_cell_x():
  {==}

def Laws.origin_is_the_center_cell_z():
  {==}

def Laws.cells_forward_and_back_come_home():
  {==}

def Laws.cells_back_and_forward_come_home():
  {==}

# Applying nothing leaves every thing as it was: by induction on the things.
def unsaved(xs: List<&2, S.Thing>) -> {xs == Save.Save.things(xs, []) : List<&2, S.Thing>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      match h:
        case S.Thing{n, p, l}:
          %unsaved(t) : {S.Thing{n, p, l} <> t == S.Thing{n, p, l} <> _ : List<&2, S.Thing>}
          {==}

def Laws.nothing_saved_changes_nothing(s):
  match s:
    case S.Scene{xs}:
      %unsaved(xs) : {S.Scene{_} == S.Scene{xs} : S.Scene}
      {==}

def Laws.a_save_goes_beside_its_scene():
  {==}
