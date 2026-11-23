# References: picking and the move gizmo

Read on 2026-11-23 for `engine/scene/pick.bend`, `engine/core/ray.bend` and
`editor/viewport/handles.bend`. Godot is master `02088c3`
(https://github.com/godotengine/godot/blob/02088c365b7061007afa20a841195e926faf2b78/), Blender
main `4faef78` (https://github.com/blender/blender/blob/4faef788f88388db91b628c125eb659dc3dc3b96/).

## Godot editor

- The viewport moved to `editor/scene/3d/node_3d_editor_viewport.cpp`; constants are in
  `editor/scene/3d/node_3d_editor_constants.h` (L37-46): `GIZMO_ARROW_SIZE 0.35`,
  `GIZMO_ARROW_RADIUS 0.065`, `GIZMO_CIRCLE_SIZE 1.1`, `GIZMO_ARROW_OFFSET = CIRCLE_SIZE + 0.3`,
  `GIZMO_PLANE_SIZE 0.25`, `GIZMO_PLANE_DST 0.2`, `GIZMO_RING_HALF_WIDTH 0.1`.
- Click select (`_select_ray` L744, `_find_items_at_pos` L1129): broad phase over AABBs
  (`gizmo_bvh_ray_query`), narrow phase per candidate (`EditorNode3DGizmo::intersect_ray`: icon,
  segments under 8 px, then mesh triangles in local space); hits ranked by distance.
- The gizmo keeps one size on screen: `gizmo_scale = manipulator_gizmo_size / pixels_per_unit`
  at its depth (`update_transform_gizmo_view` L5022).
- Arrow hit (`_transform_gizmo_select` L1488): a sphere at
  `origin + axis * gs * (ARROW_OFFSET + ARROW_SIZE/2)`, radius `gs * ARROW_SIZE/2 * 1.5`.
- Drag along an axis (`update_transform` L6464, TRANSLATE L6565): the plane holding the axis and
  facing the camera, `n = a x (a x camNormal)` through the center; intersect the ray at mouse
  down and now; `motion = a * dot(a, now - down)`. The result is computed from the transform at
  mouse down (`_edit.original`), not frame by frame.
- `Plane::intersects_ray` (`core/math/plane.cpp` L103): `den = n.dir`, no hit if `den ~ 0`,
  `t = -(n.from - d)/den`, rejects hits behind.

## Blender

- Click select (`source/blender/editors/space_view3d/view3d_select.cc`): GPU ID picking in rects
  of 14, 9, 5 px; or the nearest projected object origin within `75 * pixelsize`.
- Axis constraint (`source/blender/editors/transform/transform_constraints.cc`,
  `axisProjection` L170): closest point between the axis line and the mouse ray; falls back when
  the axis is within 5 degrees of the view.

## Ray primitives (Godot core)

- Slab method, `AABB::find_intersects_ray` (`core/math/aabb.cpp` L121): per axis, if the
  direction is 0 the origin must lie inside the slab; otherwise `t1 = (min - from)/dir`,
  `t2 = (max - from)/dir`, ordered; `tmin = max`, `tmax = min`; miss if `tmin > tmax` or
  `tmax < 0`.
- Moller-Trumbore, `ray_intersects_triangle` (`core/math/geometry_3d.h` L44), epsilon 1e-5.

## Unity and the camera ray

- `Camera.ScreenPointToRay`: pixels, origin at the lower left, a world ray from the near plane.
  https://docs.unity3d.com/ScriptReference/Camera.ScreenPointToRay.html
- Godot `Camera3D::project_local_ray_normal` (`scene/3d/camera_3d.cpp` L415): perspective
  `normalize(((x/w)*2-1) * he.x, ((1-y/h)*2-1) * he.y, -near)` with the near plane's half
  extents, then turned by the camera basis; the origin is the camera's position. Pixel y points
  down.
- Unity Move tool: arrows per axis, squares for planes.
  https://docs.unity3d.com/Manual/PositioningGameObjects.html

## What the engine takes

- `ray(camera, viewport, pixel)`: Godot's half-extents form, no matrix inverse.
- `pick(scene, ray)`: each drawn thing's box in world space by the slab method, the nearest wins
  (Godot's broad phase). Mesh triangles come later.
- Move gizmo: three arrows, hit as Godot's sphere test, kept one size on screen; a drag along an
  axis by Godot's plane rule, from the transform at mouse down.

## Click or drag

- Godot's 3D viewport: `movement_threshold_passed = _edit.original_mouse_pos.distance_to(_edit.mouse_pos) > 8 * EDSCALE`
  (`editor/scene/3d/node_3d_editor_viewport.cpp` L2722). The engine takes these 8 px, the same
  case: a click or a drag on a 3D viewport.
- For comparison: Unity's EventSystem `m_DragThreshold = 10`
  (https://github.com/Unity-Technologies/uGUI/blob/main/com.unity.ugui/Runtime/UGUI/EventSystem/EventSystem.cs
  L75); Blender `drag_threshold_mouse = 3`
  (`source/blender/makesdna/DNA_userdef_types.h` L1274); Godot's Control drag
  `drag_threshold = 10` (`scene/main/viewport.h` L415).
