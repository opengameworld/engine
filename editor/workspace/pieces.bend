# The workspace's small pieces, used by more than one window: a section of the Inspector, a fact,
# a help line, and the small choices every window makes.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene/scene.bend as S
import ../defaults/defaults.bend as D
import ./number.bend as Num
import ./state.bend as W

# ---------- Small pieces ----------

def hidden(hide: Bool) -> List<&2, Web.Attr<W.Ev>>:
  match hide:
    case True{}:
      [Web.attr{"hidden", ""}]
    case False{}:
      Nil{}

def chevron(reduced: Bool) -> List<&2, Web.Attr<W.Ev>>:
  match reduced:
    case True{}:
      [Web.style{"transition", "none"}]
    case False{}:
      Nil{}

def pick_text(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_u(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_st(c: Bool, +a: W.St, +b: W.St) -> W.St:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_list(c: Bool, +a: List<&2, String>, +b: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_attrs(c: Bool, +a: List<&2, Web.Attr<W.Ev>>, +b: List<&2, Web.Attr<W.Ev>>) -> List<&2, Web.Attr<W.Ev>>:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_ev(c: Bool, +a: W.Ev, +b: W.Ev) -> W.Ev:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_one(c: Bool, +a: Web.HTML<W.Ev>, +b: Web.HTML<W.Ev>) -> Web.HTML<W.Ev>:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_html(c: Bool, +a: List<&2, Web.HTML<W.Ev>>, +b: List<&2, Web.HTML<W.Ev>>) -> List<&2, Web.HTML<W.Ev>>:
  match c:
    case True{}:
      a
    case False{}:
      b

def seconds_text(+x: F32) -> String:
  Num.fixed(x, 1) ++ " s"

def plays_text(loop: Bool) -> String:
  match loop:
    case True{}:
      "loop"
    case False{}:
      "once"

# A row of the Details: a name and its value.
def fact(+k: String, +v: String) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "editor-anim__fact", [], [Ui.says(W.Ev, "span", "item-title", k), Ui.says(W.Ev, "span", "mono detail", v)])

def help(+text: String) -> Web.HTML<W.Ev>:
  Ui.says(W.Ev, "p", "editor-anim__help", text)

def section(+title: String, +still: Bool, +kids: List<&2, Web.HTML<W.Ev>>) -> Web.HTML<W.Ev>:
  Ui.disclosure_with(W.Ev, "", [Web.attr{"open", ""}], chevron(D.reduce_motion(still)), [Ui.disclosure_title(W.Ev, title)], [Ui.box(W.Ev, "div", "editor-anim__stack", [], kids)])

def disabled(off: Bool) -> List<&2, Web.Attr<W.Ev>>:
  match off:
    case True{}:
      [Web.attr{"disabled", ""}]
    case False{}:
      Nil{}

def labeled(+label: String, +id: String, +control: Web.HTML<W.Ev>, +note: String) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "field", [], [Web.node{"span", [Web.attr{"class", "field__label"}, Web.attr{"id", id}], [Web.text{label}]}, control, help(note)])
