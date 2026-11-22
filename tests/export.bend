# Numerical tests of export/contract.bend: what makes a build ship or be refused, and what its
# manifest says.
#
# Limits now:
# - Chosen builds (the Character game's real sizes, the mannequin's assets, one over each
#   budget), not every build.

import Base
import ../export/contract.bend as Ex

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
  Ex.Facts{"character", "Character", es, ws, credits, hlsl, t}

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

def checks() -> List<&2, Check>:
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
