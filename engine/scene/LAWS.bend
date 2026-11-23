# The laws of engine/scene (the scene and the World's places). `bend engine/scene/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./save.bend as Save
import ./scene.bend as S
import ../core/transform.bend as Tr
import ../../projects/water/scene.bend as Content
import ./place.bend as Pl

# ---------- Scene ----------

# LAW: every thing drawn in the starting scene has a complete material.
law scene_materials_are_complete:
  {S.complete(Content.start()) == True{} : Bool}

# LAW: a hidden thing needs no material, so it never makes a scene incomplete.
law hidden_thing_is_complete:
  {S.complete(S.Scene{[S.Thing{"empty", Tr.identity(), S.Hidden{}}]}) == True{} : Bool}

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

# LAW: a saved file lives in its project's folder.
law a_save_goes_to_its_project:
  {Save.file("water") == "projects/water/saved.bend" : String}
