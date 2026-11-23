# The laws of the editor's icons (editor/icons/icons.bend). `bend editor/icons/PROOF.bend` must print
# ALL PROOFS CHECK.

import Base
import ../project/files.bend as F
import ./icons.bend as I

def has_marks(ms: List<&2, I.Mark>) -> Bool:
  Bool.not(List.is_empty(&2, I.Mark, ms))

# LAW: a folder's color is one of Bend-UI's tokens.
law the_folder_color_is_a_token:
  {F.has(I.tokens(), I.tone(F.Sort.Folder{})) == True{} : Bool}

# LAW: a folder has a glyph.
law a_folder_has_a_glyph:
  {has_marks(I.glyph(F.Sort.Folder{})) == True{} : Bool}

# LAW: a scene's color is one of Bend-UI's tokens.
law the_scene_color_is_a_token:
  {F.has(I.tokens(), I.tone(F.Sort.Scene{})) == True{} : Bool}

# LAW: a scene has a glyph.
law a_scene_has_a_glyph:
  {has_marks(I.glyph(F.Sort.Scene{})) == True{} : Bool}

# LAW: a saved's color is one of Bend-UI's tokens.
law the_saved_color_is_a_token:
  {F.has(I.tokens(), I.tone(F.Sort.Saved{})) == True{} : Bool}

# LAW: a saved has a glyph.
law a_saved_has_a_glyph:
  {has_marks(I.glyph(F.Sort.Saved{})) == True{} : Bool}

# LAW: a module's color is one of Bend-UI's tokens.
law the_module_color_is_a_token:
  {F.has(I.tokens(), I.tone(F.Sort.Module{})) == True{} : Bool}

# LAW: a module has a glyph.
law a_module_has_a_glyph:
  {has_marks(I.glyph(F.Sort.Module{})) == True{} : Bool}

# LAW: a shader's color is one of Bend-UI's tokens.
law the_shader_color_is_a_token:
  {F.has(I.tokens(), I.tone(F.Sort.Shader{})) == True{} : Bool}

# LAW: a shader has a glyph.
law a_shader_has_a_glyph:
  {has_marks(I.glyph(F.Sort.Shader{})) == True{} : Bool}

# LAW: a clip's color is one of Bend-UI's tokens.
law the_clip_color_is_a_token:
  {F.has(I.tokens(), I.tone(F.Sort.Clip{})) == True{} : Bool}

# LAW: a clip has a glyph.
law a_clip_has_a_glyph:
  {has_marks(I.glyph(F.Sort.Clip{})) == True{} : Bool}

# LAW: a other's color is one of Bend-UI's tokens.
law the_other_color_is_a_token:
  {F.has(I.tokens(), I.tone(F.Sort.Other{})) == True{} : Bool}

# LAW: a other has a glyph.
law a_other_has_a_glyph:
  {has_marks(I.glyph(F.Sort.Other{})) == True{} : Bool}
