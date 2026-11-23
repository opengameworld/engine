# Rays and boxes: a half-line from a point, and the box around a set of points, in the World's
# meters. They answer "what is under the mouse?" (engine/scene/pick.bend).
#
# A ray hits a box by the slab method, as Godot's AABB::find_intersects_ray does
# (core/math/aabb.cpp): on each axis the ray is inside the box's slab between two distances, and
# the ray is in the box where the three ranges overlap. A ray parallel to an axis is inside that
# slab everywhere or nowhere. A hit behind the ray's origin is no hit; a ray that starts inside
# the box hits it at 0. References: docs/references/picking-and-gizmo.md.
#
# Limits now:
# - Boxes are aligned with the World's axes: a turned thing gets the box around its turned
#   corners, which is larger than the thing.

import Base
import ./vec.bend as V

type Ray is Data:
  Ray{origin: V.V3, dir: V.V3}

type Box is Data:
  Box{lo: V.V3, hi: V.V3}

def far() -> F32: 1.0e20

def Ray.pick(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

# The box around nothing: any point makes it grow to that point.
def nothing() -> Box:
  Box{V.V3{far(), far(), far()}, V.V3{(0.0 - far() : F32), (0.0 - far() : F32), (0.0 - far() : F32)}}

def grow(+b: Box, +p: V.V3) -> Box:
  Box{lo, hi} = b
  Box{V.V3{F32.min(V.x(lo), V.x(p)), F32.min(V.y(lo), V.y(p)), F32.min(V.z(lo), V.z(p))},
      V.V3{F32.max(V.x(hi), V.x(p)), F32.max(V.y(hi), V.y(p)), F32.max(V.z(hi), V.z(p))}}

def is_empty(+b: Box) -> Bool:
  Box{lo, hi} = b
  F32.is_gt(V.x(lo), V.x(hi))

# Where the ray enters and leaves one slab, from lo to hi along one axis.
def Ray.enter(+o: F32, +d: F32, +lo: F32, +hi: F32) -> F32:
  Ray.pick(F32.is_eq(d, 0.0),
    Ray.pick((F32.is_ge(o, lo) && F32.is_le(o, hi)), (0.0 - far() : F32), far()),
    F32.min(((lo - o) / d : F32), ((hi - o) / d : F32)))

def Ray.leave(+o: F32, +d: F32, +lo: F32, +hi: F32) -> F32:
  Ray.pick(F32.is_eq(d, 0.0),
    Ray.pick((F32.is_ge(o, lo) && F32.is_le(o, hi)), far(), (0.0 - far() : F32)),
    F32.max(((lo - o) / d : F32), ((hi - o) / d : F32)))

def Ray.in_at(+r: Ray, +b: Box) -> F32:
  Ray{o, d} = r
  Box{lo, hi} = b
  F32.max(Ray.enter(V.x(o), V.x(d), V.x(lo), V.x(hi)),
    F32.max(Ray.enter(V.y(o), V.y(d), V.y(lo), V.y(hi)), Ray.enter(V.z(o), V.z(d), V.z(lo), V.z(hi))))

def Ray.out_at(+r: Ray, +b: Box) -> F32:
  Ray{o, d} = r
  Box{lo, hi} = b
  F32.min(Ray.leave(V.x(o), V.x(d), V.x(lo), V.x(hi)),
    F32.min(Ray.leave(V.y(o), V.y(d), V.y(lo), V.y(hi)), Ray.leave(V.z(o), V.z(d), V.z(lo), V.z(hi))))

# How far along the ray it meets the box (0 when it starts inside), or `far()` for a miss.
def hit(+r: Ray, +b: Box) -> F32:
  +tin = Ray.in_at(r, b)
  +tout = Ray.out_at(r, b)
  Ray.pick((F32.is_le(tin, tout) && F32.is_ge(tout, 0.0) && Bool.not(is_empty(b))), F32.max(tin, 0.0), far())

def misses(+t: F32) -> Bool:
  F32.is_ge(t, far())

# The box around points written as a flat list: (x y z) after (x y z) for a mesh's vertices,
# (x y z r g b) after (x y z r g b) for a skeleton's lines (engine/anim/pose.bend).
def Ray.points3(xs: List<&2, F32>, +b: Box) -> Box:
  match xs:
    case x <> y <> z <> rest:
      Ray.points3(rest, grow(b, V.V3{x, y, z}))
    case _:
      b

def Ray.points6(xs: List<&2, F32>, +b: Box) -> Box:
  match xs:
    case x <> y <> z <> r <> g <> c <> rest:
      Ray.points6(rest, grow(b, V.V3{x, y, z}))
    case _:
      b

def around3(xs: List<&2, F32>) -> Box:
  Ray.points3(xs, nothing())

def around6(xs: List<&2, F32>) -> Box:
  Ray.points6(xs, nothing())

# A point along the ray.
def at(+r: Ray, +t: F32) -> V.V3:
  Ray{o, d} = r
  V.add(o, V.scale(d, t))
