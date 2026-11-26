# A value as the engine keeps it for a script: an attached script's fields (its State) and the body
# of a message (a project's Message), in one shape the engine, the Inspector and a saved scene all
# read without knowing the script.
#
# A script works with its own typed State and a project with its own typed Message; the project's
# registry (tools/project/registry.js) writes, for each, the two functions between the type and a
# Value, from the type's declaration. Bend has no reflection, so that generated code is how the
# Inspector shows a script's fields by name. The kinds a field may be are the ones the Inspector
# edits: Num (F32), Int (U32), Flag (Bool), Text (String), Vec (a V3) and Ref (a thing's id).
#
# Named holds a reference as a saved scene writes it: by the thing's name, since ids are given
# again when the scene opens (engine/scene/id.bend); opening the scene turns it into a Ref.
#
# Limits now:
# - A record keeps its field names and values in two lists, looked up by walking them.
# - No list or nested record as a field: a field is one of the kinds above.

import Base
import ../core/vec.bend as V
import ../scene/id.bend as Id

type Value is Data:
  Value.Num{n: F32}
  Value.Int{n: U32}
  Value.Flag{b: Bool}
  Value.Text{s: String}
  Value.Vec{v: V.V3}
  Value.Ref{id: Id.Id}
  Value.Named{name: String}
  Value.Rec{names: List<&2, String>, values: List<&2, Value>}

# ---------- Reading a field ----------

def num(+v: Value) -> F32:
  match v:
    case Value.Num{n}:
      n
    case _:
      0.0

def int(+v: Value) -> U32:
  match v:
    case Value.Int{n}:
      n
    case _:
      0

def flag(+v: Value) -> Bool:
  match v:
    case Value.Flag{b}:
      b
    case _:
      False{}

def text(+v: Value) -> String:
  match v:
    case Value.Text{s}:
      s
    case _:
      ""

def vec(+v: Value) -> V.V3:
  match v:
    case Value.Vec{x}:
      x
    case _:
      V.V3{0.0, 0.0, 0.0}

def ref(+v: Value) -> Id.Id:
  match v:
    case Value.Ref{i}:
      i
    case _:
      Id.none()

def Val.pick(c: Bool, +a: Value, +b: Value) -> Value:
  match c:
    case True{}:
      a
    case False{}:
      b

def Val.at_in(ns: List<&2, String>, vs: List<&2, Value>, +name: String) -> Value:
  match ns vs:
    case Con{+n, nt} Con{+v, vt}:
      Val.pick(String.eq(n, name), v, Val.at_in(nt, vt, name))
    case _ _:
      Value.Num{0.0}

# A record's field by its name (Num 0.0 when there is none, or the value is not a record).
def at(+v: Value, +name: String) -> Value:
  match v:
    case Value.Rec{ns, vs}:
      Val.at_in(ns, vs, name)
    case _:
      Value.Num{0.0}

def names(+v: Value) -> List<&2, String>:
  match v:
    case Value.Rec{ns, _}:
      ns
    case _:
      []

def values(+v: Value) -> List<&2, Value>:
  match v:
    case Value.Rec{_, vs}:
      vs
    case _:
      []

# ---------- Changing a field ----------

def Val.put_in(ns: List<&2, String>, vs: List<&2, Value>, +name: String, +x: Value) -> List<&2, Value>:
  match ns vs:
    case Con{+n, nt} Con{+v, vt}:
      Val.pick(String.eq(n, name), x, v) <> Val.put_in(nt, vt, name, x)
    case _ _:
      []

# The record with one field's value replaced (a name it does not have changes nothing).
def with_field(+v: Value, +name: String, +x: Value) -> Value:
  match v:
    case Value.Rec{ns, vs}:
      Value.Rec{ns, Val.put_in(ns, vs, name, x)}
    case _:
      v

def Val.has(ns: List<&2, String>, +name: String) -> Bool:
  match ns:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (String.eq(h, name) || Val.has(t, name))

def Val.merged_in(ns: List<&2, String>, vs: List<&2, Value>, +saved: Value) -> List<&2, Value>:
  match ns vs:
    case Con{+n, nt} Con{+v, vt}:
      Val.pick(Val.has(names(saved), n), at(saved, n), v) <> Val.merged_in(nt, vt, saved)
    case _ _:
      []

# The defaults of a script's fields with the saved values put in, by name: a field the script added
# since keeps its default, a field it dropped is forgotten.
def merged(+defaults: Value, +saved: Value) -> Value:
  match defaults:
    case Value.Rec{ns, vs}:
      Value.Rec{ns, Val.merged_in(ns, vs, saved)}
    case _:
      defaults

# ---------- What kind a value is (the Inspector draws one field for each) ----------

def kind(+v: Value) -> String:
  match v:
    case Value.Num{_}:
      "num"
    case Value.Int{_}:
      "int"
    case Value.Flag{_}:
      "flag"
    case Value.Text{_}:
      "text"
    case Value.Vec{_}:
      "vec"
    case Value.Ref{_}:
      "ref"
    case Value.Named{_}:
      "ref"
    case Value.Rec{_, _}:
      "rec"
