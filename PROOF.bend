# The proofs of LAWS.bend.

import Base
import ./LAWS.bend as Laws
import ./PROJECT.bend as P
import ./LAYERS.bend as Ly





def Laws.every_project_opens_complete(p):
  match p:
    case P.Water{}:
      {==}
    case P.Character{}:
      {==}
    case P.Mannequin{}:
      {==}
    case P.Animation{}:
      {==}
    case P.Arena{}:
      {==}

def Laws.shipped_never_imports_editor(a):
  match a:
    case Ly.Layer.Engine{}:
      {==}
    case Ly.Layer.PlatWeb{}:
      {==}
    case Ly.Layer.Project{}:
      {==}
    case Ly.Layer.Catalog{}:
      {==}
    case Ly.Layer.Mannequin{}:
      {==}
    case Ly.Layer.MannequinLaws{}:
      {==}
    case Ly.Layer.MannequinSource{}:
      {==}
    case Ly.Layer.Library{}:
      {==}
    case Ly.Layer.LibraryIndex{}:
      {==}
    case Ly.Layer.LibrarySource{}:
      {==}
    case Ly.Layer.UiKit{}:
      {==}
    case Ly.Layer.GameGen{}:
      {==}
    case Ly.Layer.Editor{}:
      {==}
    case Ly.Layer.Export{}:
      {==}
    case Ly.Layer.Rules{}:
      {==}
    case Ly.Layer.Tools{}:
      {==}
    case Ly.Layer.Tests{}:
      {==}
    case Ly.Layer.Docs{}:
      {==}
    case Ly.Layer.Refs{}:
      {==}
    case Ly.Layer.Outside{}:
      {==}

def Laws.shipped_never_imports_tooling(a):
  match a:
    case Ly.Layer.Engine{}:
      {==}
    case Ly.Layer.PlatWeb{}:
      {==}
    case Ly.Layer.Project{}:
      {==}
    case Ly.Layer.Catalog{}:
      {==}
    case Ly.Layer.Mannequin{}:
      {==}
    case Ly.Layer.MannequinLaws{}:
      {==}
    case Ly.Layer.MannequinSource{}:
      {==}
    case Ly.Layer.Library{}:
      {==}
    case Ly.Layer.LibraryIndex{}:
      {==}
    case Ly.Layer.LibrarySource{}:
      {==}
    case Ly.Layer.UiKit{}:
      {==}
    case Ly.Layer.GameGen{}:
      {==}
    case Ly.Layer.Editor{}:
      {==}
    case Ly.Layer.Export{}:
      {==}
    case Ly.Layer.Rules{}:
      {==}
    case Ly.Layer.Tools{}:
      {==}
    case Ly.Layer.Tests{}:
      {==}
    case Ly.Layer.Docs{}:
      {==}
    case Ly.Layer.Refs{}:
      {==}
    case Ly.Layer.Outside{}:
      {==}

def Laws.only_refs_import_refs(a):
  match a:
    case Ly.Layer.Engine{}:
      {==}
    case Ly.Layer.PlatWeb{}:
      {==}
    case Ly.Layer.Project{}:
      {==}
    case Ly.Layer.Catalog{}:
      {==}
    case Ly.Layer.Mannequin{}:
      {==}
    case Ly.Layer.MannequinLaws{}:
      {==}
    case Ly.Layer.MannequinSource{}:
      {==}
    case Ly.Layer.Library{}:
      {==}
    case Ly.Layer.LibraryIndex{}:
      {==}
    case Ly.Layer.LibrarySource{}:
      {==}
    case Ly.Layer.UiKit{}:
      {==}
    case Ly.Layer.GameGen{}:
      {==}
    case Ly.Layer.Editor{}:
      {==}
    case Ly.Layer.Export{}:
      {==}
    case Ly.Layer.Rules{}:
      {==}
    case Ly.Layer.Tools{}:
      {==}
    case Ly.Layer.Tests{}:
      {==}
    case Ly.Layer.Docs{}:
      {==}
    case Ly.Layer.Refs{}:
      {==}
    case Ly.Layer.Outside{}:
      {==}

def Laws.the_editor_never_ships():
  {==}

def Laws.export_never_ships():
  {==}

def Laws.tools_never_ship():
  {==}

def Laws.the_library_catalog_never_ships():
  {==}

def Laws.the_mannequin_laws_never_ship():
  {==}
