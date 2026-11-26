# Scene: everything that exists in the World, as one value.
#
# The engine's object model is data-oriented, the ECS way (see the study
# "Objetos no mundo"): a thing is only data, its parts are components, and
# what things do will be pure functions that take the scene and give back
# the next one. Nothing in a thing points at another thing, and nothing is
# changed in place, which is how Bend works and what lets it run independent
# things in parallel.
#
# A thing has:
# - an id (engine/scene/id.bend): which thing it is, given by the scene's book of ids, never the
#   id of another thing, even after it is gone (a script keeps one to refer to it);
# - a name, shown in the editor (the Scene panel);
# - a place (engine/core/transform.bend): where it is, how it is turned, its size;
# - a look: Shown with a shape (a mesh) and a material, Rigged for a
#   character (a figure: skeleton, skin, animation parameters), or Hidden
#   for a thing that is not drawn;
# - its tags: words a script finds things by (Unity's tags, Godot's groups);
# - its scripts (engine/script/attach.bend): each attached script with its own fields, as Unity's
#   MonoBehaviours on a GameObject;
# - its inbox: the messages sent to it in the last tick, for its scripts' next update
#   (engine/script/message.bend).
#
# A project writes a thing with thing(name, place, look) and a scene with scene(things): scene()
# gives every thing its id, in the order of the list. Things added later take theirs from the book
# (add); a thing removed gives its id back (remove).
#
# This file is engine code: the types every scene uses. A real scene, with
# its things, is content and lives in a project (projects/*/scene.bend).
#
# Limits now:
# - The scene is a plain list of things. That is enough for a few things;
#   with many, storing each component in its own column (full ECS) is an
#   internal change that leaves this file's meaning the same.
# - The only behaviors are a character's: advance() moves every figure's
#   animation time, and engine/anim/locomotion.bend's drive() walks them. Other
#   things never move by themselves.
# - No parent and child: every place is measured from the World's origin.
# - Two things may share a name. The editor tells them apart by their place in the list, and a
#   saved scene by their name (engine/scene/save.bend): the first of two with one name.
# - "Thing" is a working name. It shows in the editor, so it can still
#   change (Entity, Actor, Object…).

import Base
import ../render/mesh.bend as M
import ../render/material.bend as Mat
import ../core/transform.bend as Tr
import ../render/shader/node.bend as N
import ../anim/figure.bend as Fig
import ../anim/skeleton.bend as Sk
import ./id.bend as Id
import ../script/attach.bend as At
import ../script/message.bend as Msg

type Look is Data:
  Hidden{}
  Shown{shape: M.Mesh, material: Mat.Material}
  Rigged{figure: Fig.Figure}

type Thing is Data:
  Thing{id: Id.Id, name: String, place: Tr.Transform, look: Look, tags: List<&2, String>, scripts: List<&2, At.Attached>, inbox: List<&2, Msg.Mail>}

type Scene is Data:
  Scene{things: List<&2, Thing>, ids: Id.Ids}

def things(+s: Scene) -> List<&2, Thing>:
  Scene{xs, _} = s
  xs

def ids(+s: Scene) -> Id.Ids:
  Scene{_, k} = s
  k

# The same scene with other things (the same book of ids): for a step that changes things but
# makes none and removes none.
def with_things(+s: Scene, xs: List<&2, Thing>) -> Scene:
  Scene{_, k} = s
  Scene{xs, k}

# A thing as a project writes it: no id yet (scene() and add() give it one), no tags, no scripts,
# nothing received.
def thing(+n: String, +p: Tr.Transform, +l: Look) -> Thing:
  Thing{Id.none(), n, p, l, [], [], []}

def id(+t: Thing) -> Id.Id:
  Thing{i, _, _, _, _, _, _} = t
  i

def name(+t: Thing) -> String:
  Thing{_, n, _, _, _, _, _} = t
  n

def place(+t: Thing) -> Tr.Transform:
  Thing{_, _, p, _, _, _, _} = t
  p

def look(+t: Thing) -> Look:
  Thing{_, _, _, l, _, _, _} = t
  l

def tags(+t: Thing) -> List<&2, String>:
  Thing{_, _, _, _, g, _, _} = t
  g

def with_id(+t: Thing, +i: Id.Id) -> Thing:
  Thing{_, n, p, l, g, a, b} = t
  Thing{i, n, p, l, g, a, b}

def with_name(+t: Thing, +n: String) -> Thing:
  Thing{i, _, p, l, g, a, b} = t
  Thing{i, n, p, l, g, a, b}

def with_place(+t: Thing, +p: Tr.Transform) -> Thing:
  Thing{i, n, _, l, g, a, b} = t
  Thing{i, n, p, l, g, a, b}

def with_look(+t: Thing, +l: Look) -> Thing:
  Thing{i, n, p, _, g, a, b} = t
  Thing{i, n, p, l, g, a, b}

def with_tags(+t: Thing, +g: List<&2, String>) -> Thing:
  Thing{i, n, p, l, _, a, b} = t
  Thing{i, n, p, l, g, a, b}

# The scripts attached to the thing (engine/script/attach.bend), each with its own fields.
def scripts(+t: Thing) -> List<&2, At.Attached>:
  Thing{_, _, _, _, _, a, _} = t
  a

def with_scripts(+t: Thing, +a: List<&2, At.Attached>) -> Thing:
  Thing{i, n, p, l, g, _, b} = t
  Thing{i, n, p, l, g, a, b}

# The messages the thing received for its scripts' next update (engine/script/message.bend).
def inbox(+t: Thing) -> List<&2, Msg.Mail>:
  Thing{_, _, _, _, _, _, b} = t
  b

def with_inbox(+t: Thing, +b: List<&2, Msg.Mail>) -> Thing:
  Thing{i, n, p, l, g, a, _} = t
  Thing{i, n, p, l, g, a, b}

def S.has_tag_in(gs: List<&2, String>, +tag: String) -> Bool:
  match gs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (String.eq(h, tag) || S.has_tag_in(t, tag))

def has_tag(+t: Thing, +tag: String) -> Bool:
  S.has_tag_in(tags(t), tag)

# ---------- Ids ----------

# Every thing of the list with an id: index n, n+1, ... (generation 0).
def S.numbered(xs: List<&2, Thing>, +n: U32) -> List<&2, Thing>:
  match xs:
    case Nil{}:
      []
    case Con{+h, t}:
      with_id(h, Id.Id{n, 0}) <> S.numbered(t, (n + 1 : U32))

# A scene as a project writes it: its things, each given an id in the order of the list.
def scene(+xs: List<&2, Thing>) -> Scene:
  +n = List.length(&2, Thing, xs)
  Scene{S.numbered(xs, 0), Id.first(n)}

# The id the next thing added will have.
def next_id(+s: Scene) -> Id.Id:
  Id.next(ids(s))

# A thing added at the end, with a new id from the book.
def add(+s: Scene, +t: Thing) -> Scene:
  Scene{xs, k} = s
  Scene{List.append(&2, Thing, xs, [with_id(t, Id.next(k))]), Id.given(k)}

def S.keep_unless(gone: Bool, +h: Thing, rest: List<&2, Thing>) -> List<&2, Thing>:
  match gone:
    case True{}:
      rest
    case False{}:
      h <> rest

def S.without_id(xs: List<&2, Thing>, +i: Id.Id) -> List<&2, Thing>:
  match xs:
    case Nil{}:
      []
    case Con{+h, t}:
      S.keep_unless(Id.same(id(h), i), h, S.without_id(t, i))

# The thing with id i removed; its id is given back to the book (a new generation).
def remove(+s: Scene, +i: Id.Id) -> Scene:
  Scene{xs, k} = s
  Scene{S.without_id(xs, i), Id.taken(k, i)}

def S.pick_found(c: Bool, +a: Maybe<&2, Thing>, +b: Maybe<&2, Thing>) -> Maybe<&2, Thing>:
  match c:
    case True{}:
      a
    case False{}:
      b

def S.find_in(xs: List<&2, Thing>, +i: Id.Id) -> Maybe<&2, Thing>:
  match xs:
    case Nil{}:
      None{}
    case Con{+h, t}:
      S.pick_found(Id.same(id(h), i), Some{h}, S.find_in(t, i))

# The thing with id i, or None when there is none (it was removed, or the id is not this scene's).
def find(+s: Scene, +i: Id.Id) -> Maybe<&2, Thing>:
  S.find_in(things(s), i)

def S.pick_u(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def S.index_in(xs: List<&2, Thing>, +i: Id.Id, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{+h, t}:
      S.pick_u(Id.same(id(h), i), n, S.index_in(t, i, (n + 1 : U32)))

# Where the thing with id i is in the list (count(s) when it is not there).
def index_of(+s: Scene, +i: Id.Id) -> U32:
  S.index_in(things(s), i, 0)

def S.look_shown(l: Look) -> Bool:
  match l:
    case Shown{_, _}:
      True{}
    case Hidden{}:
      False{}
    case Rigged{_}:
      False{}

# Is the thing drawn? (main.js asks before it reads the shape and material.)
def is_shown(+t: Thing) -> Bool:
  S.look_shown(look(t))

def S.look_rigged(l: Look) -> Bool:
  match l:
    case Rigged{_}:
      True{}
    case _:
      False{}

# Is the thing a character? (main.js draws those every frame.)
def is_rigged(+t: Thing) -> Bool:
  S.look_rigged(look(t))

def shape(l: Look) -> M.Mesh:
  match l:
    case Shown{s, _}:
      s
    case _:
      M.Mesh{Nil{}, Nil{}}

def material(l: Look) -> Mat.Material:
  match l:
    case Shown{_, m}:
      m
    case _:
      Mat.Material{N.Rgb{0.0, 0.0, 0.0}, Nil{}}

# A character's figure (a thing that is not one gets an empty figure).
def figure(l: Look) -> Fig.Figure:
  match l:
    case Rigged{f}:
      f
    case _:
      Fig.empty()

def pick_thing(c: Bool, a: Thing, b: Thing) -> Thing:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_list(c: Bool, a: List<&2, Thing>, b: List<&2, Thing>) -> List<&2, Thing>:
  match c:
    case True{}:
      a
    case False{}:
      b

# Thing i of a list (the first is 0). Past the end: a hidden thing with no
# name, so a wrong index never breaks the editor.
def at_go(xs: List<&2, Thing>, +i: U32) -> Thing:
  match xs:
    case Nil{}:
      thing("", Tr.identity(), Hidden{})
    case +h <> +t:
      pick_thing(U32.is_eq(i, 0), h, at_go(t, (i - 1 : U32)))

def at(+s: Scene, +i: U32) -> Thing:
  +xs = things(s)
  at_go(xs, i)

# The same list with thing i replaced. Past the end, nothing changes.
def put_go(xs: List<&2, Thing>, +i: U32, +x: Thing) -> List<&2, Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      pick_list(U32.is_eq(i, 0), x <> t, h <> put_go(t, (i - 1 : U32), x))

def put(+s: Scene, +i: U32, +x: Thing) -> Scene:
  +xs = things(s)
  with_things(s, put_go(xs, i, x))

def S.material_look(l: Look, m: Mat.Material) -> Look:
  match l:
    case Shown{shape, _}:
      Shown{shape, m}
    case other:
      other

def replace_material(+t: Thing, m: Mat.Material) -> Thing:
  +l = look(t)
  with_look(t, S.material_look(l, m))

# Replacing the material uses the object's single material slot.
def with_material(+s: Scene, +i: U32, m: Mat.Material) -> Scene:
  put(s, i, replace_material(at(s, i), m))

def count(+s: Scene) -> Nat:
  +xs = things(s)
  List.length(&2, Thing, xs)

# Every drawn thing's material has a value for each of its parameters.
def complete_look(l: Look) -> Bool:
  match l:
    case Shown{_, m}:
      Mat.complete(m)
    case _:
      True{}

def all_complete(xs: List<&2, Thing>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      (complete_look(look(h)) && all_complete(t))

def complete(+s: Scene) -> Bool:
  +xs = things(s)
  all_complete(xs)

# Time
# ====

def advance_look(l: Look, +dt: F32, +reduce: Bool) -> Look:
  match l:
    case Rigged{f}:
      Rigged{Fig.advance(f, dt, reduce)}
    case _:
      l

def advance_go(xs: List<&2, Thing>, +dt: F32, +reduce: Bool) -> List<&2, Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      with_look(h, advance_look(look(h), dt, reduce)) <> advance_go(t, dt, reduce)

# The scene dt seconds later: every character's animation moves on (unless
# reduce_motion is on). Nothing else in a scene moves by itself yet.
def advance(+s: Scene, +dt: F32, +reduce: Bool) -> Scene:
  +xs = things(s)
  with_things(s, advance_go(xs, dt, reduce))

# Playing on request (engine/anim/figure.bend's play): every character whose
# Play was pressed moves on, also with reduce_motion on.
def play_look(l: Look, +dt: F32, +reduce: Bool) -> Look:
  match l:
    case Rigged{f}:
      Rigged{Fig.play(f, dt, reduce)}
    case _:
      l

def play_go(xs: List<&2, Thing>, +dt: F32, +reduce: Bool) -> List<&2, Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      with_look(h, play_look(look(h), dt, reduce)) <> play_go(t, dt, reduce)

def play(+s: Scene, +dt: F32, +reduce: Bool) -> Scene:
  +xs = things(s)
  with_things(s, play_go(xs, dt, reduce))

def on_look(l: Look) -> Bool:
  match l:
    case Rigged{f}:
      Fig.is_on(f)
    case _:
      False{}

def any_on(xs: List<&2, Thing>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (on_look(look(h)) || any_on(t))

# Is any character playing because someone pressed Play?
def playing(+s: Scene) -> Bool:
  +xs = things(s)
  any_on(xs)

def S.figure_look(l: Look, f: Fig.Figure) -> Look:
  match l:
    case Rigged{_}:
      Rigged{f}
    case Shown{m, mat}:
      Shown{m, mat}
    case Hidden{}:
      Hidden{}

# The thing with another figure; a thing that is not a character stays.
def with_figure(+t: Thing, f: Fig.Figure) -> Thing:
  +l = look(t)
  with_look(t, S.figure_look(l, f))

# Is anything in the scene animated? (main.js runs the clock only then.)
def any_rigged(xs: List<&2, Thing>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (is_rigged(h) || any_rigged(t))

def animated(+s: Scene) -> Bool:
  +xs = things(s)
  any_rigged(xs)
