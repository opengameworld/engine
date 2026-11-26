# What the Project window's Create writes: the first text of a new scene, script or shader, as
# Unity writes a new script from its template (Start and Update) and Godot from its script
# template (_ready and _process). Each file is a path inside the project's folder and its text;
# the dev server writes it (tools/dev.ts) and refuses a file that is already there.
#
#   scene(name)    scenes/<name>.bend: an empty scene and no rules; the editor fills it (Create in
#                  the Hierarchy) and Save writes what was made beside it
#   script(name)   scripts/<name>.bend: a script attached to things (engine/script/me.bend), as
#                  Unity's MonoBehaviour: its State (no fields yet), initial(), runs(), and start
#                  and update giving their thing and fields back unchanged
#   system(name)   systems/<name>.bend: start(scene) once when Play starts, update(scene, dt)
#                  every tick, both giving the scene back unchanged; the project's registry runs it
#   shader(name)   shaders/<name>.frag.glsl and its settings (.json), one color parameter, read by
#                  tools/shaders/catalog.js as any shader the project has; its default is the
#                  middle of the 0 to 1 a color channel takes (engine/render/shader/asset.bend)
#
# Limits now:
# - One template per kind; a project cannot bring its own yet (Godot's script_templates/).

import Base
import ./files.bend as F

type Written is Data:
  Written{path: String, text: String}

def path(+f: Written) -> String:
  Written{p, _} = f
  p

def text(+f: Written) -> String:
  Written{_, t} = f
  t

def scene(+name: String) -> List<&2, Written>:
  [Written{"scenes/" ++ name ++ ".bend", String.concat([
    "# The scene ", name, ". Its things are made in the editor (the Hierarchy's Create) and saved\n",
    "# in saved/", name, ".bend (engine/scene/save.bend); things written here open too.\n\n",
    "import Base\n",
    "import ../../../engine/scene/scene.bend as S\n",
    "import ../../../engine/script/rule.bend as R\n\n",
    "def start() -> S.Scene:\n",
    "  S.scene([])\n\n",
    "# What the scene's things do in Play (engine/script/rule.bend).\n",
    "def rules() -> List<&2, R.Rule>:\n",
    "  []\n"])}]

def script(+name: String) -> List<&2, Written>:
  [Written{"scripts/" ++ name ++ ".bend", String.concat([
    "# The script ", name, ": what one thing does in Play. Attach it to a thing (the Inspector's\n",
    "# Add Component > Script); each thing it is on runs its own copy, with its own State.\n",
    "#\n",
    "# Me (engine/script/me.bend) is the thing: Me.position(me), Me.moved(me, by), Me.turned(me, a),\n",
    "# Me.tags(me), Me.clicked(me). Me.world(me) is the World at the start of the tick, to read the\n",
    "# others, never to change them (engine/script/world.bend: position_of, first_named, tagged).\n",
    "# To talk to them, declare the project's messages in ../messages.bend and import it with\n",
    "# ../messages_generated.bend as Mail: Mail.send, Mail.broadcast, Mail.received.\n\n",
    "import Base\n",
    "import ../../../engine/script/me.bend as Me\n\n",
    "# This script's fields: each thing it is on has its own, shown in the Inspector. A field is\n",
    "# F32, U32, Bool, String, V.V3 or Id.Id (a reference to a thing), written name: Type.\n",
    "type State is Data:\n",
    "  State{}\n\n",
    "def initial() -> State:\n",
    "  State{}\n\n",
    "# Where it runs in a game served over a network: Me.server(), Me.client() or Me.both().\n",
    "def runs() -> Me.Runs:\n",
    "  Me.both()\n\n",
    "# Once, on the first tick of Play, before the first update (Unity's Start).\n",
    "def start(+me: Me.Me, +s: State) -> Me.Me & State:\n",
    "  (me, s)\n\n",
    "# Every tick, dt seconds long (1/60 s) (Unity's Update).\n",
    "def update(+me: Me.Me, +s: State, +dt: F32) -> Me.Me & State:\n",
    "  (me, s)\n"])}]

def system(+name: String) -> List<&2, Written>:
  [Written{"systems/" ++ name ++ ".bend", String.concat([
    "# The system ", name, ": what the project's scenes do in Play, as two pure functions from a\n",
    "# scene to the next one (a system, in Bevy's word). The engine runs every system of the project,\n",
    "# in the order of their file names, after the rules (engine/play/game.bend).\n",
    "#\n",
    "# A thing is found by its name: S.things(s) lists them, S.at(s, i) and S.put(s, i, t) read and\n",
    "# write the one at place i (engine/scene/scene.bend).\n\n",
    "import Base\n",
    "import ../../../engine/scene/scene.bend as S\n\n",
    "# Once, on the first tick of Play (Unity's Start, Godot's _ready).\n",
    "def start(+s: S.Scene) -> S.Scene:\n",
    "  s\n\n",
    "# Every tick, dt seconds long (1/60 s) (Unity's Update, Godot's _process).\n",
    "def update(+s: S.Scene, +dt: F32) -> S.Scene:\n",
    "  s\n"])}]

def shader(+name: String) -> List<&2, Written>:
  [Written{"shaders/" ++ name ++ ".frag.glsl", String.concat([
    "#version 300 es\n",
    "precision highp float;\n\n",
    "in vec3 v_local_position;\n",
    "uniform vec3 tint;\n",
    "out vec4 color;\n\n",
    "void main() {\n",
    "  color = vec4(tint, 1.0);\n",
    "}\n"])},
   Written{"shaders/" ++ name ++ ".frag.glsl.json", String.concat([
    "{\n",
    "  \"label\": \"", name, "\",\n",
    "  \"stage\": \"fragment\",\n",
    "  \"lighting\": \"unlit\",\n",
    "  \"parameters\": [\n",
    "    { \"name\": \"tint\", \"label\": \"Tint\", \"control\": \"color\", \"default\": [0.5, 0.5, 0.5] }\n",
    "  ]\n",
    "}\n"])}]

def pick_files(c: Bool, +a: List<&2, Written>, +b: List<&2, Written>) -> List<&2, Written>:
  match c:
    case True{}:
      a
    case False{}:
      b

# The files a Create of this kind writes (none for a folder: the dev server makes it).
def files(+what: String, +name: String) -> List<&2, Written>:
  pick_files(String.eq(what, "scene"), scene(name), pick_files(String.eq(what, "script"), script(name), pick_files(String.eq(what, "system"), system(name), pick_files(String.eq(what, "shader"), shader(name), []))))
