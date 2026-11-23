# Numerical tests of engine/scene/place.bend (see tests/core/quat.bend for why float math is tested here and
# not by laws).
#
# Limits now:
# - A test is checked at a few chosen values, not for every value as a law is. It catches
#   mistakes; it does not prove there are none.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/scene/place.bend as P

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.0001)

def close3(+a: V.V3, +b: V.V3) -> Bool:
  (close(V.x(a), V.x(b)) && close(V.y(a), V.y(b)) && close(V.z(a), V.z(b)))

def far() -> F32: 100000.0      # 100 km
def mm() -> F32: 0.001

# 100 km east and 100 km north of the origin.
def far_place() -> P.Place:
  P.at(V.V3{far(), 2.0, (0.0 - far() : F32)})

def checks() -> List<&2, Check>:
  [Check{"the origin is in the center cell",
     (U32.is_eq(P.cell_x(P.origin()), P.center()) && U32.is_eq(P.cell_z(P.origin()), P.center()))},
   Check{"a point inside the first cell stays in it",
     U32.is_eq(P.cell_x(P.at(V.V3{10.0, 0.0, 20.0})), P.center())},
   Check{"a point 1 m west of the origin is in the cell before it, 1023 m in",
     (U32.is_eq(P.cell_x(P.at(V.V3{(0.0 - 1.0 : F32), 0.0, 0.0})), (P.center() - 1 : U32))
       && close(V.x(P.local(P.at(V.V3{(0.0 - 1.0 : F32), 0.0, 0.0}))), 1023.0))},
   Check{"100 km east is 97 cells east, 672 m in",
     (U32.is_eq(P.cell_x(far_place()), (P.center() + 97 : U32))
       && close(V.x(P.local(far_place())), 672.0))},
   Check{"delta from the origin gives back the point in meters",
     close3(P.delta(P.origin(), P.at(V.V3{3500.0, 1.0, (0.0 - 2200.0 : F32)})), V.V3{3500.0, 1.0, (0.0 - 2200.0 : F32)})},
   Check{"delta is b - a: swapping them flips the sign",
     close3(P.delta(P.at(V.V3{3500.0, 0.0, 0.0}), P.origin()), V.V3{(0.0 - 3500.0 : F32), 0.0, 0.0})},
   Check{"moving across a cell edge and back comes home",
     close3(P.delta(P.origin(), P.move(P.move(P.at(V.V3{1020.0, 0.0, 5.0}), V.V3{10.0, 0.0, 0.0}), V.V3{(0.0 - 10.0 : F32), 0.0, 0.0})), V.V3{1020.0, 0.0, 5.0})},
   Check{"at 100 km, a 1 mm step is kept by a Place",
     close(V.x(P.delta(far_place(), P.move(far_place(), V.V3{mm(), 0.0, 0.0}))), mm())},
   Check{"at 100 km, a 1 mm step is lost by a plain F32 (why Places exist)",
     Bool.not(close(((far() + mm() : F32) - far() : F32), mm()))},
   Check{"two far Places 1 m apart are 1 m apart",
     close3(P.delta(far_place(), P.move(far_place(), V.V3{0.0, 0.0, 1.0})), V.V3{0.0, 0.0, 1.0})}]
