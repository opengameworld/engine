# The mannequin's laws: the engine's standard character keeps the rig
# standard (engine/skeleton.bend), bone by bone and vertex by vertex.
# `bend mannequin/PROOF.bend` must print ALL PROOFS CHECK (bun run check
# runs it).
#
# Limits now:
# - These laws look at integers and kinds. That the rest pose is a T-pose
#   is a matter of floats, checked in tests/mannequin.bend.

import Base
import ../engine/skeleton.bend as Sk
import ./gen/skeleton.bend as Man
import ./gen/weights.bend as W
import ../engine/skin.bend as Skin
import ../engine/helpers.bend as H
import ./gen/rules.bend as Rules

# LAW: the mannequin keeps every structural law of the standard.
law mannequin_is_valid:
  {Sk.valid(Man.skeleton()) == True{} : Bool}

# LAW: 1 root, 60 deform, 14 twist, 32 support, 64 chain bones (171 in all).
# The first four are the standard's core (107 bones); the 64 chains are
# this skin's own hair and clothes.
law mannequin_has_its_roles:
  {Sk.role_counts(Man.skeleton()) == [1, 60, 14, 32, 64] : List<&2, U32>}

# LAW: the core is 107 bones, and it stands without the outfit: no core
# bone hangs from a hair or cloth bone.
law mannequin_core_is_whole:
  {[Sk.core_count(Man.skeleton())] == [107] : List<&2, U32>}

law mannequin_core_is_closed:
  {Sk.core_closed(Man.skeleton()) == True{} : Bool}

# LAW: the humanoid core is there, each slot exactly once.
law mannequin_has_one_hips:
  {Sk.slot_count(Man.skeleton(), "hips") == 1 : U32}

law mannequin_has_one_head:
  {Sk.slot_count(Man.skeleton(), "head") == 1 : U32}

law mannequin_has_both_hands:
  {[Sk.slot_count(Man.skeleton(), "hand.L"), Sk.slot_count(Man.skeleton(), "hand.R")] == [1, 1] : List<&2, U32>}

law mannequin_has_both_feet:
  {[Sk.slot_count(Man.skeleton(), "foot.L"), Sk.slot_count(Man.skeleton(), "foot.R")] == [1, 1] : List<&2, U32>}

# LAW: every finger has its three segments, on both hands.
law mannequin_has_every_finger_tip:
  {[Sk.slot_count(Man.skeleton(), "thumb_3.L"), Sk.slot_count(Man.skeleton(), "index_3.L"),
    Sk.slot_count(Man.skeleton(), "middle_3.L"), Sk.slot_count(Man.skeleton(), "ring_3.L"),
    Sk.slot_count(Man.skeleton(), "little_3.L"), Sk.slot_count(Man.skeleton(), "thumb_3.R"),
    Sk.slot_count(Man.skeleton(), "index_3.R"), Sk.slot_count(Man.skeleton(), "middle_3.R"),
    Sk.slot_count(Man.skeleton(), "ring_3.R"), Sk.slot_count(Man.skeleton(), "little_3.R")]
   == [1, 1, 1, 1, 1, 1, 1, 1, 1, 1] : List<&2, U32>}

# LAW: every vertex of the skin: weights sum to 65535, at least one is
# above 0, each weighted joint is a bone, no bone twice in a vertex.
law mannequin_weights_hold:
  {W.all_ok() == True{} : Bool}

# LAW: each of the 46 Twist and Support bones has exactly one rule.
law mannequin_helpers_are_covered:
  {H.helpers_cover(Man.skeleton(), Rules.rules()) == True{} : Bool}
