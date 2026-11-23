# What a game takes with it, read from its opening scene: the skins its figures wear, the
# imported shaders its materials use, and the third-party works that therefore ship. Export
# asks this, so a game never carries a file its scene does not reach.
#
#   skins(scene)     each figure's skin name, once
#   shaders(scene)   each imported material's shader id, once
#   skin(name)       the files a skin name means (none: the figure is drawn as bones)
#   works(skins)     the works a game with these skins ships, for its credits
#
# Limits now:
# - Only the opening scene is read: a thing added later at run time is not seen.
# - The mannequin's files are named here and again in editor/main.js (the editor's page). Both name
#   the same files; a test should hold them together once there is a second skin.
# - Bend-UI always ships: its tokens reach the runtime through engine/scene/world.bend
#   (a named debt). It is listed for its credit.
# - Library clips are not selected yet: no project names any (figures use the code-made idle
#   and walk), so none ships.

import Base
import ../engine/scene/scene.bend as S
import ../engine/anim/figure.bend as Fig
import ../engine/render/material.bend as Mat
import ./contract.bend as Ex

type Skin is Data:
  Skin{name: String, info: String, bin: String, textures: List<&2, String>}

def Needs.has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      (String.eq(h, x) || Needs.has(t, x))

def Needs.keep(seen: Bool, +x: String, xs: List<&2, String>) -> List<&2, String>:
  match seen:
    case True{}:
      xs
    case False{}:
      x <> xs

def Needs.add(+x: String, +xs: List<&2, String>) -> List<&2, String>:
  Needs.keep(Needs.has(xs, x), x, xs)

def Needs.union(xs: List<&2, String>, +ys: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      ys
    case Con{h, t}:
      Needs.add(h, Needs.union(t, ys))

def Look.skins(l: S.Look) -> List<&2, String>:
  match l:
    case S.Hidden{}:
      []
    case S.Shown{_, _}:
      []
    case S.Rigged{f}:
      [Fig.skin(f)]

def Material.shaders(m: Mat.Material) -> List<&2, String>:
  match m:
    case Mat.Material{_, _}:
      []
    case Mat.Imported{id, _}:
      [id]

def Look.shaders(l: S.Look) -> List<&2, String>:
  match l:
    case S.Hidden{}:
      []
    case S.Shown{_, m}:
      Material.shaders(m)
    case S.Rigged{_}:
      []

def Things.skins(ts: List<&2, S.Thing>) -> List<&2, String>:
  match ts:
    case Nil{}:
      []
    case Con{t, rest}:
      Needs.union(Look.skins(S.look(t)), Things.skins(rest))

def Things.shaders(ts: List<&2, S.Thing>) -> List<&2, String>:
  match ts:
    case Nil{}:
      []
    case Con{t, rest}:
      Needs.union(Look.shaders(S.look(t)), Things.shaders(rest))

def skins(s: S.Scene) -> List<&2, String>:
  Things.skins(S.things(s))

def shaders(s: S.Scene) -> List<&2, String>:
  Things.shaders(S.things(s))

def mannequin() -> Skin:
  Skin{"mannequin", "mannequin/gen/skin.json", "mannequin/gen/skin.bin",
    ["mannequin/source/p_ism001_01.png", "mannequin/source/p_ism001_00.png"]}

def Skin.pick(known: Bool, +s: Skin) -> List<&2, Skin>:
  match known:
    case True{}:
      [s]
    case False{}:
      []

def skin(+name: String) -> List<&2, Skin>:
  Skin.pick(String.eq(name, "mannequin"), mannequin())

def Skins.files(names: List<&2, String>) -> List<&2, Skin>:
  match names:
    case Nil{}:
      []
    case Con{n, t}:
      List.append(&2, Skin, skin(n), Skins.files(t))

def Works.mannequin(wears: Bool) -> List<&2, Ex.Work>:
  match wears:
    case True{}:
      [Ex.Work.Mannequin{}]
    case False{}:
      []

def works(+skins: List<&2, String>) -> List<&2, Ex.Work>:
  Ex.Work.BendUi{} <> Works.mannequin(Needs.has(skins, "mannequin"))
