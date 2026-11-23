# Numerical tests of engine/input/actions.bend: the value of an axis is float math, which the
# law checker does not compute (see engine/input/LAWS.bend for the rest).
#
# Limits now:
# - A test is checked at a few chosen keys, not for every key as a law is.

import Base
import ../../engine/input/keyboard.bend as Kb
import ../../engine/input/actions.bend as Act

type Check is Data:
  Check{name: String, ok: Bool}

def walk() -> List<&2, Act.Context>:
  [Act.Context{"walk", [Act.Bind.Axis{"Walk", 119, 115}, Act.Bind.Axis{"Turn", 97, 100}]}]

def down(+b: Kb.Keyboard, +k: U32) -> Kb.Keyboard:
  Kb.feed(b, Kb.key(k, True{}))

def same(+a: F32, +b: F32) -> Bool:
  F32.is_eq(a, b)

def checks() -> List<&2, Check>:
  [Check{"W alone walks ahead: Walk is 1", same(Act.value(down(Kb.empty(), 119), walk(), "Walk"), 1.0)},
   Check{"S alone walks back: Walk is -1", same(Act.value(down(Kb.empty(), 115), walk(), "Walk"), (0.0 - 1.0 : F32))},
   Check{"W and S together cancel: Walk is 0", same(Act.value(down(down(Kb.empty(), 119), 115), walk(), "Walk"), 0.0)},
   Check{"A turns left: Turn is 1, and Walk stays 0", (same(Act.value(down(Kb.empty(), 97), walk(), "Turn"), 1.0) && same(Act.value(down(Kb.empty(), 97), walk(), "Walk"), 0.0))},
   Check{"a key a higher context binds gives the lower one nothing", same(Act.value(down(Kb.empty(), 119), [Act.Context{"menu", [Act.Bind.Button{"Up", 119}]}, Act.Context{"walk", [Act.Bind.Axis{"Walk", 119, 115}]}], "Walk"), 0.0)},
   Check{"the browser's KeyW held walks ahead", same(Act.value(Kb.feed_web(Kb.empty(), "KeyW", True{}), walk(), "Walk"), 1.0)},
   Check{"after the focus is lost, Walk is 0 again", same(Act.value(Kb.feed(down(Kb.empty(), 119), Kb.focus(False{})), walk(), "Walk"), 0.0)}]
