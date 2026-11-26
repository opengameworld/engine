// The engine's page: opens a scene of the project PROJECT.bend names (the page's ?project= and
// ?scene=, or the project's main scene) in the editor (editor/app.js), and gives it the
// mannequin's skin files, so any scene with the mannequin in it draws the skin. ?at= and ?pick=
// show a folder and an asset in the Project window (editor/app.js sets them after a Create); ?code=
// opens a script in the script editor (editor/code/).

import Project from "../PROJECT.bend";
import { startEditor } from "./app.js";
import shaders from "./shaders/catalog.generated.json";
import Mannequin from "../mannequin/scene.bend";
import info from "../mannequin/gen/skin.json";
import bin from "../mannequin/gen/skin.bin" with { type: "file" };
import body from "../mannequin/source/p_ism001_01.png";
import face from "../mannequin/source/p_ism001_00.png";

const params = new URLSearchParams(location.search);
const project = Project.preview(params.get("project") ?? "");
const scene = Project.scene_named(project, params.get("scene") ?? "");
startEditor(Project.opened(project, scene), {
  project,
  scene,
  rules: Project.scene_rules(project, scene),
  ownRules: Project.has_saved_rules(project, scene),
  made: Project.made(project, scene),
  removed: Project.removed(project, scene),
  base: Project.code(project, scene),
  camera: Project.camera(project),
  shaders: shaders[Project.folder(project)],
  folder: Project.folder(project),
  name: Project.name(project),
  at: params.get("at") ?? "",
  pick: params.get("pick") ?? "",
  // The scripts that do not compile (Play and the build wait for them), and the script to open.
  problems: Project.problems(project),
  offers: Project.offers(project),
  code: params.get("code") ?? "",
  skins: { [Mannequin.skin()]: { info, bin, textures: [body, face] } },
});
