# Actions: what a game reads instead of keys. A game asks "how much Walk?" or "was Jump
# pressed?", never "is W down?"; which keys give each action is data, kept in contexts.
#
# - A Button is one key: held, pressed or let go (Unreal's Down, Pressed and Released triggers;
#   Unity's IsPressed, WasPressedThisFrame, WasReleasedThisFrame).
# - An Axis is a value from -1 to 1 from two keys, one for each side: Unreal's Axis1D, made of
#   a key and a key with the Negate modifier. Both held give 0.
# - A Context is a named list of bindings (Unreal's Input Mapping Context, Unity's action
#   map). Contexts are given highest priority first: a key bound in a context is that context's,
#   and a context after it does not see it (Unreal: "the context with the highest priority will
#   be considered and the others ignored").
#
# References: docs/references/input-and-tick.md.
#
# Limits now:
# - No 2D composite (Unity's Vector2Composite) and no hold or tap timing yet: nothing uses them.
#   The character walks with two axes (engine/anim/locomotion.bend).
# - Contexts are ordered by their place in the list, not by a priority number.
# - A key only: no mouse buttons, no gamepad (Bend's Event has none yet).

import Base
import ./keyboard.bend as Kb

type Bind is Data:
  Bind.Button{name: String, key: U32}
  Bind.Axis{name: String, plus: U32, minus: U32}

type Context is Data:
  Context{name: String, binds: List<&2, Bind>}

def Act.name(+b: Bind) -> String:
  match b:
    case Bind.Button{n, _}:
      n
    case Bind.Axis{n, _, _}:
      n

def Act.binds_key(+b: Bind, +k: U32) -> Bool:
  match b:
    case Bind.Button{_, key}:
      U32.is_eq(key, k)
    case Bind.Axis{_, p, m}:
      (U32.is_eq(p, k) || U32.is_eq(m, k))

def Act.any_binds(bs: List<&2, Bind>, +k: U32) -> Bool:
  match bs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (Act.binds_key(h, k) || Act.any_binds(t, k))

def Act.binds(+c: Context) -> List<&2, Bind>:
  Context{_, bs} = c
  bs

# Does any context before this one take the key?
def Act.taken(cs: List<&2, Context>, +k: U32) -> Bool:
  match cs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (Act.any_binds(Act.binds(h), k) || Act.taken(t, k))

# Does any of these contexts bind the key?
def binds_any(+cs: List<&2, Context>, +k: U32) -> Bool:
  Act.taken(cs, k)

# A key counts for a context when no context before it binds the key.
def Act.free(+before: List<&2, Context>, +k: U32) -> Bool:
  Bool.not(Act.taken(before, k))

def Act.held(+b: Kb.Keyboard, +before: List<&2, Context>, +k: U32) -> Bool:
  (Act.free(before, k) && Kb.is_held(b, k))

def Act.one(c: Bool) -> F32:
  match c:
    case True{}:
      1.0
    case False{}:
      0.0

# The value of one binding: a Button is 1 while held, an Axis is +1, -1 or 0.
def Act.value(+b: Kb.Keyboard, +before: List<&2, Context>, +x: Bind) -> F32:
  match x:
    case Bind.Button{_, k}:
      Act.one(Act.held(b, before, k))
    case Bind.Axis{_, p, m}:
      (Act.one(Act.held(b, before, p)) - Act.one(Act.held(b, before, m)) : F32)

def Act.pressed(+b: Kb.Keyboard, +before: List<&2, Context>, +x: Bind) -> Bool:
  match x:
    case Bind.Button{_, k}:
      (Act.free(before, k) && Kb.was_pressed(b, k))
    case Bind.Axis{_, _, _}:
      False{}

def Act.released(+b: Kb.Keyboard, +before: List<&2, Context>, +x: Bind) -> Bool:
  match x:
    case Bind.Button{_, k}:
      (Act.free(before, k) && Kb.was_released(b, k))
    case Bind.Axis{_, _, _}:
      False{}

# What a question about an action looks at: the first binding with that name, in the
# contexts in order, and the contexts before the one that holds it.
type Found is Data:
  Found.None{}
  Found.At{bind: Bind, before: List<&2, Context>}

def Act.found_or(hit: Bool, +h: Bind, +before: List<&2, Context>, rest: Found) -> Found:
  match hit:
    case True{}:
      Found.At{h, before}
    case False{}:
      rest

def Act.in_binds(bs: List<&2, Bind>, +name: String, +before: List<&2, Context>) -> Found:
  match bs:
    case Nil{}:
      Found.None{}
    case Con{+h, t}:
      Act.found_or(String.eq(Act.name(h), name), h, before, Act.in_binds(t, name, before))

def Act.first(f: Found, +rest: Found) -> Found:
  match f:
    case Found.None{}:
      rest
    case Found.At{x, b}:
      Found.At{x, b}

def Act.append(xs: List<&2, Context>, +c: Context) -> List<&2, Context>:
  match xs:
    case Nil{}:
      [c]
    case Con{h, t}:
      h <> Act.append(t, c)

def Act.find(cs: List<&2, Context>, +name: String, +before: List<&2, Context>) -> Found:
  match cs:
    case Nil{}:
      Found.None{}
    case Con{+h, t}:
      Act.first(Act.in_binds(Act.binds(h), name, before), Act.find(t, name, Act.append(before, h)))

def Act.value_of(f: Found, +b: Kb.Keyboard) -> F32:
  match f:
    case Found.None{}:
      0.0
    case Found.At{x, before}:
      Act.value(b, before, x)

def Act.pressed_of(f: Found, +b: Kb.Keyboard) -> Bool:
  match f:
    case Found.None{}:
      False{}
    case Found.At{x, before}:
      Act.pressed(b, before, x)

def Act.released_of(f: Found, +b: Kb.Keyboard) -> Bool:
  match f:
    case Found.None{}:
      False{}
    case Found.At{x, before}:
      Act.released(b, before, x)

# How much of an action, from -1 to 1 (a Button: 0 or 1). An action no context binds is 0.
def value(+b: Kb.Keyboard, +cs: List<&2, Context>, +name: String) -> F32:
  Act.value_of(Act.find(cs, name, []), b)

# Is the action held? A Button while its key is down; an Axis while either of its keys is.
def Act.is_held(+b: Kb.Keyboard, +before: List<&2, Context>, +x: Bind) -> Bool:
  match x:
    case Bind.Button{_, k}:
      Act.held(b, before, k)
    case Bind.Axis{_, p, m}:
      (Act.held(b, before, p) || Act.held(b, before, m))

def Act.held_of(f: Found, +b: Kb.Keyboard) -> Bool:
  match f:
    case Found.None{}:
      False{}
    case Found.At{x, before}:
      Act.is_held(b, before, x)

def held(+b: Kb.Keyboard, +cs: List<&2, Context>, +name: String) -> Bool:
  Act.held_of(Act.find(cs, name, []), b)

# Was a Button pressed, or let go, since the last tick?
def pressed(+b: Kb.Keyboard, +cs: List<&2, Context>, +name: String) -> Bool:
  Act.pressed_of(Act.find(cs, name, []), b)

def released(+b: Kb.Keyboard, +cs: List<&2, Context>, +name: String) -> Bool:
  Act.released_of(Act.find(cs, name, []), b)

# ---------- What a context must keep (its laws) ----------

def Act.keys_of(+x: Bind) -> List<&2, U32>:
  match x:
    case Bind.Button{_, k}:
      [k]
    case Bind.Axis{_, p, m}:
      [p, m]

def Act.join(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      ys
    case Con{h, t}:
      h <> Act.join(t, ys)

def Act.all_keys(bs: List<&2, Bind>) -> List<&2, U32>:
  match bs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Act.join(Act.keys_of(h), Act.all_keys(t))

def Act.has(xs: List<&2, U32>, +k: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (U32.is_eq(h, k) || Act.has(t, k))

def Act.unique(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+h, +t}:
      (Bool.not(Act.has(t, h)) && Act.unique(t))

# No key is bound twice in one context, and no binding has the key 0 (a key with no name).
def clean(+c: Context) -> Bool:
  (Act.unique(Act.all_keys(Act.binds(c))) && Bool.not(Act.has(Act.all_keys(Act.binds(c)), 0)))
