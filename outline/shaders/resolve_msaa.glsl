#[compute]
#version 450

// Resolves the multisampled stencil-copy output into a single-sample seed
// texture for the compute-based jump-flood. A pixel is covered if any of its
// samples belong to an outlined object.
//
// For edge pixels we also nudge the seed to a sub-pixel position using the
// coverage gradient. This is what makes the final outline edge smooth instead
// of stair-stepping along the seed pixel grid (the seeds would otherwise snap
// to pixel centres). Coverage of the 3x3 neighbourhood is shared through
// workgroup memory so each pixel's coverage is only computed once.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2DMS u_msaa_src;
layout(rgba32f, set = 0, binding = 1) uniform image2D u_single_dst;

shared float s_cov[10][10];

float get_pixel_coverage(ivec2 coord, ivec2 size, int num_samples) {
	if (coord.x < 0 || coord.y < 0 || coord.x >= size.x || coord.y >= size.y) {
		return 0.0;
	}
	int count = 0;
	for (int i = 0; i < num_samples; i++) {
		if (texelFetch(u_msaa_src, coord, i).a > 0.0) {
			count++;
		}
	}
	return float(count) / float(num_samples);
}

void main() {
	ivec2 size = imageSize(u_single_dst);
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	int num_samples = textureSamples(u_msaa_src);

	// Load this pixel's coverage and the 1px halo into shared memory.
	float center_cov = get_pixel_coverage(coord, size, num_samples);
	int lx = int(gl_LocalInvocationID.x) + 1;
	int ly = int(gl_LocalInvocationID.y) + 1;
	s_cov[ly][lx] = center_cov;

	if (gl_LocalInvocationID.x == 0) {
		s_cov[ly][0] = get_pixel_coverage(coord - ivec2(1, 0), size, num_samples);
	}
	if (gl_LocalInvocationID.x == 7) {
		s_cov[ly][9] = get_pixel_coverage(coord + ivec2(1, 0), size, num_samples);
	}
	if (gl_LocalInvocationID.y == 0) {
		s_cov[0][lx] = get_pixel_coverage(coord - ivec2(0, 1), size, num_samples);
	}
	if (gl_LocalInvocationID.y == 7) {
		s_cov[9][lx] = get_pixel_coverage(coord + ivec2(0, 1), size, num_samples);
	}
	if (gl_LocalInvocationID.x == 0 && gl_LocalInvocationID.y == 0) {
		s_cov[0][0] = get_pixel_coverage(coord - ivec2(1, 1), size, num_samples);
	}
	if (gl_LocalInvocationID.x == 7 && gl_LocalInvocationID.y == 0) {
		s_cov[0][9] = get_pixel_coverage(coord + ivec2(1, -1), size, num_samples);
	}
	if (gl_LocalInvocationID.x == 0 && gl_LocalInvocationID.y == 7) {
		s_cov[9][0] = get_pixel_coverage(coord + ivec2(-1, 1), size, num_samples);
	}
	if (gl_LocalInvocationID.x == 7 && gl_LocalInvocationID.y == 7) {
		s_cov[9][9] = get_pixel_coverage(coord + ivec2(1, 1), size, num_samples);
	}

	barrier();

	if (coord.x >= size.x || coord.y >= size.y) {
		return;
	}

	vec4 result = vec4(-1.0, -1.0, 0.0, 0.0);
	if (center_cov > 0.0) {
		vec2 seed = vec2(coord) + vec2(0.5);

		// Interior pixels (fully covered) stay at the pixel centre; only edge
		// pixels are nudged toward the true silhouette using the coverage
		// gradient (Sobel), giving sub-pixel-accurate seeds.
		if (center_cov < 1.0) {
			float dx = (s_cov[ly + 1][lx + 1] + 2.0 * s_cov[ly][lx + 1] + s_cov[ly - 1][lx + 1])
			         - (s_cov[ly + 1][lx - 1] + 2.0 * s_cov[ly][lx - 1] + s_cov[ly - 1][lx - 1]);
			float dy = (s_cov[ly + 1][lx + 1] + 2.0 * s_cov[ly + 1][lx] + s_cov[ly + 1][lx - 1])
			         - (s_cov[ly - 1][lx + 1] + 2.0 * s_cov[ly - 1][lx] + s_cov[ly - 1][lx - 1]);
			vec2 normal = vec2(dx, dy);
			float len = length(normal);
			if (len > 0.001) {
				normal /= len;
				seed += normal * (0.5 - center_cov);
			}
		}

		result = vec4(seed, 0.0, 1.0);
	}

	imageStore(u_single_dst, coord, result);
}
