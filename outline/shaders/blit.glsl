#[vertex]
#version 450 core
layout(location = 0) in vec3 vertex_attrib;
void main() {
    gl_Position = vec4(vertex_attrib, 1.0);
}

#[fragment]
#version 450 core
layout(location = 0) out vec4 frag_color;

layout(set = 0, binding = 0) uniform sampler2DMS u_source;

void main() {
    ivec2 p = ivec2(gl_FragCoord.xy);
    frag_color = texelFetch(u_source, p, gl_SampleID);
}
