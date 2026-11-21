// Mesh programs and their uniform bindings. Bend supplies the mesh vertex shader.
// Limits now: linked programs are cached for the life of the WebGL context.
import { program as link } from "./gpu.js";

export function meshPrograms(gl, vertex) {
  const linked = new Map();
  return (fragment) => {
    if (linked.has(fragment)) return linked.get(fragment);
    const program = link(gl, vertex, fragment);
    const uniforms = new Map();
    const count = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS);
    for (let i = 0; i < count; i += 1) {
      const { name, size, type } = gl.getActiveUniform(program, i);
      uniforms.set(name, { size, type, location: gl.getUniformLocation(program, name) });
    }
    const mesh = { program, uniforms, vp: uniforms.get("u_vp").location, model: uniforms.get("u_model").location };
    linked.set(fragment, mesh);
    return mesh;
  };
}

export function assetUniforms(gl, mesh, asset) {
  const parameters = new Map(asset.parameters.map((p) => [p.name, p]));
  const bindings = new Map();
  for (const [uniform, { size, type, location }] of mesh.uniforms) {
    if (uniform === "u_vp" || uniform === "u_model") continue;
    // SPIRV-Cross emits HLSL constant buffer members as struct uniforms.
    const name = asset.language === "hlsl" ? uniform.split(".").at(-1) : uniform;
    const parameter = parameters.get(name);
    if (!parameter || bindings.has(name) || size !== 1 || location === null) {
      throw new Error(`Uniform "${uniform}" needs a unique scalar or RGB parameter in the descriptor.`);
    }
    let upload;
    switch (parameter.control) {
      case "number":
      case "slider":
        if (type === gl.FLOAT) upload = (value) => gl.uniform1f(location, value[0]);
        break;
      case "color":
        if (type === gl.FLOAT_VEC3) upload = (value) => gl.uniform3fv(location, value);
        break;
      case "toggle":
        if (type === gl.BOOL || type === gl.INT) upload = (value) => gl.uniform1i(location, value[0]);
        if (type === gl.UNSIGNED_INT) upload = (value) => gl.uniform1ui(location, value[0]);
        break;
      case "dropdown":
        if (type === gl.INT) upload = (value) => gl.uniform1i(location, value[0]);
        break;
    }
    if (!upload) throw new Error(`Uniform "${uniform}" has the wrong type for the ${parameter.control} control.`);
    bindings.set(name, upload);
  }
  return bindings;
}
