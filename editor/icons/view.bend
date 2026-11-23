# The icons on screen (editor/icons/icons.bend says what each one is): drawn as SVG with Web.bend.
#
#   tile(kind, ext, pose)   the Project window's tile: a sheet with its kind's color in the folded
#                           corner, its grey glyph (a clip's own pose, when it has one) and its
#                           extension at its foot; or a folder, a little wider than a sheet
#   mini(kind)              the same, at 16 px, for the folder tree
#   glyph(marks, color)     a glyph at 16 px in a color, for the Hierarchy
#   styles()                the icons' CSS, with Bend-UI's tokens
#
# Under the pointer, a sheet's glyph takes its color and its corner lifts, and a folder opens (its
# front leans and a sheet rises from it). Accessibility (ACCESSIBILITY.bend): with reduce motion on
# (body[data-motion="reduce"], set by editor/workspace/view.bend), nothing moves: only the color
# changes.
#
# Limits now:
# - A folder's open look is the same for an empty one.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../workspace/state.bend as W
import ../animation/view.bend as An
import ../project/files.bend as F
import ./icons.bend as I

def mark(+m: I.Mark) -> Web.HTML<W.Ev>:
  match m:
    case I.Mark.Path{d}:
      Web.node{"path", [Web.attr{"d", d}], []}
    case I.Mark.Circle{cx, cy, r}:
      Web.node{"circle", [Web.attr{"cx", cx}, Web.attr{"cy", cy}, Web.attr{"r", r}], []}

def marks(ms: List<&2, I.Mark>) -> List<&2, Web.HTML<W.Ev>>:
  match ms:
    case Nil{}:
      Nil{}
    case +h <> t:
      mark(h) <> marks(t)

def tint(+color: String) -> Web.Attr<W.Ev>:
  Web.style{"--c", color}

# A glyph at 16 px, in a color.
def glyph(+ms: List<&2, I.Mark>, +color: String) -> Web.HTML<W.Ev>:
  Web.node{"svg", [Web.attr{"class", "editor-icon editor-icon--glyph"}, Web.attr{"viewBox", "0 0 24 24"}, Web.attr{"aria-hidden", "true"}, tint(color)], marks(ms)}

# ---------- The folder ----------

def folder_shape() -> Web.HTML<W.Ev>:
  Web.node{"svg", [Web.attr{"class", "editor-icon__folder"}, Web.attr{"viewBox", "0 0 56 56"}, Web.attr{"aria-hidden", "true"}], [
    Web.node{"path", [Web.attr{"class", "editor-icon__back"}, Web.attr{"d", "M3 13a3 3 0 0 1 3-3h13l4.5 4.2H50a3 3 0 0 1 3 3V49a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3z"}], []},
    Web.node{"rect", [Web.attr{"class", "editor-icon__paper"}, Web.attr{"x", "10"}, Web.attr{"y", "16"}, Web.attr{"width", "36"}, Web.attr{"height", "22"}, Web.attr{"rx", "2"}], []},
    Web.node{"path", [Web.attr{"class", "editor-icon__front"}, Web.attr{"d", "M3 23a3 3 0 0 1 3-3h44a3 3 0 0 1 3 3v26a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3z"}], []}]}

# ---------- The sheet ----------

# What sits on the sheet: a clip's own pose (engine/anim/library.bend's thumbnail, in a 40 box),
# or the kind's glyph.
def face_by(none: Bool, +k: F.Sort, +pose: List<&2, F32>) -> Web.HTML<W.Ev>:
  match none:
    case True{}:
      Web.node{"g", [Web.attr{"class", "editor-icon__glyph"}, Web.attr{"transform", "translate(11 11)"}], marks(I.glyph(k))}
    case False{}:
      Web.node{"g", [Web.attr{"class", "editor-icon__pose"}, Web.attr{"transform", "translate(8 8) scale(0.75)"}], An.picture_kids(pose)}

def face(+k: F.Sort, +pose: List<&2, F32>) -> Web.HTML<W.Ev>:
  face_by(List.is_empty(&2, F32, pose), k, pose)

def foot_by(none: Bool, +ext: String) -> List<&2, Web.HTML<W.Ev>>:
  match none:
    case True{}:
      Nil{}
    case False{}:
      [Web.node{"text", [Web.attr{"class", "editor-icon__ext"}, Web.attr{"x", "23"}, Web.attr{"y", "50"}, Web.attr{"text-anchor", "middle"}], [Web.text{ext}]}]

def foot(+ext: String) -> List<&2, Web.HTML<W.Ev>>:
  foot_by(String.is_empty(ext), ext)

def sheet(+k: F.Sort, +ext: String, +pose: List<&2, F32>) -> Web.HTML<W.Ev>:
  Web.node{"svg", [Web.attr{"class", "editor-icon__sheet"}, Web.attr{"viewBox", "0 0 46 56"}, Web.attr{"aria-hidden", "true"}],
    Web.node{"path", [Web.attr{"class", "editor-icon__page"}, Web.attr{"d", "M5 1.5h29l9.5 9.5v41a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3v-48a3 3 0 0 1 3-3z"}], []} <>
    Web.node{"path", [Web.attr{"class", "editor-icon__fold"}, Web.attr{"d", "M34 1.5v7a2.5 2.5 0 0 0 2.5 2.5h7z"}], []} <>
    face(k, pose) <> foot(ext)}

def shape(+k: F.Sort, +ext: String, +pose: List<&2, F32>) -> Web.HTML<W.Ev>:
  match k:
    case F.Sort.Folder{}:
      folder_shape()
    case _:
      sheet(k, ext, pose)

# The Project window's tile picture.
def tile(+k: F.Sort, +ext: String, +pose: List<&2, F32>) -> Web.HTML<W.Ev>:
  Web.node{"span", [Web.attr{"class", "editor-icon editor-icon--tile"}, tint(I.color(k))], [shape(k, ext, pose)]}

# ---------- 16 px ----------

def mini_sheet() -> Web.HTML<W.Ev>:
  Web.node{"svg", [Web.attr{"class", "editor-icon__mini"}, Web.attr{"viewBox", "0 0 14 16"}, Web.attr{"aria-hidden", "true"}], [
    Web.node{"path", [Web.attr{"class", "editor-icon__page"}, Web.attr{"d", "M2 .8h7.5l3.7 3.7v10.2a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V1.8a1 1 0 0 1 1-1z"}], []},
    Web.node{"path", [Web.attr{"class", "editor-icon__fold"}, Web.attr{"d", "M9.5.8v3.7h3.7z"}], []}]}

def mini_of(+k: F.Sort) -> Web.HTML<W.Ev>:
  match k:
    case F.Sort.Folder{}:
      glyph(I.glyph(k), I.color(k))
    case _:
      Web.node{"span", [Web.attr{"class", "editor-icon editor-icon--mini"}, tint(I.color(k))], [mini_sheet()]}

def mini(+k: F.Sort) -> Web.HTML<W.Ev>:
  mini_of(k)

# ---------- Styles ----------

def styles() -> String:
  ".editor-icon { flex: none; display: inline-grid; place-items: center; }" ++
  ".editor-icon--glyph { width: 16px; height: 16px; fill: none; stroke: var(--c); stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }" ++
  ".editor-icon--mini { width: 16px; height: 16px; }" ++
  ".editor-icon__mini { width: 14px; height: 16px; }" ++
  ".editor-icon__mini .editor-icon__page { fill: var(--surface-2); stroke: var(--border-strong); stroke-width: 1; }" ++
  ".editor-icon__mini .editor-icon__fold { fill: var(--c); }" ++
  ".editor-icon--tile { width: calc(var(--space-7) + var(--space-2)); height: calc(var(--space-7) + var(--space-2)); transition: transform var(--duration) var(--ease); }" ++
  ".editor-icon__sheet { width: 46px; height: 56px; overflow: visible; }" ++
  ".editor-icon__folder { width: 56px; height: 56px; overflow: visible; }" ++
  ".editor-icon svg * { transform-box: view-box; }" ++
  ".editor-icon__page { fill: var(--surface-2); stroke: var(--border-strong); stroke-width: 1.2; }" ++
  ".editor-icon__fold { fill: var(--c); stroke: var(--c); stroke-width: 1.2; transform-origin: 40px 7px; transition: transform var(--duration) var(--ease); }" ++
  ".editor-icon__glyph { fill: none; stroke: var(--text-2); stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; transition: stroke var(--duration) var(--ease); }" ++
  ".editor-icon__pose { fill: none; stroke: var(--text-2); stroke-width: 2.2; stroke-linecap: round; transition: stroke var(--duration) var(--ease); }" ++
  ".editor-icon__pose circle { fill: var(--text-2); stroke: none; transition: fill var(--duration) var(--ease); }" ++
  ".editor-icon__ext { font-family: var(--font-mono); font-size: 7.5px; letter-spacing: 0.04em; text-transform: uppercase; fill: var(--text-detail); }" ++
  ".editor-icon__back { fill: color-mix(in oklab, var(--c) 30%, var(--surface)); stroke: var(--c); stroke-width: 1.4; }" ++
  ".editor-icon__front { fill: color-mix(in oklab, var(--c) 48%, var(--surface)); stroke: var(--c); stroke-width: 1.4; transform-origin: 28px 52px; transition: transform var(--duration) var(--ease); }" ++
  ".editor-icon__paper { fill: var(--text); transition: transform var(--duration) var(--ease); }" ++
  ".editor-project__tile:hover .editor-icon__glyph, .editor-project__tile[aria-pressed='true'] .editor-icon__glyph { stroke: var(--c); }" ++
  ".editor-project__tile:hover .editor-icon__pose, .editor-project__tile[aria-pressed='true'] .editor-icon__pose { stroke: var(--c); }" ++
  ".editor-project__tile:hover .editor-icon__pose circle, .editor-project__tile[aria-pressed='true'] .editor-icon__pose circle { fill: var(--c); }" ++
  ".editor-project__tile:hover .editor-icon--tile { transform: translateY(-2px); }" ++
  ".editor-project__tile:hover .editor-icon__fold { transform: rotate(-16deg) translate(-1px, -1px); }" ++
  ".editor-project__tile:hover .editor-icon__front { transform: skewX(-7deg) scaleY(0.9); }" ++
  ".editor-project__tile:hover .editor-icon__paper { transform: translateY(-5px); }" ++
  "body[data-motion='reduce'] .editor-icon--tile, body[data-motion='reduce'] .editor-icon__fold, body[data-motion='reduce'] .editor-icon__front, body[data-motion='reduce'] .editor-icon__paper { transition: none !important; transform: none !important; }" ++
  "body[data-motion='reduce'] .editor-icon__glyph, body[data-motion='reduce'] .editor-icon__pose, body[data-motion='reduce'] .editor-icon__pose circle { transition: none !important; }"
