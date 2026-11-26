# The World as a script sees it: the scene as it was at the start of the tick, to read and never
# to change. A script reads where another thing is, or finds things by name, by tag, by the script
# they carry or near a place (indirect references, as Unity's GameObject.Find and FindWithTag and
# Godot's groups); it changes another thing only by sending it a message
# (engine/script/message.bend).
#
# Every script of a tick reads the same World, so the order the scripts run in never changes what
# they see (Gregory's "one-frame-off" problem does not arise), and they may run in parallel.
#
# A reference is a thing's id (engine/scene/id.bend). A thing that is gone, or an id from nowhere,
# is not found: exists is False, and the functions that give a value give the fallback.
#
# The World is indexed once per tick (of), so finding is a lookup, not a walk over every thing:
#   things    each thing by its id
#   names, tags, scripts   the ids of the things with a name, a tag, a script (each id put at the
#             front, so making the index never walks a list; read back in the scene's order)
#   cells     the ids and positions of the things in each cell of the ground: the World's own cells
#             (engine/scene/place.bend, 1024 m a side), the same cells a server uses to send each
#             player what is near it
# near(w, p, r) looks in the cells within r of p (one to four, for r up to a cell) and keeps the
# things within r.
#
# Limits now:
# - The index is made again every tick, from every thing (n log n); a scene that keeps it up to
#   date as things move would make it once.
# - near() finds by a thing's position on the ground (X and Z); height is not in the cells, so a
#   thing far above or below is found when it is near on the ground, and then measured in 3D.

import Base
import ../core/vec.bend as V
import ../core/transform.bend as Tr
import ../scene/scene.bend as S
import ../scene/id.bend as Id
import ../scene/place.bend as Pl
import ./attach.bend as At

# A thing in a cell: its id and its position.
type Spot is Data:
  Spot{id: Id.Id, at: V.V3}

type Index is Data:
  Index{things: Map<&2, S.Thing>, names: Map<&2, List<&2, Id.Id>>, tags: Map<&2, List<&2, Id.Id>>, scripts: Map<&2, List<&2, Id.Id>>, cells: Map<&2, List<&2, Spot>>}

type World is Data:
  World{scene: S.Scene, index: Index}

# ---------- The index ----------

def Wd.key(+i: Id.Id) -> String:
  U32.show(Id.index(i)) ++ "." ++ U32.show(Id.generation(i))

def Wd.cell_key(+cx: U32, +cz: U32) -> String:
  U32.show(cx) ++ ":" ++ U32.show(cz)

def Wd.cell_of(+v: V.V3) -> String:
  +p = Pl.at(v)
  Wd.cell_key(Pl.cell_x(p), Pl.cell_z(p))

def Wd.pushed_id(r: Map<&2, List<&2, Id.Id>> & List<&2, Id.Id>, +key: String, +i: Id.Id) -> Map<&2, List<&2, Id.Id>>:
  (m, xs) = r
  Map.set(&2, List<&2, Id.Id>, m, key, i <> xs)

def Wd.push_id(m: Map<&2, List<&2, Id.Id>>, +key: String, +i: Id.Id) -> Map<&2, List<&2, Id.Id>>:
  Wd.pushed_id(Map.get(List<&2, Id.Id>, [], m, key), key, i)

def Wd.push_all(gs: List<&2, String>, m: Map<&2, List<&2, Id.Id>>, +i: Id.Id) -> Map<&2, List<&2, Id.Id>>:
  match gs:
    case Nil{}:
      m
    case Con{+h, t}:
      Wd.push_all(t, Wd.push_id(m, h, i), i)

def Wd.script_names(as: List<&2, At.Attached>) -> List<&2, String>:
  match as:
    case Nil{}:
      []
    case Con{+h, t}:
      At.script(h) <> Wd.script_names(t)

def Wd.pushed_spot(r: Map<&2, List<&2, Spot>> & List<&2, Spot>, +key: String, +s: Spot) -> Map<&2, List<&2, Spot>>:
  (m, xs) = r
  Map.set(&2, List<&2, Spot>, m, key, s <> xs)

def Wd.push_spot(m: Map<&2, List<&2, Spot>>, +key: String, +s: Spot) -> Map<&2, List<&2, Spot>>:
  Wd.pushed_spot(Map.get(List<&2, Spot>, [], m, key), key, s)

def Wd.with(+x: Index, +t: S.Thing) -> Index:
  Index{th, ns, gs, ss, cs} = x
  +i = S.id(t)
  +at = Tr.position(S.place(t))
  Index{Map.set(&2, S.Thing, th, Wd.key(i), t), Wd.push_id(ns, S.name(t), i), Wd.push_all(S.tags(t), gs, i), Wd.push_all(Wd.script_names(S.scripts(t)), ss, i), Wd.push_spot(cs, Wd.cell_of(at), Spot{i, at})}

def Wd.indexed(xs: List<&2, S.Thing>, +x: Index) -> Index:
  match xs:
    case Nil{}:
      x
    case Con{+h, t}:
      Wd.indexed(t, Wd.with(x, h))

def Wd.empty() -> Index:
  Index{Map.new(&2, S.Thing), Map.new(&2, List<&2, Id.Id>), Map.new(&2, List<&2, Id.Id>), Map.new(&2, List<&2, Id.Id>), Map.new(&2, List<&2, Spot>)}

# The World of a scene: the scene, indexed.
def of(+s: S.Scene) -> World:
  World{s, Wd.indexed(S.things(s), Wd.empty())}

def scene(+w: World) -> S.Scene:
  World{s, _} = w
  s

def Wd.index(+w: World) -> Index:
  World{_, x} = w
  x

def Ix.things(+x: Index) -> Map<&2, S.Thing>:
  Index{th, _, _, _, _} = x
  th

def Ix.names(+x: Index) -> Map<&2, List<&2, Id.Id>>:
  Index{_, ns, _, _, _} = x
  ns

def Ix.tags(+x: Index) -> Map<&2, List<&2, Id.Id>>:
  Index{_, _, gs, _, _} = x
  gs

def Ix.scripts(+x: Index) -> Map<&2, List<&2, Id.Id>>:
  Index{_, _, _, ss, _} = x
  ss

def Ix.cells(+x: Index) -> Map<&2, List<&2, Spot>>:
  Index{_, _, _, _, cs} = x
  cs

# ---------- Reading a thing by its reference ----------

def Wd.thing_at(r: Map<&2, S.Thing> & S.Thing) -> Maybe<&2, S.Thing>:
  (_, t) = r
  Some{t}

def Wd.found_in(r: Map<&2, S.Thing> & Bool, +key: String) -> Maybe<&2, S.Thing>:
  (+m, has) = r
  match has:
    case True{}:
      Wd.thing_at(Map.get(S.Thing, S.thing("", Tr.identity(), S.Hidden{}), m, key))
    case False{}:
      None{}

def Wd.find(+w: World, +i: Id.Id) -> Maybe<&2, S.Thing>:
  Wd.found_in(Map.has(&2, S.Thing, Ix.things(Wd.index(w)), Wd.key(i)), Wd.key(i))

def Wd.found(m: Maybe<&2, S.Thing>) -> Bool:
  match m:
    case Some{_}:
      True{}
    case None{}:
      False{}

# Is there a thing with this id now?
def exists(+w: World, +i: Id.Id) -> Bool:
  Wd.found(Wd.find(w, i))

def Wd.place_in(m: Maybe<&2, S.Thing>, +fallback: Tr.Transform) -> Tr.Transform:
  match m:
    case Some{t}:
      S.place(t)
    case None{}:
      fallback

# Where the thing with this id is (its Transform), or the fallback when it is not there.
def place_of(+w: World, +i: Id.Id, +fallback: Tr.Transform) -> Tr.Transform:
  Wd.place_in(Wd.find(w, i), fallback)

def Wd.position_in(m: Maybe<&2, S.Thing>, +fallback: V.V3) -> V.V3:
  match m:
    case Some{t}:
      Tr.position(S.place(t))
    case None{}:
      fallback

# Where the thing with this id is (its position), or the fallback when it is not there.
def position_of(+w: World, +i: Id.Id, +fallback: V.V3) -> V.V3:
  Wd.position_in(Wd.find(w, i), fallback)

def Wd.name_in(m: Maybe<&2, S.Thing>) -> String:
  match m:
    case Some{t}:
      S.name(t)
    case None{}:
      ""

# The name of the thing with this id ("" when it is not there).
def name_of(+w: World, +i: Id.Id) -> String:
  Wd.name_in(Wd.find(w, i))

# ---------- Finding things ----------

# A list of the index, in the scene's order (the index puts each id at the front: O(1)).
def Wd.ids_of(r: Map<&2, List<&2, Id.Id>> & List<&2, Id.Id>) -> List<&2, Id.Id>:
  (_, xs) = r
  List.reverse(&2, Id.Id, xs)

# Every thing with this name, in the scene's order.
def named(+w: World, +name: String) -> List<&2, Id.Id>:
  Wd.ids_of(Map.get(List<&2, Id.Id>, [], Ix.names(Wd.index(w)), name))

def Wd.first_of(ids: List<&2, Id.Id>) -> Id.Id:
  match ids:
    case Nil{}:
      Id.none()
    case Con{+h, _}:
      h

# The first thing with this name, or no thing (Id.none(): exists is False for it).
def first_named(+w: World, +name: String) -> Id.Id:
  Wd.first_of(named(w, name))

# Every thing with this tag, in the scene's order.
def tagged(+w: World, +tag: String) -> List<&2, Id.Id>:
  Wd.ids_of(Map.get(List<&2, Id.Id>, [], Ix.tags(Wd.index(w)), tag))

# Every thing that carries this script, in the scene's order.
def with_script(+w: World, +script: String) -> List<&2, Id.Id>:
  Wd.ids_of(Map.get(List<&2, Id.Id>, [], Ix.scripts(Wd.index(w)), script))

def Wd.spots_of(r: Map<&2, List<&2, Spot>> & List<&2, Spot>) -> List<&2, Spot>:
  (_, xs) = r
  xs

def Wd.cell(+cs: Map<&2, List<&2, Spot>>, +cx: U32, +cz: U32) -> List<&2, Spot>:
  Wd.spots_of(Map.get(List<&2, Spot>, [], cs, Wd.cell_key(cx, cz)))

def Wd.keep(c: Bool, +i: Id.Id, rest: List<&2, Id.Id>) -> List<&2, Id.Id>:
  match c:
    case True{}:
      i <> rest
    case False{}:
      rest

def Wd.within(ss: List<&2, Spot>, +p: V.V3, +r: F32) -> List<&2, Id.Id>:
  match ss:
    case Nil{}:
      []
    case Con{Spot{+i, +at}, t}:
      Wd.keep(F32.is_le(V.dist(at, p), r), i, Wd.within(t, p, r))

def Wd.row(n: Nat, +cs: Map<&2, List<&2, Spot>>, +cx: U32, +cz: U32, +p: V.V3, +r: F32) -> List<&2, Id.Id>:
  match n:
    case 0n:
      []
    case 1n+k:
      List.append(&2, Id.Id, Wd.within(Wd.cell(cs, cx, cz), p, r), Wd.row(k, cs, (cx + 1 : U32), cz, p, r))

def Wd.rows(n: Nat, +cs: Map<&2, List<&2, Spot>>, +across: Nat, +cx: U32, +cz: U32, +p: V.V3, +r: F32) -> List<&2, Id.Id>:
  match n:
    case 0n:
      []
    case 1n+k:
      List.append(&2, Id.Id, Wd.row(across, cs, cx, cz, p, r), Wd.rows(k, cs, across, cx, (cz + 1 : U32), p, r))

def Wd.span(+a: U32, +b: U32) -> Nat:
  Nat.add(U32.to_nat((b - a : U32)), 1n)

# Every thing within r meters of p (measured in 3D), found in the cells of the ground around p.
def near(+w: World, +p: V.V3, +r: F32) -> List<&2, Id.Id>:
  +cs = Ix.cells(Wd.index(w))
  +lo = Pl.at(V.V3{(V.x(p) - r : F32), 0.0, (V.z(p) - r : F32)})
  +hi = Pl.at(V.V3{(V.x(p) + r : F32), 0.0, (V.z(p) + r : F32)})
  Wd.rows(Wd.span(Pl.cell_z(lo), Pl.cell_z(hi)), cs, Wd.span(Pl.cell_x(lo), Pl.cell_x(hi)), Pl.cell_x(lo), Pl.cell_z(lo), p, r)
