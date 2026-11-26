# The script editor's state: the script open, its text as typed and as saved, and what Bend's
# checker said about the text last checked. editor/code/view.bend draws it and says what its
# events do; editor/workspace/state.bend holds it.
#
# The text is checked as it is typed, one check at a time, the last text winning: a keystroke
# asks for a check when none is running; when the answer comes, a text typed since is checked
# again. So no check waits on a timer (Godot waits for an idle timer), and the problem shown is
# always for the text in the box, or for one a check is already on its way to replace.
#
# It also holds the project's problems (engine/script/problem.bend): the scripts that did not
# compile when the page opened. They stop Play (editor/workspace/state.bend's played).
#
# Limits now:
# - One script is open at a time.

import Base
import ../../engine/script/problem.bend as Pb
import ../../engine/script/attach.bend as At

# What the page knows of the project's scripts when it opened: the ones that do not compile, and
# the ones a thing may carry (Add Component > Script), with their fields and where they run.
type Proj is Data:
  Proj{broken: List<&2, Pb.Problem>, offers: List<&2, At.Offer>}

type Code is Data:
  Code{open: Bool, path: String, text: String, saved: String, loaded: Bool, asking: Bool, checked: String, found: Bool, problem: Pb.Problem, closing: Bool, project: Proj}

def no_problem() -> Pb.Problem:
  Pb.Problem{"", Pb.Fault.Type{}, 0, 0, 0, "", ""}

def project(+c: Code) -> Proj:
  Code{_, _, _, _, _, _, _, _, _, _, p} = c
  p

# No script open; the project's problems and its scripts as the page opened.
def start(+broken: List<&2, Pb.Problem>, +offers: List<&2, At.Offer>) -> Code:
  Code{False{}, "", "", "", False{}, False{}, "", False{}, no_problem(), False{}, Proj{broken, offers}}

def is_open(+c: Code) -> Bool:
  Code{o, _, _, _, _, _, _, _, _, _, _} = c
  o

# The script's path in its project ("scripts/Mover.bend").
def path(+c: Code) -> String:
  Code{_, p, _, _, _, _, _, _, _, _, _} = c
  p

def text(+c: Code) -> String:
  Code{_, _, t, _, _, _, _, _, _, _, _} = c
  t

def saved(+c: Code) -> String:
  Code{_, _, _, s, _, _, _, _, _, _, _} = c
  s

# Has its text come from the dev server?
def loaded(+c: Code) -> Bool:
  Code{_, _, _, _, l, _, _, _, _, _, _} = c
  l

# Is a check on its way?
def asking(+c: Code) -> Bool:
  Code{_, _, _, _, _, a, _, _, _, _, _} = c
  a

# The text the last answer was for.
def checked(+c: Code) -> String:
  Code{_, _, _, _, _, _, k, _, _, _, _} = c
  k

# Did the last check find a problem? Then problem is it.
def found(+c: Code) -> Bool:
  Code{_, _, _, _, _, _, _, f, _, _, _} = c
  f

def problem(+c: Code) -> Pb.Problem:
  Code{_, _, _, _, _, _, _, _, p, _, _} = c
  p

# Was Close pressed with changes not saved (Save or Discard waits)?
def closing(+c: Code) -> Bool:
  Code{_, _, _, _, _, _, _, _, _, x, _} = c
  x

def Cd.broken_of(+p: Proj) -> List<&2, Pb.Problem>:
  Proj{b, _} = p
  b

def Cd.offers_of(+p: Proj) -> List<&2, At.Offer>:
  Proj{_, o} = p
  o

def broken(+c: Code) -> List<&2, Pb.Problem>:
  Cd.broken_of(project(c))

# The scripts a thing of the project may carry.
def offers(+c: Code) -> List<&2, At.Offer>:
  Cd.offers_of(project(c))

# The script's name: its file's, without scripts/ and .bend.
def name(+c: Code) -> String:
  String.reverse(String.drop(String.reverse(String.drop(path(c), 8n)), 5n))

# Is there something Save writes?
def dirty(+c: Code) -> Bool:
  (loaded(c) && Bool.not(String.eq(text(c), saved(c))))

# Is the last answer about the text in the box?
def fresh(+c: Code) -> Bool:
  (String.eq(text(c), checked(c)) && Bool.not(asking(c)))

# Does the text in the box have a problem Bend found (and a check is not already replacing it)?
def failing(+c: Code) -> Bool:
  (loaded(c) && found(c))

# ---------- What happens to it ----------

# A script opened: its text is asked for.
def opening(+c: Code, +p: String) -> Code:
  Code{True{}, p, "", "", False{}, False{}, "", False{}, no_problem(), False{}, project(c)}

# Its text came: it is the text saved too, and it is checked.
def arrived(+c: Code, +t: String) -> Code:
  Code{True{}, path(c), t, t, True{}, True{}, "", False{}, no_problem(), False{}, project(c)}

# A keystroke: the text is what the box holds now; a check is asked, or is already on its way.
def typed(+c: Code, +t: String) -> Code:
  Code{True{}, path(c), t, saved(c), True{}, True{}, checked(c), found(c), problem(c), False{}, project(c)}

# A check answered for text t: what it found. When the text changed since, it is checked again.
def answered(+c: Code, +t: String, +f: Bool, +p: Pb.Problem) -> Code:
  Code{is_open(c), path(c), text(c), saved(c), loaded(c), Bool.not(String.eq(text(c), t)), t, f, p, closing(c), project(c)}

# Close pressed with changes not saved: Save or Discard waits.
def asks_close(+c: Code) -> Code:
  Code{is_open(c), path(c), text(c), saved(c), loaded(c), asking(c), checked(c), found(c), problem(c), True{}, project(c)}

# Closed: no script open.
def shut(+c: Code) -> Code:
  Code{False{}, "", "", "", False{}, False{}, "", False{}, no_problem(), False{}, project(c)}
