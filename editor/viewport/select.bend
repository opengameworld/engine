# Selecting by clicking the viewport: a click (engine/input/pointer.bend) on a thing selects it,
# as a click does in Unity's Scene view, Unreal's viewport and Godot's (Node3DEditorViewport's
# _select_ray: the nearest thing under the mouse). The scene's list and the Details then show
# it. What is under the mouse is engine/scene/pick.bend's.
#
# Limits now:
# - A click on nothing keeps the selection (Unity and Godot clear it): the editor has no "nothing
#   selected" yet.
# - Only the nearest thing: a second click on the same place does not reach the one behind it
#   (Blender cycles through them).

import Base
import ../../engine/scene/scene.bend as S
import ../../engine/scene/camera.bend as Cam
import ../../engine/scene/pick.bend as Pick
import ../../engine/input/pointer.bend as Ptr

def Sel.of(+hit: Pick.Hit, +now: U32) -> U32:
  match hit:
    case Pick.Hit.At{i, _}:
      i
    case Pick.Hit.Nothing{}:
      now

def Sel.if_click(c: Bool, +s: S.Scene, +cam: Cam.Cam, +px: F32, +py: F32, +w: F32, +h: F32, +now: U32) -> U32:
  match c:
    case True{}:
      Sel.of(Pick.at(s, cam, px, py, w, h), now)
    case False{}:
      now

# The thing selected after the main button was pressed at (x0, y0) and let go at (px, py).
def picked(+s: S.Scene, +cam: Cam.Cam, +x0: F32, +y0: F32, +px: F32, +py: F32, +w: F32, +h: F32, +now: U32) -> U32:
  Sel.if_click(Ptr.is_click(x0, y0, px, py), s, cam, px, py, w, h, now)
