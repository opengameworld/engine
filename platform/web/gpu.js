// The smallest pieces every WebGL2 drawing here needs: a Bend list as a flat
// array, and a program made from two shader texts. The shaders are written
// by Bend (engine/render/shader/glsl.bend, engine/render/material.bend); JS only hands the
// text to the GPU driver.
//
// Limits now:
// - flat() copies every number once. Fine at start-up, too slow per frame:
//   draw.js still calls it per frame for bone matrices and bone lines.

// A Bend list arrives as cons cells; the GPU wants a flat array.
export const flat = (list) => {
  const out = [];
  for (let l = list; l.$ === "Con"; l = l.tail) out.push(l.head);
  return out;
};

function shader(gl, type, src) {
  const s = gl.createShader(type);
  gl.shaderSource(s, src);
  gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
    const message = gl.getShaderInfoLog(s);
    gl.deleteShader(s);
    throw new Error(message || "Shader compilation failed.");
  }
  return s;
}

export function program(gl, vert, frag) {
  const p = gl.createProgram();
  const stages = [];
  try {
    stages.push(shader(gl, gl.VERTEX_SHADER, vert));
    stages.push(shader(gl, gl.FRAGMENT_SHADER, frag));
    for (const stage of stages) gl.attachShader(p, stage);
    gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
      throw new Error(gl.getProgramInfoLog(p) || "Shader link failed.");
    }
    for (const stage of stages) gl.detachShader(p, stage);
    return p;
  } catch (error) {
    gl.deleteProgram(p);
    throw error;
  } finally {
    for (const stage of stages) gl.deleteShader(stage);
  }
}
