# The laws of engine/render (meshes and material graphs). `bend engine/render/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./mesh.bend as Mesh
import ./shader/node.bend as N
import ./shader/compile.bend as G
import ./material.bend as Mat
import ../../projects/water/water.bend as Water

# ---------- Meshes ----------

# LAW: a plane of 3 × 3 cells has 4 × 4 corners and two triangles per cell.
law plane_has_its_corners:
  {Mesh.vertex_count(Mesh.plane(3.0, 3)) == 16n : Nat}

law plane_has_two_triangles_per_cell:
  {Mesh.triangle_count(Mesh.plane(3.0, 3)) == 18n : Nat}

# LAW: every index names a vertex: the largest is the last corner.
law plane_indices_name_vertices:
  {Mesh.max_index(Mesh.indices(Mesh.plane(3.0, 3))) == 15 : U32}

# ---------- Material graphs ----------

# LAW: the water's material gives a color (a vec3), as a mesh's color must.
law water_color_is_a_color:
  {N.ty(Mat.graph(Water.material())) == N.Vec3{} : N.Ty}

# LAW: every parameter of the water's material has a value of the right size.
law water_material_is_complete:
  {Mat.complete(Water.material()) == True{} : Bool}

# LAW: a color parameter given one number is not complete.
law color_needs_three_numbers:
  for x: F32
  {Mat.complete(Mat.Material{N.Param{"tone", N.Vec3{}}, [Mat.Value{"tone", [x]}]}) == False{} : Bool}

# LAW: a value under another name does not fill the parameter.
law value_needs_the_parameters_name:
  for x: F32
  {Mat.complete(Mat.Material{N.Param{"tone", N.Vec3{}}, [Mat.Value{"tint", [x, x, x]}]}) == False{} : Bool}

# LAW: an instance keeps the graph; only the values change.
law instance_keeps_the_graph:
  for x: F32
  {Mat.graph(Mat.instance(Water.material(), [Mat.Value{"tone", [x, x, x]}])) == Mat.graph(Water.material()) : N.Node}

# LAW: a parameter used twice is one line and one uniform.
law parameter_used_twice_is_one_uniform:
  {G.count(G.graph(N.Add{N.Param{"k", N.Float{}}, N.Param{"k", N.Float{}}})) == 2 : U32}

# LAW: a color times a number is a color (brighter or darker).
law color_times_number_is_a_color:
  for r: F32
  for k: F32
  {N.ty(N.Mul{N.Rgb{r, r, r}, N.Num{k}}) == N.Vec3{} : N.Ty}

# LAW: a color plus a number does not fit; the graph is Bad, not a shader error.
law color_plus_number_is_bad:
  for r: F32
  for k: F32
  {N.ty(N.Add{N.Rgb{r, r, r}, N.Num{k}}) == N.Bad{} : N.Ty}

# LAW: mix moves between two colors by a number, never by a color.
law mix_by_a_color_is_bad:
  for r: F32
  {N.ty(N.Mix{N.Rgb{r, r, r}, N.Rgb{r, r, r}, N.Rgb{r, r, r}}) == N.Bad{} : N.Ty}

# LAW: a wave of the time is a float, so it can drive a mix.
law mix_by_a_wave_of_time_is_a_color:
  for r: F32
  {N.ty(N.Mix{N.Rgb{r, r, r}, N.Rgb{r, r, r}, N.Sin{N.Time{}}}) == N.Vec3{} : N.Ty}

# LAW: a node used twice gets one line: sin(time) + sin(time) is 3 lines
# (time, sin, +), not 5.
law shared_node_is_written_once:
  {G.count(G.graph(N.Add{N.Sin{N.Time{}}, N.Sin{N.Time{}}})) == 3 : U32}

# LAW: the output is the last line: every node it uses is written before it.
law output_is_the_last_line:
  {G.output(G.graph(N.Sin{N.Add{N.Time{}, N.Sin{N.Time{}}}})) == "n3" : String}
