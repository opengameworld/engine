# Numerical tests of export/contract.bend (what makes a build ship or be refused, and what its
# manifest says) and export/files.bend (what export writes and how it reads a built file).
#
# Limits now:
# - Chosen builds (the Character game's real sizes, the mannequin's assets, one over each
#   budget), not every build.

import Base
import ../../export/contract.bend as Ex
import ../../export/files.bend as F

type Check is Data:
  Check{name: String, ok: Bool}

def page() -> Ex.Entry: Ex.Entry{"index.html", Ex.Role.Page{}, 412, 290, "p"}
def code() -> Ex.Entry: Ex.Entry{"_/game-3f9a2c41.js", Ex.Role.Code{}, 170726, 34067, "c"}
def skin() -> Ex.Entry: Ex.Entry{"a/7d1e.bin", Ex.Role.Asset{}, 259248, 107518, "s"}
def body() -> Ex.Entry: Ex.Entry{"a/9b02.png", Ex.Role.Asset{}, 597989, 597989, "b"}
def face() -> Ex.Entry: Ex.Entry{"a/41c7.png", Ex.Role.Asset{}, 569562, 569562, "f"}
def big() -> Ex.Entry: Ex.Entry{"_/all-clips.js", Ex.Role.Code{}, 9288354, 1927325, "x"}

def tools() -> Ex.Toolchain: Ex.Toolchain{"2.0.40", True{}, False{}, False{}}

def facts(+es: List<&2, Ex.Entry>, +ws: List<&2, Ex.Work>, +credits: Bool, +hlsl: Bool, +t: Ex.Toolchain) -> Ex.Facts:
  Ex.Facts{"character", "Character", es, ws, credits, hlsl, t, []}

def with_mannequin() -> List<&2, Ex.Entry>: [page(), code(), skin(), body(), face()]

def ships(o: Ex.Outcome) -> Bool:
  match o:
    case Ex.Outcome.Shipped{_}:
      True{}
    case Ex.Outcome.Refused{_}:
      False{}

def reasons(o: Ex.Outcome) -> List<&2, Ex.Reason>:
  match o:
    case Ex.Outcome.Shipped{_}:
      []
    case Ex.Outcome.Refused{rs}:
      rs

def lines(rs: List<&2, Ex.Reason>) -> String:
  match rs:
    case Nil{}:
      ""
    case Con{r, t}:
      String.concat([Ex.say(r), "\n", lines(t)])

def refused_for(+o: Ex.Outcome, +want: Ex.Reason) -> Bool:
  String.eq(lines(reasons(o)), String.append(Ex.say(want), "\n"))

def loaded(o: Ex.Outcome) -> Ex.Load:
  match o:
    case Ex.Outcome.Shipped{m}:
      Ex.Manifest.load(m)
    case Ex.Outcome.Refused{_}:
      Ex.Load{0, 0}

def code_wire(l: Ex.Load) -> U32:
  match l:
    case Ex.Load{c, _}:
      c

def asset_wire(l: Ex.Load) -> U32:
  match l:
    case Ex.Load{_, a}:
      a

def credit_titles(o: Ex.Outcome) -> String:
  match o:
    case Ex.Outcome.Shipped{m}:
      Ex.Manifest.credit_titles(m)
    case Ex.Outcome.Refused{_}:
      "refused"


def role_name(r: Ex.Role) -> String:
  match r:
    case Ex.Role.Page{}:
      "page"
    case Ex.Role.Doc{}:
      "doc"
    case Ex.Role.Code{}:
      "code"
    case Ex.Role.Asset{}:
      "asset"

def has(+s: String, +part: String) -> Bool:
  String.contains(s, part)

def load_of(es: List<&2, Ex.Entry>) -> U32:
  match es:
    case Con{Ex.Entry{_, _, _, wire, _}, _}:
      wire
    case Nil{}:
      0

def placed() -> List<&2, Ex.Entry>:
  F.entry("index.html", 400, 300, "s", F.entry("credits.html", 900, 500, "s",
    F.entry("_/chunk-22cryak6.js", 172188, 43941, "s", F.entry("a/skin-29mnqhsf.bin", 10, 5, "s", F.entries_none()))))

def files_checks() -> List<&2, Check>:
  [Check{"index.html is the page, credits.html a doc, what is in _/ code, what is in a/ an asset",
     (String.eq(role_name(F.role_of("index.html")), "page") && String.eq(role_name(F.role_of("credits.html")), "doc")
       && String.eq(role_name(F.role_of("_/chunk-5nmq0pr0.js")), "code") && String.eq(role_name(F.role_of("a/p_ism001_00-ph83475s.png")), "asset"))},
   Check{"a character build with its pages, _/ and a/ ships",
     F.shipped(F.release(True{}, "character", placed(), True{}, F.tools("2.0.40", True{}, False{}, False{}), F.paths_none(), F.paths_none(), F.paths_none()))},
   Check{"a file beside the pages that is not a page refuses the build, and says which",
     has(F.reasons_text(F.release(True{}, "character", F.entry("skin.bin", 10, 5, "s", placed()), True{}, F.tools("2.0.40", True{}, False{}, False{}), F.paths_none(), F.paths_none(), F.paths_none())),
       "skin.bin: only pages may sit outside _/ and a/")},
   Check{"PNGs travel as they are; code and the skin's .bin travel gzipped",
     (Bool.not(F.compresses("a.png")) && F.compresses("chunk.js") && F.compresses("skin-29mnqhsf.bin"))},
   Check{"a PNG's wire size is its size; a chunk's is its gzip size",
     (U32.is_eq(load_of(F.entry("t.png", 597989, 597000, "s", F.entries_none())), 597989)
       && U32.is_eq(load_of(F.entry("c.js", 172188, 43941, "s", F.entries_none())), 43941))},
   Check{"the four projects are games; another name is not",
     (F.known("water") && F.known("character") && F.known("mannequin") && F.known("animation") && Bool.not(F.known("nonexistent")))},
   Check{"the mannequin's game imports its skin and textures; the arm's game imports none",
     (has(F.entry_js("mannequin"), "mannequin/gen/skin.bin") && has(F.entry_js("mannequin"), "p_ism001_01.png")
       && Bool.not(has(F.entry_js("character"), "skin.bin")))},
   Check{"the mannequin's credits page names it, its author and its license",
     (has(F.credits_html("mannequin"), "Sora (Kingdom Hearts Melody of Memory)") && has(F.credits_html("mannequin"), "CC BY 4.0"))},
   Check{"the generated game module opens the game it was made for",
     has(F.game_module("water"), "P.preview(\"water\")")},
   Check{"the build folder is under .export",
     String.eq(F.folder("character"), ".export/web/character")}]



def contract_checks() -> List<&2, Check>:
  [Check{"a game with the mannequin, its credits page and the treeshaken Bend ships",
     ships(Ex.release(True{}, facts(with_mannequin(), [Ex.Work.Mannequin{}], True{}, False{}, tools())))},
   Check{"its load counts the page and code apart from the assets",
     (U32.is_eq(code_wire(loaded(Ex.release(True{}, facts(with_mannequin(), [Ex.Work.Mannequin{}], True{}, False{}, tools())))), 34357)
       && U32.is_eq(asset_wire(loaded(Ex.release(True{}, facts(with_mannequin(), [Ex.Work.Mannequin{}], True{}, False{}, tools())))), 1275069))},
   Check{"its manifest carries the mannequin's credit",
     String.eq(credit_titles(Ex.release(True{}, facts(with_mannequin(), [Ex.Work.Mannequin{}], True{}, False{}, tools()))), "Sora (Kingdom Hearts Melody of Memory)")},
   Check{"a failed check refuses it, and says only that",
     refused_for(Ex.release(False{}, facts(with_mannequin(), [Ex.Work.Mannequin{}], True{}, False{}, tools())), Ex.Reason.ChecksFailed{})},
   Check{"the mannequin without a credits page is refused",
     refused_for(Ex.release(True{}, facts(with_mannequin(), [Ex.Work.Mannequin{}], False{}, False{}, tools())), Ex.Reason.Uncredited{Ex.Work.Mannequin{}})},
   Check{"CC0 clips without a credits page ship",
     ships(Ex.release(True{}, facts([page(), code()], [Ex.Work.Quaternius{}], False{}, False{}, tools())))},
   Check{"all 42 clips as code are over the code budget",
     refused_for(Ex.release(True{}, facts([page(), big()], [], False{}, False{}, tools())), Ex.Reason.OverCode{1927615, 300000})},
   Check{"no page is refused",
     refused_for(Ex.release(True{}, facts([code()], [], False{}, False{}, tools())), Ex.Reason.NoPage{})},
   Check{"two pages are refused",
     refused_for(Ex.release(True{}, facts([page(), page(), code()], [], False{}, False{}, tools())), Ex.Reason.TwoPages{})},
   Check{"assets over 2 MB are refused",
     refused_for(Ex.release(True{}, facts([page(), code(), body(), face(), body(), face()], [], False{}, False{}, tools())), Ex.Reason.OverAssets{2335102, 2000000})},
   Check{"another Bend is refused",
     refused_for(Ex.release(True{}, facts([page(), code()], [], False{}, False{}, Ex.Toolchain{"2.0.41", True{}, False{}, False{}})), Ex.Reason.WrongBend{"2.0.41"})},
   Check{"Bend without the module tree shaking is refused",
     refused_for(Ex.release(True{}, facts([page(), code()], [], False{}, False{}, Ex.Toolchain{"2.0.40", False{}, False{}, False{}})), Ex.Reason.NoTreeshake{})},
   Check{"an HLSL game without dxc is refused, and says which tool",
     refused_for(Ex.release(True{}, facts([page(), code()], [], False{}, True{}, Ex.Toolchain{"2.0.40", True{}, False{}, True{}})), Ex.Reason.ToolMissing{"dxc"})},
   Check{"a GLSL-only game builds without dxc or spirv-cross",
     ships(Ex.release(True{}, facts([page(), code()], [], False{}, False{}, tools())))}]

def checks() -> List<&2, Check>:
  List.append(&2, Check, files_checks(), contract_checks())
