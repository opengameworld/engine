# The reference character's page: the reference rig, imported by
# tools/gltf.ts, standing at the World's origin.
#
# "Sora (Kingdom Hearts Melody of Memory)" (https://skfb.ly/pPNsQ) by 雨宮レン,
# CC BY 4.0. Character (c) Square Enix / Disney. Study reference only:
# refs/ never ships, and nothing outside refs/ imports from it.

import Base
import ../../engine/scene.bend as S
import ../../engine/transform.bend as Tr
import ../../engine/figure.bend as Fig
import ./gen/skeleton.bend as Ref
import ./gen/rules.bend as Rules

def start() -> S.Scene:
  S.Scene{[
    S.Thing{"Reference", Tr.identity(), S.Rigged{Fig.make(Ref.skeleton(), "skin", Rules.rules())}}]}
