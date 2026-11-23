# The laws of engine/input (keys, the keyboard, actions and contexts).
# `bend engine/input/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./keys.bend as Keys
import ./keyboard.bend as Kb
import ./actions.bend as Act

# ---------- Keys ----------

# LAW: the browser's KeyW is Bend's w, wherever the layout puts the letter W.
law web_letter_is_bends_letter:
  {Keys.from_web("KeyW") == 119 : U32}

law web_digit_is_bends_digit:
  {Keys.from_web("Digit1") == 49 : U32}

law web_arrow_is_bends_arrow:
  {Keys.from_web("ArrowUp") == 63232 : U32}

# LAW: a key with no name here is 0, and 0 is never held.
law unnamed_key_is_zero:
  {Keys.from_web("F13") == 0 : U32}

law unnamed_key_is_never_held:
  {Kb.held(Kb.feed_web(Kb.empty(), "F13", True{})) == [] : List<&2, U32>}

# ---------- The keyboard ----------

# LAW: losing the focus lets go of every key (Godot's release_pressed_events).
law focus_lost_lets_go_of_every_key:
  {Kb.held(Kb.feed(Kb.feed(Kb.feed(Kb.empty(), Kb.key(119, True{})), Kb.key(97, True{})), Kb.focus(False{}))) == [] : List<&2, U32>}

# LAW: a key pressed and let go before a tick is seen by that tick as pressed and let go.
law a_tap_inside_one_tick_is_pressed:
  {Kb.was_pressed(Kb.feed(Kb.feed(Kb.empty(), Kb.key(32, True{})), Kb.key(32, False{})), 32) == True{} : Bool}

law a_tap_inside_one_tick_is_released:
  {Kb.was_released(Kb.feed(Kb.feed(Kb.empty(), Kb.key(32, True{})), Kb.key(32, False{})), 32) == True{} : Bool}

law a_tap_is_not_held_after:
  {Kb.is_held(Kb.feed(Kb.feed(Kb.empty(), Kb.key(32, True{})), Kb.key(32, False{})), 32) == False{} : Bool}

# LAW: a held key that auto-repeats is one press.
law repeat_is_one_press:
  {Kb.pressed(Kb.feed(Kb.feed(Kb.empty(), Kb.key(119, True{})), Kb.key(119, True{}))) == [119] : List<&2, U32>}

# LAW: after a tick, nothing is pressed or let go any more; what is held stays held.
law a_tick_forgets_presses:
  for b: Kb.Keyboard
  {Kb.pressed(Kb.ticked(b)) == [] : List<&2, U32>}

law a_tick_forgets_releases:
  for b: Kb.Keyboard
  {Kb.released(Kb.ticked(b)) == [] : List<&2, U32>}

law a_tick_keeps_what_is_held:
  for b: Kb.Keyboard
  {Kb.held(Kb.ticked(b)) == Kb.held(b) : List<&2, U32>}

# ---------- Actions and contexts ----------

# LAW: a key a higher context binds is not seen by a lower one (Unreal's priority).
law a_higher_context_takes_the_key:
  {Act.held(Kb.feed(Kb.empty(), Kb.key(119, True{})), [Act.Context{"menu", [Act.Bind.Button{"Up", 119}]}, Act.Context{"walk", [Act.Bind.Axis{"Walk", 119, 115}]}], "Walk") == False{} : Bool}

law the_higher_context_has_it:
  {Act.held(Kb.feed(Kb.empty(), Kb.key(119, True{})), [Act.Context{"menu", [Act.Bind.Button{"Up", 119}]}, Act.Context{"walk", [Act.Bind.Axis{"Walk", 119, 115}]}], "Up") == True{} : Bool}

# LAW: an action no context binds is 0.
law an_unbound_action_is_zero:
  for b: Kb.Keyboard
  {Act.value(b, [], "Walk") == 0.0 : F32}

# LAW: a context that binds a key twice is not clean.
law a_key_bound_twice_is_caught:
  {Act.clean(Act.Context{"bad", [Act.Bind.Button{"Jump", 32}, Act.Bind.Axis{"Walk", 119, 32}]}) == False{} : Bool}
