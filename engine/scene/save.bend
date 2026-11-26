# Saving a scene: what was edited, written back as Bend.
#
# A scene is code (projects/<name>/scenes/<Scene>.bend). Saving does not rewrite that code: it
# writes what differs from it, as Godot's .tscn stores only "properties [not] equal to the
# default value" and a Unity prefab instance stores its overrides. The difference is a list of
# places: for each thing whose place (Transform) was changed, its name and its place now. The
# file is projects/<name>/scenes/saved/<Scene>.bend, beside the scene's code (a folder of its
# own: a Bend import path takes plain names, so "<Scene>.saved.bend" cannot be imported); the project's
# registry (tools/project/registry.js) applies it to the scene when the scene opens, so what was
# saved is what opens.
#
# Things made in the editor (projects/prefabs.bend) are saved whole, by kind, name and place
# (made), and things of the code that were deleted by name (removed), as a Unity prefab instance
# keeps its added and removed objects beside its overrides.
#
# Bend writes the file's text (text) and says where it goes (file); the editor's dev server only
# writes it to disk (tools/dev.ts), because a browser page cannot write a file in every browser
# (showSaveFilePicker is Chromium only, per MDN). References: docs/references/play-save-undo.md.
#
# The scene's rules (engine/script/rule.bend) are saved beside the places, whole, as Godot keeps a
# scene's [connection] lines in its .tscn and Unity a UnityEvent's persistent calls in the scene:
# once the editor has saved rules (has_rules), they are the project's rules, in place of the ones
# its code writes.
#
# A thing's tags are saved when they differ from the code's (tagged). The scripts attached to
# things (engine/script/attach.bend) are saved whole, as the rules are (attached): each with the
# name of its thing, its script, and its fields; a field that refers to a thing is written as that
# thing's name, since ids are given again when the scene opens (engine/scene/id.bend). Opening the
# scene puts every attachment's fields over its script's defaults and turns names back into ids
# (settled).
#
# Limits now:
# - Places, rules, tags and attached scripts are saved. A material's values, a shader picked for a
#   thing and a clip added to a character are not yet.
# - Rules and attached scripts are saved whole, not as a difference from the code's: after the
#   editor saved them, one changed in the project's code is not seen.
# - A thing is found by its name: renaming a thing in the code loses what was saved for it, and of
#   two things with one name, the first gets it (a reference too).
# - Saving needs `bun run dev`: a built copy (dist/) has no server to write the file.

import Base
import ../core/vec.bend as V
import ../core/quat.bend as Q
import ../core/transform.bend as Tr
import ./scene.bend as S
import ./id.bend as Id
import ../script/rule.bend as R
import ../script/attach.bend as At
import ../script/value.bend as Val

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
    case Con{+h, t}:
      S.with_place(h, Save.place_of(ps, S.name(h), S.place(h))) <> Save.things(t, ps)

# The scene with every saved place put back.
def apply(+s: S.Scene, +ps: List<&2, Placed>) -> S.Scene:
  S.with_things(s, Save.things(S.things(s), ps))

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

# ---------- Tags ----------

# A thing's tags, saved when they differ from the code's (or the thing is not in the code).
type Tagged is Data:
  Tagged{name: String, tags: List<&2, String>}

def Save.pick_tags(c: Bool, +a: List<&2, String>, +b: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      a
    case False{}:
      b

def Save.tags_of(gs: List<&2, Tagged>, +name: String, +now: List<&2, String>) -> List<&2, String>:
  match gs:
    case Nil{}:
      now
    case Con{Tagged{n, g}, +t}:
      Save.pick_tags(String.eq(n, name), g, Save.tags_of(t, name, now))

def Save.tag_things(xs: List<&2, S.Thing>, +gs: List<&2, Tagged>) -> List<&2, S.Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      S.with_tags(h, Save.tags_of(gs, S.name(h), S.tags(h))) <> Save.tag_things(t, gs)

# The scene with every saved thing's tags put back.
def tag(+s: S.Scene, +gs: List<&2, Tagged>) -> S.Scene:
  S.with_things(s, Save.tag_things(S.things(s), gs))

def Save.same_tags(xs: List<&2, String>, ys: List<&2, String>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{+a, at} Con{+b, bt}:
      (String.eq(a, b) && Save.same_tags(at, bt))
    case _ _:
      False{}

def Save.base_tags(xs: List<&2, S.Thing>, +name: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case Con{+h, t}:
      Save.pick_tags(String.eq(S.name(h), name), S.tags(h), Save.base_tags(t, name))

def Save.keep_tags(c: Bool, +g: Tagged, rest: List<&2, Tagged>) -> List<&2, Tagged>:
  match c:
    case True{}:
      g <> rest
    case False{}:
      rest

def Save.tags_changed_go(now: List<&2, S.Thing>, +base: List<&2, S.Thing>) -> List<&2, Tagged>:
  match now:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Save.keep_tags(Bool.not(Save.same_tags(S.tags(h), Save.base_tags(base, S.name(h)))),
        Tagged{S.name(h), S.tags(h)}, Save.tags_changed_go(t, base))

# The tags of `now` that differ from the project's own scene `base`.
def tags_changed(+base: S.Scene, +now: S.Scene) -> List<&2, Tagged>:
  Save.tags_changed_go(S.things(now), S.things(base))

# ---------- Attached scripts ----------

# A script attached to the thing with this name, as a saved scene (or a scene's code) writes it:
# its fields with references as names (Val.Value.Named).
type Attachment is Data:
  Attachment{thing: String, script: String, fields: Val.Value}

def Save.pick_u(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# The place of the first thing with this name (n + the list's length when there is none).
def Save.named_index(xs: List<&2, S.Thing>, +name: String, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{+h, t}:
      Save.pick_u(String.eq(S.name(h), name), n, Save.named_index(t, name, (n + 1 : U32)))

def Save.attach_one(+s: S.Scene, +a: Attachment) -> S.Scene:
  Attachment{n, k, f} = a
  +i = Save.named_index(S.things(s), n, 0)
  S.put(s, i, S.with_scripts(S.at(s, i), List.append(&2, At.Attached, S.scripts(S.at(s, i)), [At.Attached{k, f}])))

def Save.attach_all(as: List<&2, Attachment>, +s: S.Scene) -> S.Scene:
  match as:
    case Nil{}:
      s
    case Con{+h, t}:
      Save.attach_all(t, Save.attach_one(s, h))

def Save.stripped(xs: List<&2, S.Thing>) -> List<&2, S.Thing>:
  match xs:
    case Nil{}:
      []
    case Con{+h, t}:
      S.with_scripts(h, []) <> Save.stripped(t)

def Save.strip_if(own: Bool, +s: S.Scene) -> S.Scene:
  match own:
    case True{}:
      S.with_things(s, Save.stripped(S.things(s)))
    case False{}:
      s

# The scene with the attachments saved: when the editor saved its own (own), they replace the
# code's; each goes to the first thing with its thing's name (none, when there is no such thing).
def attach(+s: S.Scene, +own: Bool, +as: List<&2, Attachment>) -> S.Scene:
  Save.attach_all(as, Save.strip_if(own, s))

def Save.pick_id(c: Bool, +a: Id.Id, +b: Id.Id) -> Id.Id:
  match c:
    case True{}:
      a
    case False{}:
      b

def Save.id_named(xs: List<&2, S.Thing>, +name: String) -> Id.Id:
  match xs:
    case Nil{}:
      Id.none()
    case Con{+h, t}:
      Save.pick_id(String.eq(S.name(h), name), S.id(h), Save.id_named(t, name))

def Save.resolved_one(+v: Val.Value, +xs: List<&2, S.Thing>) -> Val.Value:
  match v:
    case Val.Value.Named{n}:
      Val.Value.Ref{Save.id_named(xs, n)}
    case _:
      v

def Save.resolved_list(vs: List<&2, Val.Value>, +xs: List<&2, S.Thing>) -> List<&2, Val.Value>:
  match vs:
    case Nil{}:
      []
    case Con{+h, t}:
      Save.resolved_one(h, xs) <> Save.resolved_list(t, xs)

# A script's fields with every reference by name turned into the id of the first thing so named.
def resolved(+v: Val.Value, +xs: List<&2, S.Thing>) -> Val.Value:
  match v:
    case Val.Value.Rec{ns, vs}:
      Val.Value.Rec{ns, Save.resolved_list(vs, xs)}
    case _:
      v

def Save.settle_attached(~defaults: @+name: String -> Val.Value, as: List<&2, At.Attached>, +xs: List<&2, S.Thing>) -> List<&2, At.Attached>:
  match as:
    case Nil{}:
      []
    case Con{+h, t}:
      At.Attached{At.script(h), resolved(Val.merged(defaults(At.script(h)), At.fields(h)), xs)} <> Save.settle_attached(~defaults, t, xs)

def Save.settle_things(~defaults: @+name: String -> Val.Value, ts: List<&2, S.Thing>, +xs: List<&2, S.Thing>) -> List<&2, S.Thing>:
  match ts:
    case Nil{}:
      []
    case Con{+h, t}:
      S.with_scripts(h, Save.settle_attached(~defaults, S.scripts(h), xs)) <> Save.settle_things(~defaults, t, xs)

# The scene as it opens: every attachment's fields are its script's defaults (a project's
# registry's defaults) with its own values put in, and its references by name are ids.
def settled(~defaults: @+name: String -> Val.Value, +s: S.Scene) -> S.Scene:
  S.with_things(s, Save.settle_things(~defaults, S.things(s), S.things(s)))

def Save.name_in(m: Maybe<&2, S.Thing>) -> String:
  match m:
    case Some{t}:
      S.name(t)
    case None{}:
      ""

def Save.named_one(+v: Val.Value, +s: S.Scene) -> Val.Value:
  match v:
    case Val.Value.Ref{i}:
      Val.Value.Named{Save.name_in(S.find(s, i))}
    case _:
      v

def Save.named_list(vs: List<&2, Val.Value>, +s: S.Scene) -> List<&2, Val.Value>:
  match vs:
    case Nil{}:
      []
    case Con{+h, t}:
      Save.named_one(h, s) <> Save.named_list(t, s)

# A script's fields as a saved scene writes them: every reference as its thing's name.
def unresolved(+v: Val.Value, +s: S.Scene) -> Val.Value:
  match v:
    case Val.Value.Rec{ns, vs}:
      Val.Value.Rec{ns, Save.named_list(vs, s)}
    case _:
      v

def Save.attachments_of(+n: String, as: List<&2, At.Attached>, +s: S.Scene) -> List<&2, Attachment>:
  match as:
    case Nil{}:
      []
    case Con{+h, t}:
      Attachment{n, At.script(h), unresolved(At.fields(h), s)} <> Save.attachments_of(n, t, s)

def Save.attachments_go(xs: List<&2, S.Thing>, +s: S.Scene) -> List<&2, Attachment>:
  match xs:
    case Nil{}:
      []
    case Con{+h, t}:
      List.append(&2, Attachment, Save.attachments_of(S.name(h), S.scripts(h), s), Save.attachments_go(t, s))

# Every script attached to a thing of the scene, as the saved file writes it.
def attachments(+s: S.Scene) -> List<&2, Attachment>:
  Save.attachments_go(S.things(s), s)

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

# A field's value as Bend (a record's own field is never a record: engine/script/value.bend).
def Save.flat_value(+v: Val.Value) -> String:
  match v:
    case Val.Value.Num{n}:
      "Val.Value.Num{" ++ number(n) ++ "}"
    case Val.Value.Int{n}:
      "Val.Value.Int{" ++ U32.show(n) ++ "}"
    case Val.Value.Flag{b}:
      "Val.Value.Flag{" ++ Save.bool(b) ++ "}"
    case Val.Value.Text{t}:
      "Val.Value.Text{" ++ String.quote(t) ++ "}"
    case Val.Value.Vec{x}:
      "Val.Value.Vec{" ++ Save.v3(x) ++ "}"
    case Val.Value.Ref{_}:
      "Val.Value.Named{\"\"}"
    case Val.Value.Named{n}:
      "Val.Value.Named{" ++ String.quote(n) ++ "}"
    case Val.Value.Rec{_, _}:
      "Val.Value.Rec{[], []}"

def Save.flat_values(vs: List<&2, Val.Value>) -> String:
  match vs:
    case Nil{}:
      ""
    case Con{+h, Nil{}}:
      Save.flat_value(h)
    case Con{+h, +t}:
      Save.flat_value(h) ++ ", " ++ Save.flat_values(t)

# A script's fields as Bend: Val.Value.Rec{["speed"], [Val.Value.Num{1.0}]}.
def value_text(+v: Val.Value) -> String:
  match v:
    case Val.Value.Rec{ns, vs}:
      "Val.Value.Rec{[" ++ Save.names(ns) ++ "], [" ++ Save.flat_values(vs) ++ "]}"
    case _:
      Save.flat_value(v)

def Save.attachment_lines(as: List<&2, Attachment>) -> String:
  match as:
    case Nil{}:
      ""
    case Con{Attachment{n, k, f}, +t}:
      String.concat(["   Save.Attachment{", String.quote(n), ", ", String.quote(k), ", ", value_text(f), "}", Save.text_if(List.is_empty(&2, Attachment, t), "", ",\n"), Save.attachment_lines(t)])

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

def Save.tag_lines(gs: List<&2, Tagged>) -> String:
  match gs:
    case Nil{}:
      ""
    case Con{Tagged{n, g}, +t}:
      String.concat(["   Save.Tagged{", String.quote(n), ", [", Save.names(g), "]}", Save.text_if(List.is_empty(&2, Tagged, t), "", ",\n"), Save.tag_lines(t)])

# The text of a scene's saved file: the places that differ from the code, the things made in the
# editor (projects/prefabs.bend's lines, already written), the things of the code deleted, the
# rules when the editor holds its own (own: the editor's rules replace the code's), the tags that
# differ from the code's, and every script attached to a thing (as).
def text(+folder: String, +scene: String, +ps: List<&2, Placed>, +made: String, +removed: List<&2, String>, +own: Bool, +rs: List<&2, R.Rule>, +gs: List<&2, Tagged>, +as: List<&2, Attachment>) -> String:
  String.concat([
    "# Saved by the editor for the scene \"", scene, "\" of the project \"", folder, "\"\n",
    "# (engine/scene/save.bend). Do not edit by hand: Save in the editor writes it again. places()\n",
    "# are the places that differ from ", scene, ".bend's, made() the things made in the editor,\n",
    "# removed() the things of the code deleted, when has_rules() is True, rules() are the\n",
    "# scene's rules in place of the code's, tagged() the tags that differ from the code's, and\n",
    "# attached() every script attached to a thing, with its fields.\n\n",
    "import Base\n",
    "import ../../../../engine/core/vec.bend as V\n",
    "import ../../../../engine/core/quat.bend as Q\n",
    "import ../../../../engine/core/transform.bend as Tr\n",
    "import ../../../../engine/scene/save.bend as Save\n",
    "import ../../../../engine/script/rule.bend as R\n",
    "import ../../../../engine/script/value.bend as Val\n",
    "import ../../../prefabs.bend as Pre\n\n",
    "def places() -> List<&2, Save.Placed>:\n",
    "  [", String.drop(Save.lines(ps), 3n), "]\n\n",
    "def made() -> List<&2, Pre.Made>:\n",
    "  [", String.drop(made, 3n), "]\n\n",
    "def removed() -> List<&2, String>:\n",
    "  [", Save.names(removed), "]\n\n",
    "def has_rules() -> Bool: ", Save.bool(own), "\n\n",
    "def rules() -> List<&2, R.Rule>:\n",
    "  [", String.drop(Save.rule_lines(rs), 3n), "]\n\n",
    "def tagged() -> List<&2, Save.Tagged>:\n",
    "  [", String.drop(Save.tag_lines(gs), 3n), "]\n\n",
    "def attached() -> List<&2, Save.Attachment>:\n",
    "  [", String.drop(Save.attachment_lines(as), 3n), "]\n"])

# The rules a project opens with: the saved ones when the editor saved its own, the code's otherwise.
def rules(own: Bool, saved: List<&2, R.Rule>, code: List<&2, R.Rule>) -> List<&2, R.Rule>:
  match own:
    case True{}:
      saved
    case False{}:
      code

# Where a scene's saved file goes, from the repository's root.
def file(+folder: String, +scene: String) -> String:
  "projects/" ++ folder ++ "/scenes/saved/" ++ scene ++ ".bend"

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

def Save.drop_if(gone: Bool, +s: S.Scene, +i: Id.Id) -> S.Scene:
  match gone:
    case True{}:
      S.remove(s, i)
    case False{}:
      s

def Save.without_go(xs: List<&2, S.Thing>, +s: S.Scene, +names: List<&2, String>) -> S.Scene:
  match xs:
    case Nil{}:
      s
    case Con{+h, t}:
      Save.without_go(t, Save.drop_if(Save.has(names, S.name(h)), s, S.id(h)), names)

# The scene without the things deleted by name; their ids go back to the scene's book.
def without(+s: S.Scene, +names: List<&2, String>) -> S.Scene:
  Save.without_go(S.things(s), s, names)
