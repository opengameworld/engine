# The script editor's text, as the box under the typing draws it: line by line, each line cut in
# pieces Bend-UI colors (SYNTAX.bend, its Bend language), and the piece where Bend's checker found
# the problem marked, character for character.
#
# The box is two layers in one place, as react-simple-code-editor and CodeJar draw code: the
# person types in a text field whose letters are clear (the browser keeps the caret, the
# selection, undo and every way of typing), and under it this text is drawn with the colors and
# the mark. Both use the same font, size, line height and padding, so each letter is over its own.
#
# A line is colored on its own: in Bend a string or a comment ends with its line, so coloring
# line by line gives the same pieces as coloring the whole text.
#
# Limits now:
# - A mark covers one line: a problem whose span goes on is marked to the end of its first line,
#   as Bend's own underline does.
# - A problem at the end of a line (where something was expected) marks one space after it.

import Base
import ../../node_modules/bend-ui/SYNTAX.bend as Syn
import ../../engine/script/problem.bend as Pb

# A piece of a line: its kind (SYNTAX.bend's: 0 plain, 1 keyword ...), its text, and whether it is
# where the problem is.
type Bit is Data:
  Bit{kind: U32, text: String, marked: Bool}

def kind(+b: Bit) -> U32:
  Bit{k, _, _} = b
  k

def text(+b: Bit) -> String:
  Bit{_, t, _} = b
  t

def marked(+b: Bit) -> Bool:
  Bit{_, _, m} = b
  m

# The class Bend-UI's styles color a piece of this kind with (ui.css's .syntax__*, in the order
# bend-ui/syntax.js names them; SYNTAX.bend's kinds).
def class_of(+k: U32) -> String:
  match k:
    case 1:
      "syntax__kw"
    case 2:
      "syntax__type"
    case 3:
      "syntax__str"
    case 4:
      "syntax__num"
    case 5:
      "syntax__com"
    case 6:
      "syntax__punct"
    case 7:
      "syntax__name"
    case _:
      ""

# The text's lines (a text that ends in a line break has an empty last line, as the box shows).
def lines(+t: String) -> List<&2, String>:
  String.split(t, '\n')

def count(+t: String) -> Nat:
  List.length(&2, String, lines(t))

def Tx.bits_if(empty: Bool, +k: U32, +t: String, +m: Bool) -> List<&2, Bit>:
  match empty:
    case True{}:
      []
    case False{}:
      [Bit{k, t, m}]

def Tx.bits_of(+k: U32, +t: String, +m: Bool) -> List<&2, Bit>:
  Tx.bits_if(String.is_empty(t), k, t, m)

# The pieces of a line, the ones between `from` and `to` (counted from the line's start, 0 for its
# first character) marked; `at` is where the first piece begins.
def Tx.cut(ps: List<&2, Syn.Piece>, +from: Nat, +to: Nat, +at: Nat) -> List<&2, Bit>:
  match ps:
    case Nil{}:
      []
    case Con{+h, t}:
      Syn.Piece{k, s} = h
      +n = String.length(s)
      +a = Nat.min(n, Nat.sub(from, at))
      +b = Nat.min(n, Nat.sub(to, at))
      List.append(&2, Bit, Tx.bits_of(k, String.take(s, a), False{}),
      List.append(&2, Bit, Tx.bits_of(k, String.take(String.drop(s, a), Nat.sub(b, a)), True{}),
      List.append(&2, Bit, Tx.bits_of(k, String.drop(s, b), False{}), Tx.cut(t, from, to, Nat.add(at, n)))))

# A line with nothing marked.
def plain(+line: String) -> List<&2, Bit>:
  Tx.cut(Syn.pieces_in(Syn.bend(), line), 0n, 0n, 0n)

# The end of a line, when the problem begins there: one space, marked, so it shows.
def Tx.end_mark(past: Bool) -> List<&2, Bit>:
  match past:
    case True{}:
      [Bit{Syn.plain(), " ", True{}}]
    case False{}:
      []

# A line with `len` characters marked from column `col` (counted from 1, as Bend counts).
def marked_line(+line: String, +col: U32, +len: U32) -> List<&2, Bit>:
  +from = Nat.sub(U32.to_nat(col), 1n)
  List.append(&2, Bit, Tx.cut(Syn.pieces_in(Syn.bend(), line), from, Nat.add(from, Nat.max(1n, U32.to_nat(len))), 0n),
    Tx.end_mark(Nat.is_ge(from, String.length(line))))

# Is the problem in this text, at a place (not in a module it imports, and not without a place)?
def placed(+p: Pb.Problem) -> Bool:
  (String.is_empty(Pb.inside(p)) && Bool.not(U32.is_eq(Pb.line(p), 0)))

def Tx.row_if(here: Bool, +line: String, +p: Pb.Problem) -> List<&2, Bit>:
  match here:
    case True{}:
      marked_line(line, Pb.col(p), Pb.len(p))
    case False{}:
      plain(line)

def Tx.row(+line: String, +n: U32, +on: Bool, +p: Pb.Problem) -> List<&2, Bit>:
  Tx.row_if((on && U32.is_eq(n, Pb.line(p))), line, p)

def Tx.rows(ls: List<&2, String>, +n: U32, +on: Bool, +p: Pb.Problem) -> List<&2, List<&2, Bit>>:
  match ls:
    case Nil{}:
      []
    case Con{+h, t}:
      Tx.row(h, n, on, p) <> Tx.rows(t, (n + 1 : U32), on, p)

# Every line's pieces; when `on`, the problem's place marked (on its line, counted from 1).
def rows(+t: String, +on: Bool, +p: Pb.Problem) -> List<&2, List<&2, Bit>>:
  Tx.rows(lines(t), 1, (on && placed(p)), p)

# A line's text again, from its pieces (the end mark's space left out): what is drawn is the text.
def Tx.joined(bs: List<&2, Bit>) -> String:
  match bs:
    case Nil{}:
      ""
    case Con{+h, t}:
      text(h) ++ Tx.joined(t)

def joined(+bs: List<&2, Bit>) -> String:
  Tx.joined(bs)

# The marked text of a line's pieces.
def Tx.mark_text(m: Bool, +t: String) -> String:
  match m:
    case True{}:
      t
    case False{}:
      ""

def Tx.marks(bs: List<&2, Bit>) -> String:
  match bs:
    case Nil{}:
      ""
    case Con{+h, t}:
      Tx.mark_text(marked(h), text(h)) ++ Tx.marks(t)

def marks(+bs: List<&2, Bit>) -> String:
  Tx.marks(bs)
