# Numerical tests of engine/script/ and engine/scene/pick.bend through Play: a click on the
# mannequin in the Animation project turns it, as that project's rule says. Turning is float
# math, which the law checker does not compute.
#
# Limits now:
# - One project, one camera, one pixel.

import Base
import ../../engine/core/transform.bend as Tr
import ../../engine/scene/scene.bend as S
import ../../engine/scene/camera.bend as Cam
import ../../engine/scene/pick.bend as Pick
import ../../engine/anim/locomotion.bend as Loco
import ../../engine/play/play.bend as Play
import ../../projects/animation/scenes/Animation.bend as Anim

type Check is Data:
  Check{name: String, ok: Bool}

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.001)

def playing() -> Play.Session:
  Play.start(Play.with_rules(Play.edit(Anim.start()), Anim.rules()))

# A click in the middle of an 800 × 600 canvas, the camera framing the mannequin.
def clicked(+x: Play.Session) -> Play.Session:
  Play.click(x, Cam.close_up(), 400.0, 300.0, 400.0, 300.0, 800.0, 600.0)

def heading(+x: Play.Session) -> F32:
  Loco.heading(S.place(S.at(Play.shown(x), 0)))

def checks() -> List<&2, Check>:
  [Check{"the middle of the screen, framed on the mannequin, picks the mannequin",
     Pick.found(Pick.at(Anim.start(), Cam.close_up(), 400.0, 300.0, 800.0, 600.0))},
   Check{"the corner of the screen picks nothing",
     Bool.not(Pick.found(Pick.at(Anim.start(), Cam.close_up(), 0.0, 0.0, 800.0, 600.0)))},
   Check{"a click on the mannequin in Play turns it a quarter turn at the next tick",
     close(heading(Play.frame(clicked(playing()), 0.016666668, False{})), 1.5707964)},
   Check{"a drag of 20 pixels is not a click: the mannequin does not turn",
     close(heading(Play.frame(Play.click(playing(), Cam.close_up(), 380.0, 300.0, 400.0, 300.0, 800.0, 600.0), 0.016666668, False{})), 0.0)},
   Check{"a click while editing does nothing to the scene",
     close(heading(Play.frame(clicked(Play.with_rules(Play.edit(Anim.start()), Anim.rules())), 0.016666668, False{})), 0.0)},
   Check{"a click is answered once: two ticks later it has turned a quarter turn, not a half",
     close(heading(Play.frame(Play.frame(clicked(playing()), 0.016666668, False{}), 0.016666668, False{})), 1.5707964)},
   Check{"a click in a frame too short for a tick (1/120 s) is answered by the next tick",
     close(heading(Play.frame(Play.frame(clicked(playing()), 0.008333334, False{}), 0.008333334, False{})), 1.5707964)},
   Check{"Stop gives back the mannequin as it was edited, facing ahead",
     close(heading(Play.stop(Play.frame(clicked(playing()), 0.016666668, False{}))), 0.0)}]
