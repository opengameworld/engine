# A message from a script to other things: to one thing (by its id) or to every thing with a tag.
#
# Messages are delivered on the next tick, all at once: a script sends during its update, and the
# receivers find the message in their inbox the next time they update. This is how Bevy's messages
# work (written in one update, read in the next: crates/bevy_ecs/src/message/messages.rs) and how
# a network carries them; it lets every script of a tick update from the same world, in any order
# (Gregory's one-frame-off problem does not arise). Godot's signals and Unity's UnityEvents call
# the receiver at once instead; a pure update has no "at once", since it has no order.
#
# A message's body is a Value (engine/script/value.bend): the engine carries it without knowing it.
# A project types its messages in projects/<name>/messages.bend, and its generated Mail module
# turns them into Values and back, so Bend checks every message a script sends or reads.
#
# Limits now:
# - A message is delivered once, to the things it names that exist then; one sent to a thing that
#   is gone is dropped (as Bevy drops an unread message).
# - No message to "every thing" or to things near a place yet: one thing, or a tag.

import Base
import ../scene/id.bend as Id
import ./value.bend as Val

type To is Data:
  To.One{id: Id.Id}
  To.Tagged{tag: String}

type Mail is Data:
  Mail{from: Id.Id, to: To, body: Val.Value}

def from(+m: Mail) -> Id.Id:
  Mail{f, _, _} = m
  f

def to(+m: Mail) -> To:
  Mail{_, t, _} = m
  t

def body(+m: Mail) -> Val.Value:
  Mail{_, _, b} = m
  b

def Msg.has(gs: List<&2, String>, +tag: String) -> Bool:
  match gs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (String.eq(h, tag) || Msg.has(t, tag))

def Msg.for_to(+t: To, +id: Id.Id, +tags: List<&2, String>) -> Bool:
  match t:
    case To.One{i}:
      Id.same(i, id)
    case To.Tagged{g}:
      Msg.has(tags, g)

# Is this message for the thing with this id and these tags?
def is_for(+m: Mail, +id: Id.Id, +tags: List<&2, String>) -> Bool:
  Msg.for_to(to(m), id, tags)

def Msg.keep(c: Bool, +m: Mail, rest: List<&2, Mail>) -> List<&2, Mail>:
  match c:
    case True{}:
      m <> rest
    case False{}:
      rest

# The messages of a tick that a thing receives, in the order they were sent.
def inbox(ms: List<&2, Mail>, +id: Id.Id, +tags: List<&2, String>) -> List<&2, Mail>:
  match ms:
    case Nil{}:
      []
    case Con{+h, t}:
      Msg.keep(is_for(h, id, tags), h, inbox(t, id, tags))
