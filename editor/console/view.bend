# The Console: what the editor has to say, one line each, as Unity's Console window lists the
# editor's errors, warnings and messages. A line says its tone with an icon and a word, not with
# color alone.
#
# What writes a line: a script that does not compile (each one, when the project opens, and Play
# refused because of it: engine/script/problem.bend), a shader file that could not be used (its
# catalog's problems, when the project opens), a shader the drawing code could not link, Save
# (where it wrote, or why it could not), and a folder made or refused. A line keeps the line
# breaks of what it says (Bend's messages have several lines).
#
# Limits now:
# - A line has no time and no source link; the same line said twice shows twice (Unity's
#   Collapse is not built).
# - The page's own JavaScript errors stay in the browser's console.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P

def tone_icon(+tone: String) -> String:
  P.pick_text(String.eq(tone, "error"), "circle-x", P.pick_text(String.eq(tone, "warning"), "triangle-alert", "info"))

def tone_word(+tone: String) -> String:
  P.pick_text(String.eq(tone, "error"), "Error", P.pick_text(String.eq(tone, "warning"), "Warning", "Info"))

def line(+l: W.Line) -> Web.HTML<W.Ev>:
  Web.node{"li", [Web.attr{"class", "editor-console__line"}, Web.attr{"data-tone", W.line_tone(l)}], [
    Ui.icon_with(W.Ev, [Ui.icon_sm{}], "editor-console__icon", [], tone_icon(W.line_tone(l))),
    Ui.says(W.Ev, "span", "editor-console__tone", tone_word(W.line_tone(l))),
    Ui.says(W.Ev, "span", "editor-console__text", W.line_text(l))]}

def lines(ls: List<&2, W.Line>) -> List<&2, Web.HTML<W.Ev>>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      line(h) <> lines(t)

def count(+st: W.St) -> U32:
  U32.from_nat(List.length(&2, W.Line, W.log(st)))

# The dock tab's name: Console, with how many lines it holds.
def tab_name(+st: W.St) -> String:
  P.pick_text(U32.is_eq(count(st), 0), "Console", "Console " ++ U32.show(count(st)))

def body(empty: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match empty:
    case True{}:
      [P.help("Nothing to report.")]
    case False{}:
      [Web.node{"ul", [Web.attr{"class", "editor-console__lines"}, Web.attr{"role", "log"}, Web.attr{"aria-label", "Console"}], lines(W.log(st))}]

def tools(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  [Ui.button_with(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}], "", Web.on{Web.click{W.c_clear{}}} <> P.disabled(U32.is_eq(count(st), 0)), [Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "trash-2"), Web.text{"Clear"}])]

def view(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  [Ui.box(W.Ev, "div", "editor-dock__bar", [], tools(st)),
   Ui.box(W.Ev, "div", "editor-dock__scroll editor-console", [], body(U32.is_eq(count(st), 0), st))]
