# Keys: the codes Bend gives a key, and the browser's names for them.
#
# A key's code is Bend's own (bend2/effs/window.c, the code of its Event.Key): the key's
# character in lower case (a = 97, 1 = 49, space = 32, Escape 27, Return 13, Tab 9, Backspace
# 127), the arrows from 63232, a modifier 65536 plus the Mac's key code (Shift 65592). A native
# window gives these codes itself; in the browser, platform/web/input.js asks from_web() for the
# code of each KeyboardEvent.code.
#
# KeyboardEvent.code names the key's place on the keyboard, not the letter it types (MDN:
# "isn't altered by keyboard layout"), and from_web gives the code that place has on a US
# keyboard. So W/A/S/D stay where they are on AZERTY, and the browser and a native build on a
# US keyboard agree. References: docs/references/input-and-tick.md.
#
# Limits now:
# - Bend's native window names a key by the character it types, so on a native build with
#   another layout the same place gives another code; the browser does not have this problem.
# - Only the keys a game or the editor uses today have a name here: letters, digits, space,
#   Return, Escape, Tab, Backspace, the arrows, Shift, Control, Alt, Meta. Any other gives 0.

import Base

def a() -> U32: 97
def d() -> U32: 100
def s() -> U32: 115
def w() -> U32: 119
def space() -> U32: 32
def escape() -> U32: 27
def up() -> U32: 63232
def down() -> U32: 63233
def left() -> U32: 63234
def right() -> U32: 63235

# The character code at a place of a text, or 0.
def Keys.code_of(m: Maybe<&2, Char>) -> U32:
  match m:
    case Some{c}:
      match c:
        case Chr{k}:
          k
    case None{}:
      0

def Keys.char_at(+text: String, n: Nat) -> U32:
  Keys.code_of(String.get(text, n))

def Keys.pick(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def Keys.is_size(+text: String, +n: U32) -> Bool:
  U32.is_eq(U32.from_nat(String.length(text)), n)

# "KeyA" .. "KeyZ": the letter in lower case.
def Keys.letter(+code: String) -> Bool:
  (String.starts_with(code, "Key") && Keys.is_size(code, 4))

# "Digit0" .. "Digit9": the digit.
def Keys.digit(+code: String) -> Bool:
  (String.starts_with(code, "Digit") && Keys.is_size(code, 6))

# The named keys, by their KeyboardEvent.code.
def Keys.named(+code: String) -> U32:
  Keys.pick(String.eq(code, "Space"), 32,
  Keys.pick(String.eq(code, "Enter"), 13,
  Keys.pick(String.eq(code, "Escape"), 27,
  Keys.pick(String.eq(code, "Tab"), 9,
  Keys.pick(String.eq(code, "Backspace"), 127,
  Keys.pick(String.eq(code, "ArrowUp"), 63232,
  Keys.pick(String.eq(code, "ArrowDown"), 63233,
  Keys.pick(String.eq(code, "ArrowLeft"), 63234,
  Keys.pick(String.eq(code, "ArrowRight"), 63235,
  Keys.pick(String.eq(code, "ShiftLeft"), 65592,
  Keys.pick(String.eq(code, "ShiftRight"), 65596,
  Keys.pick(String.eq(code, "ControlLeft"), 65595,
  Keys.pick(String.eq(code, "ControlRight"), 65598,
  Keys.pick(String.eq(code, "AltLeft"), 65594,
  Keys.pick(String.eq(code, "AltRight"), 65597,
  Keys.pick(String.eq(code, "MetaLeft"), 65591,
  Keys.pick(String.eq(code, "MetaRight"), 65590, 0)))))))))))))))))

# Bend's code for the key the browser names `code` (a KeyboardEvent.code), or 0 for a key
# without a name here.
def from_web(+code: String) -> U32:
  Keys.pick(Keys.letter(code), (Keys.char_at(code, 3n) + 32 : U32),
  Keys.pick(Keys.digit(code), Keys.char_at(code, 5n), Keys.named(code)))
