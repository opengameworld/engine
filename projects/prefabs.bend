# The things the editor can create in a scene (the Hierarchy's Create), as Unity's GameObject menu
# (Create Empty, 3D Object, Character) and Godot's Add Node do. A thing created in the editor is
# saved by kind, name and place in the scene's saved file (engine/scene/save.bend), and made again
# from its kind when the scene opens.
#
#   Empty      a thing with a place and nothing drawn (Unity's Create Empty)
#   Plane      a 10 m square, the World's strong grid step (docs/world.txt), with the Water
#              project's material (projects/water/water.bend)
#   Character  the standard character (mannequin/), with the engine's locomotion
#
# Limits now:
# - Three kinds. A project cannot add its own yet.

import Base
import ../engine/scene/scene.bend as S
import ../engine/core/transform.bend as Tr
import ../engine/render/mesh.bend as M
import ../engine/scene/save.bend as Save
import ../mannequin/scene.bend as Mannequin
import ./water/water.bend as Water

type Prefab is Data:
  Prefab.Empty{}
  Prefab.Plane{}
  Prefab.Character{}

# A thing made in the editor: its name, its kind and its place.
type Made is Data:
  Made{name: String, kind: Prefab, place: Tr.Transform}

def look(+k: Prefab) -> S.Look:
  match k:
    case Prefab.Empty{}:
      S.Hidden{}
    case Prefab.Plane{}:
      S.Shown{M.plane(10.0, 1), Water.material()}
    case Prefab.Character{}:
      S.Rigged{Mannequin.figure()}

def thing(+m: Made) -> S.Thing:
  Made{n, k, p} = m
  S.Thing{n, p, look(k)}

def name_of(+m: Made) -> String:
  Made{n, _, _} = m
  n

def kind_of(+m: Made) -> Prefab:
  Made{_, k, _} = m
  k

def things(ms: List<&2, Made>) -> List<&2, S.Thing>:
  match ms:
    case Nil{}:
      Nil{}
    case +h <> t:
      thing(h) <> things(t)

# The scene with the things made in the editor, after its own.
def add(s: S.Scene, +ms: List<&2, Made>) -> S.Scene:
  S.Scene{xs} = s
  S.Scene{List.append(&2, S.Thing, xs, things(ms))}

def kind_text(+k: Prefab) -> String:
  match k:
    case Prefab.Empty{}:
      "Pre.Prefab.Empty{}"
    case Prefab.Plane{}:
      "Pre.Prefab.Plane{}"
    case Prefab.Character{}:
      "Pre.Prefab.Character{}"

def kind_name(+k: Prefab) -> String:
  match k:
    case Prefab.Empty{}:
      "Empty"
    case Prefab.Plane{}:
      "Plane"
    case Prefab.Character{}:
      "Character"

def kinds() -> List<&2, Prefab>:
  [Prefab.Empty{}, Prefab.Plane{}, Prefab.Character{}]

# One thing made, as Bend reads it back (the saved file's made()).
def text(+m: Made) -> String:
  Made{n, k, p} = m
  "Pre.Made{" ++ String.quote(n) ++ ", " ++ kind_text(k) ++ ", " ++ Save.place_text(p) ++ "}"

def Pre.sep(+t: List<&2, Made>) -> String:
  match t:
    case Nil{}:
      ""
    case Con{_, _}:
      ",\n"

# Every thing made, one per line, for engine/scene/save.bend's text.
def lines(ms: List<&2, Made>) -> String:
  match ms:
    case Nil{}:
      ""
    case Con{+h, +t}:
      String.concat(["   ", text(h), Pre.sep(t), lines(t)])
