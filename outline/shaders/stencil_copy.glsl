#[vertex]
#version 450 core
layout(location = 0) in vec3 vertex_attrib;

void main()
{
    gl_Position = vec4(vertex_attrib, 1.0);
}

#[fragment]
#version 450 core
layout (location = 0) out vec4 frag_color;

// Only fragments that pass the stencil test (stencil & mask == reference) are
// drawn, so every fragment we reach here belongs to an outlined object. We seed
// the jump-flood buffer with this pixel's own position. Background pixels are
// left at the framebuffer clear value (-1, -1, ...) which marks them empty.
//
// .a is set to 1.0 so the MSAA resolve pass can detect covered samples.
void main() {
    vec2 pos = floor(gl_FragCoord.xy) + vec2(0.5);
    frag_color = vec4(pos, 0.0, 1.0);
}
