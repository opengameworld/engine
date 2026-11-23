# Retarget: a motion becomes a clip for one skeleton.
#
# A motion (engine/anim/motion.bend) says, for a slot, how far it has turned
# from the T-pose, in the character's own space. A clip
# (engine/anim/clip.bend) wants each bone's rotation relative to its parent.
# For a bone b with parent p:
#
#   in the character's space, b now is     turn_b × rest_b
#   and its parent is                      turn_a × rest_p
#   so b relative to its parent is         inverse(rest_p) × inverse(turn_a) × turn_b × rest_b
#
# rest_b and rest_p are the bones' rotations at rest, in the character's
# space (engine/anim/pose.bend's rest_rotation). turn_a is the turn of the
# nearest bone above b that the motion drives: a bone the motion does not
# drive keeps its rest rotation relative to its parent, so it is carried
# by that same turn.
#
# The hips also move: the motion gives their distance from rest in leg
# lengths, and the leg here is the height of this skeleton's hip joint
# (the left upper leg's start) over the floor. A longer leg, a larger
# move. It is Godot's motion scale and Unreal's "animation scaled" pelvis,
# measured on the leg instead of the hips' height, so a character with
# short legs does not sink into the floor.
#
# Only bones with a slot get a track. Twist and support bones are computed
# after the clip (engine/anim/helpers.bend); chain bones stay at rest.
#
# Limits now:
# - Both rigs must rest in the T-pose, facing +Z. Nothing fixes a source
#   in an A-pose (Unreal's retarget pose, Godot's "fix silhouette").
# - Turns only: limbs keep the target's lengths, so hands and feet do not
#   reach the same points as on the source. Two hands that meet on the
#   source may miss or cross here; feet may stand wider or closer. IK
#   goals for hands and feet are the fix, not built.
# - The root's rest rotation is taken as none (the importer makes it so).

import Base
import ../core/vec.bend as V
import ../core/quat.bend as Q
import ../core/transform.bend as Tr
import ./skeleton.bend as Sk
import ./pose.bend as P
import ./clip.bend as C
import ./motion.bend as M

def pick_qs(c: Bool, a: List<&2, Q.Q>, b: List<&2, Q.Q>) -> List<&2, Q.Q>:
  match c:
    case True{}:
      a
    case False{}:
      b

def head_or(xs: List<&2, Q.Q>, +last: Q.Q) -> Q.Q:
  match xs:
    case Nil{}:
      last
    case h <> _:
      h

def tail_of(xs: List<&2, Q.Q>) -> List<&2, Q.Q>:
  match xs:
    case Nil{}:
      Nil{}
    case _ <> t:
      t

# The turns of the nearest bone, from bone i up, that the motion drives;
# none when no bone above is driven. `fuel` bounds the climb, as in
# engine/anim/pose.bend: no skeleton is deeper than 64 bones.
def above_go(fuel: Nat, +s: Sk.Skeleton, +m: M.Motion, +i: U32) -> List<&2, Q.Q>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      +b = Sk.at(s, i)
      +own = M.turns_of(m, Sk.slot(b))
      pick_qs(Bool.not(List.is_empty(&2, Q.Q, own)), own, pick_qs(U32.is_eq(i, 0), Nil{}, above_go(f, s, m, Sk.parent(b))))

def above(+s: Sk.Skeleton, +m: M.Motion, +i: U32) -> List<&2, Q.Q>:
  above_go(64n, s, m, i)

# One key per step: the bone's rotation relative to its parent. A list that
# ends early holds its last turn.
def keys_go(n: Nat, +own: List<&2, Q.Q>, +up: List<&2, Q.Q>, +last_own: Q.Q, +last_up: Q.Q, +rest_up: Q.Q, +rest_own: Q.Q, +step: F32, +t: F32) -> List<&2, C.Turn>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +a = head_or(own, last_own)
      +b = head_or(up, last_up)
      C.Turn{t, Q.normalize(Q.mul(Q.mul(Q.conj(rest_up), Q.mul(Q.conj(b), a)), rest_own))} <> keys_go(p, tail_of(own), tail_of(up), a, b, rest_up, rest_own, step, (t + step : F32))

def turns_track(+s: Sk.Skeleton, +m: M.Motion, +n: Nat, +i: U32) -> C.Track:
  +p = Sk.parent_of(s, i)
  C.Turns{i, keys_go(n, M.turns_of(m, Sk.slot(Sk.at(s, i))), above(s, m, p), Q.identity(), Q.identity(), P.rest_rotation(s, p), P.rest_rotation(s, i), M.step(m), 0.0)}

def track_if(driven: Bool, +s: Sk.Skeleton, +m: M.Motion, +n: Nat, +i: U32) -> List<&2, C.Track>:
  match driven:
    case True{}:
      [turns_track(s, m, n, i)]
    case False{}:
      Nil{}

def tracks_go(bs: List<&2, Sk.Bone>, +s: Sk.Skeleton, +m: M.Motion, +n: Nat, +i: U32) -> List<&2, C.Track>:
  match bs:
    case Nil{}:
      Nil{}
    case h <> t:
      List.append(&2, C.Track, track_if(M.drives(m, Sk.slot(h)), s, m, n, i), tracks_go(t, s, m, n, (i + 1 : U32)))

# The height of the hip joint over the floor, at rest: the leg.
def leg(+s: Sk.Skeleton) -> F32:
  V.y(P.head(P.m4_at(P.model(s, P.rest(s)), Sk.find_slot(s, "upper_leg.L"))))

def shifts_go(hs: List<&2, V.V3>, +rest: V.V3, +leg: F32, +step: F32, +t: F32) -> List<&2, C.Shift>:
  match hs:
    case Nil{}:
      Nil{}
    case h <> tl:
      C.Shift{t, V.add(rest, V.scale(h, leg))} <> shifts_go(tl, rest, leg, step, (t + step : F32))

def hips_track(has: Bool, +s: Sk.Skeleton, +m: M.Motion, +i: U32) -> List<&2, C.Track>:
  match has:
    case True{}:
      [C.Shifts{i, shifts_go(M.hips(m), Tr.position(Sk.rest(Sk.at(s, i))), leg(s), M.step(m), 0.0)}]
    case False{}:
      Nil{}

# The motion as a clip for this skeleton.
def bake(+s: Sk.Skeleton, +m: M.Motion) -> C.Clip:
  +hips = Sk.find_slot(s, "hips")
  C.Clip{M.name(m), M.seconds(m), 0.0, M.loops(m), List.append(&2, C.Track, hips_track(U32.is_lt(hips, Sk.count(s)), s, m, hips), tracks_go(Sk.bones(s), s, m, List.length(&2, V.V3, M.hips(m)), 0))}
