# The laws of engine/scene (the scene and the World's places). `bend engine/scene/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./save.bend as Save
import ./scene.bend as S
import ../core/transform.bend as Tr
import ../../projects/water/scenes/Water.bend as Content
import ./place.bend as Pl
import ./reach.bend as Rc

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

# LAW: a scene's saved file lives beside the scene, in its project's scenes/.
law a_save_goes_beside_its_scene:
  {Save.file("Water") == "scenes/saved/Water.bend" : String}

# LAW: a sample climbs to the engine's root by relative path, two folders plus the file's own depth;
# a project outside the engine names the package at any depth.
law reach_prefixes:
  {[Rc.prefix(Rc.sample(), 0n), Rc.prefix(Rc.sample(), 1n), Rc.prefix(Rc.sample(), 2n), Rc.prefix(Rc.Reach.Package{"opengame-engine@0.4.0.0"}, 2n)]
   == ["../../", "../../../", "../../../../", "opengame-engine@0.4.0.0/"] : List<&2, String>}
