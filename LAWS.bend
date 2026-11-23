# The laws of the engine as a whole: projects and layers. `bend PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./engine/scene/scene.bend as S
import ./PROJECT.bend as P
import ./LAYERS.bend as Ly

# ---------- Projects ----------

# LAW: every project opens with a complete scene (each drawn thing's
# material has a value for every parameter).
law every_project_opens_complete:
  for p: P.Project
  {S.complete(P.start(p)) == True{} : Bool}

# ---------- Layers (LAYERS.bend) ----------

# LAW: nothing that ships in a game may import the editor.
law shipped_never_imports_editor:
  for a: Ly.Layer
  {Bool.and(Ly.ships(a), Ly.may_import(a, Ly.Layer.Editor{})) == False{} : Bool}

# LAW: nothing that ships may import export, tools or the layer rules.
law shipped_never_imports_tooling:
  for a: Ly.Layer
  {Bool.and(Ly.ships(a), (Ly.may_import(a, Ly.Layer.Export{}) || Ly.may_import(a, Ly.Layer.Tools{}) || Ly.may_import(a, Ly.Layer.Rules{}))) == False{} : Bool}

# LAW: nothing outside refs/ imports refs/.
law only_refs_import_refs:
  for a: Ly.Layer
  {Bool.and(Bool.not(Ly.Layer.is_refs(a)), Ly.may_import(a, Ly.Layer.Refs{})) == False{} : Bool}

# LAW: the editor, export, tools, the library's catalog and the mannequin's laws never ship.
law the_editor_never_ships:
  {Ly.ships(Ly.Layer.Editor{}) == False{} : Bool}

law export_never_ships:
  {Ly.ships(Ly.Layer.Export{}) == False{} : Bool}

law tools_never_ship:
  {Ly.ships(Ly.Layer.Tools{}) == False{} : Bool}

law the_library_catalog_never_ships:
  {Ly.ships(Ly.Layer.LibraryIndex{}) == False{} : Bool}

law the_mannequin_laws_never_ship:
  {Ly.ships(Ly.Layer.MannequinLaws{}) == False{} : Bool}
