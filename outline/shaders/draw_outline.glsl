#[vertex]
#version 450 core
layout(location = 0) in vec3 vertex_attrib;
void main() {
    gl_Position = vec4(vertex_attrib, 1.0);
}

#[fragment]
#version 450 core
layout(location = 0) out vec4 frag_color;

layout(set = 0, binding = 0) uniform sampler2D u_src_texture;

layout(push_constant, std430) uniform Params {
    vec4 color;
    vec2 resolution;
    uint dist; // outline thickness, squared
    uint _pad0;
} params;

// This pass only runs on fragments OUTSIDE the outlined objects (the pipeline
// stencil test discards interior pixels). A fragment is part of the outline if
// the nearest object pixel (from the jump-flood buffer) is within `thickness`.
void main() {
    if (params.dist == 0) {
        discard;
    }

    ivec2 screen_pos = ivec2(gl_FragCoord.xy);
    vec4 value_discrete = texelFetch(u_src_texture, screen_pos, 0);

    // No seed reached this pixel (nothing outlined on screen).
    if (value_discrete.r < 0.0) {
        discard;
    }

    // Sub-pixel distance evaluation based on the true sample position. With MSAA
    // this runs per-sample (sample shading is enabled on the pipeline) which
    // gives anti-aliased outline edges.
    vec2 true_pos = floor(gl_FragCoord.xy) + gl_SamplePosition;
    vec2 texel_pos = true_pos - vec2(0.5);
    ivec2 i_pos = ivec2(floor(texel_pos));

    ivec2 p0 = clamp(i_pos, ivec2(0), ivec2(params.resolution) - 1);
    ivec2 p1 = clamp(i_pos + ivec2(1), ivec2(0), ivec2(params.resolution) - 1);

    vec4 v00 = texelFetch(u_src_texture, p0, 0);
    vec4 v10 = texelFetch(u_src_texture, ivec2(p1.x, p0.y), 0);
    vec4 v01 = texelFetch(u_src_texture, ivec2(p0.x, p1.y), 0);
    vec4 v11 = texelFetch(u_src_texture, p1, 0);

    float max_d = max(sqrt(float(params.dist)), 1.0);

    // Distance to the nearest object pixel. Checking the centre plus the 4
    // bilinear neighbours gives a sub-pixel-accurate distance field.
    float min_dist = 1e9;
    vec4 seeds[5] = vec4[](value_discrete, v00, v10, v01, v11);
    for (int i = 0; i < 5; i++) {
        if (seeds[i].r >= 0.0) {
            min_dist = min(min_dist, distance(true_pos, seeds[i].rg));
        }
    }
    if (min_dist > 1e8) {
        discard;
    }

    // Analytic 1px feather at the outer edge so the outline is anti-aliased
    // independent of the MSAA sample count.
    float coverage = clamp(max_d - min_dist + 0.5, 0.0, 1.0);
    if (coverage <= 0.0) {
        discard;
    }

    frag_color = vec4(params.color.rgb, params.color.a * coverage);
}
