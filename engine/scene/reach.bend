# How a project's files reach the engine: the import prefix a file writes before an engine path
# ("engine/scene/scene.bend"), for the files the engine writes into a project (a saved scene,
# engine/scene/save.bend; a new scene or script, editor/project/templates.bend).
#
# A project in the engine's projects/ climbs to the engine's root by relative path, so the prefix
# depends on how deep the file sits in the project. A project outside the engine reaches it as a Bend
# package (`opengame-engine@0.4.0.0/engine/...`), whatever the depth, because a Bend import path takes
# only plain names and an installed engine's folder is not one (docs/architecture/projects/README.md).
#
# Limits now:
# - The editor opens only the engine's own projects, so it always passes sample(); a project outside
#   the engine passes its package when the editor can open one.

import Base

type Reach is Data:
  # the engine's root is `levels` folders above the project's folder
  Reach.Up{levels: Nat}
  # the engine as a Bend package, named with its version ("opengame-engine@0.4.0.0")
  Reach.Package{name: String}

# A project of the engine's own, in projects/<name>/: two folders below the engine's root.
def sample() -> Reach:
  Reach.Up{2n}

def Reach.ups(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+k:
      "../" ++ Reach.ups(k)

# The prefix for a file `depth` folders below the project's folder (a saved scene, in scenes/saved/,
# is at depth 2).
def prefix(r: Reach, +depth: Nat) -> String:
  match r:
    case Reach.Up{levels}:
      Reach.ups(Nat.add(levels, depth))
    case Reach.Package{name}:
      name ++ "/"
