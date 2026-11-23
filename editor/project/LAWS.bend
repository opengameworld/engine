# The laws of the Project window's files (editor/project/files.bend). `bend editor/project/PROOF.bend`
# must print ALL PROOFS CHECK.

import Base
import ../../node_modules/bend-ui/TREE.bend as Tree
import ./files.bend as F

def some() -> List<&2, String>:
  ["scenes/Water.bend", "shaders/ripples.frag.glsl", "shaders/ripples.frag.glsl.json"]

# LAW: the project's files are listed under Assets, and a shader's settings file is left out.
law own_files_are_under_assets:
  {F.own(some()) == ["Assets/scenes/Water.bend", "Assets/shaders/ripples.frag.glsl"] : List<&2, String>}

# LAW: a project with no files is an empty Assets folder.
law no_files_is_an_empty_assets:
  {F.own([]) == ["Assets/"] : List<&2, String>}

# LAW: the folder tree holds the folders only, each once.
law the_tree_holds_folders:
  {F.folders(F.own(some())) == ["Assets/", "Assets/scenes/", "Assets/shaders/"] : List<&2, String>}

# LAW: a folder shows what is right inside it, folders first.
law a_folder_shows_its_own:
  {F.paths_of(F.kids(F.own(some()), "Assets")) == ["Assets/scenes", "Assets/shaders"] : List<&2, String>}

# LAW: a search finds files in any folder, by name, whatever the case.
law a_search_finds_files_anywhere:
  {F.paths_of(F.shown(F.own(some()), "Assets", "RIPP")) == ["Assets/shaders/ripples.frag.glsl"] : List<&2, String>}

# LAW: the breadcrumbs go from the top to the folder.
law the_trail_goes_down:
  {F.trail("Assets/shaders/water") == ["Assets", "Assets/shaders", "Assets/shaders/water"] : List<&2, String>}

# LAW: a new folder may not take a name that is there already.
law a_taken_name_cannot_be_made:
  {F.may_make(F.own(some()), "Assets", "shaders") == False{} : Bool}

# LAW: a new folder is made inside Assets only.
law folders_are_made_in_assets:
  {F.may_make(F.own(some()), "Library/Animations", "Mine") == False{} : Bool}

# LAW: a plain new name may be made.
law a_new_name_may_be_made:
  {F.may_make(F.own(some()), "Assets/shaders", "Water") == True{} : Bool}

# LAW: a name with a slash is refused.
law a_slash_is_refused:
  {F.may_make(F.own(some()), "Assets", "a/b") == False{} : Bool}

# LAW: a shader's id is its path inside the project's shaders folder.
law a_shader_id_is_its_file:
  {F.shader_id("Assets/shaders/ripples.frag.glsl") == "ripples.frag.glsl" : String}

# LAW: the dev server gets the path inside the project's folder.
law on_disk_drops_assets:
  {F.on_disk("Assets/shaders/water") == "shaders/water" : String}

# LAW: the dev server's listing is read one path per line, empty lines left out.
law a_listing_is_one_path_per_line:
  {F.listed("scene.bend\nshaders/\n\n") == ["scene.bend", "shaders/"] : List<&2, String>}

# LAW: a .bend in scenes/ is a scene.
law a_bend_in_scenes_is_a_scene:
  {F.kind(F.own(some()), "Assets/scenes/Water.bend") == F.Sort.Scene{} : F.Sort}

# LAW: a scene's file in scenes/saved/ is what the editor saved.
law a_saved_file_is_saved:
  {F.kind(F.own(some()), "Assets/scenes/saved/Water.bend") == F.Sort.Saved{} : F.Sort}

# LAW: a .bend in scripts/ is a script.
law a_bend_in_scripts_is_a_script:
  {F.kind(F.own(some()), "Assets/scripts/Spin.bend") == F.Sort.Script{} : F.Sort}

# LAW: a new script goes to scripts/, whatever folder is shown.
law a_script_goes_to_scripts:
  {F.new_file("script", "Spin") == "Assets/scripts/Spin.bend" : String}

# LAW: a new shader is a GLSL fragment shader in shaders/.
law a_shader_goes_to_shaders:
  {F.new_file("shader", "Glow") == "Assets/shaders/Glow.frag.glsl" : String}

# LAW: a scene's name is a word.
law a_name_with_a_space_is_refused:
  {F.may_create(F.own(some()), "scene", "Assets", "My Scene") == False{} : Bool}

# LAW: a scene that exists cannot be made again.
law a_scene_name_taken_is_refused:
  {F.may_create(F.own(some()), "scene", "Assets", "Water") == False{} : Bool}

# LAW: a new word may be a scene.
law a_new_scene_may_be_made:
  {F.may_create(F.own(some()), "scene", "Assets", "Beach") == True{} : Bool}

# LAW: a file's extension is the part after its last dot.
law the_extension_is_the_last_part:
  {F.ext(F.own(some()), "Assets/shaders/ripples.frag.glsl") == "glsl" : String}

# LAW: a folder has no extension.
law a_folder_has_no_extension:
  {F.ext(F.own(some()), "Assets/shaders") == "" : String}
