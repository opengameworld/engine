# The keyboard: which keys are held, and which were pressed or let go since the last tick.
#
# It is a fold over Bend's own events (Event.Key, Event.Focus in bend2/base.bend): feed() takes
# one event, and a tick reads the keyboard and then calls ticked(), which forgets what was
# pressed and let go. A key pressed and let go between two ticks is still seen by the next tick,
# as both pressed and let go: Godot keeps a press and a release apart for the same reason
# (ActionState's pressed and released frames, core/input/input.h). Losing the focus lets go of
# every key, as Godot's release_pressed_events() and Bend's own window do; otherwise a key held
# while the person switches windows would stay held. References: docs/references/input-and-tick.md.
#
# The browser feeds it through platform/web/input.js, which only hands over each event.
#
# Limits now:
# - Keys only: the pointer is read by the editor's camera and, in Play, by engine/play/ (a
#   click). No gamepad: Bend's Event has none yet.
# - A key held down that auto-repeats sends no new press (only the first down counts).

import Base
import ./keys.bend as Keys

type Keyboard is Data:
  Keyboard{held: List<&2, U32>, pressed: List<&2, U32>, released: List<&2, U32>}

def empty() -> Keyboard:
  Keyboard{[], [], []}

# What JS hands over: a key by the browser's name for it, and the focus.
def key(+code: U32, +down: Bool) -> Event:
  Key{code, down}

def focus(+on: Bool) -> Event:
  Focus{on}

def held(+b: Keyboard) -> List<&2, U32>:
  Keyboard{h, _, _} = b
  h

def pressed(+b: Keyboard) -> List<&2, U32>:
  Keyboard{_, p, _} = b
  p

def released(+b: Keyboard) -> List<&2, U32>:
  Keyboard{_, _, r} = b
  r

def Board.has(xs: List<&2, U32>, +k: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (U32.is_eq(h, k) || Board.has(t, k))

def Board.keep(drop: Bool, +h: U32, rest: List<&2, U32>) -> List<&2, U32>:
  match drop:
    case True{}:
      rest
    case False{}:
      h <> rest

def Board.without(xs: List<&2, U32>, +k: U32) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Board.keep(U32.is_eq(h, k), h, Board.without(t, k))

def Board.append(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      ys
    case Con{+h, t}:
      h <> Board.append(t, ys)

# A key goes down: held, and pressed since the last tick. A key already held (auto-repeat)
# changes nothing.
def Board.down(already: Bool, +b: Keyboard, +k: U32) -> Keyboard:
  match already:
    case True{}:
      b
    case False{}:
      Keyboard{h, p, r} = b
      Keyboard{k <> h, k <> p, r}

# A key comes up: no longer held, and let go since the last tick. A key that was not held
# (pressed before the page had the focus) changes nothing.
def Board.up(was: Bool, +b: Keyboard, +k: U32) -> Keyboard:
  match was:
    case True{}:
      Keyboard{h, p, r} = b
      Keyboard{Board.without(h, k), p, k <> r}
    case False{}:
      b

def Board.key(down: Bool, +b: Keyboard, +k: U32) -> Keyboard:
  match down:
    case True{}:
      Board.down(Board.has(held(b), k), b, k)
    case False{}:
      Board.up(Board.has(held(b), k), b, k)

# Losing the focus lets go of every key held.
def Board.focus(on: Bool, +b: Keyboard) -> Keyboard:
  match on:
    case True{}:
      b
    case False{}:
      Keyboard{h, p, r} = b
      Keyboard{[], p, Board.append(h, r)}

# The keyboard after one event. Events that are not about keys or the focus change nothing;
# a key Bend has no code for (0) changes nothing either.
def feed(+b: Keyboard, e: Event) -> Keyboard:
  match e:
    case Key{+k, down}:
      Board.key((down && U32.is_ne(k, 0)), b, k)
    case Focus{on}:
      Board.focus(on, b)
    case _:
      b

# The browser's KeyboardEvent.code, pressed or let go (platform/web/input.js).
def feed_web(+b: Keyboard, +code: String, +down: Bool) -> Keyboard:
  feed(b, Key{Keys.from_web(code), down})

# After a tick has read it: what was pressed and let go is forgotten.
def ticked(b: Keyboard) -> Keyboard:
  Keyboard{h, _, _} = b
  Keyboard{h, [], []}

def is_held(+b: Keyboard, +k: U32) -> Bool:
  Board.has(held(b), k)

def was_pressed(+b: Keyboard, +k: U32) -> Bool:
  Board.has(pressed(b), k)

def was_released(+b: Keyboard, +k: U32) -> Bool:
  Board.has(released(b), k)
