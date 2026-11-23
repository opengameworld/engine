# The Project window: the project's files and the engine's library, as Unity's two-column Project
# window shows them (Unreal: the Content Browser). editor/project/files.bend says what is listed.
#
#   left    the folders, as a tree (Bend-UI's TREE.bend makes its rows); a click shows a folder,
#           and a second click on the folder shown folds or unfolds it
#   top     the breadcrumbs of the folder shown, the search (any file, in any folder, by name),
#           and New folder (inside Assets)
#   right   what the folder holds, as tiles: a click picks an asset (the Inspector shows it), a
#           double click opens a folder
#
# Picking a clip tries it on the character selected, as the animation library always did
# (Mixamo's flow); Add in the Inspector keeps it. Picking a shader shows it in the Inspector, where
# Apply gives it to the thing selected. Picking a project file shows its text there.
#
# Limits now:
# - No drag and drop (Bend-UI's Web.bend has no drag event): an asset is used from the Inspector,
#   or, for a clip, by picking it.
# - The folder tree takes clicks only: its keys (TREE.bend's key) are not wired yet.
# - New folder makes an empty folder; no renaming, moving or deleting files from here, and no new
#   files: a script in this engine is a Rule, added in the Inspector (engine/script/rule.bend).
# - Making a folder and showing a file's text need `bun run dev`.
# - A clip's tile shows the source rig's stick figure, not the character in that pose.
# - The icons are editor/icons/'s: a file's kind and its extension decide them.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../node_modules/bend-ui/TREE.bend as Tree
import ../../node_modules/bend-ui/PANES.bend as Pn
import ../../engine/anim/library.bend as L
import ../../library/catalog.bend as Cat
import ../../engine/render/shader/asset.bend as A
import ../workspace/state.bend as W
import ../workspace/pieces.bend as P
import ../animation/view.bend as An
import ../shaders/view.bend as Sh
import ./files.bend as F
import ../icons/icons.bend as I
import ../icons/view.bend as Ic

# Every path the window lists: the project's files and the library's clips.
def all(+st: W.St) -> List<&2, String>:
  F.all(W.paths(W.files(st)))

# ---------- The folder tree (left) ----------

# A level sits one tree_indent (PANES.bend) further in than the one above it.
def indent(+level: U32) -> String:
  "calc(var(--space-2) + " ++ U32.show(((level - 1 : U32) * Pn.tree_indent() : U32)) ++ "px)"

def tree_row(+r: Tree.Row, +at: String) -> Web.HTML<W.Ev>:
  Tree.Row{path, name, level, folder, open, shown, pos, size} = r
  Web.node{"div", [Web.attr{"class", "tree__row"}, Web.attr{"role", "treeitem"}, Web.attr{"title", path},
    Web.attr{"aria-level", U32.show(level)}, Web.attr{"aria-posinset", U32.show(pos)}, Web.attr{"aria-setsize", U32.show(size)},
    Web.attr{"aria-expanded", Ui.bool_text(open)}, Web.attr{"aria-current", Ui.bool_text(String.eq(path, at))},
    Web.style{"padding-left", indent(level)}, Web.on{Web.click{W.f_tree{path}}}], [
    Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], P.pick_text(open, "chevron-down", "chevron-right")),
    Ic.mini(F.Sort.Folder{}),
    Ui.says(W.Ev, "span", "tree__name", name)]}

def row_shown(r: Tree.Row) -> Bool:
  Tree.Row{_, _, _, _, _, shown, _, _} = r
  shown

def tree_rows(rs: List<&2, Tree.Row>, +at: String) -> List<&2, Web.HTML<W.Ev>>:
  match rs:
    case Nil{}:
      Nil{}
    case +h <> t:
      List.append(&2, Web.HTML<W.Ev>, P.pick_html(row_shown(h), [tree_row(h, at)], Nil{}), tree_rows(t, at))

def folder_tree(+st: W.St) -> Web.HTML<W.Ev>:
  +f = W.files(st)
  Web.node{"div", [Web.attr{"class", "tree editor-project__tree"}, Web.attr{"role", "tree"}, Web.attr{"aria-label", "Folders"}],
    tree_rows(Tree.rows(F.folders(all(st)), W.open_folders(f)), W.at(f))}

# ---------- The bar (top) ----------

def crumbs(ps: List<&2, String>, +at: String) -> List<&2, Web.HTML<W.Ev>>:
  match ps:
    case Nil{}:
      Nil{}
    case +h <> Nil{}:
      [Web.node{"span", [Web.attr{"class", "breadcrumbs__item"}, Web.attr{"aria-current", "location"}], [Web.text{F.name(h)}]}]
    case +h <> t:
      Ui.button_with(W.Ev, [Ui.btn_link{}, Ui.btn_sm{}], "breadcrumbs__item", [Web.on{Web.click{W.f_go{h}}}], [Web.text{F.name(h)}]) <>
      Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "chevron-right") <> crumbs(t, at)

def search(+st: W.St) -> Web.HTML<W.Ev>:
  Ui.box(W.Ev, "div", "input-icon editor-project__search", [], [
    Ui.icon(W.Ev, "search"),
    Ui.input_with(W.Ev, [Ui.input_sm{}], "", [Web.attr{"type", "search"}, Web.attr{"placeholder", "Search"}, Web.attr{"aria-label", "Search the project"},
      Web.attr{"value", W.files_query(W.files(st))}, Web.on{Web.input{W.f_query{""}}}, Web.on{Web.change{W.a_left{}}}])])

def bar(+st: W.St) -> Web.HTML<W.Ev>:
  +f = W.files(st)
  Ui.box(W.Ev, "div", "editor-dock__bar", [], [
    Web.node{"nav", [Web.attr{"class", "breadcrumbs editor-project__crumbs"}, Web.attr{"aria-label", "Folder"}], crumbs(F.trail(W.at(f)), W.at(f))},
    search(st),
    Ui.button_with(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}], "", Web.on{Web.click{W.f_naming{True{}}}} <> P.disabled(Bool.not(F.is_own(W.at(f)))), [
      Ui.icon_with(W.Ev, [Ui.icon_sm{}], "", [], "plus"), Web.text{"New folder"}])])

# The New folder field, under the bar while it is open.
def naming(on: Bool, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match on:
    case False{}:
      Nil{}
    case True{}:
      +f = W.files(st)
      [Ui.box(W.Ev, "div", "editor-dock__bar editor-project__naming", [], [
        Web.node{"label", [Web.attr{"class", "field__label"}, Web.attr{"for", "editor-project-name"}], [Web.text{"Folder name"}]},
        Ui.input_with(W.Ev, [Ui.input_sm{}], "", [Web.attr{"id", "editor-project-name"}, Web.attr{"value", W.new_name(f)}, Web.attr{"autofocus", ""},
          Web.on{Web.input{W.f_name{""}}}, Web.on{Web.change{W.a_left{}}}]),
        Ui.button_with(W.Ev, [Ui.btn_filled{}, Ui.btn_sm{}], "", Web.on{Web.click{W.f_make{}}} <> P.disabled(Bool.not(F.may_make(all(st), W.at(f), W.new_name(f)))), [Web.text{"Create"}]),
        Ui.button(W.Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}], "Cancel", W.f_naming{False{}}),
        Ui.says(W.Ev, "span", "meta", F.why_not(all(st), W.at(f), W.new_name(f)))])]

# ---------- The tiles (right) ----------

def shader_broken(+st: W.St, +path: String) -> Bool:
  A.has_problem(A.problems(Sh.catalog(st)), F.shader_id(path))

def warning_mark(on: Bool) -> List<&2, Web.HTML<W.Ev>>:
  P.pick_html(on, [Ui.icon_with(W.Ev, [Ui.icon_sm{}], "editor-project__warning", [Web.attr{"aria-label", "Could not be used"}], "triangle-alert")], Nil{})

# A tile's picture: a clip's stick figure, or the icon of its kind.
# A tile's picture (editor/icons/): a clip shows its own pose on its sheet.
def pose_by(c: Bool, +cl: F.Clip) -> List<&2, F32>:
  match c:
    case True{}:
      L.entry_thumb(An.entry_at(L.entries(An.collection_at(Cat.collections(), F.clip_folder(cl))), F.clip_k(cl)))
    case False{}:
      Nil{}

def picture(+st: W.St, +path: String) -> Web.HTML<W.Ev>:
  Ic.tile(F.kind(all(st), path), F.ext(all(st), path), pose_by(F.is_clip(F.clip_at(path)), F.clip_at(path)))

def opens(folder: Bool, +path: String) -> List<&2, Web.Attr<W.Ev>>:
  P.pick_attrs(folder, [Web.on{Web.double_click{W.f_go{path}}}], Nil{})

def tile(+st: W.St, +path: String, +folder: Bool) -> Web.HTML<W.Ev>:
  Ui.button_with(W.Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "editor-project__tile",
    List.append(&2, Web.Attr<W.Ev>, [Web.attr{"type", "button"}, Web.attr{"title", path}, Web.attr{"aria-pressed", Ui.bool_text(String.eq(path, W.picked_path(W.files(st))))},
     Web.on{Web.click{W.f_pick{path}}}], opens(folder, path)), List.append(&2, Web.HTML<W.Ev>, [
    picture(st, path),
    Ui.says(W.Ev, "span", "editor-project__name", F.name(path))], warning_mark(shader_broken(st, path))))

def tiles(es: List<&2, Tree.Entry>, +st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  match es:
    case Nil{}:
      Nil{}
    case +h <> t:
      tile(st, F.entry_path(h), F.entry_folder(h)) <> tiles(t, st)

def content(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  +f = W.files(st)
  +es = F.shown(all(st), W.at(f), W.files_query(f))
  P.pick_html(List.is_empty(&2, Tree.Entry, es),
    [P.help(P.pick_text(String.is_empty(String.trim(W.files_query(f))), "This folder is empty.", "Nothing matches the search."))],
    [Web.node{"div", [Web.attr{"class", "editor-project__tiles"}, Web.attr{"role", "list"}], tiles(es, st)}])

def view(+st: W.St) -> List<&2, Web.HTML<W.Ev>>:
  bar(st) <> List.append(&2, Web.HTML<W.Ev>, naming(W.naming(W.files(st)), st), [
    Ui.box(W.Ev, "div", "editor-project", [], [
      Ui.box(W.Ev, "div", "editor-dock__scroll editor-project__folders", [], [folder_tree(st)]),
      Ui.box(W.Ev, "div", "editor-dock__scroll editor-project__content", [], content(st))])])

# ---------- What its clicks mean ----------

def on_files(+st: W.St, +f: W.Files) -> W.St:
  W.with_files(st, f)

# A folder of the tree clicked: the folder shown; clicked again, it folds or unfolds.
def treed(+st: W.St, +path: String) -> W.St:
  +f = W.files(st)
  +again = String.eq(W.at(f), path)
  +open = W.open_folders(f)
  on_files(st, W.with_files_query(W.with_at(W.with_open(f,
    P.pick_list(again, P.pick_list(F.has(open, path), Tree.closed(open, path), Tree.opened(open, path)), F.opened_to(open, path))), path), ""))

# A folder opened from the breadcrumbs or the tiles: shown, and open in the tree.
def went(+st: W.St, +path: String) -> W.St:
  +f = W.files(st)
  on_files(st, W.with_files_query(W.with_at(W.with_open(f, F.opened_to(W.open_folders(f), path)), path), ""))

# An asset picked: the Inspector shows it. A clip is tried on the character; a project file is
# read (editor/app.js asks the dev server, and hands its text back with f_text).
def clip_tried(+now: W.St, +c: F.Clip) -> W.St:
  An.tried(W.has_character(now), W.with_lib(now, W.with_pick(W.lib(now), F.clip_folder(c), F.clip_k(c))))

def file_read(+now: W.St, +path: String) -> W.St:
  P.pick_st((F.is_own(path) && Bool.not(F.is_folder(all(now), path))), W.asked(now, "read", F.on_disk(path)), now)

def picked_on(+now: W.St, +path: String) -> W.St:
  P.pick_st(F.is_clip(F.clip_at(path)), clip_tried(now, F.clip_at(path)), file_read(now, path))

def picked(+st: W.St, +path: String) -> W.St:
  picked_on(W.with_asset(on_files(st, W.with_picked(W.files(st), path)), True{}), path)

# Create pressed: the folder is asked of the dev server (editor/app.js), and the field closes.
def made_with(+st: W.St, +f: W.Files) -> W.St:
  W.asked(on_files(st, W.with_naming(f, False{})), "folder", F.on_disk(F.made(W.at(f), W.new_name(f))))

def made(+st: W.St) -> W.St:
  P.pick_st(F.may_make(all(st), W.at(W.files(st)), W.new_name(W.files(st))), made_with(st, W.files(st)), st)

# The project's files again, after a folder was made.
def listed(+st: W.St, +text: String) -> W.St:
  on_files(st, W.with_paths(W.files(st), F.listed(text)))

# A file's text, when it is the file still picked.
def read(+st: W.St, +path: String, +text: String) -> W.St:
  +f = W.files(st)
  P.pick_st(String.eq(F.on_disk(W.picked_path(f)), path), on_files(st, W.with_text(f, text)), st)
