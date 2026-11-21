# The reference rig's laws: the engine's rig standard, checked on the
# reference character after tools/gltf.ts imports it.
# `bend refs/sora/PROOF.bend` must print ALL PROOFS CHECK (bun run check runs it when refs/ exists).
#
# Study reference only: refs/ never ships.

import Base
import ../../engine/skeleton.bend as Sk
import ./gen/skeleton.bend as Ref
import ./gen/weights.bend as W
import ../../engine/skin.bend as Skin
import ../../engine/helpers.bend as H
import ./gen/rules.bend as Rules

# LAW: the imported skeleton keeps every structural law of the standard.
law reference_is_valid:
  {Sk.valid(Ref.skeleton()) == True{} : Bool}

# LAW: 1 root, 60 deform, 14 twist, 32 support, 64 chain bones (171 in all).
law reference_has_its_roles:
  {Sk.role_counts(Ref.skeleton()) == [1, 60, 14, 32, 64] : List<&2, U32>}

# LAW: the humanoid core is there, each slot exactly once.
law reference_has_one_hips:
  {Sk.slot_count(Ref.skeleton(), "hips") == 1 : U32}

law reference_has_one_head:
  {Sk.slot_count(Ref.skeleton(), "head") == 1 : U32}

law reference_has_both_hands:
  {[Sk.slot_count(Ref.skeleton(), "hand.L"), Sk.slot_count(Ref.skeleton(), "hand.R")] == [1, 1] : List<&2, U32>}

law reference_has_both_feet:
  {[Sk.slot_count(Ref.skeleton(), "foot.L"), Sk.slot_count(Ref.skeleton(), "foot.R")] == [1, 1] : List<&2, U32>}

# LAW: every finger has its three segments, on both hands.
law reference_has_every_finger_tip:
  {[Sk.slot_count(Ref.skeleton(), "thumb_3.L"), Sk.slot_count(Ref.skeleton(), "index_3.L"),
    Sk.slot_count(Ref.skeleton(), "middle_3.L"), Sk.slot_count(Ref.skeleton(), "ring_3.L"),
    Sk.slot_count(Ref.skeleton(), "little_3.L"), Sk.slot_count(Ref.skeleton(), "thumb_3.R"),
    Sk.slot_count(Ref.skeleton(), "index_3.R"), Sk.slot_count(Ref.skeleton(), "middle_3.R"),
    Sk.slot_count(Ref.skeleton(), "ring_3.R"), Sk.slot_count(Ref.skeleton(), "little_3.R")]
   == [1, 1, 1, 1, 1, 1, 1, 1, 1, 1] : List<&2, U32>}

# LAW: every vertex of the skin: weights sum to 65535, at least one is
# above 0, each weighted joint is a bone, no bone twice in a vertex.
law reference_weights_hold:
  {W.all_ok() == True{} : Bool}

# LAW: each of the 46 Twist and Support bones has exactly one rule.
law reference_helpers_are_covered:
  {H.helpers_cover(Ref.skeleton(), Rules.rules()) == True{} : Bool}
