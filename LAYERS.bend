# The engine's layers: which folder is what, which may import which, and what may be inside a
# published game. `bun run check` asks this file about every import in the repository, and
# `bun run export` about every file a game's build reaches, so "the runtime never imports the
# editor" and "nothing reaches refs/" are checked, not only written down.
#
#   places()             THE list of the engine's folders and root files, most specific first:
#                        a new folder is one line here, and a file no line names is Outside,
#                        which the check refuses
#   layer_of(path)       the layer of a repository path
#   typed(path)          whether `bun run check` type-checks the .bend files under it
#   may_import(a, b)     may a file of layer a import a file of layer b?
#   ships(l)             may a file of layer l be inside a published game?
#   debts()              imports that break a rule today, allowed by name until they are paid;
#                        a debt that no longer exists fails the check, so the list cannot rot
#   edge(from, to)       what the check says about one import: fine, owed, or blocked
#   stowaways(files)     the files of a game's build whose layer never ships (export refuses them)
#
# The shell (tools/layers.ts) reads files and finds the imports; this file decides.
#
# Limits now:
# - Imports are found as text (`import ./x.bend`, `from "x"`, `import("x")`, `src="x"`): an import
#   whose path is computed at run time is not seen.
# - A layer is a place in the tree; nothing checks what a file inside it does.

import Base

type Layer is Data:
  Layer.Engine{}            # engine/                  pure Bend runtime
  Layer.PlatWeb{}           # platform/web/            the runtime's JavaScript: drawing, input, frames
  Layer.Project{}           # projects/                the engine's own test games
  Layer.Catalog{}           # PROJECT.bend             the list of projects
  Layer.Mannequin{}         # mannequin/               the standard character (ships with its credit)
  Layer.MannequinLaws{}     # mannequin/ laws and weights.bend (laws data only)
  Layer.MannequinSource{}   # mannequin/source/, gltf/ the originals the importer converts
  Layer.Library{}           # library/                 the animation library's motions
  Layer.LibraryIndex{}      # library/catalog.bend     the editor's 42-clip catalog
  Layer.LibrarySource{}     # library/*/source/        the originals
  Layer.UiKit{}             # node_modules/bend-ui/    Bend-UI
  Layer.GameGen{}           # .export/gen/             written by export for one game
  Layer.Editor{}            # editor/ (its page: editor/index.html)
  Layer.Export{}            # export/                  the build tool
  Layer.Rules{}             # LAYERS.bend              this file
  Layer.Tools{}             # tools/
  Layer.Tests{}             # tests/, and every LAWS.bend and PROOF.bend
  Layer.Docs{}              # docs/, docs/ARCHITECTURE.html, docs/EXPORT.html
  Layer.Refs{}              # refs/                    third-party study material, never shipped
  Layer.Outside{}           # a path no place names

type Place is Data:
  Place{prefix: String, layer: Layer, typed: Bool}

def places() -> List<&2, Place>:
  [Place{"mannequin/LAWS.bend", Layer.MannequinLaws{}, False{}},
   Place{"mannequin/PROOF.bend", Layer.MannequinLaws{}, False{}},
   Place{"mannequin/gen/weights.bend", Layer.MannequinLaws{}, True{}},
   Place{"mannequin/source/", Layer.MannequinSource{}, False{}},
   Place{"mannequin/gltf/", Layer.MannequinSource{}, False{}},
   Place{"mannequin/", Layer.Mannequin{}, True{}},
   Place{"library/catalog.bend", Layer.LibraryIndex{}, True{}},
   Place{"library/quaternius/source/", Layer.LibrarySource{}, False{}},
   Place{"library/", Layer.Library{}, True{}},
   Place{"engine/", Layer.Engine{}, True{}},
   Place{"platform/web/", Layer.PlatWeb{}, False{}},
   Place{"projects/", Layer.Project{}, True{}},
   Place{"PROJECT.bend", Layer.Catalog{}, True{}},
   Place{"node_modules/bend-ui/", Layer.UiKit{}, False{}},
   Place{".export/gen/", Layer.GameGen{}, False{}},
   Place{"editor/", Layer.Editor{}, True{}},
   Place{"export/", Layer.Export{}, True{}},
   Place{"LAYERS.bend", Layer.Rules{}, True{}},
   Place{"tools/", Layer.Tools{}, False{}},
   Place{"tests/", Layer.Tests{}, True{}},
   Place{"docs/", Layer.Docs{}, False{}},
   Place{"docs/ARCHITECTURE.html", Layer.Docs{}, False{}},
   Place{"docs/EXPORT.html", Layer.Docs{}, False{}},
   Place{"refs/", Layer.Refs{}, False{}}]

def Layers.choose(hit: Bool, +here: Layer, +rest: Layer) -> Layer:
  match hit:
    case True{}:
      here
    case False{}:
      rest

def Layers.find(ps: List<&2, Place>, +path: String) -> Layer:
  match ps:
    case Nil{}:
      Layer.Outside{}
    case Con{Place{prefix, layer, _}, t}:
      Layers.choose(String.starts_with(path, prefix), layer, Layers.find(t, path))

# A module's laws and proofs (LAWS.bend, PROOF.bend, beside the code they speak about) are
# tests, wherever they sit; the mannequin's keep their own layer.
def Layers.is_laws(+path: String) -> Bool:
  (String.eq(path, "LAWS.bend") || String.eq(path, "PROOF.bend")
    || String.ends_with(path, "/LAWS.bend") || String.ends_with(path, "/PROOF.bend"))

def Layers.as_laws(l: Layer) -> Layer:
  match l:
    case Layer.MannequinLaws{}:
      Layer.MannequinLaws{}
    case _:
      Layer.Tests{}

def Layers.laws_or(hit: Bool, l: Layer) -> Layer:
  match hit:
    case True{}:
      Layers.as_laws(l)
    case False{}:
      l

def layer_of(+path: String) -> Layer:
  Layers.laws_or(Layers.is_laws(path), Layers.find(places(), path))

def Layers.typed_or(hit: Bool, +here: Bool, +rest: Bool) -> Bool:
  match hit:
    case True{}:
      here
    case False{}:
      rest

def Layers.typed(ps: List<&2, Place>, +path: String) -> Bool:
  match ps:
    case Nil{}:
      False{}
    case Con{Place{prefix, _, typed}, t}:
      Layers.typed_or(String.starts_with(path, prefix), typed, Layers.typed(t, path))

def typed(+path: String) -> Bool:
  Layers.typed(places(), path)

# A number per layer, so a list of layers can be searched without an equality on the type.
def Layer.id(l: Layer) -> U32:
  match l:
    case Layer.Engine{}:
      0
    case Layer.PlatWeb{}:
      1
    case Layer.Project{}:
      2
    case Layer.Catalog{}:
      3
    case Layer.Mannequin{}:
      4
    case Layer.MannequinLaws{}:
      5
    case Layer.MannequinSource{}:
      6
    case Layer.Library{}:
      7
    case Layer.LibraryIndex{}:
      8
    case Layer.LibrarySource{}:
      9
    case Layer.UiKit{}:
      10
    case Layer.GameGen{}:
      11
    case Layer.Editor{}:
      12
    case Layer.Export{}:
      13
    case Layer.Rules{}:
      14
    case Layer.Tools{}:
      15
    case Layer.Tests{}:
      16
    case Layer.Docs{}:
      17
    case Layer.Refs{}:
      18
    case Layer.Outside{}:
      19

def Layer.name(l: Layer) -> String:
  match l:
    case Layer.Engine{}:
      "engine"
    case Layer.PlatWeb{}:
      "platform/web"
    case Layer.Project{}:
      "projects"
    case Layer.Catalog{}:
      "PROJECT.bend"
    case Layer.Mannequin{}:
      "mannequin"
    case Layer.MannequinLaws{}:
      "the mannequin's laws"
    case Layer.MannequinSource{}:
      "the mannequin's originals"
    case Layer.Library{}:
      "library"
    case Layer.LibraryIndex{}:
      "the library's catalog"
    case Layer.LibrarySource{}:
      "the library's originals"
    case Layer.UiKit{}:
      "Bend-UI"
    case Layer.GameGen{}:
      "a generated game"
    case Layer.Editor{}:
      "the editor"
    case Layer.Export{}:
      "export"
    case Layer.Rules{}:
      "LAYERS.bend"
    case Layer.Tools{}:
      "tools"
    case Layer.Tests{}:
      "tests"
    case Layer.Docs{}:
      "docs"
    case Layer.Refs{}:
      "refs"
    case Layer.Outside{}:
      "no layer (add the folder to LAYERS.bend places())"

# Whether a file of this layer may be inside a published game. Everything a game runs on ships;
# tools, laws, originals and the editor never do.
def ships(l: Layer) -> Bool:
  match l:
    case Layer.Engine{}:
      True{}
    case Layer.PlatWeb{}:
      True{}
    case Layer.Project{}:
      True{}
    case Layer.Catalog{}:
      True{}
    case Layer.Mannequin{}:
      True{}
    case Layer.MannequinLaws{}:
      False{}
    case Layer.MannequinSource{}:
      True{}      # the skin's two textures live in source/ (editor/main.js and export/needs.bend take
                  # them from there); only the files a game imports ship, never the whole folder
    case Layer.Library{}:
      True{}
    case Layer.LibraryIndex{}:
      False{}
    case Layer.LibrarySource{}:
      False{}
    case Layer.UiKit{}:
      True{}
    case Layer.GameGen{}:
      True{}
    case Layer.Editor{}:
      False{}
    case Layer.Export{}:
      False{}
    case Layer.Rules{}:
      False{}
    case Layer.Tools{}:
      False{}
    case Layer.Tests{}:
      False{}
    case Layer.Docs{}:
      False{}
    case Layer.Refs{}:
      False{}
    case Layer.Outside{}:
      False{}

def Layers.has(ls: List<&2, Layer>, +id: U32) -> Bool:
  match ls:
    case Nil{}:
      False{}
    case Con{l, t}:
      (U32.is_eq(Layer.id(l), id) || Layers.has(t, id))

# What each layer may import (besides Base). Tools and tests may import anything but refs/;
# refs/ may import anything, and nothing outside refs/ imports it.
def allowed(a: Layer) -> List<&2, Layer>:
  match a:
    case Layer.Engine{}:
      [Layer.Engine{}]
    case Layer.PlatWeb{}:
      [Layer.PlatWeb{}, Layer.Engine{}]
    case Layer.Project{}:
      [Layer.Project{}, Layer.Engine{}, Layer.Mannequin{}, Layer.Library{}]
    case Layer.Catalog{}:
      [Layer.Catalog{}, Layer.Project{}, Layer.Engine{}, Layer.Mannequin{}, Layer.Library{}]
    case Layer.Mannequin{}:
      [Layer.Mannequin{}, Layer.Engine{}]
    case Layer.MannequinLaws{}:
      [Layer.MannequinLaws{}, Layer.Mannequin{}, Layer.Engine{}]
    case Layer.MannequinSource{}:
      []
    case Layer.Library{}:
      [Layer.Library{}, Layer.Engine{}]
    case Layer.LibraryIndex{}:
      [Layer.LibraryIndex{}, Layer.Library{}, Layer.Engine{}]
    case Layer.LibrarySource{}:
      []
    case Layer.UiKit{}:
      [Layer.UiKit{}]
    case Layer.GameGen{}:
      [Layer.GameGen{}, Layer.Catalog{}, Layer.Project{}, Layer.Engine{}, Layer.Mannequin{},
       Layer.MannequinSource{}, Layer.Library{}, Layer.PlatWeb{}, Layer.UiKit{}]
    case Layer.Editor{}:
      [Layer.Editor{}, Layer.Engine{}, Layer.PlatWeb{}, Layer.Project{}, Layer.Catalog{},
       Layer.Mannequin{}, Layer.MannequinSource{}, Layer.Library{}, Layer.LibraryIndex{}, Layer.UiKit{}]
    case Layer.Export{}:
      [Layer.Export{}, Layer.Catalog{}, Layer.Project{}, Layer.Engine{}, Layer.Mannequin{},
       Layer.Library{}, Layer.UiKit{}, Layer.Rules{}, Layer.Tools{}]
    case Layer.Rules{}:
      []
    case Layer.Tools{}:
      [Layer.Engine{}, Layer.PlatWeb{}, Layer.Project{}, Layer.Catalog{}, Layer.Mannequin{},
       Layer.MannequinLaws{}, Layer.MannequinSource{}, Layer.Library{}, Layer.LibraryIndex{},
       Layer.LibrarySource{}, Layer.UiKit{}, Layer.GameGen{}, Layer.Editor{}, Layer.Export{},
       Layer.Rules{}, Layer.Tools{}, Layer.Tests{}, Layer.Docs{}]
    case Layer.Tests{}:
      [Layer.Engine{}, Layer.PlatWeb{}, Layer.Project{}, Layer.Catalog{}, Layer.Mannequin{},
       Layer.MannequinLaws{}, Layer.MannequinSource{}, Layer.Library{}, Layer.LibraryIndex{},
       Layer.LibrarySource{}, Layer.UiKit{}, Layer.GameGen{}, Layer.Editor{}, Layer.Export{},
       Layer.Rules{}, Layer.Tools{}, Layer.Tests{}, Layer.Docs{}]
    case Layer.Docs{}:
      [Layer.Docs{}]
    case Layer.Refs{}:
      [Layer.Engine{}, Layer.PlatWeb{}, Layer.Project{}, Layer.Catalog{}, Layer.Mannequin{},
       Layer.MannequinLaws{}, Layer.MannequinSource{}, Layer.Library{}, Layer.LibraryIndex{},
       Layer.LibrarySource{}, Layer.UiKit{}, Layer.GameGen{}, Layer.Editor{}, Layer.Export{},
       Layer.Rules{}, Layer.Tools{}, Layer.Tests{}, Layer.Docs{}, Layer.Refs{}]
    case Layer.Outside{}:
      []

def may_import(a: Layer, b: Layer) -> Bool:
  Layers.has(allowed(a), Layer.id(b))

# ---------- Debts ----------

# An import allowed for now although it breaks a rule, and why. `from` is a path or a folder
# prefix (a generated game is .export/gen/<game>/...); `to` is the imported file.
type Debt is Data:
  Debt{from: String, to: String, why: String}

def debts() -> List<&2, Debt>:
  [Debt{"engine/scene/world.bend", "node_modules/bend-ui/TOKENS.bend",
     "the grid's colors are Bend-UI tokens; move them into engine/core/color.bend or pass them in"},
   Debt{"projects/water/water.bend", "node_modules/bend-ui/TOKENS.bend",
     "the water's color is a Bend-UI token"},
   Debt{".export/gen/", "editor/defaults/ACCESSIBILITY.bend",
     "every game reads the accessibility settings, which live in the editor's folder; they need a runtime home"}]

def Debts.is(d: Debt, +from: String, +to: String) -> Bool:
  match d:
    case Debt{f, t, _}:
      (String.starts_with(from, f) && String.eq(to, t))

def Debts.keep(hit: Bool, d: Debt, rest: List<&2, String>) -> List<&2, String>:
  match hit:
    case True{}:
      match d:
        case Debt{_, _, why}:
          [why]
    case False{}:
      rest

def Debts.why(ds: List<&2, Debt>, +from: String, +to: String) -> List<&2, String>:
  match ds:
    case Nil{}:
      []
    case Con{+d, t}:
      Debts.keep(Debts.is(d, from, to), d, Debts.why(t, from, to))


# A file a debt lets into a game although its layer never ships.
def Debts.target(ds: List<&2, Debt>, +to: String) -> Bool:
  match ds:
    case Nil{}:
      False{}
    case Con{Debt{_, t, _}, rest}:
      (String.eq(t, to) || Debts.target(rest, to))

# ---------- What the check and export ask ----------

type Edge is Data:
  Edge.Fine{}
  Edge.Owed{why: String}
  Edge.Blocked{rule: String}

def Edges.blocked(+from: String, +to: String) -> String:
  String.concat([Layer.name(layer_of(from)), " may not import ", Layer.name(layer_of(to))])

def Edges.allowed(ok: Bool, +from: String, +to: String) -> Edge:
  match ok:
    case True{}:
      Edge.Fine{}
    case False{}:
      Edge.Blocked{Edges.blocked(from, to)}

def Edges.of(owed: List<&2, String>, +from: String, +to: String) -> Edge:
  match owed:
    case Con{why, _}:
      Edge.Owed{why}
    case Nil{}:
      Edges.allowed(may_import(layer_of(from), layer_of(to)), from, to)

def edge(+from: String, +to: String) -> Edge:
  Edges.of(Debts.why(debts(), from, to), from, to)

def Stow.keep(out: Bool, +path: String, rest: List<&2, String>) -> List<&2, String>:
  match out:
    case True{}:
      path <> rest
    case False{}:
      rest

def stowaways(files: List<&2, String>) -> List<&2, String>:
  match files:
    case Nil{}:
      []
    case Con{+f, t}:
      Stow.keep(Bool.and(Bool.not(ships(layer_of(f))), Bool.not(Debts.target(debts(), f))), f, stowaways(t))

# The check's line for one import: "" when fine, "owed: <why>", or "blocked: <rule>".
def Edges.text(e: Edge) -> String:
  match e:
    case Edge.Fine{}:
      ""
    case Edge.Owed{why}:
      String.append("owed: ", why)
    case Edge.Blocked{rule}:
      String.append("blocked: ", rule)

def verdict(+from: String, +to: String) -> String:
  Edges.text(edge(from, to))

def Layers.name_of(+path: String) -> String:
  Layer.name(layer_of(path))

def placed(+path: String) -> Bool:
  Bool.not(U32.is_eq(Layer.id(layer_of(path)), 19))

# Each debt as "from<TAB>to", so the check can tell a debt nothing uses any more.
def Debts.line(d: Debt) -> String:
  match d:
    case Debt{from, to, _}:
      String.concat([from, "\t", to])

def Debts.lines(ds: List<&2, Debt>) -> List<&2, String>:
  match ds:
    case Nil{}:
      []
    case Con{d, t}:
      Debts.line(d) <> Debts.lines(t)

def debt_lines() -> List<&2, String>: Debts.lines(debts())

def Layer.is_refs(l: Layer) -> Bool: U32.is_eq(Layer.id(l), 18)
