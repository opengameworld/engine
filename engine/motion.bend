# Motion: a captured animation, stored once, for any character.
#
# A clip (engine/clip.bend) drives the bones of one skeleton. A motion is
# the same animation before it meets a skeleton: it names slots, not
# bones, and each key says how far the slot has turned from the T-pose,
# measured in the character's own space (X to its left, Y up, Z ahead).
# Because every rig that keeps the standard rests in the T-pose
# (engine/skeleton.bend), "turned this much from the T-pose" means the
# same on all of them. engine/retarget.bend turns a motion into a clip for
# one skeleton.
#
# This is how Godot keeps retargeted animation (rests overwritten to the
# profile's, position tracks only on the root and the hips, the hips'
# scaled by the character's size) and what Unreal's translation
# retargeting recommends for a biped (the pelvis scaled by proportion,
# every other bone turning only).
#
# - seconds  how long it lasts
# - step     the time between two keys; key k is at k × step
# - loop     does it start again at the end (a walk), or stop (a throw)?
# - hips     where the hips are at each key, measured from where they rest,
#            in leg lengths (1 = the height of the hip joint over the
#            floor), so a tall character moves its hips further
# - tracks   for a slot, its turn from the T-pose at each key. A track
#            with one key holds that turn for the whole motion.
#
# mirrored() gives the same motion as seen in a mirror: left and right
# slots trade tracks, and every turn and every place of the hips is
# reflected across the plane between the two sides (X = 0).
#
# Limits now:
# - Keys are evenly spaced (tools/clips.ts samples them so).
# - Only the hips move; every other slot only turns. A motion cannot
#   stretch a limb or slide a shoulder.
# - Captured in place: the hips' travel along the floor is whatever the
#   file has. Root motion (the clip moving the character) is not read.

import Base
import ./vec.bend as V
import ./quat.bend as Q

type Track is Data:
  Track{slot: String, turns: List<&2, Q.Q>}

type Motion is Data:
  Motion{name: String, seconds: F32, step: F32, loop: Bool, hips: List<&2, V.V3>, tracks: List<&2, Track>}

def name(m: Motion) -> String:
  Motion{n, _, _, _, _, _} = m
  n

def seconds(m: Motion) -> F32:
  Motion{_, s, _, _, _, _} = m
  s

def step(m: Motion) -> F32:
  Motion{_, _, d, _, _, _} = m
  d

def loops(m: Motion) -> Bool:
  Motion{_, _, _, l, _, _} = m
  l

def hips(m: Motion) -> List<&2, V.V3>:
  Motion{_, _, _, _, h, _} = m
  h

def tracks(m: Motion) -> List<&2, Track>:
  Motion{_, _, _, _, _, ts} = m
  ts

def slot(t: Track) -> String:
  Track{s, _} = t
  s

def turns(t: Track) -> List<&2, Q.Q>:
  Track{_, qs} = t
  qs

def pick_turns(c: Bool, a: List<&2, Q.Q>, b: List<&2, Q.Q>) -> List<&2, Q.Q>:
  match c:
    case True{}:
      a
    case False{}:
      b

# The turns of a slot, or none when the motion does not drive it.
def turns_of_go(ts: List<&2, Track>, +want: String) -> List<&2, Q.Q>:
  match ts:
    case Nil{}:
      Nil{}
    case h <> t:
      Track{+s, +qs} = h
      pick_turns(String.eq(s, want), qs, turns_of_go(t, want))

def turns_of(m: Motion, +want: String) -> List<&2, Q.Q>:
  turns_of_go(tracks(m), want)

def drives(+m: Motion, +want: String) -> Bool:
  Bool.not(List.is_empty(&2, Q.Q, turns_of(m, want)))

# Mirror
# ======

# A turn reflected across the plane X = 0: (x, y, z, w) becomes (x, −y, −z, w).
def mirror_q(q: Q.Q) -> Q.Q:
  Q.Q{x, y, z, w} = q
  Q.Q{x, (0.0 - y : F32), (0.0 - z : F32), w}

def mirror_qs(qs: List<&2, Q.Q>) -> List<&2, Q.Q>:
  match qs:
    case Nil{}:
      Nil{}
    case h <> t:
      mirror_q(h) <> mirror_qs(t)

def mirror_v(v: V.V3) -> V.V3:
  V.V3{x, y, z} = v
  V.V3{(0.0 - x : F32), y, z}

def mirror_vs(vs: List<&2, V.V3>) -> List<&2, V.V3>:
  match vs:
    case Nil{}:
      Nil{}
    case h <> t:
      mirror_v(h) <> mirror_vs(t)

def pick_s(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# A slot without its last two letters (".L" or ".R").
def stem(+s: String) -> String:
  String.reverse(String.drop(String.reverse(s), 2n))

# The slot on the other side: "hand.L" is "hand.R"; "hips" is "hips".
def other_side(+s: String) -> String:
  pick_s(String.ends_with(s, ".L"), stem(s) ++ ".R", pick_s(String.ends_with(s, ".R"), stem(s) ++ ".L", s))

def mirror_tracks(ts: List<&2, Track>) -> List<&2, Track>:
  match ts:
    case Nil{}:
      Nil{}
    case h <> t:
      Track{+s, qs} = h
      Track{other_side(s), mirror_qs(qs)} <> mirror_tracks(t)

def mirrored(m: Motion) -> Motion:
  Motion{n, s, d, l, h, ts} = m
  Motion{n ++ " (mirrored)", s, d, l, mirror_vs(h), mirror_tracks(ts)}

# The motion as it is, or mirrored.
def facing(mirror: Bool, m: Motion) -> Motion:
  match mirror:
    case True{}:
      mirrored(m)
    case False{}:
      m
