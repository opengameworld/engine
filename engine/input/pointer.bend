# The pointer: when a press and a release are a click, and not a drag.
#
# A press let go within 8 pixels of where it went down is a click; farther is a drag (the
# editor's camera turns with it). The 8 pixels are Godot's 3D viewport's
# (Node3DEditorViewport: "distance_to(_edit.mouse_pos) > 8 * EDSCALE"); Unity's EventSystem
# takes 10 and Blender 3 for a mouse. Godot measures from where the press began to where the
# pointer is, not the path between, and so does this. References:
# docs/references/picking-and-gizmo.md.
#
# Limits now:
# - Pixels are the canvas's CSS pixels: the 8 do not grow with the screen's scale as Godot's
#   EDSCALE does.

import Base

def slop() -> F32: 8.0

# A press at (x0, y0) let go at (x1, y1): a click?
def is_click(+x0: F32, +y0: F32, +x1: F32, +y1: F32) -> Bool:
  F32.is_le(F32.hypot((x1 - x0 : F32), (y1 - y0 : F32)), slop())
