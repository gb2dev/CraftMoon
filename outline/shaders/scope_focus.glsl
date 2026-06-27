#[vertex]
#version 450 core
layout(location = 0) in vec3 vertex_attrib;
void main() {
    gl_Position = vec4(vertex_attrib, 1.0);
}

#[fragment]
#version 450 core
layout(location = 0) out vec4 frag_color;

layout(set = 0, binding = 0) uniform sampler2DMS u_color;

layout(push_constant, std430) uniform Params {
    vec2 resolution;
    float saturation;
    float vignette_inner;
    float darken;
    uint _pad0;
    uint _pad1;
    uint _pad2;
} params;

void main() {
    ivec2 p = ivec2(gl_FragCoord.xy);
    vec3 col = texelFetch(u_color, p, gl_SampleID).rgb;

    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, params.saturation);

    float max_half = min(params.resolution.x, params.resolution.y) * 0.5;
    float px = params.vignette_inner * max_half;
    float edge_x = min(gl_FragCoord.x, params.resolution.x - gl_FragCoord.x);
    float edge_y = min(gl_FragCoord.y, params.resolution.y - gl_FragCoord.y);
    float vx = pow(max(1.0 - edge_x / px, 0.0), 3.0);
    float vy = pow(max(1.0 - edge_y / px, 0.0), 3.0);
    float v = vx + vy - vx * vy;
    col *= 1.0 - params.darken * v;

    frag_color = vec4(col, 1.0);
}
