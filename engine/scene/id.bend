# A thing's id: which thing it is, for as long as it exists, as Bevy's Entity is (an index and a
# generation; read in crates/bevy_ecs/src/entity/mod.rs) and Gregory's handles are.
#
# A scene gives ids from its own book (Ids): a new thing takes a free index, or the next one. When
# a thing goes, its index's generation goes up and the index is free again. So an id kept by
# someone (a script's reference) never names the thing that later takes the same index: the
# generations differ, and asking for it finds nothing, as Unity's destroyed object reads as null.
#
# Limits now:
# - An id is a scene's: two scenes give the same ids. A world served by several machines needs
#   the machine in the id too.
# - The book is two lists, so giving and checking an id walks them; a column (an Array) would make
#   it constant time.

import Base

type Id is Data:
  Id{index: U32, generation: U32}

# The book: each index's generation now, and the indexes free to give again.
type Ids is Data:
  Ids{generations: List<&2, U32>, free: List<&2, U32>}

def index(+i: Id) -> U32:
  Id{n, _} = i
  n

def generation(+i: Id) -> U32:
  Id{_, g} = i
  g

# No thing: the id of nothing (an index no book gives: the largest U32).
def none() -> Id:
  Id{4294967295, 0}

def same(+a: Id, +b: Id) -> Bool:
  (U32.is_eq(index(a), index(b)) && U32.is_eq(generation(a), generation(b)))

def is_none(+i: Id) -> Bool:
  same(i, none())

def fresh() -> Ids:
  Ids{[], []}

def Ids.nth_at(gs: List<&2, U32>, n: Nat) -> U32:
  match gs n:
    case Nil{} _:
      0
    case Con{+h, _} 0n:
      h
    case Con{_, t} 1n+p:
      Ids.nth_at(t, p)

def Ids.nth(gs: List<&2, U32>, +i: U32) -> U32:
  Ids.nth_at(gs, U32.to_nat(i))

# The generation of index i now.
def generation_of(+ids: Ids, +i: U32) -> U32:
  Ids{gs, _} = ids
  Ids.nth(gs, i)

def Ids.count(gs: List<&2, U32>) -> U32:
  U32.from_nat(List.length(&2, U32, gs))

def Ids.next_of(fs: List<&2, U32>, +gs: List<&2, U32>) -> Id:
  match fs:
    case Nil{}:
      Id{Ids.count(gs), 0}
    case Con{+i, _}:
      Id{i, Ids.nth(gs, i)}

# The next id the book gives: a free index (at its generation now), or the next index.
def next(+ids: Ids) -> Id:
  Ids{gs, fs} = ids
  Ids.next_of(fs, gs)

def Ids.given_of(fs: List<&2, U32>, +gs: List<&2, U32>) -> Ids:
  match fs:
    case Nil{}:
      Ids{List.append(&2, U32, gs, [0]), []}
    case Con{_, t}:
      Ids{gs, t}

# The book after it gave next(ids).
def given(+ids: Ids) -> Ids:
  Ids{gs, fs} = ids
  Ids.given_of(fs, gs)

def Ids.bumped_at(gs: List<&2, U32>, n: Nat) -> List<&2, U32>:
  match gs n:
    case Nil{} _:
      []
    case Con{+h, t} 0n:
      (h + 1 : U32) <> t
    case Con{+h, t} 1n+p:
      h <> Ids.bumped_at(t, p)

def Ids.bumped(gs: List<&2, U32>, +i: U32) -> List<&2, U32>:
  Ids.bumped_at(gs, U32.to_nat(i))

def Ids.has(xs: List<&2, U32>, +x: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (U32.is_eq(h, x) || Ids.has(t, x))

# Is this id a thing that exists now? (Its index was given, is not free, and is at its generation.)
def alive(+ids: Ids, +i: Id) -> Bool:
  Ids{gs, fs} = ids
  (U32.is_lt(index(i), Ids.count(gs)) && Bool.not(Ids.has(fs, index(i))) && U32.is_eq(Ids.nth(gs, index(i)), generation(i)))

def Ids.taken_if(live: Bool, +ids: Ids, +i: Id) -> Ids:
  match live:
    case True{}:
      Ids{gs, fs} = ids
      Ids{Ids.bumped(gs, index(i)), List.append(&2, U32, fs, [index(i)])}
    case False{}:
      ids

# The book after the thing with id i went: its index's generation goes up and the index is free.
# An id that is not alive changes nothing.
def taken(+ids: Ids, +i: Id) -> Ids:
  Ids.taken_if(alive(ids, i), ids, i)

def Ids.zeros(n: Nat) -> List<&2, U32>:
  match n:
    case 0n:
      []
    case 1n+p:
      0 <> Ids.zeros(p)

# The book after it gave n ids, one after the other: indexes 0 to n - 1, at generation 0.
def first(+n: Nat) -> Ids:
  Ids{Ids.zeros(n), []}
