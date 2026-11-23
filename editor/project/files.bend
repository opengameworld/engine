# The Project window's files: what it lists, in which folder, and what each file is.
# (Unity calls it the Project window; Unreal, the Content Browser.)
#
# Two roots, as Unity's Project window has Assets and Packages:
#   Assets             the project's own folder (projects/<folder>/), as tools/project/files.js
#                      lists it into editor/project/files_generated.bend; the dev server lists it
#                      again after a folder is made
#   Library/Animations the animation library (library/catalog.bend): a folder per collection, a
#                      clip per file; it ships with the engine, as Unity's Packages do
#
# A path is its folders and its name, parted by "/" (Bend-UI's TREE.bend reads paths so, and
# draws the folder tree from them). A path that ends in "/" is a folder with nothing in it yet.
#
# A shader's settings file (ripples.frag.glsl.json beside ripples.frag.glsl) is not listed: it is
# part of its shader, as Unity hides a .meta file beside its asset.
#
# Limits now:
# - A clip is found by its collection's name and its own: two clips of one collection with one
#   name are one path.
# - A name with "/" in it cannot be listed (it would read as a folder).

import Base
import ../../node_modules/bend-ui/TREE.bend as Tree
import ../../engine/anim/library.bend as L
import ../../library/catalog.bend as Cat

# ---------- The roots ----------

def assets() -> String: "Assets"
def library() -> String: "Library"
def animations() -> String: "Library/Animations"

def pick_s(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def put_if(c: Bool, +x: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      x <> rest
    case False{}:
      rest

def has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (String.eq(h, x) || has(t, x))

# ---------- The project's files ----------

# A path without its last n characters.
def cut(+p: String, +n: Nat) -> String:
  String.reverse(String.drop(String.reverse(p), n))

# Is this a shader's settings (x.json beside x)?
def is_settings(+p: String, +files: List<&2, String>) -> Bool:
  (String.ends_with(p, ".json") && has(files, cut(p, 5n)))

def pick_list(c: Bool, a: List<&2, String>, b: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      a
    case False{}:
      b

def own_go(xs: List<&2, String>, +files: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      put_if(Bool.not(is_settings(h, files)), assets() ++ "/" ++ h, own_go(t, files))

# The project's files under Assets ("scene.bend" is "Assets/scene.bend"), with their settings
# files left out. A project with no files is an empty Assets.
def own(+files: List<&2, String>) -> List<&2, String>:
  pick_list(List.is_empty(&2, String, files), [assets() ++ "/"], own_go(files, files))

# The files of the project as the dev server sends them: one path per line.
def listed(+text: String) -> List<&2, String>:
  List.filter(~String, ~Tree.filled, String.lines(text))

# ---------- The library's clips ----------

def clip_path(+c: L.Collection, +e: L.Entry) -> String:
  animations() ++ "/" ++ L.name(c) ++ "/" ++ L.entry_name(e)

def clip_paths_of(es: List<&2, L.Entry>, +c: L.Collection) -> List<&2, String>:
  match es:
    case Nil{}:
      Nil{}
    case h <> t:
      clip_path(c, h) <> clip_paths_of(t, c)

def clip_paths_go(cs: List<&2, L.Collection>) -> List<&2, String>:
  match cs:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.append(&2, String, clip_paths_of(L.entries(h), h), clip_paths_go(t))

def clip_paths() -> List<&2, String>:
  clip_paths_go(Cat.collections())

# Every path the Project window lists: the project's, then the library's.
def all(+files: List<&2, String>) -> List<&2, String>:
  List.append(&2, String, own(files), clip_paths())

# Where a clip's path points in the library: its collection, its place in it, and whether the
# path is a clip at all.
type Clip is Data:
  Clip{folder: U32, k: U32, found: Bool}

def no_clip() -> Clip:
  Clip{0, 0, False{}}

def pick_clip(c: Bool, +a: Clip, +b: Clip) -> Clip:
  match c:
    case True{}:
      a
    case False{}:
      b

def first_clip(+a: Clip, +b: Clip) -> Clip:
  Clip{f, k, ok} = a
  pick_clip(ok, Clip{f, k, ok}, b)

def clip_in(es: List<&2, L.Entry>, +c: L.Collection, +f: U32, +k: U32, +path: String) -> Clip:
  match es:
    case Nil{}:
      no_clip()
    case +h <> t:
      pick_clip(String.eq(clip_path(c, h), path), Clip{f, k, True{}}, clip_in(t, c, f, (k + 1 : U32), path))

def clip_go(cs: List<&2, L.Collection>, +f: U32, +path: String) -> Clip:
  match cs:
    case Nil{}:
      no_clip()
    case +h <> t:
      first_clip(clip_in(L.entries(h), h, f, 0, path), clip_go(t, (f + 1 : U32), path))

def clip_at(+path: String) -> Clip:
  clip_go(Cat.collections(), 0, path)

def clip_folder(+c: Clip) -> U32:
  Clip{f, _, _} = c
  f

def clip_k(+c: Clip) -> U32:
  Clip{_, k, _} = c
  k

def is_clip(+c: Clip) -> Bool:
  Clip{_, _, ok} = c
  ok

# ---------- Folders ----------

# The folder a path is in ("" at the top).
def parent(+path: String) -> String:
  Tree.parent(path)

# The last part of a path: its name.
def name(+path: String) -> String:
  Tree.last_of(Tree.parts(path), "")

def entry_path(e: Tree.Entry) -> String:
  Tree.Entry{_, _, p} = e
  p

# The paths of entries, in order.
def paths_of(es: List<&2, Tree.Entry>) -> List<&2, String>:
  match es:
    case Nil{}:
      Nil{}
    case h <> t:
      entry_path(h) <> paths_of(t)

def entry_folder(e: Tree.Entry) -> Bool:
  Tree.Entry{_, f, _} = e
  f

def folders_go(es: List<&2, Tree.Entry>) -> List<&2, String>:
  match es:
    case Nil{}:
      Nil{}
    case +h <> t:
      put_if(entry_folder(h), entry_path(h) ++ "/", folders_go(t))

# Every folder, as a path the folder tree reads ("Assets/shaders/"): the tree on the left shows
# folders only, as Unity's two-column Project window does.
def folders(+paths: List<&2, String>) -> List<&2, String>:
  folders_go(Tree.sorted(paths))

def is_folder(+paths: List<&2, String>, +path: String) -> Bool:
  has(folders(paths), path ++ "/")

def put_entry(c: Bool, +e: Tree.Entry, rest: List<&2, Tree.Entry>) -> List<&2, Tree.Entry>:
  match c:
    case True{}:
      e <> rest
    case False{}:
      rest

def kids_go(es: List<&2, Tree.Entry>, +at: String) -> List<&2, Tree.Entry>:
  match es:
    case Nil{}:
      Nil{}
    case +h <> t:
      put_entry(String.eq(parent(entry_path(h)), at), h, kids_go(t, at))

# What a folder holds, folders first, then files, each by name.
def kids(+paths: List<&2, String>, +at: String) -> List<&2, Tree.Entry>:
  kids_go(Tree.sorted(paths), at)

def found_go(es: List<&2, Tree.Entry>, +q: String) -> List<&2, Tree.Entry>:
  match es:
    case Nil{}:
      Nil{}
    case +h <> t:
      put_entry((Bool.not(entry_folder(h)) && String.contains(String.to_lower(name(entry_path(h))), q)), h, found_go(t, q))

# Every file whose name holds the search, in any folder (as Unity's Project search does).
def found(+paths: List<&2, String>, +query: String) -> List<&2, Tree.Entry>:
  found_go(Tree.sorted(paths), String.to_lower(String.trim(query)))

def pick_entries(c: Bool, a: List<&2, Tree.Entry>, b: List<&2, Tree.Entry>) -> List<&2, Tree.Entry>:
  match c:
    case True{}:
      a
    case False{}:
      b

# What the content side shows: the search's files while there is a search, the folder's otherwise.
def shown(+paths: List<&2, String>, +at: String, +query: String) -> List<&2, Tree.Entry>:
  pick_entries(String.is_empty(String.trim(query)), kids(paths, at), found(paths, query))

# Every folder from the top down to `at`, for the breadcrumbs ("Assets", "Assets/shaders").
def trail_go(+ps: List<&2, String>, +above: String) -> List<&2, String>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> t:
      Tree.under(above, h) <> trail_go(t, Tree.under(above, h))

def trail(+at: String) -> List<&2, String>:
  trail_go(Tree.parts(at), "")

def opened_go(ps: List<&2, String>, +open: List<&2, String>) -> List<&2, String>:
  match ps:
    case Nil{}:
      open
    case +h <> t:
      opened_go(t, put_if(Bool.not(has(open, h)), h, open))

# Every folder above `at`, and `at`: the folders the tree keeps open to show it.
def opened_to(+open: List<&2, String>, +at: String) -> List<&2, String>:
  opened_go(trail(at), open)

# ---------- What a file is ----------

type Sort is Data:
  Sort.Folder{}
  Sort.Clip{}
  Sort.Shader{}
  Sort.Module{}
  Sort.Other{}

def any_end(+p: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      (String.ends_with(p, h) || any_end(p, t))

# The shader languages tools/shaders/catalog.js reads.
def shader_ends() -> List<&2, String>:
  [".glsl", ".hlsl", ".wgsl", ".shader", ".frag", ".vert", ".fs", ".vs", ".ps"]

def pick_kind(c: Bool, +a: Sort, +b: Sort) -> Sort:
  match c:
    case True{}:
      a
    case False{}:
      b

def kind(+paths: List<&2, String>, +path: String) -> Sort:
  pick_kind(is_folder(paths, path), Sort.Folder{},
  pick_kind(String.starts_with(path, animations() ++ "/"), Sort.Clip{},
  pick_kind(any_end(path, shader_ends()), Sort.Shader{},
  pick_kind(String.ends_with(path, ".bend"), Sort.Module{}, Sort.Other{}))))

def kind_name(+k: Sort) -> String:
  match k:
    case Sort.Folder{}:
      "Folder"
    case Sort.Clip{}:
      "Animation clip"
    case Sort.Shader{}:
      "Shader"
    case Sort.Module{}:
      "Bend module"
    case Sort.Other{}:
      "File"

# The icon of each kind (Bend-UI's set: Lucide).
def kind_icon(+k: Sort) -> String:
  match k:
    case Sort.Folder{}:
      "folder"
    case Sort.Clip{}:
      "play"
    case Sort.Shader{}:
      "wand-sparkles"
    case Sort.Module{}:
      "code"
    case Sort.Other{}:
      "file-text"

# A shader's id in the project's catalog: its path inside the project's shaders folder
# (tools/shaders/catalog.js names it so).
def shader_id(+path: String) -> String:
  String.drop(path, String.length(assets() ++ "/shaders/"))

# A path inside the project's folder on disk (what the dev server reads and writes).
def on_disk(+path: String) -> String:
  String.drop(path, String.length(assets() ++ "/"))

# Is the path the project's own (under Assets), so the dev server can read it or make a folder in it?
def is_own(+path: String) -> Bool:
  (String.eq(path, assets()) || String.starts_with(path, assets() ++ "/"))

# ---------- A new folder ----------

def has_bad(+name: String) -> Bool:
  (String.contains(name, "/") || String.contains(name, "\\") || String.eq(name, ".") || String.eq(name, "..") || String.starts_with(name, "."))

def kid_named(es: List<&2, Tree.Entry>, +n: String) -> Bool:
  match es:
    case Nil{}:
      False{}
    case +h <> t:
      (String.eq(name(entry_path(h)), n) || kid_named(t, n))

def may_make_n(+paths: List<&2, String>, +at: String, +n: String) -> Bool:
  (is_own(at) && Bool.not(String.is_empty(n)) && Bool.not(has_bad(n)) && Bool.not(kid_named(kids(paths, at), n)))

# May a folder with this name be made in `at`? Only inside Assets, with a name that is one part
# of a path, not hidden, and not taken by what is already there.
def may_make(+paths: List<&2, String>, +at: String, +name: String) -> Bool:
  may_make_n(paths, at, String.trim(name))

def why_not_n(+paths: List<&2, String>, +at: String, +n: String) -> String:
  pick_s(Bool.not(is_own(at)), "Folders are made inside Assets.",
  pick_s(String.is_empty(n), "",
  pick_s(has_bad(n), "A name has no slash and does not start with a dot.",
  pick_s(kid_named(kids(paths, at), n), "This folder already has something with that name.", ""))))

# Why a name cannot be used, for the line under the field ("" when it can).
def why_not(+paths: List<&2, String>, +at: String, +name: String) -> String:
  why_not_n(paths, at, String.trim(name))

# The path of the new folder.
def made(+at: String, +name: String) -> String:
  Tree.under(at, String.trim(name))
