# Rules: what a thing does when something happens to it, written as data.
#
# A rule names a thing, a trigger and a response: "when Box is clicked, turn it 45°". It is the
# same tuple as Unity's UnityEvent persistent call (target, method name, argument, saved in the
# scene) and Godot's [connection] line in a .tscn (from, signal, to, method, binds), with one
# change: the method is not a name looked up at run time but one of a closed set of Bend
# constructors, so a rule is type-checked, saved in the scene's file, and chosen from a menu in
# the editor. Rules are kept beside the scene's things, as Godot keeps its connections in their
# own section of the scene, and name their thing as Godot names a node. A rule runs in Play only
# (Unity's RuntimeOnly). References: docs/references/scripting-and-events.md.
#
# The triggers:
#   Clicked  the thing was clicked in Play: pressed and let go on it (Unity's
#            OnMouseUpAsButton, Bevy's PointerClick)
#   Started  Play began (Unity's Start, Unreal's BeginPlay); once
#
# The responses (all on the thing the rule names):
#   Move{by}      its place moves by a vector, in meters
#   Turn{angle}   it turns around the World's up (Y), in radians; positive turns +Z toward +X
#   Play{clip}    a character shows its clip `clip` (0 is locomotion) and plays it
#
# Limits now:
# - A rule acts on its own thing only (Unity lets a call target another object).
# - A project's own kind of response is not a rule: it is the project's own step function, run
#   after the rules (engine/script/respond.bend says where), as Bevy systems are.
# - No trigger for entering an area or for time yet.

import Base
import ../core/vec.bend as V

type Trigger is Data:
  Trigger.Clicked{}
  Trigger.Started{}

type Response is Data:
  Response.Move{by: V.V3}
  Response.Turn{angle: F32}
  Response.Play{clip: U32}

type Rule is Data:
  Rule{thing: String, when: Trigger, does: Response}

def thing(+r: Rule) -> String:
  Rule{n, _, _} = r
  n

def when(+r: Rule) -> Trigger:
  Rule{_, w, _} = r
  w

def does(+r: Rule) -> Response:
  Rule{_, _, d} = r
  d

# What happened in one tick, for the rules to answer (made by engine/play/play.bend). Clicked
# holds the place of the thing in the scene's list.
type Happening is Data:
  Happening.Clicked{index: U32}
  Happening.Started{}
