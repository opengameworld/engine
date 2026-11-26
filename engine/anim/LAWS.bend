# The laws of engine/anim (skeletons, animation, skin, locomotion). `bend engine/anim/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ../scene/scene.bend as S
import ../core/transform.bend as Tr
import ./skeleton.bend as Sk
import ../../projects/character/arm.bend as Arm
import ./figure.bend as Fig
import ./skin.bend as Skin
import ./helpers.bend as H
import ./locomotion.bend as Loco
import ../render/mesh.bend as Mesh
import ../render/material.bend as Mat

# ---------- Skeletons ----------
# The rig standard's structural laws (engine/anim/skeleton.bend), on the test arm
# and on skeletons that break each one.

# LAW: the test arm keeps every structural law.
law arm_is_valid:
  {Sk.valid(Arm.skeleton()) == True{} : Bool}

# LAW: the test arm has one root, five deform bones (three arm, two
# finger), one twist, one support.
law arm_has_its_roles:
  {Sk.role_counts(Arm.skeleton()) == [1, 5, 1, 1, 0] : List<&2, U32>}

# LAW: the test arm's hand is found by its slot.
law arm_hand_has_a_slot:
  {Sk.find_slot(Arm.skeleton(), "hand.L") == 4 : U32}

# LAW: a bone listed before its parent breaks the order.
law child_before_parent_is_invalid:
  for t: Tr.Transform
  {Sk.valid(Sk.Skeleton{[
     Sk.Bone{"root", "root", Sk.Root{}, 0, t, 0.0},
     Sk.Bone{"a", "", Sk.Deform{}, 2, t, 0.0},
     Sk.Bone{"b", "", Sk.Deform{}, 0, t, 0.0}]}) == False{} : Bool}

# LAW: a second root is not allowed.
law two_roots_are_invalid:
  for t: Tr.Transform
  {Sk.valid(Sk.Skeleton{[
     Sk.Bone{"root", "root", Sk.Root{}, 0, t, 0.0},
     Sk.Bone{"another root", "", Sk.Root{}, 0, t, 0.0}]}) == False{} : Bool}

# LAW: a Deform bone may not hang from a computed bone.
law deform_under_twist_is_invalid:
  for t: Tr.Transform
  {Sk.valid(Sk.Skeleton{[
     Sk.Bone{"root", "root", Sk.Root{}, 0, t, 0.0},
     Sk.Bone{"twist", "", Sk.Twist{}, 0, t, 0.0},
     Sk.Bone{"hand", "", Sk.Deform{}, 1, t, 0.0}]}) == False{} : Bool}

# LAW: helpers may hang from helpers (the mannequin does this).
law support_under_twist_is_valid:
  for t: Tr.Transform
  {Sk.valid(Sk.Skeleton{[
     Sk.Bone{"root", "root", Sk.Root{}, 0, t, 0.0},
     Sk.Bone{"arm", "", Sk.Deform{}, 0, t, 0.0},
     Sk.Bone{"twist", "", Sk.Twist{}, 1, t, 0.0},
     Sk.Bone{"fix", "", Sk.Support{}, 2, t, 0.0}]}) == True{} : Bool}

# ---------- Animation ----------

# LAW: with reduce_motion on, a character's animation never moves by itself.
law reduce_motion_freezes_figures:
  for f: Fig.Figure
  for dt: F32
  {Fig.advance(f, dt, True{}) == f : Fig.Figure}

# LAW: the same for a whole scene.
law reduce_motion_freezes_scenes:
  for s: S.Scene
  for dt: F32
  {S.advance(s, dt, True{}) == s : S.Scene}

# LAW: a character that is not on does not play: with Play not pressed,
# asking it to play changes nothing, with motion reduced or not.
law a_stopped_figure_does_not_play:
  for f: Fig.Figure
  for dt: F32
  for reduce: Bool
  {Fig.play(Fig.set_on(f, False{}), dt, reduce) == Fig.set_on(f, False{}) : Fig.Figure}

# ---------- Skin weights ----------
# The weight rules of engine/anim/skin.bend, on single vertices (the reference
# rig's 4074 vertices are checked by mannequin/LAWS.bend).

# LAW: weights that sum to 65535 over distinct bones are fine.
law weights_that_sum_to_the_whole_hold:
  {Skin.vertex_ok(1, 2, 0, 0, 40000, 25535, 0, 0, 6) == True{} : Bool}

# LAW: weights that miss the whole by 1 do not.
law weights_one_short_fail:
  {Skin.vertex_ok(1, 2, 0, 0, 40000, 25534, 0, 0, 6) == False{} : Bool}

# LAW: a vertex with no weight would fall to the origin, so it fails.
law vertex_without_weight_fails:
  {Skin.vertex_ok(0, 0, 0, 0, 0, 0, 0, 0, 6) == False{} : Bool}

# LAW: the same bone twice in a vertex fails.
law same_bone_twice_fails:
  {Skin.vertex_ok(3, 3, 0, 0, 30000, 35535, 0, 0, 6) == False{} : Bool}

# LAW: a weighted joint past the last bone fails.
law joint_past_the_end_fails:
  {Skin.vertex_ok(6, 0, 0, 0, 65535, 0, 0, 0, 6) == False{} : Bool}

# LAW: empty slots (weight 0) may point anywhere.
law empty_slots_are_ignored:
  {Skin.vertex_ok(2, 9, 9, 9, 65535, 0, 0, 0, 6) == True{} : Bool}

# ---------- Helper bones ----------

# LAW: every Twist and Support bone of the test arm has exactly one rule.
law arm_helpers_are_covered:
  {H.helpers_cover(Arm.skeleton(), Arm.rules()) == True{} : Bool}

# LAW: a helper without a rule is caught.
law missing_helper_rule_is_caught:
  {H.helpers_cover(Arm.skeleton(), [H.Rule{3, 4, H.Roll{}, 0.5}]) == False{} : Bool}

# LAW: a rule on a Deform bone is caught (clips move those, not rules).
law rule_on_deform_bone_is_caught:
  {H.helpers_cover(Arm.skeleton(), [H.Rule{3, 4, H.Roll{}, 0.5}, H.Rule{5, 2, H.Full{}, 0.5}, H.Rule{2, 1, H.Full{}, 0.5}]) == False{} : Bool}

# ---------- Locomotion ----------

# LAW: walking moves characters only: a thing that is drawn but not a character stays where it is.
law walking_never_moves_a_shown_thing:
  for n: String
  for p: Tr.Transform
  for sh: Mesh.Mesh
  for m: Mat.Material
  for i: Loco.Input
  for dt: F32
  {Loco.drive_thing(S.thing(n, p, S.Shown{sh, m}), i, dt) == S.thing(n, p, S.Shown{sh, m}) : S.Thing}

law walking_never_moves_a_hidden_thing:
  for n: String
  for p: Tr.Transform
  for i: Loco.Input
  for dt: F32
  {Loco.drive_thing(S.thing(n, p, S.Hidden{}), i, dt) == S.thing(n, p, S.Hidden{}) : S.Thing}
