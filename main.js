// The engine's page: opens the project PROJECT.bend names in the editor
// (editor/app.js), and gives it the mannequin's skin files, so any scene
// with the mannequin in it draws the skin.

import Project from "./PROJECT.bend";
import { startEditor } from "./editor/app.js";
import shaders from "./editor/shaders/catalog.generated.json";
import Mannequin from "./mannequin/scene.bend";
import info from "./mannequin/gen/skin.json";
import bin from "./mannequin/gen/skin.bin" with { type: "file" };
import body from "./mannequin/source/p_ism001_01.png";
import face from "./mannequin/source/p_ism001_00.png";

const slug = new URLSearchParams(location.search).get("project") ?? "";
const project = Project.preview(slug);
startEditor(Project.start(project), {
  camera: Project.camera(project),
  shaders: shaders[Project.folder(project)],
  folder: Project.folder(project),
  skins: { [Mannequin.skin()]: { info, bin, textures: [body, face] } },
});
