# Picking: which thing of the scene is under a point of the screen.
#
# The ray from the camera through the pixel (engine/scene/camera.bend's ray) is tested against
# the box around each thing that is drawn, and the nearest hit wins: the broad phase Godot's
# editor runs before anything finer (Node3DEditorViewport::_select_ray, which ranks hits by
# distance). A shown thing's box holds its mesh's vertices, placed by its Transform; a
# character's holds the lines of its skeleton in the pose it has now. A hidden thing is never
# picked. References: docs/references/picking-and-gizmo.md.
#
# The editor selects with it (a click on the viewport), and Play gives the thing clicked to the
# scripts (engine/script/).
#
# Limits now:
# - Boxes, not triangles: a click on the empty corner of a thing's box picks it. Godot then
#   tests the mesh's triangles (TriangleMesh::intersect_ray); that is not built.
# - Every thing is tested, one by one: no tree of boxes (Godot keeps a BVH).
# - A character's box is its skeleton's, which leaves out the skin's thickness.

import Base
import ../core/vec.bend as V
import ../core/transform.bend as Tr
import ../core/ray.bend as R
import ../render/mesh.bend as M
import ../anim/figure.bend as Fig
import ./scene.bend as S
import ./camera.bend as Cam

def Pick.placed(vs: List<&2, F32>, +t: Tr.Transform, +b: R.Box) -> R.Box:
  match vs:
    case x <> y <> z <> rest:
      Pick.placed(rest, t, R.grow(b, Tr.point(t, V.V3{x, y, z})))
    case _:
      b

# The box around a thing in the World (empty for a hidden thing).
def box(t: S.Thing) -> R.Box:
  match t:
    case S.Thing{n, p, l}:
      match l:
        case S.Shown{sh, m}:
          Pick.placed(M.vertices(sh), p, R.nothing())
        case S.Rigged{f}:
          R.around6(Fig.lines(f, p))
        case S.Hidden{}:
          R.nothing()

# What a pick found: nothing, or the thing at a place of the list, at a distance along the ray.
type Hit is Data:
  Hit.Nothing{}
  Hit.At{index: U32, t: F32}

def Pick.keep_if(c: Bool, +a: Hit, +b: Hit) -> Hit:
  match c:
    case True{}:
      a
    case False{}:
      b

def Pick.nearer(+i: U32, +t: F32, best: Hit) -> Hit:
  match best:
    case Hit.Nothing{}:
      Pick.keep_if(R.misses(t), Hit.Nothing{}, Hit.At{i, t})
    case Hit.At{+j, +u}:
      Pick.keep_if(F32.is_lt(t, u), Hit.At{i, t}, Hit.At{j, u})

def Pick.go(xs: List<&2, S.Thing>, +r: R.Ray, +i: U32, best: Hit) -> Hit:
  match xs:
    case Nil{}:
      best
    case Con{h, t}:
      Pick.go(t, r, (i + 1 : U32), Pick.nearer(i, R.hit(r, box(h)), best))

# The nearest thing the ray meets.
def along(+s: S.Scene, +r: R.Ray) -> Hit:
  Pick.go(S.things(s), r, 0, Hit.Nothing{})

# The thing under the pixel (x, y) of a canvas w × h, seen by `cam`.
def at(+s: S.Scene, +cam: Cam.Cam, +x: F32, +y: F32, +w: F32, +h: F32) -> Hit:
  along(s, Cam.ray(cam, x, y, w, h))

def found(+h: Hit) -> Bool:
  match h:
    case Hit.Nothing{}:
      False{}
    case Hit.At{_, _}:
      True{}

def index(+h: Hit) -> U32:
  match h:
    case Hit.Nothing{}:
      0
    case Hit.At{i, _}:
      i
