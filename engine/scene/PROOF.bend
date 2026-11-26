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
        case S.Thing{i, n, p, l, g, a, b}:
          %unsaved(t) : {S.Thing{i, n, p, l, g, a, b} <> t == S.Thing{i, n, p, l, g, a, b} <> _ : List<&2, S.Thing>}
          {==}

def Laws.nothing_saved_changes_nothing(s):
  match s:
    case S.Scene{xs, k}:
      %unsaved(xs) : {S.Scene{_, k} == S.Scene{xs, k} : S.Scene}
      {==}

def Laws.a_save_goes_beside_its_scene():
  {==}

def Laws.a_scene_numbers_its_things():
  {==}

def Laws.a_thing_is_found_by_its_id():
  {==}

def Laws.a_thing_removed_is_not_found():
  {==}

def Laws.a_freed_index_comes_back_newer():
  {==}

def Laws.an_old_id_never_names_a_new_thing():
  {==}

def Laws.removing_twice_is_removing_once():
  {==}

def Laws.moving_keeps_ids():
  {==}

def Laws.a_thing_has_its_tags():
  {==}
