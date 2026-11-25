# The laws of engine/play (Play mode; the tick is float math, tested in tests/play/). `bend engine/play/PROOF.bend` must print ALL
# PROOFS CHECK.

import Base
import ../scene/scene.bend as S
import ./play.bend as Play
import ../input/keyboard.bend as Kb
import ../script/problem.bend as Pb

# ---------- Play mode ----------

# LAW: Play starts from the scene as it was edited.
law play_starts_from_the_edited_scene:
  for x: Play.Session
  {Play.shown(Play.start(x)) == Play.edited(x) : S.Scene}

# LAW: Stop gives back the edited scene, whatever happened while playing.
law stop_gives_back_the_edited_scene:
  for x: Play.Session
  {Play.shown(Play.stop(x)) == Play.edited(x) : S.Scene}

# LAW: Play then Stop is the scene untouched (Unity's and Unreal's default).
law play_then_stop_is_the_scene:
  for s: S.Scene
  {Play.shown(Play.stop(Play.start(Play.edit(s)))) == s : S.Scene}

# LAW: a change made while playing is forgotten by Stop.
law a_change_in_play_is_forgotten:
  for s: S.Scene
  for t: S.Scene
  {Play.shown(Play.stop(Play.with_scene(Play.start(Play.edit(s)), t))) == s : S.Scene}

# LAW: a change made while editing is the edited scene.
law a_change_in_edit_is_kept:
  for s: S.Scene
  for t: S.Scene
  {Play.edited(Play.with_scene(Play.edit(s), t)) == t : S.Scene}

# LAW: while paused, a frame changes nothing.
law a_paused_frame_changes_nothing:
  for s: S.Scene
  for dt: F32
  for r: Bool
  {Play.frame(Play.pause(Play.start(Play.edit(s))), dt, r) == Play.pause(Play.start(Play.edit(s))) : Play.Session}

# LAW: while editing, keys are not heard: nothing walks in Edit.
law keys_are_not_heard_while_editing:
  for s: S.Scene
  for c: String
  for d: Bool
  {Play.keys(Play.key(Play.edit(s), c, d)) == Kb.empty() : Kb.Keyboard}

# LAW: Play starts with no key held.
law play_starts_with_no_key_held:
  for x: Play.Session
  {Play.keys(Play.start(x)) == Kb.empty() : Kb.Keyboard}

# LAW: Step does nothing unless paused.
law step_needs_pause:
  for s: S.Scene
  {Play.step(Play.start(Play.edit(s))) == Play.start(Play.edit(s)) : Play.Session}

# LAW: the toolbar's Play (1) then Stop (0) is the scene untouched.
law toolbar_play_then_stop_is_the_scene:
  for s: S.Scene
  {Play.shown(Play.to_mode(Play.to_mode(Play.edit(s), 1), 0)) == s : S.Scene}

# LAW: asking a session for the mode it is in changes nothing.
law asking_for_edit_while_editing_changes_nothing:
  for s: S.Scene
  {Play.to_mode(Play.edit(s), 0) == Play.edit(s) : Play.Session}

# LAW: while a script does not compile, Play does not start: the session stays in Edit.
law no_play_while_a_script_does_not_compile:
  for s: S.Scene
  for p: Pb.Problem
  for ps: List<&2, Pb.Problem>
  {Play.to_mode_checked(Play.edit(s), 1, p <> ps) == Play.edit(s) : Play.Session}

# LAW: with every script compiling, Play starts as the toolbar asks.
law play_starts_when_every_script_compiles:
  for s: S.Scene
  {Play.to_mode_checked(Play.edit(s), 1, []) == Play.to_mode(Play.edit(s), 1) : Play.Session}
