# The editor's asset icons: what each kind of file and each kind of thing looks like, in one
# place, as Godot keeps its editor icons in editor/icons/ (one SVG per class, 16×16, recolored for
# the light theme). The design is "Canto colorido" (the study in the artifact "Ícones do Editor",
# 2026-11-23): a file is a sheet with a folded corner, its kind's color lives in that corner only,
# its glyph is grey and takes the color under the pointer, and its extension is written small at
# its foot; a folder is a folder, a little wider than a sheet, that opens under the pointer.
#
# Every color is one of Bend-UI's color tokens (TOKENS.bend, drawn as CSS variables, with their
# dark values in the dark theme); nothing here invents one. Each kind says which token, and why:
#
#   Folder   warning-text   amber, the folder's color in Unity's, Godot's and macOS's file icons
#   Scene    accent-text    the scene is what the editor opens and works on: the accent
#   Saved    syntax-string  saved.bend holds written values, which a code view colors as strings
#   Module   syntax-type    a Bend module defines types and functions: the type color
#   Shader   syntax-keyword shader source, in the code color that stands out most
#   Clip     success-text   a clip is motion to play, the green of Play and "go"
#   Other    text-detail    a file the engine does not use: no color of its own
#
# The glyphs are 24-unit strokes, drawn here so they match the sheet; Bend-UI's set (Lucide) has no
# scene, shader or folder-that-opens shapes.
#
# Limits now:
# - A token name is text: a wrong one is caught by the laws (every tone is one of tokens()), not
#   by Bend-UI's own laws.
# - The icons are drawn at 16 px in trees and about 56 px in the Project window's tiles; no size
#   setting yet (Unity's zoom slider).

import Base
import ../../engine/scene/scene.bend as S
import ../project/files.bend as F

# One stroke of a glyph, in a 24 × 24 box: a path, or a circle.
type Mark is Data:
  Mark.Path{d: String}
  Mark.Circle{cx: String, cy: String, r: String}

# ---------- The colors ----------

# Bend-UI's color tokens an icon may use.
def tokens() -> List<&2, String>:
  ["warning-text", "accent-text", "syntax-string", "syntax-type", "syntax-keyword", "success-text", "text-detail"]

def tone(+k: F.Sort) -> String:
  match k:
    case F.Sort.Folder{}:
      "warning-text"
    case F.Sort.Scene{}:
      "accent-text"
    case F.Sort.Saved{}:
      "syntax-string"
    case F.Sort.Module{}:
      "syntax-type"
    case F.Sort.Shader{}:
      "syntax-keyword"
    case F.Sort.Clip{}:
      "success-text"
    case F.Sort.Other{}:
      "text-detail"

# The CSS that colors an icon: its kind's token.
def color(+k: F.Sort) -> String:
  "var(--" ++ tone(k) ++ ")"

# ---------- The glyphs ----------

def folder_glyph() -> List<&2, Mark>:
  [Mark.Path{"M3 7.5A2.5 2.5 0 0 1 5.5 5h3.6l2 2.2h7.4A2.5 2.5 0 0 1 21 9.7v7.8a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z"}]

# A scene: a cube, the World's things in a box.
def scene_glyph() -> List<&2, Mark>:
  [Mark.Path{"M12 3 4 7.5v9L12 21l8-4.5v-9z"}, Mark.Path{"M4 7.5 12 12l8-4.5M12 12v9"}]

# Saved: a disk.
def saved_glyph() -> List<&2, Mark>:
  [Mark.Path{"M5 3.5h11l3.5 3.5v12a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 19V5A1.5 1.5 0 0 1 5 3.5z"}, Mark.Path{"M7.5 3.5V8h7V3.5M7.5 20.5v-6h9v6"}]

# A module: Bend's braces.
def module_glyph() -> List<&2, Mark>:
  [Mark.Path{"M8.5 4C6.5 4 6.5 5.6 6.5 7v2c0 1.2-.8 2.3-2.3 2.6 1.5.3 2.3 1.4 2.3 2.6v2.3c0 1.4 0 3 2 3"}, Mark.Path{"M15.5 4c2 0 2 1.6 2 3v2c0 1.2.8 2.3 2.3 2.6-1.5.3-2.3 1.4-2.3 2.6v2.3c0 1.4 0 3-2 3"}]

# A shader: the sphere a material is shown on, with its light.
def shader_glyph() -> List<&2, Mark>:
  [Mark.Circle{"12", "12", "8.5"}, Mark.Path{"M3.6 12.6c2.4 2 14.4 2 16.8 0"}, Mark.Path{"M8.2 7.4a5 5 0 0 1 3.4-1.6"}]

# A clip: a figure in motion.
def clip_glyph() -> List<&2, Mark>:
  [Mark.Circle{"12", "4.6", "1.9"}, Mark.Path{"M12 7v6.2M12 9.2 8 12.4M12 9.2l4.2 2.3M12 13.2 8.8 19.8M12 13.2l4 5.6"}]

# Any other file: lines of text.
def other_glyph() -> List<&2, Mark>:
  [Mark.Path{"M7 8h10M7 12h10M7 16h6"}]

def glyph(+k: F.Sort) -> List<&2, Mark>:
  match k:
    case F.Sort.Folder{}:
      folder_glyph()
    case F.Sort.Scene{}:
      scene_glyph()
    case F.Sort.Saved{}:
      saved_glyph()
    case F.Sort.Module{}:
      module_glyph()
    case F.Sort.Shader{}:
      shader_glyph()
    case F.Sort.Clip{}:
      clip_glyph()
    case F.Sort.Other{}:
      other_glyph()

# ---------- Things, in the Hierarchy ----------

def pick_marks(c: Bool, +a: List<&2, Mark>, +b: List<&2, Mark>) -> List<&2, Mark>:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_s(c: Bool, +a: String, +b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# A character: a person.
def character_glyph() -> List<&2, Mark>:
  [Mark.Circle{"12", "7.5", "3.5"}, Mark.Path{"M5 20.5c.8-4 3.6-6 7-6s6.2 2 7 6"}]

# A hidden thing: an eye, struck through.
def hidden_glyph() -> List<&2, Mark>:
  [Mark.Path{"M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z"}, Mark.Circle{"12", "12", "2.6"}, Mark.Path{"M4 20 20 4"}]

# A thing's glyph: a character is a person, a shown thing the sphere its material is drawn on, a
# hidden thing an eye struck through.
def thing_glyph(+t: S.Thing) -> List<&2, Mark>:
  pick_marks(S.is_rigged(t), character_glyph(), pick_marks(S.is_shown(t), shader_glyph(), hidden_glyph()))

# A thing's color: a character is a clip's player (success-text), a shown thing carries a shader
# (syntax-keyword), a hidden thing has none (text-detail).
def thing_color(+t: S.Thing) -> String:
  pick_s(S.is_rigged(t), color(F.Sort.Clip{}), pick_s(S.is_shown(t), color(F.Sort.Shader{}), color(F.Sort.Other{})))

