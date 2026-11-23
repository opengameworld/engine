# Numerical tests of engine/anim/retarget.bend on the mannequin.
#
# A motion says how far a slot has turned from the T-pose, in the
# character's space. These build small motions by hand and look at where
# the mannequin's joints end up.
#
# Limits now:
# - A few chosen turns, not every one. The captured motions of library/
#   are looked at in the editor, not checked here.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/core/quat.bend as Q
import ../../engine/anim/skeleton.bend as Sk
import ../../engine/anim/pose.bend as P
import ../../engine/anim/clip.bend as C
import ../../engine/anim/motion.bend as M
import ../../engine/anim/retarget.bend as R
import ../../mannequin/gen/skeleton.bend as Man

type Check is Data:
  Check{name: String, ok: Bool}

def near(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.001)

def near3(+a: V.V3, +b: V.V3) -> Bool:
  (near(V.x(a), V.x(b)) && near(V.y(a), V.y(b)) && near(V.z(a), V.z(b)))

def still() -> Q.Q: Q.identity()

# A quarter turn around the character's Z: what points along +X (the left
# arm, in the T-pose) now points up.
def up() -> Q.Q:
  Q.axis_angle(V.V3{0.0, 0.0, 1.0}, 1.5707964)

# One key; `hips` is where the hips are, in leg lengths from rest.
def motion(+hips: V.V3, +tracks: List<&2, M.Track>) -> M.Motion:
  M.Motion{"test", 1.0, 1.0, True{}, [hips], tracks}

def nowhere() -> V.V3: V.V3{0.0, 0.0, 0.0}

# Where the bone of a slot starts when the mannequin plays motion m.
def at(+m: M.Motion, +slot: String) -> V.V3:
  P.head(P.m4_at(P.model(Man.skeleton(), C.sample(R.bake(Man.skeleton(), m), P.rest(Man.skeleton()), 0.0)), Sk.find_slot(Man.skeleton(), slot)))

def rest_at(+slot: String) -> V.V3:
  at(motion(nowhere(), Nil{}), slot)

# The arm raised: the upper arm turned up, nothing else driven.
def raised() -> M.Motion:
  motion(nowhere(), [M.Track{"upper_arm.L", [up()]}])

# The arm raised, with the forearm told to stay as in the T-pose.
def bent() -> M.Motion:
  motion(nowhere(), [M.Track{"upper_arm.L", [up()]}, M.Track{"lower_arm.L", [still()]}])

def upper_arm() -> F32:
  (V.x(rest_at("lower_arm.L")) - V.x(rest_at("upper_arm.L")) : F32)

def forearm() -> F32:
  (V.x(rest_at("hand.L")) - V.x(rest_at("lower_arm.L")) : F32)

def checks() -> List<&2, Check>:
  [Check{"a motion that turns nothing leaves the mannequin in its T-pose",
     (near3(at(motion(nowhere(), [M.Track{"hips", [still()]}, M.Track{"upper_arm.L", [still()]}, M.Track{"foot.R", [still()]}]), "hand.L"), rest_at("hand.L")) && near3(at(motion(nowhere(), [M.Track{"hips", [still()]}, M.Track{"foot.R", [still()]}]), "toes.R"), rest_at("toes.R")))},
   Check{"the upper arm turned a quarter around Z points up: the elbow is over the shoulder",
     near3(at(raised(), "lower_arm.L"), V.add(rest_at("upper_arm.L"), V.V3{0.0, upper_arm(), 0.0}))},
   Check{"a forearm the motion does not drive goes with the upper arm: the wrist is over the elbow",
     (near(V.x(at(raised(), "hand.L")), V.x(at(raised(), "lower_arm.L"))) && F32.is_lt(V.y(at(raised(), "lower_arm.L")), V.y(at(raised(), "hand.L"))))},
   Check{"a forearm told to stay as in the T-pose points along +X from the raised elbow",
     (near(V.x(at(bent(), "hand.L")), (V.x(at(bent(), "lower_arm.L")) + forearm() : F32)) && near(V.y(at(bent(), "hand.L")), V.y(at(bent(), "lower_arm.L"))))},
   Check{"the right arm is not moved by the left arm's turn",
     near3(at(raised(), "hand.R"), rest_at("hand.R"))},
   Check{"hips half a leg down: they drop by half the height of the hip joint",
     near(V.y(at(motion(V.V3{0.0, (0.0 - 0.5 : F32), 0.0}, Nil{}), "hips")), (V.y(rest_at("hips")) - 0.5 * R.leg(Man.skeleton()) : F32))}]
