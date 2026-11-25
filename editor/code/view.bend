# The script editor: a project's script, open in the middle of the editor (over the viewport),
# as Godot opens a script in its Script screen and Visual Studio in a document tab.
#
#   head      the script's name, what the checker says (Checking, No problems, 1 problem), "Not
#             saved", Save and Close
#   the code  line numbers, and the text in Bend's colors (Bend-UI's SYNTAX.bend), the place of a
#             problem underlined and its line marked, character for character (editor/code/text.bend)
#   foot      the problem in words: where (line and column) and what Bend said, or "No problems"
#
# The text is checked as it is typed (editor/code/code.bend says how): editor/app.js sends it to
# the dev server, which checks it with Bend's own checker (tools/script/check.ts), as the script
# will be used in Play. A script is opened from the Inspector (Edit script) or by a double click
# in the Project window. Save writes it (the dev server's /write); the engine restarts and checks
# it again, and a script that does not compile stops Play and the build until it does
# (engine/script/problem.bend), as in Unity.
#
# Saving restarts the engine, so a scene with changes not saved is saved first (as Create asks).
#
# Accessibility: the text field is a real text field (the browser's caret, selection, undo, and
# screen readers read it); the drawing under it is hidden from them. The problem is said in words
# under the code (aria-describedby), and the field says it is invalid. Nothing here moves.
#
# Limits now:
# - Tab leaves the field, as in any text field (a code editor would indent): Web.bend does not
#   say where the caret is, so Bend cannot put spaces there (docs/bend-ui-requests.txt). Indent
#   with spaces.
# - Long lines do not wrap; the code scrolls sideways.
# - No completion, no go to definition, no find.
# - One problem at a time: Bend's checker stops at the first.
# - Save is a button: Ctrl+S would also be the S the character walks back with in Play
#   (editor/viewport/keys.bend's laws compare keys without their modifiers).
# - Bend-UI has no code field: this one is made of Bend-UI's code colors and a text field
#   (docs/bend-ui-requests.txt).

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/script/problem.bend as Pb
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P
import ../project/files.bend as F
import ../icons/view.bend as Ic
import ./code.bend as Cd
import ./text.bend as Tx

# ---------- What happens ----------

# A script opened ("scripts/Mover.bend"): its text is asked of the dev server. A script with
# changes not saved stays open.
def opened(+st: W.St, +path: String) -> W.St:
  P.pick_st(Cd.dirty(W.code(st)), st, W.asked(W.with_code(st, Cd.opening(W.code(st), path)), "read", path))

def Ce.arrived_if(here: Bool, +st: W.St, +text: String) -> W.St:
  match here:
    case True{}:
      W.asked(W.with_code(st, Cd.arrived(W.code(st), text)), "check", Cd.path(W.code(st)))
    case False{}:
      st

# A file's text came: when it is the script being opened, it fills the editor and is checked.
def text_in(+st: W.St, +path: String, +text: String) -> W.St:
  +c = W.code(st)
  Ce.arrived_if((Cd.is_open(c) && String.eq(Cd.path(c), path) && Bool.not(Cd.loaded(c))), st, text)

# A keystroke: the text is checked, unless a check is already on its way (its answer asks again).
def typed(+st: W.St, +text: String) -> W.St:
  +c = W.code(st)
  P.pick_st(Cd.asking(c), W.with_code(st, Cd.typed(c, text)), W.asked(W.with_code(st, Cd.typed(c, text)), "check", Cd.path(c)))

def Ce.answer_if(here: Bool, +st: W.St, +c: Cd.Code) -> W.St:
  match here:
    case True{}:
      P.pick_st(Cd.asking(c), W.asked(W.with_code(st, c), "check", Cd.path(c)), W.with_code(st, c))
    case False{}:
      st

# The checker answered for text t: when the text changed since, it is checked again.
def checked(+st: W.St, +t: String, +f: Bool, +p: Pb.Problem) -> W.St:
  +c = W.code(st)
  Ce.answer_if((Cd.is_open(c) && Cd.loaded(c)), st, Cd.answered(c, t, f, p))

# May Save write the script? Something changed, and the scene has nothing waiting (saving
# restarts the engine, which would drop it).
def may_save(+st: W.St) -> Bool:
  (Cd.dirty(W.code(st)) && Bool.not(W.dirty(st)))

def save(+st: W.St) -> W.St:
  P.pick_st(may_save(st), W.asked(st, "write", Cd.path(W.code(st))), st)

# Close: with changes not saved, Save or Discard waits (force drops them).
def close(+st: W.St, +force: Bool) -> W.St:
  +c = W.code(st)
  P.pick_st((Cd.dirty(c) && Bool.not(force)), W.with_code(st, Cd.asks_close(c)), W.with_code(st, Cd.shut(c)))

# ---------- What it shows ----------

def Ce.bits(bs: List<&2, Tx.Bit>) -> List<&2, Web.HTML<W.Ev>>:
  match bs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Web.node{"span", [Web.attr{"class", Tx.class_of(Tx.kind(h)) ++ P.pick_text(Tx.marked(h), " editor-code__mark", "")}], [Web.text{Tx.text(h)}]} <> Ce.bits(t)

# A line: its pieces, or one space so an empty line keeps its height.
def Ce.line(+bs: List<&2, Tx.Bit>, +here: Bool) -> Web.HTML<W.Ev>:
  Web.node{"span", [Web.attr{"class", P.pick_text(here, "editor-code__line editor-code__line--problem", "editor-code__line")}],
    P.pick_html(List.is_empty(&2, Tx.Bit, bs), [Web.text{" "}], Ce.bits(bs))}

def Ce.lines(rs: List<&2, List<&2, Tx.Bit>>, +n: U32, +at: U32) -> List<&2, Web.HTML<W.Ev>>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Ce.line(h, U32.is_eq(n, at)) <> Ce.lines(t, (n + 1 : U32), at)

def Ce.numbers(left: Nat, +n: U32, +at: U32) -> List<&2, Web.HTML<W.Ev>>:
  match left:
    case 0n:
      Nil{}
    case 1n+k:
      Web.node{"span", [Web.attr{"class", P.pick_text(U32.is_eq(n, at), "editor-code__num editor-code__num--problem", "editor-code__num")}], [Web.text{U32.show(n)}]} <> Ce.numbers(k, (n + 1 : U32), at)

def Ce.save_look(dirty: Bool) -> Ui.Btn:
  match dirty:
    case True{}:
      Ui.btn_filled{}
    case False{}:
      Ui.btn_plain{}

# The line the problem is on, 0 for none drawn in this text.
def problem_line(+c: Cd.Code) -> U32:
  P.pick_u((Cd.failing(c) && Tx.placed(Cd.problem(c))), Pb.line(Cd.problem(c)), 0)

def sheet(+c: Cd.Code) -> Web.HTML<W.Ev>:
  +at = problem_line(c)
  Web.node{"div", [Web.attr{"class", "editor-code__scroll"}], [
    Web.node{"div", [Web.attr{"class", "editor-code__sheet"}], [
      Web.node{"pre", [Web.attr{"class", "editor-code__gutter editor-code__text"}, Web.attr{"aria-hidden", "true"}], Ce.numbers(Tx.count(Cd.text(c)), 1, at)},
      Web.node{"div", [Web.attr{"class", "editor-code__stack"}], [
        Web.node{"pre", [Web.attr{"class", "editor-code__mirror editor-code__text"}, Web.attr{"aria-hidden", "true"}], Ce.lines(Tx.rows(Cd.text(c), Cd.failing(c), Cd.problem(c)), 1, at)},
        Web.node{"textarea", [Web.attr{"class", "editor-code__input editor-code__text"}, Web.attr{"id", "editor-code-input"},
          Web.attr{"value", Cd.text(c)}, Web.attr{"spellcheck", "false"}, Web.attr{"autocomplete", "off"}, Web.attr{"autocapitalize", "off"},
          Web.attr{"autocorrect", "off"}, Web.attr{"wrap", "off"}, Web.attr{"aria-label", "The code of " ++ Cd.name(c) ++ ".bend"},
          Web.attr{"aria-invalid", Ui.bool_text(Cd.failing(c))}, Web.attr{"aria-describedby", "editor-code-problem"},
          Web.on{Web.input{W.k_typed{""}}}], []}]}]}]}

# What the checker says, in the head: a tag in a tone and a word, not color alone.
def status(+c: Cd.Code) -> Web.HTML<W.Ev>:
  P.pick_one(Bool.not(Cd.loaded(c)), Ui.says(W.Ev, "span", "tag", "Opening"),
  P.pick_one(Cd.asking(c), Ui.says(W.Ev, "span", "tag", "Checking"),
  P.pick_one(Cd.found(c), Ui.says(W.Ev, "span", "tag tag--danger", "1 problem"), Ui.says(W.Ev, "span", "tag tag--success", "No problems"))))

# Where the problem is, in words.
def located(+p: Pb.Problem) -> String:
  P.pick_text(String.is_empty(Pb.inside(p)), "", "In " ++ Pb.inside(p) ++ P.pick_text(String.is_empty(Pb.place(p)), "", ", ")) ++
  P.pick_text(String.is_empty(Pb.place(p)), "", P.pick_text(String.is_empty(Pb.inside(p)), "L", "l") ++ String.drop(Pb.place(p), 1n))

def foot_kids(+c: Cd.Code) -> List<&2, Web.HTML<W.Ev>>:
  P.pick_html(Cd.found(c), [
    Ui.icon_with(W.Ev, [Ui.icon_sm{}], "editor-code__icon editor-code__icon--problem", [], "circle-x"),
    Web.node{"div", [Web.attr{"class", "editor-code__said"}], [
      Ui.says(W.Ev, "strong", "editor-code__where", Pb.kind_name(Pb.kind(Cd.problem(c))) ++ P.pick_text(String.is_empty(located(Cd.problem(c))), "", " · " ++ located(Cd.problem(c)))),
      Ui.says(W.Ev, "span", "editor-code__words", Pb.text(Cd.problem(c)))]}],
  P.pick_html(Cd.loaded(c), [
    Ui.icon_with(W.Ev, [Ui.icon_sm{}], "editor-code__icon", [], "circle-check"),
    Ui.says(W.Ev, "span", "editor-code__words", P.pick_text(Cd.asking(c), "Checking with Bend.", "No problems: Bend checks this script as Play runs it."))],
    [P.help("The script's text shows under `bun run dev`.")]))

def foot(+c: Cd.Code) -> Web.HTML<W.Ev>:
  Web.node{"div", [Web.attr{"class", "editor-code__foot"}, Web.attr{"id", "editor-code-problem"}, Web.attr{"role", "status"}], foot_kids(c)}

# Under the head: why Save waits, or the choice Close asks for.
def notes(+st: W.St, +c: Cd.Code) -> List<&2, Web.HTML<W.Ev>>:
  P.pick_html(Cd.closing(c), [
    Ui.box(W.Ev, "div", "editor-code__note", [], [
      P.help(Cd.name(c) ++ ".bend has changes that are not saved."),
      Ui.button_with(W.Ev, [Ui.btn_filled{}, Ui.btn_sm{}], "", Web.on{Web.click{W.k_save{}}} <> P.disabled(Bool.not(may_save(st))), [Web.text{"Save"}]),
      Ui.button(W.Ev, [Ui.btn_bordered{}, Ui.btn_danger{}, Ui.btn_sm{}], "Discard and close", W.k_close{True{}})])],
  P.pick_html((Cd.dirty(c) && W.dirty(st)), [
    Ui.box(W.Ev, "div", "editor-code__note", [], [P.help("Save the scene first: saving a script restarts the engine.")])], Nil{}))

def head(+st: W.St, +c: Cd.Code) -> Web.HTML<W.Ev>:
  Ui.panel_header(W.Ev, List.append(&2, Web.HTML<W.Ev>, [
    Ic.mini(F.Sort.Script{}),
    Web.node{"span", [Web.attr{"id", "editor-code-title"}, Web.attr{"class", "item-title"}], [Web.text{Cd.name(c) ++ ".bend"}]},
    status(c)],
    List.append(&2, Web.HTML<W.Ev>, P.pick_html(Cd.dirty(c), [Ui.says(W.Ev, "span", "meta", "Not saved")], Nil{}), [
    Ui.box(W.Ev, "div", "editor-code__end", [], [
      Ui.button_with(W.Ev, [Ce.save_look(Cd.dirty(c)), Ui.btn_sm{}], "", Web.on{Web.click{W.k_save{}}} <> P.disabled(Bool.not(may_save(st))), [Web.text{"Save"}]),
      Ui.icon_button(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "Close", "x", W.k_close{False{}})])])))

def body(loaded: Bool, +c: Cd.Code) -> List<&2, Web.HTML<W.Ev>>:
  match loaded:
    case True{}:
      [sheet(c), foot(c)]
    case False{}:
      [foot(c)]

def Ce.panel_if(open: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match open:
    case True{}:
      +c = W.code(st)
      [Ui.panel_as(W.Ev, "section", "editor-window editor-code", [Web.attr{"aria-labelledby", "editor-code-title"}],
        List.append(&2, Web.HTML<W.Ev>, [head(st, c)], List.append(&2, Web.HTML<W.Ev>, notes(st, c), body(Cd.loaded(c), c))))]
    case False{}:
      Nil{}

# The editor, over the viewport, while a script is open.
def panel(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  Ce.panel_if(Cd.is_open(W.code(st)), st)

# Its styles, with Bend-UI's tokens. The text field and the drawing under it share one font, size,
# line height and padding (editor-code__text), so each letter typed is over its colored one; the
# field's own letters are clear, and its caret and selection show.
def styles() -> String:
  ".editor-code { grid-column: 2; grid-row: 2; position: relative; z-index: var(--layer-foot); min-width: 0; min-height: 0; }" ++
  ".editor-code__end { margin-left: auto; display: flex; align-items: center; gap: var(--space-1); }" ++
  ".editor-code__note { display: flex; align-items: center; flex-wrap: wrap; gap: var(--space-2); padding: var(--space-1) var(--space-3); border-bottom: var(--border-width) solid var(--border); }" ++
  ".editor-code__scroll { flex: 1; min-height: 0; overflow: auto; background: var(--surface-2); }" ++
  ".editor-code__sheet { display: grid; grid-template-columns: auto minmax(0, 1fr); min-width: 100%; width: max-content; min-height: 100%; }" ++
  ".editor-code__text { margin: 0; padding: var(--space-2) var(--space-3); font-family: var(--font-mono); font-size: var(--text-sm); line-height: var(--leading-body); tab-size: 2; white-space: pre; letter-spacing: normal; border: 0; }" ++
  ".editor-code__gutter { position: sticky; left: 0; z-index: 1; text-align: right; color: var(--text-2); background: var(--surface-2); border-right: var(--border-width) solid var(--border); user-select: none; }" ++
  ".editor-code__num, .editor-code__line { display: block; }" ++
  ".editor-code__num--problem { color: var(--danger-text); font-weight: var(--weight-medium); }" ++
  ".editor-code__stack { position: relative; min-width: 0; }" ++
  ".editor-code__mirror { pointer-events: none; color: var(--text); }" ++
  ".editor-code__line--problem { background: var(--danger-soft); }" ++
  ".editor-code__mark { text-decoration: underline wavy var(--danger); text-decoration-skip-ink: none; text-underline-offset: 0.2em; }" ++
  ".editor-code__input { position: absolute; inset: 0; width: 100%; height: 100%; resize: none; overflow: hidden; background: transparent; color: transparent; -webkit-text-fill-color: transparent; caret-color: var(--text); outline: none; }" ++
  ".editor-code__input:focus-visible { box-shadow: inset 0 0 0 var(--focus-width) var(--accent); }" ++
  ".editor-code__input::selection { background: var(--accent-soft); }" ++
  ".editor-code__foot { display: flex; align-items: flex-start; gap: var(--space-2); padding: var(--space-2) var(--space-3); border-top: var(--border-width) solid var(--border); font-size: var(--text-sm); max-height: calc(var(--side-width) / 2); overflow: auto; }" ++
  ".editor-code__icon { flex: none; margin-top: var(--space-hairline); color: var(--success-text); }" ++
  ".editor-code__icon--problem { color: var(--danger-text); }" ++
  ".editor-code__said { display: flex; flex-direction: column; gap: var(--space-1); min-width: 0; }" ++
  ".editor-code__where { color: var(--danger-text); }" ++
  ".editor-code__words { white-space: pre-wrap; overflow-wrap: anywhere; font-family: var(--font-mono); font-size: var(--text-xs); }"
