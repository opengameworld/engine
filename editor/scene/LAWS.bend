# The laws of the Scene and Details panels. `bend editor/scene/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ../../engine/render/mesh.bend as Mesh
import ../../engine/render/shader/node.bend as N
import ../../engine/render/material.bend as Mat
import ../../projects/water/water.bend as Water
import ../../engine/scene/scene.bend as S
import ../../engine/core/transform.bend as Tr
import ../../projects/water/scene.bend as Content
import ./panels.bend as O
import ../../engine/core/vec.bend as V

# ---------- Scene and Details panels ----------
# Laws that edit use a one-cell plane: the checker works every list out in
# full, and the real water's 1681 vertices overflow its stack.

# LAW: the Scene panel lists the scene's things by name, in order.
law scene_panel_lists_the_scene:
  {O.names(Content.start()) == ["Water"] : List<&2, String>}

# LAW: a shown thing has a Transform section and a Material section.
law details_show_transform_and_material:
  {O.titles(O.sections(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 0)) == ["Transform", "Material"] : List<&2, String>}

# LAW: a hidden thing has only its Transform.
law hidden_thing_shows_only_transform:
  {O.titles(O.sections(S.Scene{[S.Thing{"empty", Tr.identity(), S.Hidden{}}]}, 0)) == ["Transform"] : List<&2, String>}

# LAW: typing 3 in Position X puts the thing at x = 3 and nothing else moves.
law typing_position_x_moves_to_it:
  {Tr.position(S.place(S.at(O.apply(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 0, O.Pos{0}, 3.0), 0))) == V.V3{3.0, 0.0, 0.0} : V.V3}

# LAW: editing never adds or removes things.
law editing_keeps_every_thing:
  for x: F32
  {S.count(O.apply(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 0, O.Size{1}, x)) == S.count(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}) : Nat}

# LAW: editing a material value keeps its graph, so no shader is compiled.
law editing_a_value_keeps_the_graph:
  for x: F32
  {Mat.graph(S.material(S.look(S.at(O.apply(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 0, O.Val{"tone", 1}, x), 0)))) == Mat.graph(Water.material()) : N.Node}

# LAW: an edit past the end of the list changes nothing.
law editing_past_the_end_changes_nothing:
  for x: F32
  {O.apply(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 7, O.Pos{0}, x) == S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]} : S.Scene}
