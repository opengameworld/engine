# The camera: how we look at the World. It orbits a target point.
# Y is up. yaw turns around Y, pitch tilts up and down, dist is the distance
# to the target in meters. The browser only reads the mouse and passes the
# numbers here; every move is decided in this file.
#
# In Play the same camera follows the character (follow): its target goes
# where the character's hips are, every tick, and nothing else changes. It
# keeps the angle and the distance the person gave it, never turns or sways
# by itself and never eases after the character: camera sway, shake and a
# camera that moves by itself are what makes people motion sick
# (tothinkabout/Input e Play.html, section 5), so this is the same with
# reduce motion on or off. Drag, right-drag and the wheel still work.
#
# Limits now:
# - The camera does not keep out of walls: there are none yet.
# - It follows the first character of the scene.

import Base
import ../core/vec.bend as V
import ../core/ray.bend as R

type Cam is Data:
  Cam{target: V.V3, yaw: F32, pitch: F32, dist: F32}

# Lens: vertical field of view (60°) and the clip planes, in meters.
def fov() -> F32: 1.0471976
def near() -> F32: 0.05
def far() -> F32: 2000.0

# How the mouse maps to motion.
def orbit_speed() -> F32: 0.005    # radians per pixel
def zoom_speed() -> F32: 0.0015    # per wheel unit
def pitch_limit() -> F32: 1.55     # just short of straight up or down
def dist_min() -> F32: 0.5
def dist_max() -> F32: 500.0

# Where the editor starts: looking at the origin from above, at 45°.
def start() -> Cam:
  Cam{V.V3{0.0, 0.0, 0.0}, 0.7853982, 0.4636476, 14.0}

# The point the camera looks at.
# A person standing at the World's origin, framed from head to feet: the
# camera looks at hip height from 3.4 m away, a little from above.
def close_up() -> Cam:
  Cam{V.V3{0.0, 0.85, 0.0}, 0.7853982, 0.2, 3.4}

def target(cam: Cam) -> V.V3:
  Cam{t, _, _, _} = cam
  t

# The height of a person's hips above their feet (close_up's target).
def hips() -> F32:
  V.y(target(close_up()))

# In Play: the camera looks at a character standing at `feet`.
def follow(+cam: Cam, +feet: V.V3) -> Cam:
  Cam{_, yaw, pitch, dist} = cam
  Cam{V.add(feet, V.V3{0.0, hips(), 0.0}), yaw, pitch, dist}

# The camera's position in the World.
def eye(cam: Cam) -> V.V3:
  Cam{target, +yaw, +pitch, +dist} = cam
  V.add(target, V.V3{(F32.cos(pitch) * F32.sin(yaw) * dist : F32), (F32.sin(pitch) * dist : F32), (F32.cos(pitch) * F32.cos(yaw) * dist : F32)})

# Drag to orbit: the World turns with the mouse.
def orbit(cam: Cam, +dx: F32, +dy: F32) -> Cam:
  Cam{target, yaw, pitch, dist} = cam
  +lim = pitch_limit()
  Cam{target, (yaw - dx * orbit_speed() : F32), F32.clamp((pitch + dy * orbit_speed() : F32), (0.0 - lim : F32), lim), dist}

# Meters the target moves per pixel, so the ground follows the mouse.
def per_pixel(+dist: F32, +height: F32) -> F32:
  (2.0 * dist * F32.tan((fov() / 2.0 : F32)) / F32.max(height, 1.0) : F32)

# Drag to pan: the target slides across the screen plane.
def pan(+cam: Cam, +dx: F32, +dy: F32, +height: F32) -> Cam:
  Cam{+target, +yaw, +pitch, +dist} = cam
  +f = V.norm(V.sub(target, eye(cam)))
  +right = V.norm(V.cross(f, V.V3{0.0, 1.0, 0.0}))
  +up = V.cross(right, f)
  +k = per_pixel(dist, height)
  Cam{V.add(target, V.add(V.scale(right, (0.0 - dx * k : F32)), V.scale(up, (dy * k : F32)))), yaw, pitch, dist}

# Wheel to zoom: closer or farther, never through the target.
def zoom(cam: Cam, +wheel: F32) -> Cam:
  Cam{target, yaw, pitch, dist} = cam
  Cam{target, yaw, pitch, F32.clamp((dist * F32.exp((wheel * zoom_speed() : F32)) : F32), dist_min(), dist_max())}

# The ray from the camera through the pixel (x, y) of a canvas w × h pixels, y pointing down:
# Godot's Camera3D::project_ray_normal for a perspective camera (scene/3d/camera_3d.cpp), a
# point on the near plane's half extents turned by the camera's basis, with no matrix inverse.
# References: docs/references/picking-and-gizmo.md.
def ray(+cam: Cam, +x: F32, +y: F32, +w: F32, +h: F32) -> R.Ray:
  +e = eye(cam)
  +f = V.norm(V.sub(target(cam), e))
  +right = V.norm(V.cross(f, V.V3{0.0, 1.0, 0.0}))
  +up = V.cross(right, f)
  +k = F32.tan((fov() / 2.0 : F32))
  +nx = ((2.0 * x / F32.max(w, 1.0) - 1.0) * k * (w / F32.max(h, 1.0)) : F32)
  +ny = ((1.0 - 2.0 * y / F32.max(h, 1.0)) * k : F32)
  R.Ray{e, V.norm(V.add(f, V.add(V.scale(right, nx), V.scale(up, ny))))}

# World to camera space (a right-handed look-at).
def Cam.pick(c: Bool, +a: Cam, +b: Cam) -> Cam:
  match c:
    case True{}:
      a
    case False{}:
      b

# A drag of the pointer: it pans with the right button or Shift held (`pan`), and orbits
# otherwise. `height` is the canvas's height in pixels.
def drag(+cam: Cam, +dx: F32, +dy: F32, +pan_it: Bool, +height: F32) -> Cam:
  Cam.pick(pan_it, pan(cam, dx, dy, height), orbit(cam, dx, dy))

def view(+cam: Cam) -> V.M4:
  Cam{+target, _, _, _} = cam
  +e = eye(cam)
  +f = V.norm(V.sub(target, e))
  +s = V.norm(V.cross(f, V.V3{0.0, 1.0, 0.0}))
  +u = V.cross(s, f)
  V.M4{
    V.V4{V.x(s), V.x(u), (0.0 - V.x(f) : F32), 0.0},
    V.V4{V.y(s), V.y(u), (0.0 - V.y(f) : F32), 0.0},
    V.V4{V.z(s), V.z(u), (0.0 - V.z(f) : F32), 0.0},
    V.V4{(0.0 - V.dot(s, e) : F32), (0.0 - V.dot(u, e) : F32), V.dot(f, e), 1.0}}

# Camera space to the screen (perspective).
def proj(+aspect: F32) -> V.M4:
  +f = (1.0 / F32.tan((fov() / 2.0 : F32)) : F32)
  +n = near()
  +r = far()
  V.M4{
    V.V4{(f / aspect : F32), 0.0, 0.0, 0.0},
    V.V4{0.0, f, 0.0, 0.0},
    V.V4{0.0, 0.0, ((r + n) / (n - r) : F32), (0.0 - 1.0 : F32)},
    V.V4{0.0, 0.0, (2.0 * r * n / (n - r) : F32), 0.0}}

# Everything the GPU needs from the camera, in one list:
# the view-projection matrix (16, column-major), then the eye (3).
def frame(+cam: Cam, +aspect: F32) -> List<F32>:
  +e = eye(cam)
  List.append(&1, F32, V.flat(V.mul(proj(aspect), view(cam))), [V.x(e), V.y(e), V.z(e)])
