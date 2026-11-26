"""Convert an FBX into a static Bend mesh with its authored corner normals.

Run from the engine root:
  blender --background --factory-startup --python-exit-code 1 \
    --python tools/static_fbx.py -- input.fbx projects/water/model.bend --ground

Limits now:
- Exports the rest pose as one indexed mesh for one engine material.
- Exports positions and normals. UVs, textures, and animation stay in the FBX.
"""

import argparse
import math
import os
import sys
from pathlib import Path

import bpy


def engine_axes(vector):
    x, y, z = vector
    return (float(x), float(z), float(-y))


def extract():
    vertices = []
    normals = []
    triangles = []
    splits = 0

    graph = bpy.context.evaluated_depsgraph_get()
    for obj in sorted(bpy.context.scene.objects, key=lambda item: item.name):
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        try:
            mesh.calc_loop_triangles()
            transform = evaluated.matrix_world
            linear = transform.to_3x3()
            normal_transform = linear.inverted().transposed()
            reverse_winding = linear.determinant() < 0
            corners = mesh.corner_normals
            positions = [engine_axes(transform @ vertex.co) for vertex in mesh.vertices]
            remap = {}
            used_vertices = set()
            for face in mesh.loop_triangles:
                if face.area <= 0:
                    continue
                triangle = []
                for vertex, loop in zip(face.vertices, face.loops, strict=True):
                    source_normal = corners[loop].vector
                    key = (vertex, tuple(source_normal))
                    if key not in remap:
                        transformed = (normal_transform @ source_normal).normalized()
                        remap[key] = len(vertices)
                        vertices.append(positions[vertex])
                        normals.append(engine_axes(transformed))
                        used_vertices.add(vertex)
                    triangle.append(remap[key])
                if reverse_winding:
                    triangle[1], triangle[2] = triangle[2], triangle[1]
                triangles.append(tuple(triangle))
            splits += len(remap) - len(used_vertices)
        finally:
            evaluated.to_mesh_clear()
    return vertices, normals, triangles, splits


def bend_float(value):
    magnitude = f"{abs(value):.6f}"
    return f"(0.0 - {magnitude} : F32)" if value < -0.0000005 else magnitude


def emit_list(name, bend_type, rows, format_value):
    # Small functions keep the generated lists within the compiler's parser stack.
    chunk_size = 64
    body = []
    names = []
    for start in range(0, len(rows), chunk_size):
        chunk = f"{name}_{start // chunk_size}"
        names.append(f"{chunk}()")
        lines = [", ".join(map(format_value, row)) for row in rows[start : start + chunk_size]]
        body.append(f"def {chunk}() -> List<&2, {bend_type}>:\n  [" + ",\n   ".join(lines) + "]\n")
    return "\n".join(body), f"List.concat(&2, {bend_type}, [{', '.join(names)}])"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--ground", action="store_true", help="Place the bottom of the mesh at y = 0")
    parser.add_argument("--credit", help="Source credit to include in the generated mesh")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(args.source), use_anim=False, use_custom_normals=True)
    vertices, normals, triangles, splits = extract()
    if not triangles or not all(math.isfinite(v) for point in vertices for v in point):
        raise ValueError("The FBX must contain finite triangles.")
    if not all(math.isclose(math.hypot(*n), 1.0, abs_tol=1e-5) for n in normals):
        raise ValueError("The FBX contains an invalid vertex normal.")
    minimum_y = min(point[1] for point in vertices)
    height = max(point[1] for point in vertices) - minimum_y
    if args.ground:
        vertices = [(x, y - minimum_y, z) for x, y, z in vertices]

    position_code, positions = emit_list("positions", "F32", vertices, bend_float)
    index_code, indices = emit_list("triangles", "U32", triangles, str)
    normal_code, normal_list = emit_list("normals", "F32", normals, bend_float)
    mesh_path = Path(__file__).resolve().parents[1] / "engine" / "mesh.bend"
    mesh_import = os.path.relpath(mesh_path, args.destination.resolve().parent).replace(os.sep, "/")
    if not mesh_import.startswith("."):
        mesh_import = f"./{mesh_import}"
    credit = "".join(f"# Source: {line}\n" for line in (args.credit or "").splitlines())
    pivot = "# The bottom sits at y = 0.\n" if args.ground else ""
    header = f"""# Static preview mesh converted from {args.source.name}.
{credit}# Blender Z-up was rotated to engine Y-up. Lengths are in meters.
{pivot}#
# Limits now:
# - This preview stores positions, triangle indices, and normals for one material.

import Base
import {mesh_import} as Mesh

"""
    shape = f"\ndef shape() -> Mesh.Mesh:\n  Mesh.WithNormals{{{positions},\n    {indices},\n    {normal_list}}}\n"
    args.destination.write_text(header + "\n".join((position_code, index_code, normal_code)) + shape, encoding="utf-8")
    print(f"Exported {len(vertices)} vertices and {len(triangles)} triangles; height {height:.4f} m")
    print(f"Duplicated {splits} vertices where FBX corners have different normals")


if __name__ == "__main__":
    main()
