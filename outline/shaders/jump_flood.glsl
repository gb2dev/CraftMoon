#[compute]
#version 450

const float INFINITY = 1e9;

// Invocations in the (x, y, z) dimension.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Source seed texture and destination image (ping-ponged each pass).
layout(set = 0, binding = 0) uniform sampler2D u_src_texture;
layout(rgba32f, set = 0, binding = 1) uniform image2D u_dest_image;

layout(push_constant, std430) uniform Params {
	uint stride;
	uint _pad0;
	uint _pad1;
	uint _pad2;
} params;

// Performs a single jump-flood pass: for each pixel, look at the 8 neighbours at
// the current stride plus itself, and keep the nearest seed position found.
void main() {
	ivec2 image_size = imageSize(u_dest_image);
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (pos.x >= image_size.x || pos.y >= image_size.y) {
		return;
	}

	float best_dist = INFINITY;
	vec2 best_pos = vec2(-1.0);

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			ivec2 offset = ivec2(x * int(params.stride), y * int(params.stride));
			ivec2 offset_pos = clamp(pos + offset, ivec2(0, 0), image_size - 1);
			vec4 nearest_val = texelFetch(u_src_texture, offset_pos, 0);
			vec2 nearest_pos = nearest_val.rg;
			if (nearest_pos.x != -1.0) {
				vec2 delta = (vec2(pos) + vec2(0.5)) - nearest_pos;
				float dist = dot(delta, delta);
				if (dist < best_dist) {
					best_dist = dist;
					best_pos = nearest_pos;
				}
			}
		}
	}

	imageStore(
		u_dest_image,
		pos,
		best_dist != INFINITY ?
			vec4(best_pos.x, best_pos.y, 0.0, 1.0) :
			vec4(-1.0, -1.0, 0.0, 0.0));
}
