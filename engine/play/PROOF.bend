# The proofs of engine/play/LAWS.bend.

import Base
import ./LAWS.bend as Laws
import ./play.bend as Play

def Laws.play_starts_from_the_edited_scene(x):
  match x:
    case Play.Session{m, e, r, k, c, cs, sc}:
      {==}

def Laws.stop_gives_back_the_edited_scene(x):
  match x:
    case Play.Session{m, e, r, k, c, cs, sc}:
      {==}

def Laws.play_then_stop_is_the_scene(s):
  {==}

def Laws.a_change_in_play_is_forgotten(s, t):
  {==}

def Laws.a_change_in_edit_is_kept(s, t):
  {==}

def Laws.a_paused_frame_changes_nothing(s, dt, r):
  {==}

def Laws.keys_are_not_heard_while_editing(s, c, d):
  {==}

def Laws.play_starts_with_no_key_held(x):
  match x:
    case Play.Session{m, e, r, k, c, cs, sc}:
      {==}

def Laws.step_needs_pause(s):
  {==}

def Laws.toolbar_play_then_stop_is_the_scene(s):
  {==}

def Laws.asking_for_edit_while_editing_changes_nothing(s):
  {==}

def Laws.no_play_while_a_script_does_not_compile(s, p, ps):
  {==}

def Laws.play_starts_when_every_script_compiles(s):
  {==}
