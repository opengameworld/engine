# What a tick of Play costs with many scripts attached: n things, each with the Arena's Walker
# (projects/arena/scripts/Walker.bend), run for k ticks through the whole tick (engine/play/game.bend:
# input, rules, systems, attached scripts, messages, clocks). tools/bench/scripts.ts times it in
# JavaScript (where the editor runs in a browser), and `bend tools/bench/scripts.bend` (main) runs
# it compiled for this machine.
#
# Limits now:
# - Every thing stands at the origin and no script sends a message: it measures the scripts' own
#   step and the World's index, not a crowd talking.

import Base
import ../../engine/scene/scene.bend as S
import ../../engine/core/transform.bend as Tr
import ../../engine/core/vec.bend as V
import ../../engine/anim/locomotion.bend as Loco
import ../../engine/play/game.bend as Game
import ../../engine/script/attach.bend as At
import ../../engine/script/value.bend as Val
import ../../engine/script/world.bend as World
import ../../engine/scene/id.bend as Id
import ../../projects/arena/project_generated.bend as Arena

def walker() -> S.Thing:
  S.with_scripts(S.with_tags(S.thing("Walker", Tr.identity(), S.Hidden{}), ["crowd"]), [At.Attached{"Walker", Val.Value.Rec{["speed", "pings"], [Val.Value.Num{1.0}, Val.Value.Int{0}]}}])

def walkers(n: Nat) -> List<&2, S.Thing>:
  match n:
    case 0n:
      []
    case 1n+k:
      walker() <> walkers(k)

def ticks(k: Nat, +s: S.Scene) -> S.Scene:
  match k:
    case 0n:
      s
    case 1n+j:
      ticks(j, Game.tick_with(~Arena.start, ~Arena.update, ~Arena.run, s, Loco.still(), [], []))

# n things, k ticks: the first thing's X after them (1 m per second of ticks), so the work is done.
def run(+n: Nat, +k: Nat) -> F32:
  V.x(Tr.position(S.place(S.at(ticks(k, S.scene(walkers(n))), 0))))

def main() -> String:
  "1000 things, 60 ticks: x = " ++ F32.show(run(1000n, 60n))

def plain(n: Nat) -> List<&2, S.Thing>:
  match n:
    case 0n:
      []
    case 1n+k:
      S.thing("Thing", Tr.identity(), S.Hidden{}) <> plain(k)

# The same ticks with no script attached: what the tick costs without the scripts' step.
def run_plain(+n: Nat, +k: Nat) -> F32:
  V.x(Tr.position(S.place(S.at(ticks(k, S.scene(plain(n))), 0))))

def Bench.indexes(k: Nat, +s: S.Scene, +n: Nat) -> Nat:
  match k:
    case 0n:
      n
    case 1n+j:
      Bench.indexes(j, s, List.length(&2, Id.Id, World.tagged(World.of(s), "crowd")))

# The World's index alone (engine/script/world.bend's of), made k times over n things.
def run_index(+n: Nat, +k: Nat) -> Nat:
  Bench.indexes(k, S.scene(walkers(n)), 0n)
