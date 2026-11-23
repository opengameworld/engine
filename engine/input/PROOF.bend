# The proofs of engine/input/LAWS.bend.

import Base
import ./LAWS.bend as Laws
import ./keyboard.bend as Kb

def Laws.web_letter_is_bends_letter():
  {==}

def Laws.web_digit_is_bends_digit():
  {==}

def Laws.web_arrow_is_bends_arrow():
  {==}

def Laws.unnamed_key_is_zero():
  {==}

def Laws.unnamed_key_is_never_held():
  {==}

def Laws.focus_lost_lets_go_of_every_key():
  {==}

def Laws.a_tap_inside_one_tick_is_pressed():
  {==}

def Laws.a_tap_inside_one_tick_is_released():
  {==}

def Laws.a_tap_is_not_held_after():
  {==}

def Laws.repeat_is_one_press():
  {==}

def Laws.a_tick_forgets_presses(b):
  match b:
    case Kb.Keyboard{h, p, r}:
      {==}

def Laws.a_tick_forgets_releases(b):
  match b:
    case Kb.Keyboard{h, p, r}:
      {==}

def Laws.a_tick_keeps_what_is_held(b):
  match b:
    case Kb.Keyboard{h, p, r}:
      {==}

def Laws.a_higher_context_takes_the_key():
  {==}

def Laws.the_higher_context_has_it():
  {==}

def Laws.an_unbound_action_is_zero(b):
  {==}

def Laws.a_key_bound_twice_is_caught():
  {==}
