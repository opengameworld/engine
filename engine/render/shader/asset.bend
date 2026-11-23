# Asset: an imported shader, as the editor and the engine know it.
#
# A shader file of a project (projects/<name>/shaders/) comes with a list
# of parameters: the numbers a person may change, and the control each one
# is changed with. tools/shaders/catalog.js reads the files and writes the
# project's catalog as Bend values of these types
# (editor/shaders/catalog_generated.bend), so the rules about a parameter
# are checked here, in Bend, and the same rules serve the editor's panel
# and anything else that edits a material.
#
# A control says what a value may be:
# - AsNumber    any number
# - AsColor     three numbers (R, G, B), each from 0 to 1
# - AsToggle    0 (off) or 1 (on)
# - AsSlider    a number from min to max
# - AsDropdown  the value of one of its choices
#
# A material that uses an asset (engine/render/material.bend's Imported) holds only
# the values that were changed. value() gives what a parameter is worth on
# a material: the changed value when it is a valid one, the default
# otherwise. edit() changes one parameter and gives the material back with
# every parameter's value written, or the same material when the new value
# is not valid.
#
# A problem is something wrong with a shader file (it did not compile, its
# settings are wrong): the file's path, the name its settings give it (the
# path again when they give none), and what to say. An asset with a
# problem cannot be chosen.
#
# Limits now:
# - A value is numbers only: no textures, no vectors but the RGB color.
# - Finite numbers are assumed: the page turns a text into a number with
#   F32.read, which gives none for a text that is not a number.
# - The drawing code (platform/web/materials.js) still checks a value again
#   in JavaScript before it goes to the GPU, with rules written a second
#   time there; it should ask this file.

import Base
import ../material.bend as Mat

type Choice is Data:
  Choice{label: String, value: F32}

type Control is Data:
  AsNumber{}
  AsColor{}
  AsToggle{}
  AsSlider{min: F32, max: F32, step: F32}
  AsDropdown{choices: List<&2, Choice>}

type Param is Data:
  Param{name: String, label: String, control: Control, default: List<&2, F32>}

type Asset is Data:
  Asset{id: String, label: String, language: String, params: List<&2, Param>}

type Problem is Data:
  Problem{path: String, label: String, message: String}

type Catalog is Data:
  Catalog{assets: List<&2, Asset>, problems: List<&2, Problem>}

def none() -> Catalog:
  Catalog{Nil{}, Nil{}}

def assets(c: Catalog) -> List<&2, Asset>:
  Catalog{xs, _} = c
  xs

def problems(c: Catalog) -> List<&2, Problem>:
  Catalog{_, ps} = c
  ps

def id(a: Asset) -> String:
  Asset{i, _, _, _} = a
  i

def label(a: Asset) -> String:
  Asset{_, l, _, _} = a
  l

def language(a: Asset) -> String:
  Asset{_, _, g, _} = a
  g

def params(a: Asset) -> List<&2, Param>:
  Asset{_, _, _, ps} = a
  ps

def param_name(p: Param) -> String:
  Param{n, _, _, _} = p
  n

def param_label(p: Param) -> String:
  Param{_, l, _, _} = p
  l

def control(p: Param) -> Control:
  Param{_, _, c, _} = p
  c

def default(p: Param) -> List<&2, F32>:
  Param{_, _, _, d} = p
  d

def path(p: Problem) -> String:
  Problem{x, _, _} = p
  x

def problem_label(p: Problem) -> String:
  Problem{_, l, _} = p
  l

def message(p: Problem) -> String:
  Problem{_, _, m} = p
  m

# Finding
# =======

def pick_params(c: Bool, a: List<&2, Param>, b: List<&2, Param>) -> List<&2, Param>:
  match c:
    case True{}:
      a
    case False{}:
      b

# The parameters of the asset with this id; none when there is no such asset.
def params_of(xs: List<&2, Asset>, +want: String) -> List<&2, Param>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      Asset{+i, _, _, +ps} = h
      pick_params(String.eq(i, want), ps, params_of(t, want))

# Is there a problem with this path?
def has_problem(ps: List<&2, Problem>, +want: String) -> Bool:
  match ps:
    case Nil{}:
      False{}
    case h <> t:
      (String.eq(path(h), want) || has_problem(t, want))

# A catalog with one more problem (a shader that failed when it was tried).
def with_problem(c: Catalog, +p: String, +m: String) -> Catalog:
  Catalog{xs, ps} = c
  Catalog{xs, List.append(&2, Problem, ps, [Problem{p, p, m}])}

# Valid values
# ============

def between(+x: F32, +lo: F32, +hi: F32) -> Bool:
  (Bool.not(F32.is_lt(x, lo)) && Bool.not(F32.is_lt(hi, x)))

def all_unit(xs: List<&2, F32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      (between(h, 0.0, 1.0) && all_unit(t))

def is_choice(cs: List<&2, Choice>, +x: F32) -> Bool:
  match cs:
    case Nil{}:
      False{}
    case h <> t:
      Choice{_, v} = h
      (F32.is_eq(v, x) || is_choice(t, x))

def first(xs: List<&2, F32>) -> F32:
  match xs:
    case Nil{}:
      0.0
    case h <> _:
      h

# May a parameter with this control be worth these numbers?
def fits(c: Control, +xs: List<&2, F32>) -> Bool:
  match c:
    case AsNumber{}:
      True{}
    case AsColor{}:
      all_unit(xs)
    case AsToggle{}:
      (F32.is_eq(first(xs), 0.0) || F32.is_eq(first(xs), 1.0))
    case AsSlider{lo, hi, _}:
      between(first(xs), lo, hi)
    case AsDropdown{cs}:
      is_choice(cs, first(xs))

# As many numbers as the default has, and numbers the control allows.
def valid(p: Param, +xs: List<&2, F32>) -> Bool:
  Param{_, _, c, d} = p
  (Nat.is_eq(List.length(&2, F32, xs), List.length(&2, F32, d)) && fits(c, xs))

# Values on a material
# ====================

def pick_nums(c: Bool, a: List<&2, F32>, b: List<&2, F32>) -> List<&2, F32>:
  match c:
    case True{}:
      a
    case False{}:
      b

# The numbers a material holds under a name; none when it holds none.
def held(vs: List<&2, Mat.Value>, +want: String) -> List<&2, F32>:
  match vs:
    case Nil{}:
      Nil{}
    case h <> t:
      Mat.Value{+n, +xs} = h
      pick_nums(String.eq(n, want), xs, held(t, want))

# What the parameter is worth on these values: the held numbers when they
# are valid, its default otherwise.
def value(+p: Param, +vs: List<&2, Mat.Value>) -> List<&2, F32>:
  +own = held(vs, param_name(p))
  pick_nums(valid(p, own), own, default(p))

# Every parameter's value, with the one named `name` worth `xs`.
def written(ps: List<&2, Param>, +vs: List<&2, Mat.Value>, +name: String, +xs: List<&2, F32>) -> List<&2, Mat.Value>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> t:
      Mat.Value{param_name(h), pick_nums(String.eq(param_name(h), name), xs, value(h, vs))} <> written(t, vs, name, xs)

def pick_material(c: Bool, a: Mat.Material, b: Mat.Material) -> Mat.Material:
  match c:
    case True{}:
      a
    case False{}:
      b

def valid_named(ps: List<&2, Param>, +name: String, +xs: List<&2, F32>) -> Bool:
  match ps:
    case Nil{}:
      False{}
    case +h <> t:
      ((String.eq(param_name(h), name) && valid(h, xs)) || valid_named(t, name, xs))

# The material with parameter `name` worth `xs`; the same material when
# there is no such parameter or the numbers are not valid for it.
def edit(+m: Mat.Material, +ps: List<&2, Param>, +name: String, +xs: List<&2, F32>) -> Mat.Material:
  pick_material(valid_named(ps, name, xs), Mat.instance(m, written(ps, Mat.values(m), name, xs)), m)

# Number k of a list set to x.
def set_at(xs: List<&2, F32>, +k: U32, +x: F32) -> List<&2, F32>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      pick_nums(U32.is_eq(k, 0), x <> t, h <> set_at(t, (k - 1 : U32), x))

def no_asset() -> Asset:
  Asset{"", "", "", Nil{}}

def pick_asset(c: Bool, a: Asset, b: Asset) -> Asset:
  match c:
    case True{}:
      a
    case False{}:
      b

# The asset with this id; an empty one when there is none.
def asset_of(xs: List<&2, Asset>, +want: String) -> Asset:
  match xs:
    case Nil{}:
      no_asset()
    case +h <> t:
      pick_asset(String.eq(id(h), want), h, asset_of(t, want))

def pick_string(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# What is wrong with this path; "" when nothing is.
def problem_of(ps: List<&2, Problem>, +want: String) -> String:
  match ps:
    case Nil{}:
      ""
    case +h <> t:
      pick_string(String.eq(path(h), want), message(h), problem_of(t, want))

# What the parameter named `name` is worth on these values; none when
# there is no such parameter.
def value_named(ps: List<&2, Param>, +vs: List<&2, Mat.Value>, +name: String) -> List<&2, F32>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> t:
      pick_nums(String.eq(param_name(h), name), value(h, vs), value_named(t, vs, name))

# The label of the choice worth x; "" when no choice is.
def choice_label(cs: List<&2, Choice>, +x: F32) -> String:
  match cs:
    case Nil{}:
      ""
    case h <> t:
      Choice{+l, v} = h
      pick_string(F32.is_eq(v, x), l, choice_label(t, x))
