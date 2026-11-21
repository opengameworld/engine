# Credits

The motions in this folder come from the "Universal Animation Library" by
Quaternius (https://quaternius.itch.io/universal-animation-library), its
free Standard version, under Creative Commons Zero (CC0 1.0),
https://creativecommons.org/publicdomain/zero/1.0/. The pack's own license
and readme are in `source/`.

`source/UAL1_Standard.glb` is the pack's file with root motion disabled,
unchanged. `gen/motions.bend` is what `tools/clips.ts` read from it,
following `clips.json`: 42 clips, each stored as turns from the T-pose so
it plays on any character that keeps the engine's rig standard.

The pack also has a file with root motion baked into every clip
(UAL1_Standard_RM.glb). It is not here yet: the engine does not read root
motion.

CC0 asks for no credit. The library shows this one anyway, on the folder.
