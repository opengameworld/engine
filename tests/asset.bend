# Numerical tests of engine/shader/asset.bend: what a parameter may be
# worth, and what editing one does to a material.
#
# Limits now:
# - A few chosen values per control, not every one.

import Base
import ../engine/material.bend as Mat
import ../engine/shader/asset.bend as A

type Check is Data:
  Check{name: String, ok: Bool}

def density() -> A.Param:
  A.Param{"density", "Density", A.AsSlider{0.5, 8.0, 0.1}, [2.4]}

def tint() -> A.Param:
  A.Param{"tint", "Tint", A.AsColor{}, [0.08, 0.67, 0.76]}

def pattern() -> A.Param:
  A.Param{"pattern", "Pattern", A.AsDropdown{[A.Choice{"Radial", 0.0}, A.Choice{"Diagonal", 1.0}]}, [0.0]}

def lights() -> A.Param:
  A.Param{"highlights", "Highlights", A.AsToggle{}, [1.0]}

def params() -> List<&2, A.Param>:
  [tint(), density(), pattern(), lights()]

def fresh() -> Mat.Material:
  Mat.imported("ripples.frag.glsl")

def same(a: List<&2, F32>, b: List<&2, F32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      (F32.is_eq(x, y) && same(xs, ys))
    case _ _:
      False{}

def worth(+m: Mat.Material, +p: A.Param) -> List<&2, F32>:
  A.value(p, Mat.values(m))

def checks() -> List<&2, Check>:
  [Check{"a slider takes a number inside its range, and not one outside",
     (A.valid(density(), [3.0]) && Bool.not(A.valid(density(), [9.0])) && Bool.not(A.valid(density(), [0.1])))},
   Check{"a color takes three numbers from 0 to 1, not two, not one over 1",
     (A.valid(tint(), [0.0, 0.5, 1.0]) && Bool.not(A.valid(tint(), [0.0, 0.5])) && Bool.not(A.valid(tint(), [0.0, 0.5, 1.5])))},
   Check{"a toggle is 0 or 1; a menu is one of its choices",
     (A.valid(lights(), [0.0]) && Bool.not(A.valid(lights(), [0.5])) && A.valid(pattern(), [1.0]) && Bool.not(A.valid(pattern(), [2.0])))},
   Check{"a material that holds nothing is worth each parameter's default",
     (same(worth(fresh(), density()), [2.4]) && same(worth(fresh(), tint()), [0.08, 0.67, 0.76]))},
   Check{"editing one parameter changes it and keeps the others at their values",
     (same(worth(A.edit(fresh(), params(), "density", [5.0]), density()), [5.0]) && same(worth(A.edit(fresh(), params(), "density", [5.0]), tint()), [0.08, 0.67, 0.76]))},
   Check{"an edit that is not valid leaves the material as it was",
     same(worth(A.edit(A.edit(fresh(), params(), "density", [5.0]), params(), "density", [99.0]), density()), [5.0])},
   Check{"a held value that is not valid is read as the default",
     same(worth(Mat.instance(fresh(), [Mat.Value{"density", [99.0]}]), density()), [2.4])},
   Check{"one channel of a color can be set alone",
     same(A.set_at([0.08, 0.67, 0.76], 1, 0.5), [0.08, 0.5, 0.76])},
   Check{"a problem with a path is found, and a catalog can gain one",
     (Bool.not(A.has_problem(A.problems(A.none()), "x.glsl")) && A.has_problem(A.problems(A.with_problem(A.none(), "x.glsl", "did not link")), "x.glsl"))}]
