# A script that does not compile, as the engine knows it: which script, what kind of error, where
# it is in the script, and what is wrong. Bend's checker finds it (tools/script/check.ts); each
# project's registry lists its scripts' problems (tools/project/registry.js: problems()), and
# leaves those scripts out, so the rest of the project still compiles and the editor opens, as
# Unity keeps running the last scripts that compiled.
#
# While a project has a problem:
# - Play does not start (engine/play/play.bend's to_mode_checked), as Unity refuses Play mode
#   until every compiler error is fixed;
# - the build stops (tools/project/registry.js fails, so `bun run build` and `bun run export` do);
# - the editor's Console says each one (editor/workspace/state.bend), as said() writes it:
#     Mover.bend — Type error on line 12, column 3: expected S.Scene, found F32
#
# The kind is where Bend stopped (tools/script/check.ts decides it from the step that failed):
#   Syntax       the text cannot be read as Bend (a word missing, one too many, a bad indent)
#   Import       an import line, or the file it names
#   Type         the code reads, but a value is not what is asked of it (or a name is not defined)
#   Shape        start or update is missing, or is not what the engine calls in Play
#   Unfinished   a ? hole is left in the code
#
# A place is a line and a column, counted from 1 as Bend's own errors count them; 0 means Bend
# gave no place. len is how many characters the error covers on that line (at least 1).
#
# Limits now:
# - Bend stops at its first error, so a script has one problem at a time.
# - A problem says where it is in the script's text; an error inside a module the script imports
#   names that module (inside) and its place there.

import Base

type Fault is Data:
  Fault.Syntax{}
  Fault.Import{}
  Fault.Type{}
  Fault.Shape{}
  Fault.Unfinished{}

type Problem is Data:
  Problem{script: String, kind: Fault, line: U32, col: U32, len: U32, text: String, inside: String}

def script(+p: Problem) -> String:
  Problem{s, _, _, _, _, _, _} = p
  s

def kind(+p: Problem) -> Fault:
  Problem{_, k, _, _, _, _, _} = p
  k

def line(+p: Problem) -> U32:
  Problem{_, _, l, _, _, _, _} = p
  l

def col(+p: Problem) -> U32:
  Problem{_, _, _, c, _, _, _} = p
  c

def len(+p: Problem) -> U32:
  Problem{_, _, _, _, n, _, _} = p
  n

def text(+p: Problem) -> String:
  Problem{_, _, _, _, _, t, _} = p
  t

def inside(+p: Problem) -> String:
  Problem{_, _, _, _, _, _, i} = p
  i

def Pb.pick(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def Pb.pick_kind(c: Bool, +a: Fault, +b: Fault) -> Fault:
  match c:
    case True{}:
      a
    case False{}:
      b

# The kind tools/script/check.ts names ("syntax", "import", "type", "shape", "unfinished"); a name
# it does not use is a type error, the kind Bend's checker gives most.
def kind_of(+name: String) -> Fault:
  Pb.pick_kind(String.eq(name, "syntax"), Fault.Syntax{},
  Pb.pick_kind(String.eq(name, "import"), Fault.Import{},
  Pb.pick_kind(String.eq(name, "shape"), Fault.Shape{},
  Pb.pick_kind(String.eq(name, "unfinished"), Fault.Unfinished{}, Fault.Type{}))))

# The kind in words, as the Console and the script editor say it.
def kind_name(+k: Fault) -> String:
  match k:
    case Fault.Syntax{}:
      "Syntax error"
    case Fault.Import{}:
      "Import error"
    case Fault.Type{}:
      "Type error"
    case Fault.Shape{}:
      "Wrong start or update"
    case Fault.Unfinished{}:
      "Unfinished code"

# Does any script fail to compile? Then Play and the build wait.
def any(ps: List<&2, Problem>) -> Bool:
  Bool.not(List.is_empty(&2, Problem, ps))

# Where it is, in words: "line 8, column 3", or "" when Bend gave no place.
def place(+p: Problem) -> String:
  Pb.pick(U32.is_eq(line(p), 0), "", "line " ++ U32.show(line(p)) ++ ", column " ++ U32.show(col(p)))

# What the Console says: the script's file, the kind of error, its line (and the module it is in),
# and what is wrong.
def said(+p: Problem) -> String:
  script(p) ++ ".bend — " ++ kind_name(kind(p)) ++
  Pb.pick(String.is_empty(inside(p)), "", " in " ++ inside(p)) ++
  Pb.pick(String.is_empty(place(p)), "", " on " ++ place(p)) ++ ": " ++ text(p)
