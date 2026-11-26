# One tick of the scripts attached to things (engine/script/attach.bend, engine/script/me.bend).
#
# For every thing: its Me is made from the thing, the World as the scene was at the start of this
# step (engine/script/world.bend), the messages it received, and whether it was clicked; each of its
# scripts runs in turn, with its own fields, and gets the Me the one before it left (a thing's
# scripts run in the order they were attached); the thing takes the place and tags its last script
# left, and every attachment keeps its new fields. Then the messages sent in this step are
# delivered: each thing's inbox is what was sent to it, for its scripts' next update.
#
# Which code runs for a script's name is the project's (its generated registry's run, passed here
# as a template), as a project's systems are passed to engine/play/game.bend.
#
# Every thing reads the same World and changes only itself, so the result does not depend on the
# order the things are visited in, and each thing's step could run in parallel.
#
# Limits now:
# - The things are visited one after the other; Bend's parallel lets could run them at once.
# - A thing with no script is visited too (its Me is made and dropped).

import Base
import ../scene/scene.bend as S
import ../scene/id.bend as Id
import ./attach.bend as At
import ./value.bend as Val
import ./message.bend as Msg
import ./me.bend as Me
import ./world.bend as Wd
import ./rule.bend as R

def Run.is_click_on(+h: R.Happening, +n: U32) -> Bool:
  match h:
    case R.Happening.Clicked{i}:
      U32.is_eq(i, n)
    case R.Happening.Started{}:
      False{}

def Run.clicked_in(hs: List<&2, R.Happening>, +n: U32) -> Bool:
  match hs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (Run.is_click_on(h, n) || Run.clicked_in(t, n))

# One attachment ran: its fields are the ones it gave back, and the Me goes on to the next script.
def Run.push(r: Me.Me & Val.Value, +a: At.Attached, +done: List<&2, At.Attached>) -> Me.Me & List<&2, At.Attached>:
  (m, v) = r
  (m, List.append(&2, At.Attached, done, [At.with_fields(a, v)]))

def Run.one(~run: @+name: String -> @+first: Bool -> @+me: Me.Me -> @+v: Val.Value -> @+dt: F32 -> Me.Me & Val.Value, +a: At.Attached, acc: Me.Me & List<&2, At.Attached>, +first: Bool, +dt: F32) -> Me.Me & List<&2, At.Attached>:
  (m, done) = acc
  Run.push(run(At.script(a), first, m, At.fields(a), dt), a, done)

def Run.attached(~run: @+name: String -> @+first: Bool -> @+me: Me.Me -> @+v: Val.Value -> @+dt: F32 -> Me.Me & Val.Value, as: List<&2, At.Attached>, acc: Me.Me & List<&2, At.Attached>, +first: Bool, +dt: F32) -> Me.Me & List<&2, At.Attached>:
  match as:
    case Nil{}:
      acc
    case Con{+h, t}:
      Run.attached(~run, t, Run.one(~run, h, acc, first, dt), first, dt)

# The thing after its scripts, and the messages they sent.
def Run.finish(+t: S.Thing, r: Me.Me & List<&2, At.Attached>) -> S.Thing & List<&2, Msg.Mail>:
  (+m, as) = r
  (S.with_scripts(Me.apply(t, m), as), Me.sent(m))

def Run.thing(~run: @+name: String -> @+first: Bool -> @+me: Me.Me -> @+v: Val.Value -> @+dt: F32 -> Me.Me & Val.Value, +w: Wd.World, +hs: List<&2, R.Happening>, +n: U32, +first: Bool, +dt: F32, +t: S.Thing) -> S.Thing & List<&2, Msg.Mail>:
  Run.finish(t, Run.attached(~run, S.scripts(t), (Me.of(t, w, Run.clicked_in(hs, n)), []), first, dt))

def Run.join(a: S.Thing & List<&2, Msg.Mail>, b: List<&2, S.Thing> & List<&2, Msg.Mail>) -> List<&2, S.Thing> & List<&2, Msg.Mail>:
  (x, m1) = a
  (xs, m2) = b
  (x <> xs, List.append(&2, Msg.Mail, m1, m2))

def Run.things(~run: @+name: String -> @+first: Bool -> @+me: Me.Me -> @+v: Val.Value -> @+dt: F32 -> Me.Me & Val.Value, xs: List<&2, S.Thing>, +w: Wd.World, +hs: List<&2, R.Happening>, +n: U32, +first: Bool, +dt: F32) -> List<&2, S.Thing> & List<&2, Msg.Mail>:
  match xs:
    case Nil{}:
      ([], [])
    case Con{+h, t}:
      Run.join(Run.thing(~run, w, hs, n, first, dt, h), Run.things(~run, t, w, hs, (n + 1 : U32), first, dt))

# Every thing's inbox: the messages of this step sent to it.
def Run.deliver(xs: List<&2, S.Thing>, +ms: List<&2, Msg.Mail>) -> List<&2, S.Thing>:
  match xs:
    case Nil{}:
      []
    case Con{+h, t}:
      S.with_inbox(h, Msg.inbox(ms, S.id(h), S.tags(h))) <> Run.deliver(t, ms)

def Run.after(+s: S.Scene, r: List<&2, S.Thing> & List<&2, Msg.Mail>) -> S.Scene:
  (xs, ms) = r
  S.with_things(s, Run.deliver(xs, ms))

def Run.any(xs: List<&2, S.Thing>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (Bool.not(List.is_empty(&2, At.Attached, S.scripts(h))) || Bool.not(List.is_empty(&2, Msg.Mail, S.inbox(h))) || Run.any(t))

def Run.step_if(~run: @+name: String -> @+first: Bool -> @+me: Me.Me -> @+v: Val.Value -> @+dt: F32 -> Me.Me & Val.Value, some: Bool, +s: S.Scene, +hs: List<&2, R.Happening>, +first: Bool, +dt: F32) -> S.Scene:
  match some:
    case True{}:
      Run.after(s, Run.things(~run, S.things(s), Wd.of(s), hs, 0, first, dt))
    case False{}:
      s

# One step of every attached script: `first` on the tick Play starts (each script's start, then its
# update), hs what happened since the last tick (a click), dt the tick's length. A scene where no
# thing has a script or a message waiting is left as it is, without indexing its World.
def step(~run: @+name: String -> @+first: Bool -> @+me: Me.Me -> @+v: Val.Value -> @+dt: F32 -> Me.Me & Val.Value, +s: S.Scene, +hs: List<&2, R.Happening>, +first: Bool, +dt: F32) -> S.Scene:
  Run.step_if(~run, Run.any(S.things(s)), s, hs, first, dt)

# No scripts: a script's name runs nothing (a page with no project, and the tests).
def none(+name: String, +first: Bool, +me: Me.Me, +v: Val.Value, +dt: F32) -> Me.Me & Val.Value:
  (me, v)
