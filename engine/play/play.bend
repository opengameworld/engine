# Play mode: editing a scene and playing it are two different things.
#
#   Edit     the scene is edited; nothing walks. With motion allowed, characters breathe (their
#            clock runs, as before); with reduce motion on, nothing moves by itself.
#   Playing  a copy of the edited scene runs, one fixed tick at a time (engine/play/tick.bend,
#            engine/play/game.bend), read from the keys through actions (engine/input/).
#   Paused   the copy stands still. Step runs exactly one tick.
#
# Stop drops the copy and gives back the scene as it was edited: what happened in Play, and any
# change made to the scene while playing, is gone. This is Unity's default ("Any changes you make
# in the Editor during Play Mode reset when you exit Play Mode") and Unreal's (changes in Play
# "are not saved by default"). A scene is a Bend value, so the copy is the value itself and
# giving it back is exact: the laws say so. Play, Pause and Step are Unity's toolbar buttons.
# References: docs/references/play-save-undo.md.
#
# The session is what platform/web/ and the editor hold; they ask it what to draw (shown) and
# hand it the keys and the frames.
#
# Limits now:
# - Play runs in the same page as the editor, not in a process of its own (Godot runs the game
#   apart so a crash does not take the editor with it).
# - The contexts are the character's (engine/anim/locomotion.bend's context()): a project cannot
#   bring its own yet.
# - There is no "keep the changes made in Play" (Unreal's Keep Simulation Changes).
# - A click is heard only while playing, not while paused.

import Base
import ../scene/scene.bend as S
import ../input/keyboard.bend as Kb
import ../input/actions.bend as Act
import ../anim/locomotion.bend as Loco
import ./tick.bend as Tick
import ./game.bend as Game
import ../script/rule.bend as R
import ../input/pointer.bend as Ptr
import ../scene/pick.bend as Pick
import ../core/vec.bend as V
import ../core/transform.bend as Tr
import ../scene/camera.bend as Cam

type Mode is Data:
  Mode.Edit{}
  Mode.Playing{}
  Mode.Paused{}

# The scene's rules (engine/script/rule.bend), and what happened since the last tick for them to
# answer: a click, or Play starting.
type Script is Data:
  Script{rules: List<&2, R.Rule>, pending: List<&2, R.Happening>}

def Play.started(+sc: Script) -> Script:
  Script{rs, _} = sc
  Script{rs, [R.Happening.Started{}]}

def Play.cleared(+sc: Script) -> Script:
  Script{rs, _} = sc
  Script{rs, []}

def Play.rules_of(+sc: Script) -> List<&2, R.Rule>:
  Script{rs, _} = sc
  rs

def Play.pending_of(+sc: Script) -> List<&2, R.Happening>:
  Script{_, hs} = sc
  hs

def Play.later(hs: List<&2, R.Happening>, +h: R.Happening) -> List<&2, R.Happening>:
  match hs:
    case Nil{}:
      [h]
    case Con{x, t}:
      x <> Play.later(t, h)

def Play.happened(+sc: Script, +h: R.Happening) -> Script:
  Script{rs, hs} = sc
  Script{rs, Play.later(hs, h)}

type Session is Data:
  Session{mode: Mode, edited: S.Scene, running: S.Scene, keys: Kb.Keyboard, clock: Tick.Clock, contexts: List<&2, Act.Context>, script: Script}

# A scene, being edited.
def edit(+s: S.Scene) -> Session:
  Session{Mode.Edit{}, s, s, Kb.empty(), Tick.zero(), [Loco.context()], Script{[], []}}

def mode(+x: Session) -> Mode:
  Session{m, _, _, _, _, _, _} = x
  m

def edited(+x: Session) -> S.Scene:
  Session{_, e, _, _, _, _, _} = x
  e

# What is drawn: the copy in Play, the edited scene in Edit (they are the same then).
def shown(+x: Session) -> S.Scene:
  Session{_, _, r, _, _, _, _} = x
  r

def keys(+x: Session) -> Kb.Keyboard:
  Session{_, _, _, k, _, _, _} = x
  k

def contexts(+x: Session) -> List<&2, Act.Context>:
  Session{_, _, _, _, _, cs, _} = x
  cs

def Play.is_edit(m: Mode) -> Bool:
  match m:
    case Mode.Edit{}:
      True{}
    case _:
      False{}

def Play.is_playing(m: Mode) -> Bool:
  match m:
    case Mode.Playing{}:
      True{}
    case _:
      False{}

def Play.is_paused(m: Mode) -> Bool:
  match m:
    case Mode.Paused{}:
      True{}
    case _:
      False{}

def is_editing(+x: Session) -> Bool:
  Play.is_edit(mode(x))

def is_playing(+x: Session) -> Bool:
  Play.is_playing(mode(x))

def is_paused(+x: Session) -> Bool:
  Play.is_paused(mode(x))

# ---------- The buttons ----------

# Play: a copy of the edited scene starts, with no key held and the clock at zero.
def start(+x: Session) -> Session:
  Session{_, e, _, _, _, cs, sc} = x
  Session{Mode.Playing{}, e, e, Kb.empty(), Tick.zero(), cs, Play.started(sc)}

# Stop: the copy is dropped; the edited scene is back.
def stop(+x: Session) -> Session:
  Session{_, e, _, _, _, cs, sc} = x
  Session{Mode.Edit{}, e, e, Kb.empty(), Tick.zero(), cs, Play.cleared(sc)}

def Play.paused(m: Mode) -> Mode:
  match m:
    case Mode.Playing{}:
      Mode.Paused{}
    case Mode.Paused{}:
      Mode.Playing{}
    case Mode.Edit{}:
      Mode.Edit{}

# Pause, or go on: only while playing.
def pause(+x: Session) -> Session:
  Session{m, e, r, k, c, cs, sc} = x
  Session{Play.paused(m), e, r, k, Tick.zero(), cs, sc}

def Play.from_edit(+want: U32, +x: Session) -> Session:
  match want:
    case 0:
      x
    case _:
      start(x)

def Play.from_playing(+want: U32, +x: Session) -> Session:
  match want:
    case 0:
      stop(x)
    case 1:
      x
    case _:
      pause(x)

def Play.from_paused(+want: U32, +x: Session) -> Session:
  match want:
    case 0:
      stop(x)
    case 1:
      pause(x)
    case _:
      x

# The session in the mode the editor's toolbar shows (editor/workspace/state.bend's Run):
# 0 editing, 1 playing, 2 paused. Asking for the mode it is already in changes nothing.
def Play.toward(m: Mode, +want: U32, +x: Session) -> Session:
  match m:
    case Mode.Edit{}:
      Play.from_edit(want, x)
    case Mode.Playing{}:
      Play.from_playing(want, x)
    case Mode.Paused{}:
      Play.from_paused(want, x)

def to_mode(+x: Session, +want: U32) -> Session:
  Play.toward(mode(x), want, x)

# ---------- Ticks ----------

type Run is Data:
  Run{scene: S.Scene, keys: Kb.Keyboard}

# `n` ticks: each reads the actions, and what was pressed is seen by the first tick only.
# What happened is answered by the first tick only, as what was pressed is.
def Play.ticks(n: Nat, +r: Run, +cs: List<&2, Act.Context>, +rs: List<&2, R.Rule>, +hs: List<&2, R.Happening>) -> Run:
  match n:
    case 0n:
      r
    case 1n+p:
      Run{s, k} = r
      Play.ticks(p, Run{Game.tick(s, Loco.read(k, cs), rs, hs), Kb.ticked(k)}, cs, rs, [])

# After the ticks of a frame: what happened was answered by the first tick, if one ran; a frame
# that ran no tick keeps it for the next.
def Play.answered(ran: Bool, +sc: Script) -> Script:
  match ran:
    case True{}:
      Play.cleared(sc)
    case False{}:
      sc

def Play.run_of(+r: Run, +x: Session, +c: Tick.Clock, +ran: Bool) -> Session:
  Run{s, k} = r
  Session{m, e, _, _, _, cs, sc} = x
  Session{m, e, s, k, c, cs, Play.answered(ran, sc)}

# Step: exactly one tick, while paused.
def Play.stepped(paused: Bool, +x: Session) -> Session:
  match paused:
    case True{}:
      Session{m, e, r, k, c, cs, sc} = x
      Play.run_of(Play.ticks(1n, Run{r, k}, cs, Play.rules_of(sc), Play.pending_of(sc)), x, c, True{})
    case False{}:
      x

def step(+x: Session) -> Session:
  Play.stepped(is_paused(x), x)

# The editor's clock while editing (what the editor did before Play existed): characters'
# clocks run only when motion is allowed, or when someone pressed Play on a clip.
def Play.edit_frame(+s: S.Scene, +dt: F32, +reduce: Bool) -> S.Scene:
  S.play(S.advance(s, dt, reduce), dt, reduce)

def Play.playing_frame(+x: Session, +dt: F32) -> Session:
  Session{m, e, r, k, c, cs, sc} = x
  +now = Tick.advance(c, dt)
  +n = Tick.steps(now)
  Play.run_of(Play.ticks(U32.to_nat(n), Run{r, k}, cs, Play.rules_of(sc), Play.pending_of(sc)), x, Tick.spent(now, n), U32.is_gt(n, 0))

def Play.edit_of(+x: Session, +dt: F32, +reduce: Bool) -> Session:
  Session{m, e, _, k, c, cs, sc} = x
  +s = Play.edit_frame(e, dt, reduce)
  Session{m, s, s, k, c, cs, sc}

# One browser frame of `dt` seconds.
def Play.frame_in(m: Mode, +x: Session, +dt: F32, +reduce: Bool) -> Session:
  match m:
    case Mode.Edit{}:
      Play.edit_of(x, dt, reduce)
    case Mode.Playing{}:
      Play.playing_frame(x, dt)
    case Mode.Paused{}:
      x

def frame(+x: Session, +dt: F32, +reduce: Bool) -> Session:
  Play.frame_in(mode(x), x, dt, reduce)

# Does a frame change what is drawn? Then the page draws every frame.
def Play.runs_in(m: Mode, +x: Session, +reduce: Bool) -> Bool:
  match m:
    case Mode.Edit{}:
      (S.animated(edited(x)) && (Bool.not(reduce) || S.playing(edited(x))))
    case Mode.Playing{}:
      True{}
    case Mode.Paused{}:
      False{}

def runs(+x: Session, +reduce: Bool) -> Bool:
  Play.runs_in(mode(x), x, reduce)

# ---------- What comes in ----------

def Play.with_keys(+x: Session, +k: Kb.Keyboard) -> Session:
  Session{m, e, r, _, c, cs, sc} = x
  Session{m, e, r, k, c, cs, sc}

# A key, by the browser's KeyboardEvent.code: heard only while playing or paused, never while
# editing (the editor's own shortcuts are Bend-UI's, editor/keys.bend).
def Play.key_in(editing: Bool, +x: Session, +code: String, +down: Bool) -> Session:
  match editing:
    case True{}:
      x
    case False{}:
      Play.with_keys(x, Kb.feed_web(keys(x), code, down))

def key(+x: Session, +code: String, +down: Bool) -> Session:
  Play.key_in(is_editing(x), x, code, down)

# The page lost (False) or got back (True) the focus: losing it lets go of every key.
def focus(+x: Session, +on: Bool) -> Session:
  Play.with_keys(x, Kb.feed(keys(x), Kb.focus(on)))

def Play.with_scene_in(editing: Bool, +m: Mode, +e: S.Scene, +s: S.Scene, +k: Kb.Keyboard, +c: Tick.Clock, +cs: List<&2, Act.Context>, +sc: Script) -> Session:
  match editing:
    case True{}:
      Session{m, s, s, k, c, cs, sc}
    case False{}:
      Session{m, e, s, k, c, cs, sc}

# The scene was changed by hand (the Details, the Shaders screen). While editing, that is the
# edited scene; while playing, only the copy changes, and Stop forgets it.
def with_scene(+x: Session, +s: S.Scene) -> Session:
  Session{m, e, _, k, c, cs, sc} = x
  Play.with_scene_in(is_editing(x), m, e, s, k, c, cs, sc)

# ---------- Rules and clicks ----------

def rules(+x: Session) -> List<&2, R.Rule>:
  Session{_, _, _, _, _, _, sc} = x
  Play.rules_of(sc)

# The scene's rules (a project's, engine/script/rule.bend).
def with_rules(+x: Session, +rs: List<&2, R.Rule>) -> Session:
  Session{m, e, r, k, c, cs, sc} = x
  Session{m, e, r, k, c, cs, Script{rs, Play.pending_of(sc)}}

def Play.add(+x: Session, +h: R.Happening) -> Session:
  Session{m, e, r, k, c, cs, sc} = x
  Session{m, e, r, k, c, cs, Play.happened(sc, h)}

def Play.clicked_on(+hit: Pick.Hit, +x: Session) -> Session:
  match hit:
    case Pick.Hit.At{i, _}:
      Play.add(x, R.Happening.Clicked{i})
    case Pick.Hit.Nothing{}:
      x

def Play.click_in(answer: Bool, +x: Session, +cam: Cam.Cam, +px: F32, +py: F32, +w: F32, +h: F32) -> Session:
  match answer:
    case True{}:
      Play.clicked_on(Pick.at(shown(x), cam, px, py, w, h), x)
    case False{}:
      x

# The main button pressed at (x0, y0) and let go at (px, py) on a canvas w × h, seen by `cam`.
# While playing, a click (engine/input/pointer.bend) on a thing is a Clicked for the next tick's
# rules; a drag, a click on nothing, or any click while editing or paused, is not.
def click(+x: Session, +cam: Cam.Cam, +x0: F32, +y0: F32, +px: F32, +py: F32, +w: F32, +h: F32) -> Session:
  Play.click_in((is_playing(x) && Ptr.is_click(x0, y0, px, py)), x, cam, px, py, w, h)

# ---------- The camera ----------

def Play.feet_or(c: Bool, +h: S.Thing, rest: Maybe<&2, V.V3>) -> Maybe<&2, V.V3>:
  match c:
    case True{}:
      Some{Tr.position(S.place(h))}
    case False{}:
      rest

# Where the first character of the scene stands.
def Play.first_feet(xs: List<&2, S.Thing>) -> Maybe<&2, V.V3>:
  match xs:
    case Nil{}:
      None{}
    case Con{+h, t}:
      Play.feet_or(S.is_rigged(h), h, Play.first_feet(t))

def Play.follow_if(m: Maybe<&2, V.V3>, +cam: Cam.Cam) -> Cam.Cam:
  match m:
    case Some{p}:
      Cam.follow(cam, p)
    case None{}:
      cam

def Play.camera_in(editing: Bool, +x: Session, +cam: Cam.Cam) -> Cam.Cam:
  match editing:
    case True{}:
      cam
    case False{}:
      Play.follow_if(Play.first_feet(S.things(shown(x))), cam)

# The camera this frame: in Edit the person's, as they left it; in Play it follows the first
# character (engine/scene/camera.bend's follow).
def camera(+x: Session, +cam: Cam.Cam) -> Cam.Cam:
  Play.camera_in(is_editing(x), x, cam)
