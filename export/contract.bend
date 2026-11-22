# Export's decisions about one game folder: what each file is, how it is cached, the two
# budgets, the credits a game owes, the build machine it needs, and whether the build ships.
# The shell (export/web.ts, later) only measures a build into Facts and writes what this file
# returns; it never decides (docs/architecture/export).
#
#   release(checks, facts)    Shipped{manifest} or Refused{reasons}; the checks are matched
#                             first, so nothing ships when `bun run check` failed (a law)
#   cache(role)               the page revalidates; code and assets are immutable (hashed names)
#   code_budget/asset_budget  bytes on the wire, from one reach rule: 1.6 Mbit/s, the first
#                             frame in 1.5 s, the game playable in 10 s
#   attribution(page, works)  a work whose license asks for its credit refuses a folder without
#                             a credits page (the mannequin is CC BY 4.0: a law)
#   toolchain(tools, hlsl)    the pinned Bend, its module tree shaking (not-in-bend.txt), and
#                             dxc + spirv-cross when the game uses an HLSL shader
#   say(reason)               one line for a person
#
# Limits now:
# - Facts are measured by the shell; nothing here reads a file or a clock.
# - Only web builds. Native targets come with their own exporter.
# - Hashed names are the bundler's; a file named without a hash is not detected yet.
# - The mannequin depicts a character owned by Square Enix / Disney: its CC BY credit covers
#   the model, not the character. Nothing here decides about that (the owner's call).
# - The budget numbers come from the reach rule above; a real phone may differ.

import Base

# Page: index.html, the one page a game opens on. Doc: another page beside it (credits.html),
# not needed for the first frame. Code: JS and CSS. Asset: everything else (skins, textures).
type Role is Data:
  Role.Page{}
  Role.Doc{}
  Role.Code{}
  Role.Asset{}

type Cache is Data:
  Cache.Immutable{}
  Cache.Revalidate{}

# Third-party works the engine can put in a game. A new one is a new case, and every match
# below makes the compiler ask what to do with it.
type Work is Data:
  Work.Mannequin{}
  Work.Quaternius{}
  Work.BendUi{}

# One file of the folder. `wire` is what a player downloads: gzip size for text, raw size for
# files that are already compressed (PNG).
type Entry is Data:
  Entry{path: String, role: Role, bytes: U32, wire: U32, sha: String}

type Toolchain is Data:
  Toolchain{bend: String, treeshake: Bool, dxc: Bool, spirv_cross: Bool}

type Facts is Data:
  Facts{game: String, title: String, entries: List<&2, Entry>, works: List<&2, Work>,
    credits_page: Bool, hlsl: Bool, tools: Toolchain}

type Reason is Data:
  Reason.ChecksFailed{}
  Reason.NoPage{}
  Reason.TwoPages{}
  Reason.OverCode{wire: U32, budget: U32}
  Reason.OverAssets{wire: U32, budget: U32}
  Reason.Uncredited{work: Work}
  Reason.WrongBend{found: String}
  Reason.NoTreeshake{}
  Reason.ToolMissing{tool: String}

type Load is Data:
  Load{code: U32, assets: U32}

type Credit is Data:
  Credit{title: String, author: String, license: String, url: String, notice: String}

type Manifest is Data:
  Manifest{format: U32, game: String, title: String, load: Load, credits: List<&2, Credit>,
    entries: List<&2, Entry>}

type Outcome is Data:
  Outcome.Shipped{m: Manifest}
  Outcome.Refused{reasons: List<&2, Reason>}

def format() -> U32: 1

def pinned_bend() -> String: "2.0.40"

# 1.6 Mbit/s is 200,000 bytes a second: the code blocks the first frame (1.5 s); the assets do
# not (the game is playable within 10 s).
def code_budget() -> U32: 300000

def asset_budget() -> U32: 2000000

def cache(r: Role) -> Cache:
  match r:
    case Role.Page{}:
      Cache.Revalidate{}
    case Role.Doc{}:
      Cache.Revalidate{}
    case Role.Code{}:
      Cache.Immutable{}
    case Role.Asset{}:
      Cache.Immutable{}

# ---------- Credits ----------

def credit(w: Work) -> Credit:
  match w:
    case Work.Mannequin{}:
      Credit{"Sora (Kingdom Hearts Melody of Memory)", "雨宮レン", "CC BY 4.0",
        "https://skfb.ly/pPNsQ", "The character is (c) Square Enix / Disney."}
    case Work.Quaternius{}:
      Credit{"Universal Animation Library", "Quaternius", "CC0 1.0",
        "https://quaternius.com", ""}
    case Work.BendUi{}:
      Credit{"Bend-UI", "Isabella Herman", "no license file",
        "https://github.com/isabellaherman/Bend-UI", ""}

# Whether the work's license asks for its credit to be shown. CC0 asks nothing; a work with no
# license found is shown, as the safe side.
def must_show(w: Work) -> Bool:
  match w:
    case Work.Mannequin{}:
      True{}
    case Work.Quaternius{}:
      False{}
    case Work.BendUi{}:
      True{}

def credits(ws: List<&2, Work>) -> List<&2, Credit>:
  match ws:
    case Nil{}:
      []
    case Con{w, t}:
      credit(w) <> credits(t)

def attribution.keep(show: Bool, w: Work, rest: List<&2, Reason>) -> List<&2, Reason>:
  match show:
    case True{}:
      Reason.Uncredited{w} <> rest
    case False{}:
      rest

def attribution.go(ws: List<&2, Work>) -> List<&2, Reason>:
  match ws:
    case Nil{}:
      []
    case Con{+w, t}:
      attribution.keep(must_show(w), w, attribution.go(t))

# Matched on the credits page first: with one in the folder nothing is owed, whatever ships.
def attribution(credits_page: Bool, ws: List<&2, Work>) -> List<&2, Reason>:
  match credits_page:
    case True{}:
      []
    case False{}:
      attribution.go(ws)

# ---------- The folder's shape and load ----------

def Load.code(+wire: U32, l: Load) -> Load:
  match l:
    case Load{code, assets}:
      Load{(code + wire : U32), assets}

def Load.assets(+wire: U32, l: Load) -> Load:
  match l:
    case Load{code, assets}:
      Load{code, (assets + wire : U32)}

def Load.add(role: Role, +wire: U32, l: Load) -> Load:
  match role:
    case Role.Page{}:
      Load.code(wire, l)
    case Role.Doc{}:
      Load.assets(wire, l)
    case Role.Code{}:
      Load.code(wire, l)
    case Role.Asset{}:
      Load.assets(wire, l)

def Load.entry(e: Entry, l: Load) -> Load:
  match e:
    case Entry{_, role, _, wire, _}:
      Load.add(role, wire, l)

def load(es: List<&2, Entry>) -> Load:
  match es:
    case Nil{}:
      Load{0, 0}
    case Con{e, t}:
      Load.entry(e, load(t))

def Role.is_page(r: Role) -> U32:
  match r:
    case Role.Page{}:
      1
    case Role.Doc{}:
      0
    case Role.Code{}:
      0
    case Role.Asset{}:
      0

def Entry.page(e: Entry) -> U32:
  match e:
    case Entry{_, role, _, _, _}:
      Role.is_page(role)

def pages(es: List<&2, Entry>) -> U32:
  match es:
    case Nil{}:
      0
    case Con{e, t}:
      (Entry.page(e) + pages(t) : U32)

def shape.many(many: Bool) -> List<&2, Reason>:
  match many:
    case True{}:
      [Reason.TwoPages{}]
    case False{}:
      []

def shape.count(none: Bool, +n: U32) -> List<&2, Reason>:
  match none:
    case True{}:
      [Reason.NoPage{}]
    case False{}:
      shape.many(U32.is_gt(n, 1))

def shape.pages(+n: U32) -> List<&2, Reason>:
  shape.count(U32.is_eq(n, 0), n)

def shape(es: List<&2, Entry>) -> List<&2, Reason>:
  shape.pages(pages(es))

def over(over: Bool, r: Reason) -> List<&2, Reason>:
  match over:
    case True{}:
      [r]
    case False{}:
      []

def budget(l: Load) -> List<&2, Reason>:
  match l:
    case Load{+code, +assets}:
      List.append(&2, Reason,
        over(U32.is_gt(code, code_budget()), Reason.OverCode{code, code_budget()}),
        over(U32.is_gt(assets, asset_budget()), Reason.OverAssets{assets, asset_budget()}))

# ---------- The build machine ----------

def toolchain.hlsl(hlsl: Bool, dxc: Bool, spirv_cross: Bool) -> List<&2, Reason>:
  match hlsl:
    case True{}:
      List.append(&2, Reason,
        over(Bool.not(dxc), Reason.ToolMissing{"dxc"}),
        over(Bool.not(spirv_cross), Reason.ToolMissing{"spirv-cross"}))
    case False{}:
      []

def toolchain(t: Toolchain, hlsl: Bool) -> List<&2, Reason>:
  match t:
    case Toolchain{+bend, treeshake, dxc, spirv_cross}:
      List.concat(&2, Reason,
        [over(Bool.not(String.eq(bend, pinned_bend())), Reason.WrongBend{bend}),
         over(Bool.not(treeshake), Reason.NoTreeshake{}),
         toolchain.hlsl(hlsl, dxc, spirv_cross)])

# ---------- The verdict ----------

def manifest(f: Facts) -> Manifest:
  match f:
    case Facts{game, title, +entries, works, _, _, _}:
      Manifest{format(), game, title, load(entries), credits(works), entries}

def reasons(f: Facts) -> List<&2, Reason>:
  match f:
    case Facts{_, _, +entries, works, credits_page, hlsl, tools}:
      List.concat(&2, Reason,
        [shape(entries), budget(load(entries)), attribution(credits_page, works),
         toolchain(tools, hlsl)])

def decide(rs: List<&2, Reason>, +f: Facts) -> Outcome:
  match rs:
    case Nil{}:
      Outcome.Shipped{manifest(f)}
    case Con{r, t}:
      Outcome.Refused{r <> t}

def release.go(+f: Facts) -> Outcome:
  decide(reasons(f), f)

# Nothing ships when the checks failed: `checks` is matched first, so the law holds by
# reduction for any facts.
def release(checks: Bool, +f: Facts) -> Outcome:
  match checks:
    case False{}:
      Outcome.Refused{[Reason.ChecksFailed{}]}
    case True{}:
      release.go(f)

# ---------- For a person ----------

def Credit.title(c: Credit) -> String:
  match c:
    case Credit{title, _, _, _, _}:
      title

def Work.title(w: Work) -> String:
  Credit.title(credit(w))

def say(r: Reason) -> String:
  match r:
    case Reason.ChecksFailed{}:
      "check: `bun run check` did not pass; nothing ships until it does"
    case Reason.NoPage{}:
      "shape: the build has no index.html"
    case Reason.TwoPages{}:
      "shape: the build has more than one page"
    case Reason.OverCode{wire, budget}:
      String.concat(["budget: the code is ", U32.show(wire), " bytes on the wire, over the ",
        U32.show(budget), " the first frame allows (1.5 s at 1.6 Mbit/s)"])
    case Reason.OverAssets{wire, budget}:
      String.concat(["budget: the assets are ", U32.show(wire), " bytes on the wire, over the ",
        U32.show(budget), " a playable game allows (10 s at 1.6 Mbit/s)"])
    case Reason.Uncredited{w}:
      String.concat(["credits: ", Work.title(w),
        " ships, and its license asks for its credit to be shown: the folder needs credits.html"])
    case Reason.WrongBend{found}:
      String.concat(["toolchain: Bend ", found, " found; the engine pins ", pinned_bend()])
    case Reason.NoTreeshake{}:
      "toolchain: ../bend lacks the module tree shaking the engine builds with (see not-in-bend.txt)"
    case Reason.ToolMissing{tool}:
      String.concat(["toolchain: ", tool, " is not installed, and the game uses an HLSL shader"])

# ---------- Reading a manifest ----------

def Manifest.load(m: Manifest) -> Load:
  match m:
    case Manifest{_, _, _, l, _, _}:
      l

def Credit.titles(cs: List<&2, Credit>) -> String:
  match cs:
    case Nil{}:
      ""
    case Con{c, Nil{}}:
      Credit.title(c)
    case Con{c, t}:
      String.concat([Credit.title(c), ", ", Credit.titles(t)])

def Manifest.credit_titles(m: Manifest) -> String:
  match m:
    case Manifest{_, _, _, _, cs, _}:
      Credit.titles(cs)
