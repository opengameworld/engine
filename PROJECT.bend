# The projects this engine knows, and the one it opens.
#
# A project is a folder in projects/:
#
#   projects/<folder>/
#     scenes/<Scene>.bend         a scene's code: start() gives its things, rules() what they do
#     scenes/saved/<Scene>.bend   what the editor saved for it (engine/scene/save.bend)
#     scripts/<Script>.bend       a script: start(scene) once when Play starts, update(scene, dt)
#                                 every tick (engine/play/game.bend)
#     shaders/                    its shaders (tools/shaders/catalog.js)
#     project_generated.bend      its registry: every scene and script above, imported
#                                 (tools/project/registry.js writes it; not tracked)
#
# A project has any number of scenes, as a Unity or Godot project does; one is its main scene, the
# one it opens with (Godot's application/run/main_scene), here main(). The engine (engine/) and the
# editor (editor/) are shared by every project.
#
# Why a written list of projects and not "every folder in projects/": a Bend import is fixed, and a
# project nobody imports does not exist for the compiler. The gain: one law checks every project's
# main scene at once, and adding a project makes the compiler point at every match below that
# misses it. Inside a project, its scenes and scripts are found by the registry, so a new scene or
# script needs no line here.
#
# Limits now:
# - Which project opens is this file's open() (or the page's ?project=); there is no project
#   picker in the editor.
# - The build (bun run build) bundles every project listed here, the mannequin's skin with them.
#   Nothing from refs/ may ever be listed: refs/ is for third-party assets kept only for study,
#   which never ship (tools/check.ts fails if anything outside refs/ imports from it).

import Base
import ./engine/scene/scene.bend as S
import ./engine/scene/camera.bend as Cam
import ./engine/script/rule.bend as R
import ./engine/play/play.bend as Play
import ./engine/script/problem.bend as Pb
import ./projects/prefabs.bend as Pre
import ./projects/water/project_generated.bend as WaterP
import ./projects/character/project_generated.bend as CharacterP
import ./projects/mannequin/project_generated.bend as MannequinP
import ./projects/animation/project_generated.bend as AnimationP

type Project is Data:
  Water{}
  Character{}
  Mannequin{}
  Animation{}

# Which project opens. Change this one line.
def open() -> Project: Animation{}

def name(p: Project) -> String:
  match p:
    case Water{}:
      "Water"
    case Character{}:
      "Character"
    case Mannequin{}:
      "Mannequin"
    case Animation{}:
      "Animation"

def folder(p: Project) -> String:
  match p:
    case Water{}:
      "water"
    case Character{}:
      "character"
    case Mannequin{}:
      "mannequin"
    case Animation{}:
      "animation"

# The scene a project opens with (a file of its scenes/).
def main(p: Project) -> String:
  match p:
    case Water{}:
      "Water"
    case Character{}:
      "Character"
    case Mannequin{}:
      "Mannequin"
    case Animation{}:
      "Animation"

def pick_project(c: Bool, a: Project, b: Project) -> Project:
  match c:
    case True{}:
      a
    case False{}:
      b

# A preview link can open a project explicitly. Unknown names use the default.
def preview(+slug: String) -> Project:
  pick_project(String.eq(slug, "water"), Water{},
  pick_project(String.eq(slug, "character"), Character{},
  pick_project(String.eq(slug, "mannequin"), Mannequin{},
  pick_project(String.eq(slug, "animation"), Animation{}, open()))))

# ---------- Scenes (each project's registry) ----------

def scenes(p: Project) -> List<&2, String>:
  match p:
    case Water{}:
      WaterP.scenes()
    case Character{}:
      CharacterP.scenes()
    case Mannequin{}:
      MannequinP.scenes()
    case Animation{}:
      AnimationP.scenes()

def has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (String.eq(h, x) || has(t, x))

def pick_s(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# The scene a link asks for, when the project has it; its main scene otherwise.
def scene_named(+p: Project, +want: String) -> String:
  pick_s(has(scenes(p), want), want, main(p))

# A scene as its code makes it, before what was saved (engine/scene/save.bend compares with it).
def code(+p: Project, +sc: String) -> S.Scene:
  match p:
    case Water{}:
      WaterP.code(sc)
    case Character{}:
      CharacterP.code(sc)
    case Mannequin{}:
      MannequinP.code(sc)
    case Animation{}:
      AnimationP.code(sc)

# A scene as it opens: its code with what the editor saved put back.
def opened(+p: Project, +sc: String) -> S.Scene:
  match p:
    case Water{}:
      WaterP.opened(sc)
    case Character{}:
      CharacterP.opened(sc)
    case Mannequin{}:
      MannequinP.opened(sc)
    case Animation{}:
      AnimationP.opened(sc)

# What a scene's things do in Play (engine/script/rule.bend): the rules the editor saved, or its code's.
def scene_rules(+p: Project, +sc: String) -> List<&2, R.Rule>:
  match p:
    case Water{}:
      WaterP.rules(sc)
    case Character{}:
      CharacterP.rules(sc)
    case Mannequin{}:
      MannequinP.rules(sc)
    case Animation{}:
      AnimationP.rules(sc)

# Did the editor save a scene's rules? Then they are its rules.
def has_saved_rules(+p: Project, +sc: String) -> Bool:
  match p:
    case Water{}:
      WaterP.own_rules(sc)
    case Character{}:
      CharacterP.own_rules(sc)
    case Mannequin{}:
      MannequinP.own_rules(sc)
    case Animation{}:
      AnimationP.own_rules(sc)

# The things made in the editor in a scene, and the things of its code deleted there.
def made(+p: Project, +sc: String) -> List<&2, Pre.Made>:
  match p:
    case Water{}:
      WaterP.made(sc)
    case Character{}:
      CharacterP.made(sc)
    case Mannequin{}:
      MannequinP.made(sc)
    case Animation{}:
      AnimationP.made(sc)

def removed(+p: Project, +sc: String) -> List<&2, String>:
  match p:
    case Water{}:
      WaterP.removed(sc)
    case Character{}:
      CharacterP.removed(sc)
    case Mannequin{}:
      MannequinP.removed(sc)
    case Animation{}:
      AnimationP.removed(sc)

# A project's main scene, as it opens, and its rules (what a published game plays).
def start(+p: Project) -> S.Scene:
  opened(p, main(p))

def rules(+p: Project) -> List<&2, R.Rule>:
  scene_rules(p, main(p))

def scene(+p: Project) -> S.Scene:
  code(p, main(p))

# The scene the editor opens with.
def opening() -> S.Scene:
  start(open())

# ---------- Play, with the project's scripts ----------

# One browser frame of Play, with the project's scripts (engine/play/play.bend's frame_with).
def frame(+p: Project, +x: Play.Session, +dt: F32, +reduce: Bool) -> Play.Session:
  match p:
    case Water{}:
      Play.frame_with(~WaterP.start, ~WaterP.update, x, dt, reduce)
    case Character{}:
      Play.frame_with(~CharacterP.start, ~CharacterP.update, x, dt, reduce)
    case Mannequin{}:
      Play.frame_with(~MannequinP.start, ~MannequinP.update, x, dt, reduce)
    case Animation{}:
      Play.frame_with(~AnimationP.start, ~AnimationP.update, x, dt, reduce)

# Step (one tick while paused), with the project's scripts.
def step(+p: Project, +x: Play.Session) -> Play.Session:
  match p:
    case Water{}:
      Play.step_with(~WaterP.start, ~WaterP.update, x)
    case Character{}:
      Play.step_with(~CharacterP.start, ~CharacterP.update, x)
    case Mannequin{}:
      Play.step_with(~MannequinP.start, ~MannequinP.update, x)
    case Animation{}:
      Play.step_with(~AnimationP.start, ~AnimationP.update, x)

# The project's scripts that do not compile (engine/script/problem.bend): while there is one, Play
# does not start (to_mode below) and the build stops (tools/project/registry.js).
def problems(+p: Project) -> List<&2, Pb.Problem>:
  match p:
    case Water{}:
      WaterP.problems()
    case Character{}:
      CharacterP.problems()
    case Mannequin{}:
      MannequinP.problems()
    case Animation{}:
      AnimationP.problems()

# The toolbar's mode (0 editing, 1 playing, 2 paused), for this project: Play waits while one of its
# scripts does not compile (engine/play/play.bend's to_mode_checked).
def to_mode(+p: Project, +x: Play.Session, +want: U32) -> Play.Session:
  Play.to_mode_checked(x, want, problems(p))

# ---------- The camera ----------

# Where the editor's camera starts: the whole Water, or a person up close.
def camera(p: Project) -> Cam.Cam:
  match p:
    case Water{}:
      Cam.start()
    case Character{}:
      Cam.close_up()
    case Mannequin{}:
      Cam.close_up()
    case Animation{}:
      Cam.close_up()

def opening_camera() -> Cam.Cam:
  camera(open())
