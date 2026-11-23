# The proofs of engine/anim/LAWS.bend.

import Base
import ./LAWS.bend as Laws
import ../scene/scene.bend as S
import ./locomotion.bend as Loco
import ./figure.bend as Fig


def Laws.arm_is_valid():
  {==}

def Laws.arm_has_its_roles():
  {==}

def Laws.arm_hand_has_a_slot():
  {==}

def Laws.child_before_parent_is_invalid(t):
  {==}

def Laws.two_roots_are_invalid(t):
  {==}

def Laws.deform_under_twist_is_invalid(t):
  {==}

def Laws.support_under_twist_is_valid(t):
  {==}

def Laws.reduce_motion_freezes_figures(f, dt):
  {==}

def Laws.a_stopped_figure_does_not_play(f, dt, reduce):
  match f:
    case Fig.Figure{s, k, ps, i, w, h, r, v, cs, n, o, tr}:
      {==}

# A scene's things, advanced with reduce_motion on, are the same things:
# by induction on the list, looking at each thing's look.
def frozen_things(xs: List<&2, S.Thing>, dt: F32) -> {xs == S.advance_go(xs, dt, True{}) : List<&2, S.Thing>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      match h:
        case S.Thing{n, p, l}:
          match l:
            case S.Hidden{}:
              %frozen_things(t, dt) : {S.Thing{n, p, S.Hidden{}} <> t == S.Thing{n, p, S.Hidden{}} <> _ : List<&2, S.Thing>}
              {==}
            case S.Shown{sh, m}:
              %frozen_things(t, dt) : {S.Thing{n, p, S.Shown{sh, m}} <> t == S.Thing{n, p, S.Shown{sh, m}} <> _ : List<&2, S.Thing>}
              {==}
            case S.Rigged{f}:
              %frozen_things(t, dt) : {S.Thing{n, p, S.Rigged{f}} <> t == S.Thing{n, p, S.Rigged{f}} <> _ : List<&2, S.Thing>}
              {==}

def Laws.reduce_motion_freezes_scenes(s, dt):
  match s:
    case S.Scene{xs}:
      %frozen_things(xs, dt) : {S.Scene{_} == S.Scene{xs} : S.Scene}
      {==}

def Laws.weights_that_sum_to_the_whole_hold():
  {==}

def Laws.weights_one_short_fail():
  {==}

def Laws.vertex_without_weight_fails():
  {==}

def Laws.same_bone_twice_fails():
  {==}

def Laws.joint_past_the_end_fails():
  {==}

def Laws.empty_slots_are_ignored():
  {==}

def Laws.arm_helpers_are_covered():
  {==}

def Laws.missing_helper_rule_is_caught():
  {==}

def Laws.rule_on_deform_bone_is_caught():
  {==}

def Laws.walking_never_moves_a_shown_thing(n, p, sh, m, i, dt):
  {==}

def Laws.walking_never_moves_a_hidden_thing(n, p, i, dt):
  {==}
