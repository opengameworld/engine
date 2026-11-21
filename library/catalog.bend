# The animation library's catalog: its folders, and the clip each entry
# becomes on a character.
#
# Two folders, in one place:
# - folder 0: Universal Animation Library, by Quaternius (CC0): the 42
#   clips of its free Standard version, as motions (library/quaternius/,
#   read by tools/clips.ts). They play on any character that keeps the rig
#   standard (engine/retarget.bend).
# - folder 1: Engine Originals: the clips made for this engine. Today, the
#   idle and the walk written as code (engine/gait.bend).
#
# Limits now:
# - The whole collection is compiled into the editor's page (about 3.8 MB
#   of Bend for 42 clips): a game should take only the clips it uses, and
#   nothing picks them out yet.
# - The folders are written here by hand: a new collection is a new case
#   in collections() and in clip().
# - The code-made clips have no picture and cannot be mirrored.
# - Engine Originals lists the two code-made clips only; a clip authored
#   in a tool has no way in yet but through a .glb and tools/clips.ts.

import Base
import ../engine/skeleton.bend as Sk
import ../engine/clip.bend as C
import ../engine/gait.bend as G
import ../engine/retarget.bend as R
import ../engine/library.bend as L
import ../engine/motion.bend as M
import ./quaternius/gen/motions.bend as Ual

def captured_go(n: Nat, +i: U32) -> List<&2, L.Entry>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      L.Entry{Ual.name(i), Ual.seconds(i), Ual.category(i), Ual.loops(i), Ual.thumb(i)} <> captured_go(p, (i + 1 : U32))

def captured() -> L.Collection:
  L.Collection{Ual.collection(), Ual.credit(), Ual.license(), captured_go(U32.to_nat(Ual.count()), 0)}

def originals() -> L.Collection:
  L.Collection{"Engine Originals", "made for this engine", "", [L.Entry{"Idle", G.idle_seconds(), "Idle", True{}, Nil{}}, L.Entry{"Walk", G.walk_seconds(), "Locomotion", True{}, Nil{}}]}

# The categories the library filters by, in order.
def categories() -> List<&2, String>:
  Ual.categories()

def collections() -> List<&2, L.Collection>:
  [captured(), originals()]

def original(+s: Sk.Skeleton, +i: U32) -> C.Clip:
  match i:
    case 0:
      G.idle(s)
    case _:
      G.walk(s)

# Entry i of folder `folder`, as a clip for this skeleton; mirrored, when
# asked, if it is a captured motion.
def clip(+s: Sk.Skeleton, +folder: U32, +i: U32, +mirror: Bool) -> C.Clip:
  match folder:
    case 0:
      R.bake(s, M.facing(mirror, Ual.motion(i)))
    case _:
      original(s, i)

# Can entries of this folder be mirrored? (Only captured motions.)
def mirrors(+folder: U32) -> Bool:
  U32.is_eq(folder, 0)
