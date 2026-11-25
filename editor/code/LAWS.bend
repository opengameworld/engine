# The laws of the script editor (editor/code/). `bend editor/code/PROOF.bend` must print
# ALL PROOFS CHECK.

import Base
import ../../engine/script/problem.bend as Pb
import ./text.bend as Tx
import ./code.bend as C

def first(rs: List<&2, List<&2, Tx.Bit>>) -> List<&2, Tx.Bit>:
  match rs:
    case Nil{}:
      []
    case Con{h, _}:
      h

def second(rs: List<&2, List<&2, Tx.Bit>>) -> List<&2, Tx.Bit>:
  match rs:
    case Nil{}:
      []
    case Con{_, t}:
      first(t)

# ---------- What is drawn is the text ----------

# LAW: a line's pieces, put together again, are the line: coloring adds and drops nothing.
law the_pieces_are_the_line:
  {Tx.joined(Tx.plain("def update(+s: S.Scene, +dt: F32) -> S.Scene: # every tick")) == "def update(+s: S.Scene, +dt: F32) -> S.Scene: # every tick" : String}

# LAW: marking a problem adds and drops nothing either.
law marking_keeps_the_line:
  {Tx.joined(Tx.marked_line("  s + 1", 5, 1)) == "  s + 1" : String}

# LAW: the mark is exactly where Bend says: column 5, one character, is the +.
law the_mark_is_the_place:
  {Tx.marks(Tx.marked_line("  s + 1", 5, 1)) == "+" : String}

# LAW: a mark longer than one character covers all of them, across colored pieces.
law a_long_mark_covers_its_characters:
  {Tx.marks(Tx.marked_line("  dt + s", 3, 6)) == "dt + s" : String}

# LAW: a mark never goes past its line.
law a_mark_stops_at_the_end_of_its_line:
  {Tx.marks(Tx.marked_line("  dt", 3, 9)) == "dt" : String}

# LAW: a problem at the end of a line is a marked space there, so it shows.
law a_problem_at_the_end_is_a_marked_space:
  {Tx.marks(Tx.marked_line("  s +", 6, 1)) == " " : String}

# LAW: a text that ends in a line break has an empty last line, as the box shows one.
law a_last_line_break_is_a_line:
  {Tx.count("a\nb\n") == 3n : Nat}

# LAW: only the problem's line is marked.
law only_its_line_is_marked:
  {Tx.marks(first(Tx.rows("s\n  dt\n", True{}, Pb.Problem{"Mover", Pb.Fault.Type{}, 2, 3, 2, "", ""}))) == "" : String}

law its_line_is_marked:
  {Tx.marks(second(Tx.rows("s\n  dt\n", True{}, Pb.Problem{"Mover", Pb.Fault.Type{}, 2, 3, 2, "", ""}))) == "dt" : String}

# LAW: a problem in a module the script imports marks nothing in the script.
law a_problem_elsewhere_marks_nothing_here:
  {Tx.marks(second(Tx.rows("s\n  dt\n", True{}, Pb.Problem{"Mover", Pb.Fault.Type{}, 2, 3, 2, "", "engine/scene/scene.bend"}))) == "" : String}

# ---------- The text and its checks ----------

# LAW: a script's name is its file's.
law a_script_is_named_by_its_file:
  {C.name(C.opening(C.start([]), "scripts/Mover.bend")) == "Mover" : String}

# LAW: a script just opened has nothing to save.
law a_script_just_read_has_nothing_to_save:
  {C.dirty(C.arrived(C.opening(C.start([]), "scripts/Mover.bend"), "def x")) == False{} : Bool}

# LAW: a keystroke is something to save.
law a_keystroke_is_something_to_save:
  {C.dirty(C.typed(C.arrived(C.opening(C.start([]), "scripts/Mover.bend"), "def x"), "def y")) == True{} : Bool}

# LAW: an answer for an older text asks again: the last text typed is always checked.
law an_old_answer_asks_again:
  {C.asking(C.answered(C.typed(C.arrived(C.opening(C.start([]), "scripts/Mover.bend"), "a"), "b"), "a", False{}, C.no_problem())) == True{} : Bool}

# LAW: an answer for the text in the box ends the checking.
law the_answer_for_the_text_ends_it:
  {C.asking(C.answered(C.typed(C.arrived(C.opening(C.start([]), "scripts/Mover.bend"), "a"), "b"), "b", False{}, C.no_problem())) == False{} : Bool}

# LAW: closing keeps the project's problems: Play still waits for them.
law closing_keeps_the_projects_problems:
  for p: Pb.Problem
  {Pb.any(C.broken(C.shut(C.opening(C.start([p]), "scripts/Mover.bend")))) == True{} : Bool}
