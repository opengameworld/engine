# Places: where a thing is in an open World, kilometers from the origin, without losing precision.
#
# An F32 has 24 bits of mantissa: at 10 km from the origin it can no longer tell two points 1 mm
# apart, and at 100 km not 8 mm apart. So a Place is a cell of the ground (a square of `size()`
# meters on X and Z, numbered by U32) and a position inside it, in meters, which stays small.
#
#   Place{cx, cz, local}   the cell on X and on Z, and where in it (local.y is the height)
#   at(v)                  the Place of a point given in meters from the origin
#   move(p, d)             p moved by d meters; the Place changes cell when it crosses an edge
#   delta(a, b)            b - a in meters, as a V3: what renders, physics and sound work with
#
# Renderers, physics and sound never see a Place: they work in meters around a chosen Place (the
# camera's, the player's), with `delta(origin, p)`. Near that origin those numbers are small and
# exact; far from it they are coarse, and far things matter less.
#
# The World's conventions stay (engine/world.bend): Y up, right-handed, one unit is one meter.
# Cell numbers are U32 with the origin's cell at `center()`, since Bend 2.0.40 has no signed
# integers: cell center() + 1 is east of it, center() - 1 west.
#
# Limits now:
# - Height is not split into cells: local.y is a plain F32, exact to about 1 mm up to 8 km.
# - After a move, local.x and local.z are in [0, size()]; a rounding can leave one exactly at
#   size() (the next cell's edge) instead of 0 in the next cell. Both name the same point.
# - delta() between Places very far apart (thousands of km) is an F32 in meters, so it is coarse;
#   it is only exact near the origin it is measured from, which is how it is used.

import Base
import ./vec.bend as V

type Place is Data:
  Place{cx: U32, cz: U32, local: V.V3}

# The side of a cell, in meters. At 1024 m an F32 still tells apart points 0.1 mm apart.
def size() -> F32: 1024.0

# The number of the origin's cell, on X and on Z: half of what a U32 holds.
def center() -> U32: 2147483648

def origin() -> Place:
  Place{center(), center(), V.V3{0.0, 0.0, 0.0}}

def cell_x(+p: Place) -> U32:
  match p:
    case Place{x, _, _}:
      x

def cell_z(+p: Place) -> U32:
  match p:
    case Place{_, z, _}:
      z

def local(+p: Place) -> V.V3:
  match p:
    case Place{_, _, l}:
      l

def Place.word(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def Place.pick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

# A cell number moved by n whole cells: forward (east, south) or back.
def step(+cell: U32, +n: U32, forward: Bool) -> U32:
  Place.word(forward, (cell + n : U32), (cell - n : U32))

# A cell number moved by k cells, k a whole number as an F32 (it may be negative).
def shift(+cell: U32, +k: F32) -> U32:
  step(cell, F32.to_u32(F32.abs(k)), F32.is_ge(k, 0.0))

# How many whole cells the coordinate v (meters within a cell) has left its cell by.
def cells_out(+v: F32) -> F32:
  F32.floor((v / size() : F32))

# The coordinate v brought back into its cell, after `cells_out(v)` cells were taken away.
def kept(+v: F32) -> F32:
  (v - cells_out(v) * size() : F32)

# A Place whose local position may have left its cell, put in the right cell.
def settle(+p: Place) -> Place:
  match p:
    case Place{cx, cz, V.V3{+lx, ly, +lz}}:
      Place{shift(cx, cells_out(lx)), shift(cz, cells_out(lz)), V.V3{kept(lx), ly, kept(lz)}}

# The Place of a point given in meters from the origin.
def at(v: V.V3) -> Place:
  settle(Place{center(), center(), v})

def move(+p: Place, d: V.V3) -> Place:
  match p:
    case Place{cx, cz, l}:
      settle(Place{cx, cz, V.add(l, d)})

# b - a for two cell numbers, as a whole number of cells (negative when b is before a).
def cells_between(+a: U32, +b: U32) -> F32:
  Place.pick(U32.is_ge(b, a), U32.to_f32((b - a : U32)), (0.0 - U32.to_f32((a - b : U32)) : F32))

# One axis of delta(): the cells between, in meters, plus the local difference.
def Place.axis(+a: U32, +b: U32, +la: F32, +lb: F32) -> F32:
  (cells_between(a, b) * size() + (lb - la) : F32)

# b - a in meters. Near a, this is exact to the precision of the local positions.
def delta(+a: Place, +b: Place) -> V.V3:
  match a:
    case Place{ax, az, V.V3{alx, aly, alz}}:
      match b:
        case Place{bx, bz, V.V3{blx, bly, blz}}:
          V.V3{Place.axis(ax, bx, alx, blx), (bly - aly : F32), Place.axis(az, bz, alz, blz)}
