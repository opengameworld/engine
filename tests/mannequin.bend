# Numerical tests of the mannequin's rest pose (mannequin/gen/skeleton.bend).
#
# The rig standard's reference pose is the T-pose, the one Unity's Humanoid,
# Godot's SkeletonProfileHumanoid and VRM 1.0 ask for: standing on the
# World's origin, facing +Z, left side toward +X, arms straight out along
# X and level with the ground. Clips, the grip and retargeting all start
# from it, so the standard character must be in it.
#
# Limits now:
# - Checks the standard character only; a law for "any skeleton is in a
#   T-pose" needs floats in the law checker.
# - "Level" and "straight" allow 1 cm (the World's unit is the meter). The
#   largest drift measured is 0.9 cm, at the wrists.
# - Fingers and palms are not checked.

import Base
import ../engine/vec.bend as V
import ../engine/skeleton.bend as Sk
import ../engine/pose.bend as P
import ../mannequin/gen/skeleton.bend as Man

type Check is Data:
  Check{name: String, ok: Bool}

def near(+a: F32, +b: F32, +by: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), by)

def cm() -> F32: 0.01
def exact() -> F32: 0.0001

# Where the bone of a slot starts, at rest, in the character's space.
def at(+slot: String) -> V.V3:
  P.head(P.m4_at(P.model(Man.skeleton(), P.rest(Man.skeleton())), Sk.find_slot(Man.skeleton(), slot)))

# b is a's mirror across the plane X = 0.
def mirrored(+a: V.V3, +b: V.V3) -> Bool:
  (near(V.x(a), (0.0 - V.x(b) : F32), exact()) && near(V.y(a), V.y(b), exact()) && near(V.z(a), V.z(b), exact()))

# From a to b nothing changes but X: same height, same depth.
def level(+a: V.V3, +b: V.V3) -> Bool:
  (near(V.y(a), V.y(b), cm()) && near(V.z(a), V.z(b), cm()))

def checks() -> List<&2, Check>:
  [Check{"the root is on the ground, at the origin",
     (near(V.x(at("root")), 0.0, exact()) && near(V.y(at("root")), 0.0, exact()) && near(V.z(at("root")), 0.0, exact()))},
   Check{"the left side is toward +X",
     F32.is_lt(0.0, V.x(at("hand.L")))},
   Check{"the left arm is level from shoulder joint to elbow",
     level(at("upper_arm.L"), at("lower_arm.L"))},
   Check{"the left arm is level from elbow to wrist",
     level(at("lower_arm.L"), at("hand.L"))},
   Check{"the left arm reaches outward: shoulder, elbow, wrist in order along X",
     (F32.is_lt(V.x(at("upper_arm.L")), V.x(at("lower_arm.L"))) && F32.is_lt(V.x(at("lower_arm.L")), V.x(at("hand.L"))))},
   Check{"the right arm mirrors the left",
     (mirrored(at("upper_arm.L"), at("upper_arm.R")) && mirrored(at("lower_arm.L"), at("lower_arm.R")) && mirrored(at("hand.L"), at("hand.R")))},
   Check{"the right leg mirrors the left",
     (mirrored(at("upper_leg.L"), at("upper_leg.R")) && mirrored(at("foot.L"), at("foot.R")) && mirrored(at("toes.L"), at("toes.R")))},
   Check{"each leg goes straight down: the ankle is under the hip joint",
     near(V.x(at("upper_leg.L")), V.x(at("foot.L")), cm())},
   Check{"it faces +Z: the toes are ahead of the ankles",
     F32.is_lt(V.z(at("foot.L")), V.z(at("toes.L")))}]
