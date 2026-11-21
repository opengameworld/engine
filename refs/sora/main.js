// The reference character's page: the shared editor (editor/app.js) on the
// reference scene, with its skin. Study reference only: refs/ never ships.

import Reference from "./scene.bend";
import { startEditor } from "../../editor/app.js";
import Camera from "../../engine/camera.bend";
import info from "./gen/skin.json";
import bin from "./gen/skin.bin" with { type: "file" };
import body from "./source/p_ism001_01.png";
import face from "./source/p_ism001_00.png";

startEditor(Reference.start(), {
  camera: Camera.close_up(),
  skins: { skin: { info, bin, textures: [body, face] } },
});
