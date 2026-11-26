# What a script attached to a thing gets: its own thing (Me), and nothing else to change. As Unity's
# MonoBehaviour sees its own GameObject through `this`, a script sees its thing's id, name, place
# and tags, the World as it was at the start of the tick (engine/script/world.bend: to read the
# others, never to change them), the messages its thing received, and whether it was clicked.
#
# A script of a project is a file of projects/<name>/scripts/ with:
#
#   type State is Data:                         its fields: each attachment has its own (Unity's
#     State{speed: F32, target: Id.Id}          serialized fields), shown in the Inspector; a field
#                                               is F32, U32, Bool, String, V.V3 or Id.Id
#   def initial() -> State                      the fields of a new attachment
#   def runs() -> Me.Runs                       where it runs in a networked game (see Runs)
#   def start(+me: Me.Me, +s: State) -> Me.Me & State             on the first tick of Play
#   def update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State  every tick, dt seconds long
#
# start and update give back their thing and their fields, changed. The engine writes the thing's
# place and tags back into the scene, keeps the fields for the next tick, and delivers the messages
# sent (post; a project's Mail.send) on the next tick. tools/script/check.ts checks this shape.
#
# Limits now:
# - A script changes its thing's place and tags; its look (its material, its animation) not yet.
# - A script cannot make or remove things yet.

import Base
import ../core/vec.bend as V
import ../core/quat.bend as Q
import ../core/transform.bend as Tr
import ../scene/scene.bend as S
import ../scene/id.bend as Id
import ./world.bend as Wd
import ./message.bend as Msg
import ./value.bend as Val

# Where a script runs in a game served over a network: on the server (what decides: damage, an
# inventory, a quest), on each player's machine (what is only seen: effects, the camera), or on both
# (movement, predicted where the player is and decided on the server). Today every script runs where
# the game runs: this is the mark a server will read.
type Runs is Data:
  Runs.Server{}
  Runs.Client{}
  Runs.Both{}

def server() -> Runs:
  Runs.Server{}

def client() -> Runs:
  Runs.Client{}

def both() -> Runs:
  Runs.Both{}

def runs_name(+r: Runs) -> String:
  match r:
    case Runs.Server{}:
      "Server"
    case Runs.Client{}:
      "Client"
    case Runs.Both{}:
      "Server and client"

type Me is Data:
  Me{id: Id.Id, name: String, place: Tr.Transform, tags: List<&2, String>, world: Wd.World, got: List<&2, Msg.Mail>, sent: List<&2, Msg.Mail>, clicked: Bool}

# The Me of a thing, for one tick: what it received, the World, and whether it was clicked.
def of(+t: S.Thing, +w: Wd.World, +clicked: Bool) -> Me:
  Me{S.id(t), S.name(t), S.place(t), S.tags(t), w, S.inbox(t), [], clicked}

# ---------- What a script reads ----------

def id(+me: Me) -> Id.Id:
  Me{i, _, _, _, _, _, _, _} = me
  i

def name(+me: Me) -> String:
  Me{_, n, _, _, _, _, _, _} = me
  n

def place(+me: Me) -> Tr.Transform:
  Me{_, _, p, _, _, _, _, _} = me
  p

def position(+me: Me) -> V.V3:
  Tr.position(place(me))

def tags(+me: Me) -> List<&2, String>:
  Me{_, _, _, g, _, _, _, _} = me
  g

def world(+me: Me) -> Wd.World:
  Me{_, _, _, _, w, _, _, _} = me
  w

# The messages the thing received since the last tick, as the engine keeps them (a project's
# generated Mail.received gives them typed).
def received(+me: Me) -> List<&2, Msg.Mail>:
  Me{_, _, _, _, _, r, _, _} = me
  r

# The messages sent in this tick so far.
def sent(+me: Me) -> List<&2, Msg.Mail>:
  Me{_, _, _, _, _, _, s, _} = me
  s

# Was the thing clicked (in Play) since the last tick?
def clicked(+me: Me) -> Bool:
  Me{_, _, _, _, _, _, _, c} = me
  c

# No thing: a reference that names nothing (the World finds nothing for it).
def nobody() -> Id.Id:
  Id.none()

# ---------- What a script changes ----------

def with_place(+me: Me, +p: Tr.Transform) -> Me:
  Me{i, n, _, g, w, r, s, c} = me
  Me{i, n, p, g, w, r, s, c}

# Moved by `by` meters (the World's units), in the World's axes.
def moved(+me: Me, +by: V.V3) -> Me:
  with_place(me, Tr.with_position(place(me), V.add(position(me), by)))

# Turned by `angle` radians around the World's up.
def turned(+me: Me, +angle: F32) -> Me:
  with_place(me, Tr.with_rotation(place(me), Q.mul(Q.axis_angle(V.V3{0.0, 1.0, 0.0}, angle), Tr.rotation(place(me)))))

def with_tags(+me: Me, +g: List<&2, String>) -> Me:
  Me{i, n, p, _, w, r, s, c} = me
  Me{i, n, p, g, w, r, s, c}

# A message sent, with its body as a Value (a project's Mail.send and Mail.broadcast write the body
# from its typed Message).
def post(+me: Me, +to: Msg.To, +body: Val.Value) -> Me:
  Me{i, n, p, g, w, r, s, c} = me
  Me{i, n, p, g, w, r, List.append(&2, Msg.Mail, s, [Msg.Mail{i, to, body}]), c}

# The thing after its script's tick: the place and tags the script left.
def apply(+t: S.Thing, +me: Me) -> S.Thing:
  S.with_tags(S.with_place(t, place(me)), tags(me))
