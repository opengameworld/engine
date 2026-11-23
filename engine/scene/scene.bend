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
# - a name, shown in the editor (the Scene panel);
# - a place (engine/core/transform.bend): where it is, how it is turned, its size;
# - a look: Shown with a shape (a mesh) and a material, Rigged for a
#   character (a figure: skeleton, skin, animation parameters), or Hidden
#   for a thing that is not drawn.
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
# - A thing has no id but its place in the list. Two things may share a
#   name; the editor tells them apart by place, so reordering the list
#   changes which is which.
# - "Thing" is a working name. It shows in the editor, so it can still
#   change (Entity, Actor, Object…).

import Base
import ../render/mesh.bend as M
import ../render/material.bend as Mat
import ../core/transform.bend as Tr
import ../render/shader/node.bend as N
import ../anim/figure.bend as Fig
import ../anim/skeleton.bend as Sk

type Look is Data:
  Hidden{}
  Shown{shape: M.Mesh, material: Mat.Material}
  Rigged{figure: Fig.Figure}

type Thing is Data:
  Thing{name: String, place: Tr.Transform, look: Look}

type Scene is Data:
  Scene{things: List<&2, Thing>}

def things(s: Scene) -> List<&2, Thing>:
  Scene{xs} = s
  xs

def name(t: Thing) -> String:
  Thing{n, _, _} = t
  n

def place(t: Thing) -> Tr.Transform:
  Thing{_, p, _} = t
  p

def look(t: Thing) -> Look:
  Thing{_, _, l} = t
  l

# Is the thing drawn? (main.js asks before it reads the shape and material.)
def is_shown(t: Thing) -> Bool:
  Thing{_, _, l} = t
  match l:
    case Shown{_, _}:
      True{}
    case Hidden{}:
      False{}
    case Rigged{_}:
      False{}

# Is the thing a character? (main.js draws those every frame.)
def is_rigged(t: Thing) -> Bool:
  Thing{_, _, l} = t
  match l:
    case Rigged{_}:
      True{}
    case _:
      False{}

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
      Thing{"", Tr.identity(), Hidden{}}
    case +h <> +t:
      pick_thing(U32.is_eq(i, 0), h, at_go(t, (i - 1 : U32)))

def at(s: Scene, +i: U32) -> Thing:
  Scene{xs} = s
  at_go(xs, i)

# The same list with thing i replaced. Past the end, nothing changes.
def put_go(xs: List<&2, Thing>, +i: U32, +x: Thing) -> List<&2, Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      pick_list(U32.is_eq(i, 0), x <> t, h <> put_go(t, (i - 1 : U32), x))

def put(s: Scene, +i: U32, +x: Thing) -> Scene:
  Scene{xs} = s
  Scene{put_go(xs, i, x)}

def replace_material(t: Thing, m: Mat.Material) -> Thing:
  Thing{n, p, l} = t
  match l:
    case Shown{shape, _}:
      Thing{n, p, Shown{shape, m}}
    case other:
      Thing{n, p, other}

# Replacing the material uses the object's single material slot.
def with_material(+s: Scene, +i: U32, m: Mat.Material) -> Scene:
  put(s, i, replace_material(at(s, i), m))

def count(s: Scene) -> Nat:
  Scene{xs} = s
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

def complete(s: Scene) -> Bool:
  Scene{xs} = s
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
    case h <> t:
      Thing{n, p, l} = h
      Thing{n, p, advance_look(l, dt, reduce)} <> advance_go(t, dt, reduce)

# The scene dt seconds later: every character's animation moves on (unless
# reduce_motion is on). Nothing else in a scene moves by itself yet.
def advance(s: Scene, +dt: F32, +reduce: Bool) -> Scene:
  Scene{xs} = s
  Scene{advance_go(xs, dt, reduce)}

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
    case h <> t:
      Thing{n, p, l} = h
      Thing{n, p, play_look(l, dt, reduce)} <> play_go(t, dt, reduce)

def play(s: Scene, +dt: F32, +reduce: Bool) -> Scene:
  Scene{xs} = s
  Scene{play_go(xs, dt, reduce)}

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
def playing(s: Scene) -> Bool:
  Scene{xs} = s
  any_on(xs)

# The thing with another figure; a thing that is not a character stays.
def with_figure(t: Thing, f: Fig.Figure) -> Thing:
  Thing{n, p, l} = t
  match l:
    case Rigged{_}:
      Thing{n, p, Rigged{f}}
    case Shown{m, mat}:
      Thing{n, p, Shown{m, mat}}
    case Hidden{}:
      Thing{n, p, Hidden{}}

# Is anything in the scene animated? (main.js runs the clock only then.)
def any_rigged(xs: List<&2, Thing>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (is_rigged(h) || any_rigged(t))

def animated(s: Scene) -> Bool:
  Scene{xs} = s
  any_rigged(xs)
