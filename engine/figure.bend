# Figure: the component that makes a thing a character.
#
# A figure has a skeleton (engine/skeleton.bend), the skin drawn over it
# (the path of a mesh file the browser loads, or "" for bones only), its
# clips (an idle and a walk, engine/gait.bend), and its animation
# parameters: named numbers the editor shows in the Details panel, stored
# like a material's values so the same panel code shows and edits them.
#
#   time   seconds since the animation started (moved by the clock, or by
#          hand when reduce_motion is on)
#   speed  how fast the character moves, in m/s: 0 stands (idle), the
#          walk's own speed (1.3) walks; in between the two blend
#   grip   how closed the hands are: 0 open, 1 a fist (engine/hand.bend)
#   bones  1 draws the skeleton over the skin (x-ray), 0 hides it
#
# A figure also carries the clips added to it from the library
# (library/catalog.bend), which one it shows, and whether it is playing:
#
#   clips  the clips added, each already made for this skeleton
#   shown  0 shows locomotion (the idle and the walk, mixed by speed);
#          n shows the nth clip added, alone, over the whole body;
#          one past the last shows the trial
#   on     the person pressed Play
#   trial  a clip being tried: shown, not added. Picking a clip in the
#          library tries it on the character, as Mixamo previews a clip
#          on yours; Add keeps it.
#
# The pose a figure takes is a pure function of the figure: nothing about
# animation is hidden in state. That is what lets a networked game rebuild
# any character's pose from a few numbers.
#
# Limits now:
# - The skin is a path, read by the browser; the mesh itself never passes
#   through Bend (too many numbers). Its laws are checked when it is made
#   (tools/gltf.ts).
# - Cost: the mannequin (171 bones) takes about 17 ms per frame for
#   pose + skin matrices on the JS target (measured in Bun, warm), at the
#   edge of 60 fps. Most of it is list lookups (each one walks the list);
#   arrays (Bend's Array type) are the planned fix.
# - A shown clip takes the whole body. There is no blend into it or out of it, no mask by
#   body part, no state machine: the clip shows, or locomotion does.
# - A clip is made for the skeleton when it is added; a figure whose
#   skeleton changed would keep clips of the old one.
# - One clock for idle and walk: while walking, the idle's breath runs at
#   the walk's pace too (it barely shows under the walk).

import Base
import ./skeleton.bend as Sk
import ./pose.bend as P
import ./clip.bend as C
import ./gait.bend as G
import ./blend.bend as B
import ./material.bend as Mat
import ./transform.bend as Tr
import ./vec.bend as V
import ./skin.bend as Skin
import ./helpers.bend as H
import ./ik.bend as IK
import ./hand.bend as Hand

type Figure is Data:
  Figure{skeleton: Sk.Skeleton, skin: String, params: List<&2, Mat.Value>, idle: C.Clip, walk: C.Clip, helpers: List<&2, H.Prepared>, rest_model: List<&2, V.M4>, inverse: List<&2, V.M4>, clips: List<&2, C.Clip>, shown: U32, on: Bool, trial: C.Clip}

# No clip: one second of nothing.
def no_clip() -> C.Clip:
  C.Clip{"", 1.0, 0.0, True{}, Nil{}}

def pick_n(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

# A figure for a skeleton, standing at time 0, with the code-made clips
# and the rules of its helper bones (engine/helpers.bend). Its bones show
# when it has no skin.
def make(+s: Sk.Skeleton, +skin: String, rules: List<&2, H.Rule>) -> Figure:
  Figure{s, skin, [Mat.Value{"time", [0.0]}, Mat.Value{"speed", [0.0]}, Mat.Value{"grip", [0.0]}, Mat.Value{"bones", [pick_n(String.eq(skin, ""), 1.0, 0.0)]}], G.idle(s), G.walk(s), H.prepare(s, rules), P.model(s, P.rest(s)), Skin.inverse_rest(s), Nil{}, 0, False{}, no_clip()}

def empty() -> Figure:
  make(Sk.Skeleton{Nil{}}, "", Nil{})

def skeleton(f: Figure) -> Sk.Skeleton:
  Figure{s, _, _, _, _, _, _, _, _, _, _, _} = f
  s

def skin(f: Figure) -> String:
  Figure{_, k, _, _, _, _, _, _, _, _, _, _} = f
  k

def params(f: Figure) -> List<&2, Mat.Value>:
  Figure{_, _, ps, _, _, _, _, _, _, _, _, _} = f
  ps

def idle(f: Figure) -> C.Clip:
  Figure{_, _, _, i, _, _, _, _, _, _, _, _} = f
  i

def walk(f: Figure) -> C.Clip:
  Figure{_, _, _, _, w, _, _, _, _, _, _, _} = f
  w

def helpers(f: Figure) -> List<&2, H.Prepared>:
  Figure{_, _, _, _, _, h, _, _, _, _, _, _} = f
  h

# The skeleton's rest model pose and its inverses, computed once in make().
def rest_model(f: Figure) -> List<&2, V.M4>:
  Figure{_, _, _, _, _, _, r, _, _, _, _, _} = f
  r

def inverse(f: Figure) -> List<&2, V.M4>:
  Figure{_, _, _, _, _, _, _, v, _, _, _, _} = f
  v

def with_params(f: Figure, ps: List<&2, Mat.Value>) -> Figure:
  Figure{s, k, _, i, w, h, r, v, cs, n, o, tr} = f
  Figure{s, k, ps, i, w, h, r, v, cs, n, o, tr}

def clips(f: Figure) -> List<&2, C.Clip>:
  Figure{_, _, _, _, _, _, _, _, cs, _, _, _} = f
  cs

def shown(f: Figure) -> U32:
  Figure{_, _, _, _, _, _, _, _, _, n, _, _} = f
  n

def is_on(f: Figure) -> Bool:
  Figure{_, _, _, _, _, _, _, _, _, _, o, _} = f
  o

def pick_f(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def first(xs: List<&2, F32>) -> F32:
  match xs:
    case Nil{}:
      0.0
    case h <> _:
      h

# The value of a named parameter (0 when the figure has none).
def param_go(ps: List<&2, Mat.Value>, +want: String) -> F32:
  match ps:
    case Nil{}:
      0.0
    case h <> t:
      Mat.Value{+n, xs} = h
      pick_f(String.eq(n, want), first(xs), param_go(t, want))

def param(+f: Figure, +want: String) -> F32:
  param_go(params(f), want)

# How much of the walk is in the pose, from 0 (standing) to 1 (walking).
def walk_weight(+f: Figure) -> F32:
  F32.clamp((param(f, "speed") / F32.max(C.speed(walk(f)), 0.001) : F32), 0.0, 1.0)

# How fast the animation clock runs: at the walk's pace when walking (the
# feet keep up with the ground), never under half while the walk shows.
def rate(+f: Figure) -> F32:
  F32.max(walk_weight(f), 0.5)

# The walk's clock is the figure's time, which advance() moves at rate().
def walk_time(+f: Figure) -> F32:
  param(f, "time")

def trial(f: Figure) -> C.Clip:
  Figure{_, _, _, _, _, _, _, _, _, _, _, tr} = f
  tr

# Clip number n of the ones added, counting from 1; past the last, `other`.
def clip_at(cs: List<&2, C.Clip>, +n: U32, other: C.Clip) -> C.Clip:
  match cs:
    case Nil{}:
      other
    case h <> t:
      match n:
        case 0:
          other
        case 1:
          h
        case _:
          clip_at(t, (n - 1 : U32), other)

# The clip that shows when it is not locomotion: an added one, or the trial.
def shown_clip(+f: Figure) -> C.Clip:
  clip_at(clips(f), shown(f), trial(f))

# The body's pose before the hands, the floor and the helpers: locomotion
# (the idle and the walk, mixed by speed), or the shown clip alone.
def body(locomotion: Bool, +f: Figure, +rest: P.Pose) -> P.Pose:
  match locomotion:
    case True{}:
      B.mix(C.sample(idle(f), rest, param(f, "time")), C.sample(walk(f), rest, walk_time(f)), walk_weight(f))
    case False{}:
      C.sample(shown_clip(f), rest, param(f, "time"))

# The pose the figure takes now: the body (locomotion or the shown clip);
# the hands closed by grip; the feet kept on the floor
# (engine/ik.bend); then the helper bones' rules on top. Gregory's
# pipeline: sample, blend, post-process.
def pose(+f: Figure) -> P.Pose:
  +s = skeleton(f)
  +rest = P.rest(s)
  H.apply(helpers(f), IK.ground(s, rest_model(f), Hand.grip(s, body(U32.is_eq(shown(f), 0), f, rest), param(f, "grip"))))

# Should the editor draw the bones? (the "bones" parameter)
def shows_bones(+f: Figure) -> Bool:
  F32.is_gt(param(f, "bones"), 0.5)

# The figure's bones as lines in the World (6 floats per end), standing
# where `place` puts it.
def lines(+f: Figure, +place: Tr.Transform) -> List<&2, F32>:
  P.lines(skeleton(f), pose(f), place)

# The skinning matrices of the figure's pose (engine/skin.bend), 16 floats
# per bone, standing where `place` puts it.
def palette(+f: Figure, +place: Tr.Transform) -> List<&2, F32>:
  Skin.palette(skeleton(f), pose(f), place, inverse(f))

# Time
# ====

def set_first(xs: List<&2, F32>, +x: F32) -> List<&2, F32>:
  match xs:
    case Nil{}:
      [x]
    case _ <> t:
      x <> t

def pick_vs(c: Bool, a: List<&2, Mat.Value>, b: List<&2, Mat.Value>) -> List<&2, Mat.Value>:
  match c:
    case True{}:
      a
    case False{}:
      b

def set_param_go(ps: List<&2, Mat.Value>, +want: String, +x: F32) -> List<&2, Mat.Value>:
  match ps:
    case Nil{}:
      Nil{}
    case h <> +t:
      Mat.Value{+n, +xs} = h
      pick_vs(String.eq(n, want), Mat.Value{n, set_first(xs, x)} <> t, Mat.Value{n, xs} <> set_param_go(t, want, x))

def set_param(+f: Figure, +want: String, +x: F32) -> Figure:
  with_params(f, set_param_go(params(f), want, x))

# The figure with its time moved by `by` seconds, or as it is.
def later(go: Bool, +f: Figure, +by: F32) -> Figure:
  match go:
    case True{}:
      set_param(f, "time", (param(f, "time") + by : F32))
    case False{}:
      f

# The figure dt seconds later. With reduce_motion on, nothing moves by
# itself: time changes only when someone types it.
def advance(+f: Figure, +dt: F32, reduce: Bool) -> Figure:
  match reduce:
    case True{}:
      f
    case False{}:
      later(U32.is_eq(shown(f), 0), f, (F32.clamp(dt, 0.0, 0.1) * rate(f) : F32))

def pick_f32(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

# Playing on request
# ==================
# advance() is the clock moving by itself, and reduce_motion stops it.
# play() is the person pressing Play: the figure they asked for moves in
# place, and nothing else does. Motion asked for is not motion by itself,
# so Play works with reduce_motion on (ACCESSIBILITY.bend); the camera
# still never travels.
#
# With motion allowed, locomotion already runs by itself in advance(), so
# play() adds nothing to it: one frame never moves time twice.
#
# A clip that plays once stops at its end: time holds there and the figure
# is no longer on. Play again starts it over.

def count(f: Figure) -> U32:
  U32.from_nat(List.length(&2, C.Clip, clips(f)))

def shows_locomotion(f: Figure) -> Bool:
  U32.is_eq(shown(f), 0)

# Is the trial showing (and not one of the clips added)?
def shows_trial(+f: Figure) -> Bool:
  U32.is_lt(count(f), shown(f))

# How long what shows lasts: the shown clip, or one walk cycle.
def length(+f: Figure) -> F32:
  pick_f32(shows_locomotion(f), C.seconds(walk(f)), C.seconds(shown_clip(f)))

# Does what shows start again at its end?
def loops(+f: Figure) -> Bool:
  (shows_locomotion(f) || C.loops(shown_clip(f)))

def with_on(f: Figure, +o: Bool) -> Figure:
  Figure{s, k, ps, i, w, h, r, v, cs, n, _, tr} = f
  Figure{s, k, ps, i, w, h, r, v, cs, n, o, tr}

# A clip that loops starts over at its end, so its time stays inside it
# (locomotion's time runs on: the idle and the walk have different lengths).
def around(over: Bool, +t: F32, +length: F32) -> F32:
  match over:
    case True{}:
      (t - length : F32)
    case False{}:
      t

# The figure at time t, stopped if a clip that plays once reached its end.
def arrive(ended: Bool, +f: Figure, +t: F32) -> Figure:
  match ended:
    case True{}:
      with_on(set_param(f, "time", length(f)), False{})
    case False{}:
      set_param(f, "time", around((Bool.not(shows_locomotion(f)) && Bool.not(F32.is_lt(t, length(f)))), t, length(f)))

def played(go: Bool, +f: Figure, +by: F32) -> Figure:
  match go:
    case True{}:
      +t = (param(f, "time") + by : F32)
      arrive((Bool.not(loops(f)) && Bool.not(F32.is_lt(t, length(f)))), f, t)
    case False{}:
      f

# The figure dt seconds later, if it is on.
def play(+f: Figure, +dt: F32, +reduce: Bool) -> Figure:
  +clip = Bool.not(shows_locomotion(f))
  played((is_on(f) && (reduce || clip)), f, (F32.clamp(dt, 0.0, 0.1) * pick_f32(clip, 1.0, rate(f)) : F32))

# Has a clip that plays once reached its end?
def at_end(+f: Figure) -> Bool:
  (Bool.not(loops(f)) && Bool.not(F32.is_lt(param(f, "time"), length(f))))

def restart(over: Bool, +f: Figure) -> Figure:
  match over:
    case True{}:
      set_param(f, "time", 0.0)
    case False{}:
      f

# Play pressed (from the start, if the clip had ended), or Stop.
def set_on(+f: Figure, +o: Bool) -> Figure:
  with_on(restart((o && at_end(f)), f), o)

# Go to a moment of what shows, as a time bar does: never before 0, never
# past the end.
def seek(+f: Figure, +t: F32) -> Figure:
  set_param(f, "time", F32.clamp(t, 0.0, length(f)))

# One frame: a thirtieth of a second, the pace motions are sampled at
# (tools/clips.ts).
def frame() -> F32: 0.033333

# The frame the time is in, and the time of a frame.
def frame_now(+f: Figure) -> U32:
  F32.to_u32(F32.round((param(f, "time") / frame() : F32)))

# One frame ahead, or one back (never before the first).
def step_frame(+f: Figure, ahead: Bool) -> Figure:
  match ahead:
    case True{}:
      seek(f, (param(f, "time") + frame() : F32))
    case False{}:
      seek(f, (param(f, "time") - frame() : F32))

def with_shown(f: Figure, +n: U32) -> Figure:
  Figure{s, k, ps, i, w, h, r, v, cs, _, o, tr} = f
  Figure{s, k, ps, i, w, h, r, v, cs, n, o, tr}

def with_trial(f: Figure, c: C.Clip) -> Figure:
  Figure{s, k, ps, i, w, h, r, v, +cs, _, o, _} = f
  Figure{s, k, ps, i, w, h, r, v, cs, (U32.from_nat(List.length(&2, C.Clip, cs)) + 1 : U32), o, c}

def with_clips(f: Figure, cs: List<&2, C.Clip>, +n: U32) -> Figure:
  Figure{s, k, ps, i, w, h, r, v, _, _, o, tr} = f
  Figure{s, k, ps, i, w, h, r, v, cs, n, o, tr}

# Show clip n (0: locomotion) from its start.
def show(+f: Figure, +n: U32) -> Figure:
  with_shown(set_param(f, "time", 0.0), n)

# Try a clip, already made for this skeleton: it shows from its start, and
# is not added.
def try(+f: Figure, c: C.Clip) -> Figure:
  with_trial(set_param(f, "time", 0.0), c)

# Keep the trial: it becomes the last clip added, and goes on showing where
# it is (the trial shows as one past the last, which is now its own place).
def keep(+f: Figure) -> Figure:
  with_clips(f, List.append(&2, C.Clip, clips(f), [trial(f)]), shown(f))

# Add a clip, already made for this skeleton, and show it from its start.
def add(+f: Figure, c: C.Clip) -> Figure:
  keep(try(f, c))

def without(cs: List<&2, C.Clip>, +n: U32) -> List<&2, C.Clip>:
  match cs:
    case Nil{}:
      Nil{}
    case h <> t:
      match n:
        case 0:
          h <> t
        case 1:
          t
        case _:
          h <> without(t, (n - 1 : U32))

# Take off the clip that shows, if it is one of the added: the figure goes
# back to locomotion.
def remove_shown(+f: Figure) -> Figure:
  with_clips(set_param(f, "time", 0.0), without(clips(f), shown(f)), 0)

def clip_names_go(cs: List<&2, C.Clip>) -> List<&2, String>:
  match cs:
    case Nil{}:
      Nil{}
    case h <> t:
      C.name(h) <> clip_names_go(t)

# The names of the clips added, in order.
def clip_names(f: Figure) -> List<&2, String>:
  clip_names_go(clips(f))

def name_at(cs: List<&2, C.Clip>, +n: U32, +other: String) -> String:
  match cs:
    case Nil{}:
      other
    case h <> t:
      match n:
        case 0:
          other
        case 1:
          C.name(h)
        case _:
          name_at(t, (n - 1 : U32), other)

def pick_text(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# The name of what shows.
def shown_name(+f: Figure) -> String:
  pick_text(shows_locomotion(f), "Locomotion", name_at(clips(f), shown(f), C.name(trial(f))))

def has_named_go(cs: List<&2, C.Clip>, +want: String) -> Bool:
  match cs:
    case Nil{}:
      False{}
    case h <> t:
      (String.eq(C.name(h), want) || has_named_go(t, want))

# Was a clip of this name added?
def has_clip(f: Figure, +want: String) -> Bool:
  has_named_go(clips(f), want)
