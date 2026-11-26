# The Arena project's scene: the engine's test of scripts attached to things
# (engine/script/me.bend). Each thing is a tile one meter wide on the ground.
#
#   Walker A, Walker B   the same script (scripts/Walker.bend) with their own speed: each walks
#                        along X at its speed and counts the Pings it receives (tag "crowd")
#   Beacon               sends a Ping to every thing tagged "crowd" every second (scripts/Beacon.bend)
#   Follower             walks to Target, a direct reference set by name (scripts/Follower.bend), and
#                        sends it a Hit when it is there
#   Target               counts the Hits and their power (scripts/Target.bend)
#
# The scripts are attached here, in the scene's code, with the fields that differ from each
# script's initial(); the editor attaches them the same way (Add Component > Script) and saves
# them in saved/Arena.bend.
#
# Limits now:
# - The tiles are flat planes: the Arena tests scripts, not looks.

import Base
import ../../../engine/scene/scene.bend as S
import ../../../engine/core/vec.bend as V
import ../../../engine/core/transform.bend as Tr
import ../../../engine/render/mesh.bend as M
import ../../../engine/script/rule.bend as R
import ../../../engine/script/attach.bend as At
import ../../../engine/script/value.bend as Val
import ../../water/water.bend as Water

def tile() -> S.Look:
  S.Shown{M.plane(1.0, 1), Water.material()}

# Bend has no negative literals: a coordinate below zero is 0 minus it.
def neg(+x: F32) -> F32:
  (0.0 - x : F32)

def at(+x: F32, +z: F32) -> Tr.Transform:
  Tr.at(V.V3{x, 0.0, z})

# A script attached with some fields of its own; the rest are its initial()'s.
def with(+name: String, +ns: List<&2, String>, +vs: List<&2, Val.Value>) -> At.Attached:
  At.Attached{name, Val.Value.Rec{ns, vs}}

def start() -> S.Scene:
  S.scene([
    S.thing("Ground", Tr.identity(), S.Shown{M.plane(20.0, 1), Water.material()}),
    S.with_scripts(S.with_tags(S.thing("Walker A", at(neg(6.0), neg(4.0)), tile()), ["crowd"]), [with("Walker", ["speed"], [Val.Value.Num{1.0}])]),
    S.with_scripts(S.with_tags(S.thing("Walker B", at(neg(6.0), neg(2.0)), tile()), ["crowd"]), [with("Walker", ["speed"], [Val.Value.Num{2.0}])]),
    S.with_scripts(S.thing("Beacon", at(0.0, 4.0), tile()), [with("Beacon", [], [])]),
    S.with_scripts(S.thing("Target", at(4.0, 2.0), tile()), [with("Target", [], [])]),
    S.with_scripts(S.thing("Follower", at(neg(4.0), 2.0), tile()), [with("Follower", ["target"], [Val.Value.Named{"Target"}])])])

# What the scene's things do in Play, besides their scripts (engine/script/rule.bend).
def rules() -> List<&2, R.Rule>:
  []
