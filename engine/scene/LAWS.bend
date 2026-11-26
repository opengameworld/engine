# The laws of engine/scene (the scene and the World's places). `bend engine/scene/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./save.bend as Save
import ./scene.bend as S
import ../core/transform.bend as Tr
import ../../projects/water/scenes/Water.bend as Content
import ./place.bend as Pl
import ./id.bend as Id

# ---------- Scene ----------

# LAW: every thing drawn in the starting scene has a complete material.
law scene_materials_are_complete:
  {S.complete(Content.start()) == True{} : Bool}

# LAW: a hidden thing needs no material, so it never makes a scene incomplete.
law hidden_thing_is_complete:
  {S.complete(S.scene([S.thing("empty", Tr.identity(), S.Hidden{})])) == True{} : Bool}

# ---------- Places (the open World's coordinates) ----------

# LAW: the origin is in the center cell, on X and on Z.
law origin_is_the_center_cell_x:
  {Pl.cell_x(Pl.origin()) == Pl.center() : U32}

law origin_is_the_center_cell_z:
  {Pl.cell_z(Pl.origin()) == Pl.center() : U32}

# LAW: stepping cells forward and the same number back comes home, even across the center.
law cells_forward_and_back_come_home:
  {Pl.step(Pl.step(Pl.center(), 5, True{}), 5, False{}) == Pl.center() : U32}

law cells_back_and_forward_come_home:
  {Pl.step(Pl.step(Pl.center(), 7, False{}), 7, True{}) == Pl.center() : U32}

# ---------- Saving (engine/scene/save.bend) ----------

# LAW: with nothing saved, a project opens as its code makes it.
law nothing_saved_changes_nothing:
  for s: S.Scene
  {Save.apply(s, []) == s : S.Scene}

# LAW: a scene's saved file lives beside the scene, in its project's scenes/.
law a_save_goes_beside_its_scene:
  {Save.file("water", "Water") == "projects/water/scenes/saved/Water.bend" : String}

# ---------- Ids (engine/scene/id.bend) ----------

def two() -> S.Scene:
  S.scene([S.thing("a", Tr.identity(), S.Hidden{}), S.thing("b", Tr.identity(), S.Hidden{})])

def found(m: Maybe<&2, S.Thing>) -> Bool:
  match m:
    case Some{_}:
      True{}
    case None{}:
      False{}

# LAW: a scene gives its things their ids in the order of the list.
law a_scene_numbers_its_things:
  {Id.same(S.id(S.at(two(), 1)), Id.Id{1, 0}) == True{} : Bool}

# LAW: a thing is found by its id.
law a_thing_is_found_by_its_id:
  {found(S.find(two(), Id.Id{1, 0})) == True{} : Bool}

# LAW: a thing removed is not found by its id any more (a reference to it reads as nothing).
law a_thing_removed_is_not_found:
  {found(S.find(S.remove(two(), Id.Id{0, 0}), Id.Id{0, 0})) == False{} : Bool}

# LAW: a thing added after one was removed takes its index with a new generation...
law a_freed_index_comes_back_newer:
  {Id.same(S.id(S.at(S.add(S.remove(two(), Id.Id{0, 0}), S.thing("c", Tr.identity(), S.Hidden{})), 1)), Id.Id{0, 1}) == True{} : Bool}

# LAW: ...so the old id never names the new thing.
law an_old_id_never_names_a_new_thing:
  {found(S.find(S.add(S.remove(two(), Id.Id{0, 0}), S.thing("c", Tr.identity(), S.Hidden{})), Id.Id{0, 0})) == False{} : Bool}

# LAW: removing an id that is not alive changes nothing.
law removing_twice_is_removing_once:
  {S.count(S.remove(S.remove(two(), Id.Id{0, 0}), Id.Id{0, 0})) == 1n : Nat}

# LAW: things that change place keep their ids.
law moving_keeps_ids:
  {Id.same(S.id(S.at(S.advance(two(), 1.0, False{}), 1)), Id.Id{1, 0}) == True{} : Bool}

# LAW: a thing's tags are found.
law a_thing_has_its_tags:
  {S.has_tag(S.with_tags(S.thing("a", Tr.identity(), S.Hidden{}), ["enemy", "boss"]), "boss") == True{} : Bool}
