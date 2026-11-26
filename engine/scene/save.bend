# Saving a scene: what was edited, written back as Bend.
#
# A scene is code (projects/<name>/scenes/<Scene>.bend). Saving does not rewrite that code: it
# writes what differs from it, as Godot's .tscn stores only "properties [not] equal to the
# default value" and a Unity prefab instance stores its overrides. The difference is a list of
# places: for each thing whose place (Transform) was changed, its name and its place now. The
# file is scenes/saved/<Scene>.bend in the project's folder, beside the scene's code (a folder of its
# own: a Bend import path takes plain names, so "<Scene>.saved.bend" cannot be imported); the project's
# registry (tools/project/registry.js) applies it to the scene when the scene opens, so what was
# saved is what opens.
#
# Things made in the editor (projects/prefabs.bend) are saved whole, by kind, name and place
# (made), and things of the code that were deleted by name (removed), as a Unity prefab instance
# keeps its added and removed objects beside its overrides.
#
# Bend writes the file's text (text), with imports that reach the engine as engine/scene/reach.bend
# says, and where it goes (file); the editor's dev server only
# writes it to disk (tools/dev.ts), because a browser page cannot write a file in every browser
# (showSaveFilePicker is Chromium only, per MDN). References: docs/references/play-save-undo.md.
#
# The scene's rules (engine/script/rule.bend) are saved beside the places, whole, as Godot keeps a
# scene's [connection] lines in its .tscn and Unity a UnityEvent's persistent calls in the scene:
# once the editor has saved rules (has_rules), they are the project's rules, in place of the ones
# its code writes.
#
# Limits now:
# - Only places and rules are saved. A material's values, a shader picked for a thing and a clip
#   added to a character are not yet.
# - Rules are saved whole, not as a difference from the code's: after the editor saved them, a rule
#   changed in the project's code is not seen until saved.bend's has_rules is False again.
# - A thing is found by its name: renaming a thing in the code loses its saved place.
# - Saving needs `bun run dev`: a built copy (dist/) has no server to write the file.

import Base
import ../core/vec.bend as V
import ../core/quat.bend as Q
import ../core/transform.bend as Tr
import ./scene.bend as S
import ../script/rule.bend as R
import ./reach.bend as Rc

type Placed is Data:
  Placed{name: String, place: Tr.Transform}

# ---------- Applying what was saved ----------

def Save.pick_place(c: Bool, +a: Tr.Transform, +b: Tr.Transform) -> Tr.Transform:
  match c:
    case True{}:
      a
    case False{}:
      b


def Save.place_of(ps: List<&2, Placed>, +name: String, +now: Tr.Transform) -> Tr.Transform:
  match ps:
    case Nil{}:
      now
    case Con{Placed{n, p}, +t}:
      Save.pick_place(String.eq(n, name), p, Save.place_of(t, name, now))

def Save.things(xs: List<&2, S.Thing>, +ps: List<&2, Placed>) -> List<&2, S.Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      S.Thing{+n, +p, l} = h
      S.Thing{n, Save.place_of(ps, n, p), l} <> Save.things(t, ps)

# The scene with every saved place put back.
def apply(s: S.Scene, +ps: List<&2, Placed>) -> S.Scene:
  S.Scene{xs} = s
  S.Scene{Save.things(xs, ps)}

# ---------- What changed ----------

def Save.same3(+a: V.V3, +b: V.V3) -> Bool:
  (F32.is_eq(V.x(a), V.x(b)) && F32.is_eq(V.y(a), V.y(b)) && F32.is_eq(V.z(a), V.z(b)))

def Save.sameq(+a: Q.Q, +b: Q.Q) -> Bool:
  Q.Q{ax, ay, az, aw} = a
  Q.Q{bx, by, bz, bw} = b
  (F32.is_eq(ax, bx) && F32.is_eq(ay, by) && F32.is_eq(az, bz) && F32.is_eq(aw, bw))

def same_place(+a: Tr.Transform, +b: Tr.Transform) -> Bool:
  (Save.same3(Tr.position(a), Tr.position(b)) && Save.sameq(Tr.rotation(a), Tr.rotation(b)) && Save.same3(Tr.scale(a), Tr.scale(b)))

def Save.keep(c: Bool, +p: Placed, rest: List<&2, Placed>) -> List<&2, Placed>:
  match c:
    case True{}:
      p <> rest
    case False{}:
      rest

def Save.base_place(xs: List<&2, S.Thing>, +name: String, +none: Tr.Transform) -> Tr.Transform:
  match xs:
    case Nil{}:
      none
    case Con{+h, t}:
      Save.pick_place(String.eq(S.name(h), name), S.place(h), Save.base_place(t, name, none))

def Save.in_base(xs: List<&2, S.Thing>, +name: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+h, t}:
      (String.eq(S.name(h), name) || Save.in_base(t, name))

# The places of `now` that differ from the project's own scene `base`.

def Save.changed_go(now: List<&2, S.Thing>, +base: List<&2, S.Thing>) -> List<&2, Placed>:
  match now:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Save.keep(Bool.not(same_place(S.place(h), Save.base_place(base, S.name(h), S.place(h)))) || Bool.not(Save.in_base(base, S.name(h))),
        Placed{S.name(h), S.place(h)}, Save.changed_go(t, base))

def changed(+base: S.Scene, +now: S.Scene) -> List<&2, Placed>:
  Save.changed_go(S.things(now), S.things(base))

# ---------- Writing it as Bend ----------

# A number as Bend reads it back: always with a point, and a negative one as (0.0 - x : F32),
# since Bend has no negative literals and F32.show writes 1e20 as digits only.
def Save.text_if(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b


def Save.dotted(+t: String) -> String:
  Save.text_if((String.contains(t, ".") || String.contains(t, "e")), t, (t ++ ".0"))

def number(+x: F32) -> String:
  Save.text_if(F32.is_lt(x, 0.0),
    "(0.0 - " ++ Save.dotted(F32.show((0.0 - x : F32))) ++ " : F32)",
    Save.dotted(F32.show(x)))

def Save.v3(+v: V.V3) -> String:
  "V.V3{" ++ number(V.x(v)) ++ ", " ++ number(V.y(v)) ++ ", " ++ number(V.z(v)) ++ "}"

def Save.q(+q: Q.Q) -> String:
  Q.Q{x, y, z, w} = q
  "Q.Q{" ++ number(x) ++ ", " ++ number(y) ++ ", " ++ number(z) ++ ", " ++ number(w) ++ "}"

def Save.place(+t: Tr.Transform) -> String:
  "Tr.Transform{" ++ Save.v3(Tr.position(t)) ++ ", " ++ Save.q(Tr.rotation(t)) ++ ", " ++ Save.v3(Tr.scale(t)) ++ "}"

def Save.sep(+t: List<&2, Placed>) -> String:
  match t:
    case Nil{}:
      ""
    case Con{_, _}:
      ",\n"

# The text of projects/<folder>/saved.bend.

def Save.lines(ps: List<&2, Placed>) -> String:
  match ps:
    case Nil{}:
      ""
    case Con{Placed{n, p}, +t}:
      String.concat(["   Save.Placed{", String.quote(n), ", ", Save.place(p), "}", Save.sep(t), Save.lines(t)])

def Save.names(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{+h, Nil{}}:
      String.quote(h)
    case Con{+h, +t}:
      String.quote(h) ++ ", " ++ Save.names(t)

def Save.bool(b: Bool) -> String:
  match b:
    case True{}:
      "True{}"
    case False{}:
      "False{}"

def Save.when(+w: R.Trigger) -> String:
  match w:
    case R.Trigger.Clicked{}:
      "R.Trigger.Clicked{}"
    case R.Trigger.Started{}:
      "R.Trigger.Started{}"

def Save.does(+d: R.Response) -> String:
  match d:
    case R.Response.Move{v}:
      "R.Response.Move{" ++ Save.v3(v) ++ "}"
    case R.Response.Turn{a}:
      "R.Response.Turn{" ++ number(a) ++ "}"
    case R.Response.Play{c}:
      "R.Response.Play{" ++ U32.show(c) ++ "}"

# One rule as Bend: R.Rule{"Box", R.Trigger.Clicked{}, R.Response.Turn{0.5}}.
def rule(+r: R.Rule) -> String:
  "R.Rule{" ++ String.quote(R.thing(r)) ++ ", " ++ Save.when(R.when(r)) ++ ", " ++ Save.does(R.does(r)) ++ "}"

def Save.rule_sep(+t: List<&2, R.Rule>) -> String:
  match t:
    case Nil{}:
      ""
    case Con{_, _}:
      ",\n"

def Save.rule_lines(rs: List<&2, R.Rule>) -> String:
  match rs:
    case Nil{}:
      ""
    case Con{+h, +t}:
      String.concat(["   ", rule(h), Save.rule_sep(t), Save.rule_lines(t)])

# The text of a scene's saved file: the places that differ from the code, the things made in the
# editor (projects/prefabs.bend's lines, already written), the things of the code deleted, and the
# rules when the editor holds its own (own: the editor's rules replace the code's).
# The file sits two folders below the project's (scenes/saved/), and reaches the engine as r says.
def text(r: Rc.Reach, +folder: String, +scene: String, +ps: List<&2, Placed>, +made: String, +removed: List<&2, String>, +own: Bool, +rs: List<&2, R.Rule>) -> String:
  +e = Rc.prefix(r, 2n)
  String.concat([
    "# Saved by the editor for the scene \"", scene, "\" of the project \"", folder, "\"\n",
    "# (engine/scene/save.bend). Do not edit by hand: Save in the editor writes it again. places()\n",
    "# are the places that differ from ", scene, ".bend's, made() the things made in the editor,\n",
    "# removed() the things of the code deleted, and, when has_rules() is True, rules() are the\n",
    "# scene's rules in place of the code's.\n\n",
    "import Base\n",
    "import ", e, "engine/core/vec.bend as V\n",
    "import ", e, "engine/core/quat.bend as Q\n",
    "import ", e, "engine/core/transform.bend as Tr\n",
    "import ", e, "engine/scene/save.bend as Save\n",
    "import ", e, "engine/script/rule.bend as R\n",
    "import ", e, "projects/prefabs.bend as Pre\n\n",
    "def places() -> List<&2, Save.Placed>:\n",
    "  [", String.drop(Save.lines(ps), 3n), "]\n\n",
    "def made() -> List<&2, Pre.Made>:\n",
    "  [", String.drop(made, 3n), "]\n\n",
    "def removed() -> List<&2, String>:\n",
    "  [", Save.names(removed), "]\n\n",
    "def has_rules() -> Bool: ", Save.bool(own), "\n\n",
    "def rules() -> List<&2, R.Rule>:\n",
    "  [", String.drop(Save.rule_lines(rs), 3n), "]\n"])

# The rules a project opens with: the saved ones when the editor saved its own, the code's otherwise.
def rules(own: Bool, saved: List<&2, R.Rule>, code: List<&2, R.Rule>) -> List<&2, R.Rule>:
  match own:
    case True{}:
      saved
    case False{}:
      code

# Where a scene's saved file goes, inside its project's folder.
def file(+scene: String) -> String:
  "scenes/saved/" ++ scene ++ ".bend"

# A transform as Bend reads it back (projects/prefabs.bend writes the things made with it).
def place_text(+t: Tr.Transform) -> String:
  Save.place(t)

# ---------- Deleting ----------

def Save.has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (String.eq(h, x) || Save.has(t, x))

def Save.keep_thing(c: Bool, +h: S.Thing, rest: List<&2, S.Thing>) -> List<&2, S.Thing>:
  match c:
    case True{}:
      h <> rest
    case False{}:
      rest

def Save.without_go(xs: List<&2, S.Thing>, +names: List<&2, String>) -> List<&2, S.Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Save.keep_thing(Bool.not(Save.has(names, S.name(h))), h, Save.without_go(t, names))

# The scene without the things deleted by name.
def without(s: S.Scene, +names: List<&2, String>) -> S.Scene:
  S.Scene{xs} = s
  S.Scene{Save.without_go(xs, names)}
