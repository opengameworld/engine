# Tests of scripts attached to things (engine/script/run.bend), on the Arena project's scene
# (projects/arena/): its things, in order, are Ground (no script), Walker A (speed 1), Walker B
# (speed 2), Beacon, Target and Follower. Each test runs real ticks (engine/play/game.bend's
# tick_with) with the project's registry, as Play does.
#
# Limits now:
# - A test is checked at a few chosen values, not for every value as a law is.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/core/transform.bend as Tr
import ../../engine/scene/scene.bend as S
import ../../engine/scene/id.bend as Id
import ../../engine/anim/locomotion.bend as Loco
import ../../engine/play/game.bend as Game
import ../../engine/script/rule.bend as R
import ../../engine/script/attach.bend as At
import ../../engine/script/value.bend as Val
import ../../engine/script/world.bend as World
import ../../projects/arena/project_generated.bend as Arena

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.01)

def happened(first: Bool) -> List<&2, R.Happening>:
  match first:
    case True{}:
      [R.Happening.Started{}]
    case False{}:
      []

# n ticks of Play; the first one answers Play starting.
def ticks(n: Nat, +s: S.Scene, +first: Bool) -> S.Scene:
  match n:
    case 0n:
      s
    case 1n+k:
      ticks(k, Game.tick_with(~Arena.start, ~Arena.update, ~Arena.run, s, Loco.still(), [], happened(first)), False{})

def opened() -> S.Scene:
  Arena.opened("Arena")

def after(+n: Nat) -> S.Scene:
  ticks(n, opened(), True{})

def x_of(+s: S.Scene, +i: U32) -> F32:
  V.x(Tr.position(S.place(S.at(s, i))))

def first_fields(as: List<&2, At.Attached>) -> Val.Value:
  match as:
    case Nil{}:
      Val.Value.Rec{[], []}
    case Con{+h, _}:
      At.fields(h)

# A field of thing i's first script.
def field(+s: S.Scene, +i: U32, +name: String) -> Val.Value:
  Val.at(first_fields(S.scripts(S.at(s, i))), name)

def distance(+s: S.Scene, +a: U32, +b: U32) -> F32:
  V.dist(Tr.position(S.place(S.at(s, a))), Tr.position(S.place(S.at(s, b))))

def pick_n(c: Bool, +a: Nat, +b: Nat) -> Nat:
  match c:
    case True{}:
      a
    case False{}:
      b

# The tick the Beacon first sends on (its left is back to its every then): 60 ticks of 1/60 s add
# up to one second give or take the last digit of an F32, so it is the 60th or the 61st.
def sent_on() -> Nat:
  pick_n(close(Val.num(field(after(60n), 3, "left")), 1.0), 60n, 61n)

def reversed(+s: S.Scene) -> S.Scene:
  S.with_things(s, List.reverse(&2, S.Thing, S.things(s)))

def checks() -> List<&2, Check>:
  +one = after(60n)
  [Check{"a script attached in the scene's code gets its fields, over its initial()", close(Val.num(field(opened(), 2, "speed")), 2.0)},
   Check{"a field the scene does not set keeps the script's initial()", U32.is_eq(Val.int(field(opened(), 1, "pings")), 0)},
   Check{"a reference set by name is the id of that thing", Id.same(Val.ref(field(opened(), 5, "target")), S.id(S.at(opened(), 4)))},
   Check{"the same script on two things: each walks at its own speed (1 m in a second)", close((x_of(one, 1) - x_of(opened(), 1) : F32), 1.0)},
   Check{"...and the other at its own (2 m in a second)", close((x_of(one, 2) - x_of(opened(), 2) : F32), 2.0)},
   Check{"a thing with no script does not move", close(x_of(one, 0), x_of(opened(), 0))},
   Check{"a message sent to a tag is not there on the tick it is sent", U32.is_eq(Val.int(field(after(sent_on()), 1, "pings")), 0)},
   Check{"it is there on the next tick, for every thing with the tag", (U32.is_eq(Val.int(field(after(1n+sent_on()), 1, "pings")), 1) && U32.is_eq(Val.int(field(after(1n+sent_on()), 2, "pings")), 1))},
   Check{"a message is received once", U32.is_eq(Val.int(field(after(2n+sent_on()), 1, "pings")), 1)},
   Check{"a thing without the tag does not receive it", U32.is_eq(Val.int(field(after(1n+sent_on()), 4, "hits")), 0)},
   Check{"a script follows its reference (1.5 m closer in a second)", close(distance(one, 5, 4), (distance(opened(), 5, 4) - 1.5 : F32))},
   Check{"a message to one thing by its reference reaches it", U32.is_gt(Val.int(field(after(330n), 4, "hits")), 0)},
   Check{"a reference to a thing removed is followed nowhere", close(x_of(ticks(60n, S.remove(opened(), S.id(S.at(opened(), 4))), True{}), 4), x_of(opened(), 5))},
   Check{"the order things are in does not change what each does", close(x_of(ticks(60n, reversed(opened()), True{}), 4), x_of(one, 1))},
   Check{"each attachment keeps its fields between ticks", close(Val.num(field(one, 2, "speed")), 2.0)},
   Check{"near finds the things within a distance (1.5 m of Target: Target)", Nat.is_eq(List.length(&2, Id.Id, World.near(World.of(opened()), V.V3{4.0, 0.0, 2.0}, 1.5)), 1n)},
   Check{"near measures every thing it finds (9 m of Target: four things)", Nat.is_eq(List.length(&2, Id.Id, World.near(World.of(opened()), V.V3{4.0, 0.0, 2.0}, 9.0)), 4n)},
   Check{"tagged finds every thing with the tag", Nat.is_eq(List.length(&2, Id.Id, World.tagged(World.of(opened()), "crowd")), 2n)},
   Check{"first_named finds a thing by its name", Id.same(World.first_named(World.of(opened()), "Beacon"), S.id(S.at(opened(), 3)))},
   Check{"a name no thing has finds nothing", Bool.not(World.exists(World.of(opened()), World.first_named(World.of(opened()), "Nobody")))}]
